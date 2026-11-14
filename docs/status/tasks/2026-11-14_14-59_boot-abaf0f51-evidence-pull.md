# Boot evidence pull: id8 abaf0f51 (full: abaf0f511515482ba85ec05b7adf3492)

Pulled 2026-11-14 14:59 UTC by scripts/boot-evidence-pull.sh (canonical sections; parameterizes the freeze-27/28 bespoke pulls).
Boot window: 2026-11-14 09:29:52 -> 2026-11-14 15:41:18 (journalctl --list-boots).
Pre-vacuum gate: this file is the docs/status evidence for boot id8 abaf0f51 — commit it, then re-run scripts/pre-vacuum-evidence-gate.sh.

## Boot boundary (first 3 / last 12 lines — crash-vs-clean-shutdown discriminator)

### First 3 lines
```
Nov 14 09:29:52 evo-x2 kernel: Linux version 7.3.3 (nixbld@localhost) (gcc (GCC) 16.2.0, GNU ld (GNU Binutils) 2.46) #1-NixOS SMP PREEMPT_DYNAMIC @1793989110
Nov 14 09:29:52 evo-x2 kernel: Command line: initrd=\EFI\nixos\hax4lzv0p0czdmnqci6q20ywkam7cq9h-initrd-linux-7.3.3-initrd.efi init=/nix/store/xfbd8lvrkwkla7w2ffri64mnj5ssf7i4-nixos-system-evo-x2-26.11.20261107.f4a03c0/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.backend=efi pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=128M nmi_watchdog=panic softlockup_panic=1
Nov 14 09:29:52 evo-x2 kernel: x86/split lock detection: #DB: warning on user-space bus_locks
```

### Last 12 lines
```
Nov 14 15:41:18 evo-x2 systemd[1]: Unmounting /home/lars/.cache/go-mod...
Nov 14 15:41:18 evo-x2 systemd[1]: Unmounting /home/lars/.cache/golangci-lint...
Nov 14 15:41:18 evo-x2 systemd[1]: Unmounting /home/lars/.cache/nix...
Nov 14 15:41:18 evo-x2 systemd[1]: Unmounting /home/lars/tmp...
Nov 14 15:41:18 evo-x2 systemd[1]: Unmounting /mnt/btrfs-root...
Nov 14 15:41:18 evo-x2 systemd[1]: Unmounting /run/keys...
Nov 14 15:41:18 evo-x2 systemd[1]: Unmounting /run/secrets.d...
Nov 14 15:41:18 evo-x2 systemd[1]: Unmounting /run/wrappers...
Nov 14 15:41:18 evo-x2 systemd[1]: Unmounting /tmp...
Nov 14 15:41:18 evo-x2 systemd[1]: Stopping Flush Journal to Persistent Storage...
Nov 14 15:41:18 evo-x2 systemd[1]: boot.mount: Deactivated successfully.
Nov 14 15:41:18 evo-x2 systemd[1]: Unmounted /boot.
```

## Census
- oom-lines: 10
- oom kill-pass join: 2 killed process(es) — 2 memcg-attested, 0 unit-joined, 0 unresolved
- guard-lines (memory-emergency-guard): 1273
- thermal-THROTTLE-lines: 5
- kernel panic/BUG/oops lines: 4

## Kernel OOM lines (all)
```
Nov 14 10:00:08 evo-x2 kernel: nix invoked oom-killer: gfp_mask=0x100cca(GFP_HIGHUSER_MOVABLE), order=0, oom_score_adj=0
Nov 14 10:00:08 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_MEMCG,nodemask=(null),cpuset=/,mems_allowed=0,oom_memcg=/system.slice/tq-agent-pool.service,task_memcg=/system.slice/tq-agent-pool.service,task=nix,pid=272197,uid=1000
Nov 14 10:02:41 evo-x2 kernel: nix invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
Nov 14 10:02:41 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_MEMCG,nodemask=(null),cpuset=/,mems_allowed=0,oom_memcg=/system.slice/tq-agent-pool.service,task_memcg=/system.slice/tq-agent-pool.service,task=nix,pid=1515201,uid=1000
Nov 14 14:47:29 evo-x2 kernel: kswapd0 invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
Nov 14 14:48:38 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_NONE,nodemask=(null),cpuset=/,mems_allowed=0,global_oom,task_memcg=/system.slice/llama-vlm-cap.service,task=llama-server,pid=3265754,uid=1000
Nov 14 14:48:38 evo-x2 kernel: Out of memory: Killed process 3265754 (llama-server) total-vm:16839428kB, anon-rss:2377644kB, file-rss:2112kB, shmem-rss:0kB, UID:1000 pgtables:21812kB oom_score_adj:300
Nov 14 14:48:38 evo-x2 kernel: kswapd0 invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
Nov 14 14:48:38 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_NONE,nodemask=(null),cpuset=/,mems_allowed=0,global_oom,task_memcg=/user.slice/user-1000.slice/user@1000.service/app.slice/helium.service,task=helium,pid=255935,uid=1000
Nov 14 14:48:38 evo-x2 kernel: Out of memory: Killed process 255935 (helium) total-vm:1519141648kB, anon-rss:130116kB, file-rss:2932kB, shmem-rss:1184kB, UID:1000 pgtables:1572kB oom_score_adj:300
```

## OOM kill-pass join — memcg per killed process (kernel-attested or systemd unit-join, never inferred)
```
pid=3265754 task=llama-server uid=1000 memcg=/system.slice/llama-vlm-cap.service basis=attested
pid=255935 task=helium uid=1000 memcg=/user.slice/user-1000.slice/user@1000.service/app.slice/helium.service basis=attested
```

## memory-emergency-guard lines (all)
```
Nov 14 09:30:06 evo-x2 post-crash-calm-gate[1845]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 6 min ago (window 60 min).
Nov 14 09:31:06 evo-x2 post-crash-calm-gate[28962]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 7 min ago (window 60 min).
Nov 14 09:31:21 evo-x2 post-crash-calm-gate[40207]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 8 min ago (window 60 min).
Nov 14 09:31:36 evo-x2 post-crash-calm-gate[45116]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 8 min ago (window 60 min).
Nov 14 09:31:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:32:21 evo-x2 memory-emergency-guard-check[54769]: MEMORY EMERGENCY IO-PAUSE (trip #9853, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 09:32:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:32:21 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 471ms CPU time over 1.029s wall clock time, 11M memory peak, 288K read from disk, 69.3M written to disk.
Nov 14 09:32:21 evo-x2 post-crash-calm-gate[59186]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 14 09:32:36 evo-x2 post-crash-calm-gate[64777]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 14 09:32:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:32:51 evo-x2 post-crash-calm-gate[69313]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 14 09:33:06 evo-x2 post-crash-calm-gate[71774]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 14 09:33:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:33:21 evo-x2 post-crash-calm-gate[76669]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 14 09:33:36 evo-x2 post-crash-calm-gate[79039]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 14 09:33:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:34:20 evo-x2 memory-emergency-guard-check[87128]: MEMORY EMERGENCY still active (I/O PSI some avg60=42.84% sustained (max disk busy 100.0%, MemAvailable=79.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (120s < 150s, 30s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 14 09:34:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:34:59 evo-x2 memory-emergency-guard-check[95876]: MEMORY EMERGENCY IO-PAUSE (trip #9854, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 09:34:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:34:59 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 758ms CPU time over 9.251s wall clock time, 11.5M memory peak, 3.4M read from disk, 25.3M written to disk.
Nov 14 09:35:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:35:21 evo-x2 post-crash-calm-gate[117825]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 14 09:35:36 evo-x2 post-crash-calm-gate[126026]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 14 09:35:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:35:51 evo-x2 post-crash-calm-gate[135629]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 14 09:36:06 evo-x2 post-crash-calm-gate[138660]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 14 09:36:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:36:21 evo-x2 post-crash-calm-gate[141850]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 14 09:36:36 evo-x2 post-crash-calm-gate[144485]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 14 09:36:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:36:51 evo-x2 post-crash-calm-gate[150484]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 14 09:37:06 evo-x2 post-crash-calm-gate[151856]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 14 09:37:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:37:21 evo-x2 post-crash-calm-gate[154716]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 14 09:37:36 evo-x2 post-crash-calm-gate[154982]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 14 09:37:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:37:51 evo-x2 post-crash-calm-gate[157753]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 3 min ago (window 60 min).
Nov 14 09:38:06 evo-x2 post-crash-calm-gate[158714]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 3 min ago (window 60 min).
Nov 14 09:38:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:38:21 evo-x2 post-crash-calm-gate[161529]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 3 min ago (window 60 min).
Nov 14 09:38:36 evo-x2 post-crash-calm-gate[164132]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 3 min ago (window 60 min).
Nov 14 09:38:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:38:51 evo-x2 post-crash-calm-gate[166891]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 4 min ago (window 60 min).
Nov 14 09:39:06 evo-x2 post-crash-calm-gate[167227]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 4 min ago (window 60 min).
Nov 14 09:39:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:39:21 evo-x2 post-crash-calm-gate[169857]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 4 min ago (window 60 min).
Nov 14 09:39:36 evo-x2 post-crash-calm-gate[170347]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 4 min ago (window 60 min).
Nov 14 09:39:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:39:51 evo-x2 post-crash-calm-gate[173170]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 5 min ago (window 60 min).
Nov 14 09:39:53 evo-x2 systemd[1639]: Started [systemd-run] /nix/store/jrbrr93d8zj7np9ss67p1kh9yjf3ppbc-libnotify-0.8.9/bin/notify-send -u normal -t 30000 "SEV1: UNIT CRASH LOOP; IO-PAUSE DISARMED" "A monitored service is restart-looping (tq-agent-pool) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u tq-agent-pool -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading. | memory-emergency-guard zone-6 IO-PAUSE matched NO pausable tree 1930 trips in a row — the storm writer is outside every ioPause.cgroupPattern and the guard CANNOT shed IO. Extend the patterns to the attributed writer (journalctl -u memory-emergency-guard | grep 'IO-PAUSE').".
Nov 14 09:40:06 evo-x2 post-crash-calm-gate[173833]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 5 min ago (window 60 min).
Nov 14 09:40:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:40:21 evo-x2 post-crash-calm-gate[176272]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 5 min ago (window 60 min).
Nov 14 09:40:36 evo-x2 post-crash-calm-gate[179189]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 5 min ago (window 60 min).
Nov 14 09:40:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:40:51 evo-x2 post-crash-calm-gate[181401]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 6 min ago (window 60 min).
Nov 14 09:41:06 evo-x2 post-crash-calm-gate[181931]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 6 min ago (window 60 min).
Nov 14 09:41:21 evo-x2 post-crash-calm-gate[182255]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 6 min ago (window 60 min).
Nov 14 09:41:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:41:36 evo-x2 post-crash-calm-gate[184584]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 6 min ago (window 60 min).
Nov 14 09:41:51 evo-x2 post-crash-calm-gate[188088]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 7 min ago (window 60 min).
Nov 14 09:41:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:42:07 evo-x2 post-crash-calm-gate[190846]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 7 min ago (window 60 min).
Nov 14 09:42:22 evo-x2 post-crash-calm-gate[191185]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 7 min ago (window 60 min).
Nov 14 09:42:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:42:37 evo-x2 post-crash-calm-gate[195897]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 7 min ago (window 60 min).
Nov 14 09:42:52 evo-x2 post-crash-calm-gate[205468]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 8 min ago (window 60 min).
Nov 14 09:42:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:43:07 evo-x2 post-crash-calm-gate[220953]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 8 min ago (window 60 min).
Nov 14 09:43:22 evo-x2 post-crash-calm-gate[250045]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 8 min ago (window 60 min).
Nov 14 09:43:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:43:37 evo-x2 post-crash-calm-gate[254617]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 8 min ago (window 60 min).
Nov 14 09:43:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:44:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:44:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:45:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:45:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:46:23 evo-x2 memory-emergency-guard-check[320447]: MEMORY EMERGENCY IO-PAUSE (trip #9855, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 09:46:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:46:23 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 499ms CPU time over 579ms wall clock time, 9.8M memory peak, 16K read from disk, 14.2M written to disk.
Nov 14 09:46:52 evo-x2 memory-emergency-guard-check[343490]: MEMORY EMERGENCY still active (I/O PSI some avg60=48.88% sustained (max disk busy 27.5%, MemAvailable=43.6% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 14 09:46:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:47:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:47:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:48:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:48:55 evo-x2 memory-emergency-guard-check[393384]: MEMORY EMERGENCY IO-PAUSE (trip #9856, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 09:48:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:48:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 771ms CPU time over 2.099s wall clock time, 10M memory peak, 18.9M read from disk, 3.3M written to disk.
Nov 14 09:49:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:49:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:50:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:50:49 evo-x2 gatus[80249]: 2026/11/14 09:50:49 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=User Slice Memory with description='user-1000.slice memory exceeds 72G (90% of its MemoryHigh=80G). Throttling starts at 80G, hard kill at 90G. Desktop + crush-agent sessions legitimately use 40-60G; act only if PSI/zram also degrade (memory-emergency-guard owns real pressure).' has been TRIGGERED
Nov 14 09:50:49 evo-x2 gatus[80249]: 2026/11/14 09:50:49 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=User Slice Memory with description='user-1000.slice memory exceeds 72G (90% of its MemoryHigh=80G). Throttling starts at 80G, hard kill at 90G. Desktop + crush-agent sessions legitimately use 40-60G; act only if PSI/zram also degrade (memory-emergency-guard owns real pressure).' has been TRIGGERED
Nov 14 09:50:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:51:25 evo-x2 memory-emergency-guard-check[464390]: MEMORY EMERGENCY IO-PAUSE (trip #9857, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 09:51:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:51:25 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 897ms CPU time over 2.194s wall clock time, 10.9M memory peak, 52.3M read from disk, 84.6M written to disk.
Nov 14 09:51:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:52:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:52:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:53:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:53:57 evo-x2 memory-emergency-guard-check[709618]: MEMORY EMERGENCY IO-PAUSE (trip #9858, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 09:53:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:53:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.068s CPU time over 4.124s wall clock time, 8.5M memory peak, 6.6M read from disk, 29.9M written to disk.
Nov 14 09:54:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:54:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:55:08 evo-x2 post-crash-calm-gate[872708]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 14 09:55:23 evo-x2 post-crash-calm-gate[908812]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 14 09:55:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:55:38 evo-x2 post-crash-calm-gate[943826]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 14 09:55:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:56:08 evo-x2 post-crash-calm-gate[1004919]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 14 09:56:38 evo-x2 memory-emergency-guard-check[1047600]: MEMORY EMERGENCY IO-PAUSE (trip #9859, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 09:56:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:56:38 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.194s CPU time over 6.109s wall clock time, 8.6M memory peak, 29.1M read from disk, 31.2M written to disk.
Nov 14 09:57:03 evo-x2 memory-emergency-guard-check[1115848]: MEMORY EMERGENCY still active (I/O PSI some avg60=52.36% sustained (max disk busy 95.1%, MemAvailable=31.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 14 09:57:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:57:08 evo-x2 post-crash-calm-gate[1127797]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 14 09:57:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:57:53 evo-x2 post-crash-calm-gate[1216649]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 14 09:58:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:58:08 evo-x2 post-crash-calm-gate[1248507]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 14 09:58:23 evo-x2 post-crash-calm-gate[1275141]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 14 09:58:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:59:06 evo-x2 memory-emergency-guard-check[1360274]: MEMORY EMERGENCY IO-PAUSE (trip #9860, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 09:59:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 09:59:06 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.109s CPU time over 3.488s wall clock time, 10.2M memory peak, 36M read from disk, 55.2M written to disk.
Nov 14 09:59:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:00:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:00:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:01:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:01:35 evo-x2 memory-emergency-guard-check[1669714]: MEMORY EMERGENCY IO-PAUSE (trip #9861, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 10:01:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:01:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.068s CPU time over 2.496s wall clock time, 10.9M memory peak, 13M read from disk, 31M written to disk.
Nov 14 10:01:39 evo-x2 post-crash-calm-gate[1688190]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 14 10:01:54 evo-x2 post-crash-calm-gate[1726695]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 14 10:02:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:02:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:03:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:03:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:03:54 evo-x2 post-crash-calm-gate[2036732]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 14 10:04:06 evo-x2 memory-emergency-guard-check[2065400]: MEMORY EMERGENCY IO-PAUSE (trip #9862, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 10:04:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:04:06 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.208s CPU time over 3.555s wall clock time, 11.9M memory peak, 54.5M read from disk, 80.3M written to disk.
Nov 14 10:04:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:04:40 evo-x2 post-crash-calm-gate[2171253]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 14 10:05:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:05:10 evo-x2 post-crash-calm-gate[2252673]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 14 10:05:25 evo-x2 post-crash-calm-gate[2288310]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 14 10:05:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:06:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:06:10 evo-x2 post-crash-calm-gate[2391077]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 14 10:06:35 evo-x2 memory-emergency-guard-check[2423872]: MEMORY EMERGENCY IO-PAUSE (trip #9863, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 10:06:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:06:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 991ms CPU time over 1.834s wall clock time, 11.1M memory peak, 42.5M read from disk, 70M written to disk.
Nov 14 10:07:03 evo-x2 memory-emergency-guard-check[2498744]: MEMORY EMERGENCY still active (I/O PSI some avg60=47.01% sustained (max disk busy 98.9%, MemAvailable=43.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 14 10:07:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:07:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:08:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:08:06 evo-x2 systemd[1639]: Started [systemd-run] /nix/store/jrbrr93d8zj7np9ss67p1kh9yjf3ppbc-libnotify-0.8.9/bin/notify-send -u normal -t 30000 "SEV1: UNIT CRASH LOOP; ZRAM SWAP CRITICAL; IO-PAUSE DISARMED" "A monitored service is restart-looping (tq-agent-pool) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u tq-agent-pool -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading. | zram (the ONLY swap) is nearly full AND margins are degraded (PSI some avg10=6.09%, MemAvailable=42.0%) — the memory guard is about to sacrifice FastFlowLM; shed load now. | memory-emergency-guard zone-6 IO-PAUSE matched NO pausable tree 1939 trips in a row — the storm writer is outside every ioPause.cgroupPattern and the guard CANNOT shed IO. Extend the patterns to the attributed writer (journalctl -u memory-emergency-guard | grep 'IO-PAUSE').".
Nov 14 10:08:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:08:36 evo-x2 systemd[1639]: Started [systemd-run] /nix/store/jrbrr93d8zj7np9ss67p1kh9yjf3ppbc-libnotify-0.8.9/bin/notify-send -u normal -t 30000 "SEV1: ZRAM SWAP CRITICAL; IO-PAUSE DISARMED" "zram (the ONLY swap) is nearly full AND margins are degraded (PSI some avg10=6.43%, MemAvailable=40.8%) — the memory guard is about to sacrifice FastFlowLM; shed load now. | memory-emergency-guard zone-6 IO-PAUSE matched NO pausable tree 1939 trips in a row — the storm writer is outside every ioPause.cgroupPattern and the guard CANNOT shed IO. Extend the patterns to the attributed writer (journalctl -u memory-emergency-guard | grep 'IO-PAUSE').".
Nov 14 10:09:05 evo-x2 memory-emergency-guard-check[2686971]: MEMORY EMERGENCY IO-PAUSE (trip #9864, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 10:09:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:09:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.195s CPU time over 2.252s wall clock time, 11.4M memory peak, 66M read from disk, 89.7M written to disk.
Nov 14 10:09:06 evo-x2 systemd[1639]: Started [systemd-run] /nix/store/jrbrr93d8zj7np9ss67p1kh9yjf3ppbc-libnotify-0.8.9/bin/notify-send -u normal -t 30000 "SEV1: IO-PAUSE DISARMED" "memory-emergency-guard zone-6 IO-PAUSE matched NO pausable tree 1940 trips in a row — the storm writer is outside every ioPause.cgroupPattern and the guard CANNOT shed IO. Extend the patterns to the attributed writer (journalctl -u memory-emergency-guard | grep 'IO-PAUSE').".
Nov 14 10:09:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:10:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:10:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:10:37 evo-x2 systemd[1639]: Started [systemd-run] /nix/store/jrbrr93d8zj7np9ss67p1kh9yjf3ppbc-libnotify-0.8.9/bin/notify-send -u normal -t 30000 "SEV1: UNIT CRASH LOOP; IO-PAUSE DISARMED" "A monitored service is restart-looping (tq-agent-pool) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u tq-agent-pool -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading. | memory-emergency-guard zone-6 IO-PAUSE matched NO pausable tree 1940 trips in a row — the storm writer is outside every ioPause.cgroupPattern and the guard CANNOT shed IO. Extend the patterns to the attributed writer (journalctl -u memory-emergency-guard | grep 'IO-PAUSE').".
Nov 14 10:11:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:11:35 evo-x2 memory-emergency-guard-check[2831101]: MEMORY EMERGENCY IO-PAUSE (trip #9865, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 10:11:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:11:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 946ms CPU time over 2.043s wall clock time, 11.1M memory peak, 70.1M read from disk, 109.8M written to disk.
Nov 14 10:12:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:12:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:13:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:13:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:14:05 evo-x2 memory-emergency-guard-check[2981877]: MEMORY EMERGENCY IO-PAUSE (trip #9866, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 10:14:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:14:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 737ms CPU time over 1.224s wall clock time, 10.6M memory peak, 12.8M read from disk, 64.8M written to disk.
Nov 14 10:14:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:15:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:15:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:16:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:16:36 evo-x2 memory-emergency-guard-check[3117861]: MEMORY EMERGENCY IO-PAUSE (trip #9867, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 10:16:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:16:36 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 872ms CPU time over 1.103s wall clock time, 9M memory peak, 3M read from disk, 27.5M written to disk.
Nov 14 10:17:05 evo-x2 memory-emergency-guard-check[3160476]: MEMORY EMERGENCY still active (I/O PSI some avg60=59.30% sustained (max disk busy 100.0%, MemAvailable=51.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 14 10:17:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:17:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:17:56 evo-x2 post-crash-calm-gate[3219703]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 14 10:18:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:18:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:19:08 evo-x2 memory-emergency-guard-check[3294350]: MEMORY EMERGENCY IO-PAUSE (trip #9868, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 10:19:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:19:08 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 594ms CPU time over 781ms wall clock time, 11.5M memory peak, 3.7M read from disk, 29.3M written to disk.
Nov 14 10:19:26 evo-x2 post-crash-calm-gate[3331751]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 14 10:19:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:19:41 evo-x2 post-crash-calm-gate[3344535]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 14 10:20:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:20:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:21:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:21:26 evo-x2 post-crash-calm-gate[3444830]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 14 10:21:39 evo-x2 memory-emergency-guard-check[3458152]: MEMORY EMERGENCY IO-PAUSE (trip #9869, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 10:21:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:21:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 699ms CPU time over 1.159s wall clock time, 13.3M memory peak, 7.1M read from disk, 45.6M written to disk.
Nov 14 10:21:41 evo-x2 post-crash-calm-gate[3467501]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 14 10:22:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:22:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:23:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:23:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:24:09 evo-x2 memory-emergency-guard-check[3582374]: MEMORY EMERGENCY IO-PAUSE (trip #9870, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 10:24:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:24:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 722ms CPU time over 1.068s wall clock time, 11.2M memory peak, 13.3M read from disk, 46.8M written to disk.
Nov 14 10:24:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:25:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:25:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:26:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:26:39 evo-x2 memory-emergency-guard-check[3726306]: sort: fflush failed: 'standard output': Broken pipe
Nov 14 10:26:39 evo-x2 memory-emergency-guard-check[3726306]: sort: write error
Nov 14 10:26:39 evo-x2 memory-emergency-guard-check[3724925]: MEMORY EMERGENCY IO-PAUSE (trip #9871, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 10:26:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:26:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 835ms CPU time over 1.099s wall clock time, 9.6M memory peak, 7.6M read from disk, 32.6M written to disk.
Nov 14 10:27:08 evo-x2 memory-emergency-guard-check[3762000]: MEMORY EMERGENCY still active (I/O PSI some avg60=56.72% sustained (max disk busy 99.8%, MemAvailable=51.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 14 10:27:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:27:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:28:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:28:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:29:09 evo-x2 memory-emergency-guard-check[3826936]: MEMORY EMERGENCY IO-PAUSE (trip #9872, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 10:29:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:29:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 595ms CPU time over 888ms wall clock time, 10.3M memory peak, 10.4M read from disk, 38.8M written to disk.
Nov 14 10:29:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:30:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:30:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:31:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:31:40 evo-x2 memory-emergency-guard-check[3940515]: MEMORY EMERGENCY IO-PAUSE (trip #9873, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 10:31:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:31:40 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 814ms CPU time over 1.825s wall clock time, 11.2M memory peak, 29M read from disk, 68M written to disk.
Nov 14 10:32:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:32:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:33:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:33:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:34:10 evo-x2 memory-emergency-guard-check[4052738]: MEMORY EMERGENCY IO-PAUSE (trip #9874, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 10:34:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:34:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 678ms CPU time over 1.327s wall clock time, 10.9M memory peak, 37M read from disk, 65.9M written to disk.
Nov 14 10:34:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:35:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:35:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:36:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:36:39 evo-x2 memory-emergency-guard-check[4137443]: MEMORY EMERGENCY IO-PAUSE (trip #9875, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 10:36:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:36:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 550ms CPU time over 883ms wall clock time, 11.4M memory peak, 1.8M read from disk, 13.2M written to disk.
Nov 14 10:37:09 evo-x2 memory-emergency-guard-check[4166180]: MEMORY EMERGENCY still active (I/O PSI some avg60=58.99% sustained (max disk busy 100.0%, MemAvailable=37.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 14 10:37:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:37:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:38:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:38:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:39:10 evo-x2 memory-emergency-guard-check[62668]: MEMORY EMERGENCY IO-PAUSE (trip #9876, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 10:39:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:39:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 985ms CPU time over 1.771s wall clock time, 9.3M memory peak, 18.4M read from disk, 56.8M written to disk.
Nov 14 10:39:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:40:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:40:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:41:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:41:43 evo-x2 memory-emergency-guard-check[221604]: MEMORY EMERGENCY IO-PAUSE (trip #9877, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 10:41:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:41:43 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.107s CPU time over 4.832s wall clock time, 8.1M memory peak, 28.6M read from disk, 56M written to disk.
Nov 14 10:42:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:42:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:43:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:43:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:44:13 evo-x2 memory-emergency-guard-check[419772]: MEMORY EMERGENCY IO-PAUSE (trip #9878, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 10:44:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:44:13 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 699ms CPU time over 4.744s wall clock time, 11.7M memory peak, 17.4M read from disk, 65M written to disk.
Nov 14 10:44:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:45:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:45:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:46:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:46:45 evo-x2 memory-emergency-guard-check[631046]: MEMORY EMERGENCY IO-PAUSE (trip #9879, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 10:46:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:46:45 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.025s CPU time over 5.314s wall clock time, 9.6M memory peak, 10M read from disk, 57.4M written to disk.
Nov 14 10:47:10 evo-x2 memory-emergency-guard-check[690805]: MEMORY EMERGENCY still active (I/O PSI some avg60=43.75% sustained (max disk busy 96.1%, MemAvailable=46.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 14 10:47:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:47:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:48:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:48:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:49:12 evo-x2 memory-emergency-guard-check[871621]: MEMORY EMERGENCY IO-PAUSE (trip #9880, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 10:49:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:49:12 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 912ms CPU time over 2.089s wall clock time, 10.9M memory peak, 11M read from disk, 29.3M written to disk.
Nov 14 10:49:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:50:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:50:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:51:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:51:41 evo-x2 memory-emergency-guard-check[1100494]: MEMORY EMERGENCY IO-PAUSE (trip #9881, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 10:51:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:51:41 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 584ms CPU time over 812ms wall clock time, 12M memory peak, 5.4M read from disk, 31.5M written to disk.
Nov 14 10:52:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:52:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:53:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:53:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:54:16 evo-x2 memory-emergency-guard-check[1205756]: MEMORY EMERGENCY IO-PAUSE (trip #9882, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 10:54:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:54:16 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 647ms CPU time over 5.825s wall clock time, 11.4M memory peak, 15.3M read from disk, 36.6M written to disk.
Nov 14 10:54:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:55:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:55:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:56:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:56:45 evo-x2 memory-emergency-guard-check[1325375]: MEMORY EMERGENCY IO-PAUSE (trip #9883, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 10:56:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:56:45 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 655ms CPU time over 4.613s wall clock time, 11M memory peak, 17.8M read from disk, 64.7M written to disk.
Nov 14 10:57:10 evo-x2 memory-emergency-guard-check[1377432]: MEMORY EMERGENCY still active (I/O PSI some avg60=69.19% sustained (max disk busy 100.0%, MemAvailable=54.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 14 10:57:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:57:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:58:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:58:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:59:14 evo-x2 memory-emergency-guard-check[1549399]: MEMORY EMERGENCY IO-PAUSE (trip #9884, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 10:59:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 10:59:14 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 673ms CPU time over 3.084s wall clock time, 12.9M memory peak, 13M read from disk, 66.7M written to disk.
Nov 14 10:59:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:00:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:00:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:01:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:01:44 evo-x2 memory-emergency-guard-check[1642584]: MEMORY EMERGENCY IO-PAUSE (trip #9885, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 11:01:44 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:01:44 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 593ms CPU time over 3.011s wall clock time, 11.8M memory peak, 11.2M read from disk, 45.8M written to disk.
Nov 14 11:02:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:02:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:03:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:03:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:04:16 evo-x2 memory-emergency-guard-check[1728673]: MEMORY EMERGENCY IO-PAUSE (trip #9886, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 11:04:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:04:16 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 534ms CPU time over 3.018s wall clock time, 11.1M memory peak, 560K read from disk, 22.5M written to disk.
Nov 14 11:04:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:05:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:05:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:06:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:06:46 evo-x2 memory-emergency-guard-check[1820794]: MEMORY EMERGENCY IO-PAUSE (trip #9887, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 11:06:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:06:46 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 554ms CPU time over 2.374s wall clock time, 12.2M memory peak, 1M read from disk, 30.1M written to disk.
Nov 14 11:07:15 evo-x2 memory-emergency-guard-check[1855948]: MEMORY EMERGENCY still active (I/O PSI some avg60=61.40% sustained (max disk busy 99.5%, MemAvailable=50.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (31s < 150s, 119s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 14 11:07:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:07:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:07:46 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 94ms CPU time over 183ms wall clock time, 7.4M memory peak, 1.2M read from disk, 4K written to disk.
Nov 14 11:08:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:08:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:09:19 evo-x2 memory-emergency-guard-check[1917339]: MEMORY EMERGENCY IO-PAUSE (trip #9888, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 11:09:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:09:19 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 564ms CPU time over 1.776s wall clock time, 11M memory peak, 2.2M read from disk, 42.3M written to disk.
Nov 14 11:09:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:10:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:10:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:11:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:11:50 evo-x2 memory-emergency-guard-check[2010452]: MEMORY EMERGENCY IO-PAUSE (trip #9889, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 11:11:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:11:50 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 551ms CPU time over 1.917s wall clock time, 11.5M memory peak, 2.3M read from disk, 33.3M written to disk.
Nov 14 11:12:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:12:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:13:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:13:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:14:19 evo-x2 memory-emergency-guard-check[2126825]: MEMORY EMERGENCY IO-PAUSE (trip #9890, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 11:14:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:14:19 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 531ms CPU time over 706ms wall clock time, 10.4M memory peak, 1M read from disk, 23.9M written to disk.
Nov 14 11:14:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:15:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:15:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:16:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:16:50 evo-x2 memory-emergency-guard-check[2239599]: MEMORY EMERGENCY IO-PAUSE (trip #9891, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 11:16:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:16:50 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 540ms CPU time over 918ms wall clock time, 11M memory peak, 4.6M read from disk, 37.8M written to disk.
Nov 14 11:17:19 evo-x2 memory-emergency-guard-check[2280157]: MEMORY EMERGENCY still active (I/O PSI some avg60=82.95% sustained (max disk busy 100.0%, MemAvailable=51.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 14 11:17:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:17:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:18:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:18:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:19:20 evo-x2 memory-emergency-guard-check[2352651]: MEMORY EMERGENCY IO-PAUSE (trip #9892, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 11:19:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:19:20 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 580ms CPU time over 732ms wall clock time, 10M memory peak, 1.2M read from disk, 26.5M written to disk.
Nov 14 11:19:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:20:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:20:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:21:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:21:50 evo-x2 memory-emergency-guard-check[2421032]: MEMORY EMERGENCY IO-PAUSE (trip #9893, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 11:21:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:21:50 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 538ms CPU time over 705ms wall clock time, 10.4M memory peak, 1.5M read from disk, 26M written to disk.
Nov 14 11:22:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:22:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:22:57 evo-x2 systemd[1639]: Started [systemd-run] /nix/store/jrbrr93d8zj7np9ss67p1kh9yjf3ppbc-libnotify-0.8.9/bin/notify-send -u normal -t 30000 "SEV1: UNIT CRASH LOOP; ZRAM SWAP CRITICAL; IO-PAUSE DISARMED" "A monitored service is restart-looping (tq-agent-pool) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u tq-agent-pool -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading. | zram (the ONLY swap) is nearly full AND margins are degraded (PSI some avg10=11.31%, MemAvailable=54.3%) — the memory guard is about to sacrifice FastFlowLM; shed load now. | memory-emergency-guard zone-6 IO-PAUSE matched NO pausable tree 1969 trips in a row — the storm writer is outside every ioPause.cgroupPattern and the guard CANNOT shed IO. Extend the patterns to the attributed writer (journalctl -u memory-emergency-guard | grep 'IO-PAUSE').".
Nov 14 11:23:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:23:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:24:21 evo-x2 memory-emergency-guard-check[2496784]: MEMORY EMERGENCY IO-PAUSE (trip #9894, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 11:24:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:24:21 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 555ms CPU time over 843ms wall clock time, 11.3M memory peak, 9.7M read from disk, 42.5M written to disk.
Nov 14 11:24:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:25:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:25:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:26:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:26:51 evo-x2 memory-emergency-guard-check[2598624]: MEMORY EMERGENCY IO-PAUSE (trip #9895, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 11:26:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:26:51 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 582ms CPU time over 760ms wall clock time, 11M memory peak, 688K read from disk, 25.7M written to disk.
Nov 14 11:27:20 evo-x2 memory-emergency-guard-check[2636121]: MEMORY EMERGENCY still active (I/O PSI some avg60=53.91% sustained (max disk busy 99.7%, MemAvailable=53.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 14 11:27:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:27:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:27:58 evo-x2 systemd[1639]: Started [systemd-run] /nix/store/jrbrr93d8zj7np9ss67p1kh9yjf3ppbc-libnotify-0.8.9/bin/notify-send -u normal -t 30000 "SEV1: UNIT CRASH LOOP; IO-PAUSE DISARMED" "A monitored service is restart-looping (tq-agent-pool) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u tq-agent-pool -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading. | memory-emergency-guard zone-6 IO-PAUSE matched NO pausable tree 1971 trips in a row — the storm writer is outside every ioPause.cgroupPattern and the guard CANNOT shed IO. Extend the patterns to the attributed writer (journalctl -u memory-emergency-guard | grep 'IO-PAUSE').".
Nov 14 11:28:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:28:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:29:22 evo-x2 memory-emergency-guard-check[2748565]: MEMORY EMERGENCY IO-PAUSE (trip #9896, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 11:29:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:29:22 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 891ms CPU time over 1.808s wall clock time, 10.3M memory peak, 38.7M read from disk, 66.1M written to disk.
Nov 14 11:29:51 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:30:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:30:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:31:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:31:57 evo-x2 memory-emergency-guard-check[2958650]: MEMORY EMERGENCY IO-PAUSE (trip #9897, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 11:31:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:31:57 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.272s CPU time over 5.379s wall clock time, 10M memory peak, 31.2M read from disk, 80.1M written to disk.
Nov 14 11:32:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:32:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:33:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:33:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:34:22 evo-x2 memory-emergency-guard-check[3191348]: MEMORY EMERGENCY IO-PAUSE (trip #9898, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 11:34:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:34:22 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 682ms CPU time over 941ms wall clock time, 12.3M memory peak, 8.2M read from disk, 36.1M written to disk.
Nov 14 11:34:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:35:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:35:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:36:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:36:53 evo-x2 memory-emergency-guard-check[3339590]: MEMORY EMERGENCY IO-PAUSE (trip #9899, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 11:36:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:36:53 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 624ms CPU time over 1.173s wall clock time, 11.8M memory peak, 6.5M read from disk, 27.3M written to disk.
Nov 14 11:37:22 evo-x2 memory-emergency-guard-check[3370057]: MEMORY EMERGENCY still active (I/O PSI some avg60=59.05% sustained (max disk busy 100.0%, MemAvailable=50.9% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 14 11:37:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:37:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:38:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:38:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:39:23 evo-x2 memory-emergency-guard-check[3444403]: MEMORY EMERGENCY IO-PAUSE (trip #9900, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 11:39:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:39:23 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 626ms CPU time over 1.117s wall clock time, 12M memory peak, 21.1M read from disk, 65.2M written to disk.
Nov 14 11:39:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:40:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:40:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:41:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:41:53 evo-x2 memory-emergency-guard-check[3606231]: MEMORY EMERGENCY IO-PAUSE (trip #9901, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 11:41:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:41:53 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 682ms CPU time over 1.065s wall clock time, 15.6M memory peak, 8.2M read from disk, 50M written to disk.
Nov 14 11:42:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:42:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:43:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:43:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:44:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:44:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:45:26 evo-x2 memory-emergency-guard-check[3831610]: MEMORY EMERGENCY IO-PAUSE (trip #9902, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 11:45:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:45:26 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 928ms CPU time over 3.586s wall clock time, 13M memory peak, 41M read from disk, 67.6M written to disk.
Nov 14 11:45:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:46:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:46:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:47:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:48:00 evo-x2 memory-emergency-guard-check[4055480]: MEMORY EMERGENCY IO-PAUSE (trip #9903, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 11:48:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:48:00 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.386s CPU time over 7.242s wall clock time, 8.9M memory peak, 56.2M read from disk, 80.1M written to disk.
Nov 14 11:48:23 evo-x2 memory-emergency-guard-check[4102043]: MEMORY EMERGENCY still active (I/O PSI some avg60=48.25% sustained (max disk busy 99.2%, MemAvailable=27.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 14 11:48:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:48:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:49:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:49:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:50:25 evo-x2 memory-emergency-guard-check[66314]: MEMORY EMERGENCY IO-PAUSE (trip #9904, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 11:50:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:50:25 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.035s CPU time over 2.649s wall clock time, 9.7M memory peak, 31.4M read from disk, 56.7M written to disk.
Nov 14 11:50:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:51:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:51:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:52:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:52:55 evo-x2 memory-emergency-guard-check[258781]: MEMORY EMERGENCY IO-PAUSE (trip #9905, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 11:52:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:52:55 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 888ms CPU time over 2.199s wall clock time, 17.3M memory peak, 48.8M read from disk, 104.6M written to disk.
Nov 14 11:53:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:53:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:54:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:54:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:55:24 evo-x2 memory-emergency-guard-check[380832]: MEMORY EMERGENCY IO-PAUSE (trip #9906, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 11:55:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:55:24 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 694ms CPU time over 937ms wall clock time, 12.5M memory peak, 9.5M read from disk, 44.3M written to disk.
Nov 14 11:55:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:56:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:56:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:57:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:57:54 evo-x2 memory-emergency-guard-check[476257]: MEMORY EMERGENCY IO-PAUSE (trip #9907, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 11:57:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:57:54 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 623ms CPU time over 1.109s wall clock time, 10.5M memory peak, 3.7M read from disk, 26.1M written to disk.
Nov 14 11:58:23 evo-x2 memory-emergency-guard-check[505905]: MEMORY EMERGENCY still active (I/O PSI some avg60=58.26% sustained (max disk busy 100.0%, MemAvailable=52.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 14 11:58:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:58:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:59:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 11:59:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:00:25 evo-x2 memory-emergency-guard-check[656862]: MEMORY EMERGENCY IO-PAUSE (trip #9908, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 12:00:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:00:25 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 690ms CPU time over 1.478s wall clock time, 11.7M memory peak, 24.8M read from disk, 50.4M written to disk.
Nov 14 12:00:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:01:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:01:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:02:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:02:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:03:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:03:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:04:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:04:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:05:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:05:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:06:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:06:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:07:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:07:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:08:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:08:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:09:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:09:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:10:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:10:58 evo-x2 memory-emergency-guard-check[1206025]: MEMORY EMERGENCY IO-PAUSE (trip #9909, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 12:10:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:10:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 817ms CPU time over 1.715s wall clock time, 10.2M memory peak, 50.9M read from disk, 78.3M written to disk.
Nov 14 12:11:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:11:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 142ms CPU time over 206ms wall clock time, 6.4M memory peak, 1.3M read from disk, 4K written to disk.
Nov 14 12:11:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:12:27 evo-x2 memory-emergency-guard-check[1300354]: MEMORY EMERGENCY still active (I/O PSI some avg60=42.06% sustained (max disk busy 100.0%, MemAvailable=36.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (91s < 150s, 59s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 14 12:12:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:12:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:13:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:13:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:14:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:14:58 evo-x2 memory-emergency-guard-check[1426279]: MEMORY EMERGENCY IO-PAUSE (trip #9910, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 12:14:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:14:58 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 563ms CPU time over 678ms wall clock time, 10.6M memory peak, 2.5M read from disk, 14.2M written to disk.
Nov 14 12:15:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:15:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 192ms CPU time over 291ms wall clock time, 9.7M memory peak, 1.7M read from disk, 4K written to disk.
Nov 14 12:15:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:16:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:16:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:17:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:17:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:18:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:18:34 evo-x2 systemd[1639]: Started [systemd-run] /nix/store/jrbrr93d8zj7np9ss67p1kh9yjf3ppbc-libnotify-0.8.9/bin/notify-send -u normal -t 30000 "SEV1: UNIT CRASH LOOP; IO-PAUSE DISARMED" "A monitored service is restart-looping (tq-agent-pool) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u tq-agent-pool -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading. | memory-emergency-guard zone-6 IO-PAUSE matched NO pausable tree 1986 trips in a row — the storm writer is outside every ioPause.cgroupPattern and the guard CANNOT shed IO. Extend the patterns to the attributed writer (journalctl -u memory-emergency-guard | grep 'IO-PAUSE').".
Nov 14 12:18:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:19:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:19:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:20:05 evo-x2 systemd[1639]: Started [systemd-run] /nix/store/jrbrr93d8zj7np9ss67p1kh9yjf3ppbc-libnotify-0.8.9/bin/notify-send -u normal -t 30000 "SEV1: UNIT CRASH LOOP; ZRAM SWAP CRITICAL; IO-PAUSE DISARMED" "A monitored service is restart-looping (tq-agent-pool) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u tq-agent-pool -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading. | zram (the ONLY swap) is nearly full AND margins are degraded (PSI some avg10=7.52%, MemAvailable=53.9%) — the memory guard is about to sacrifice FastFlowLM; shed load now. | memory-emergency-guard zone-6 IO-PAUSE matched NO pausable tree 1986 trips in a row — the storm writer is outside every ioPause.cgroupPattern and the guard CANNOT shed IO. Extend the patterns to the attributed writer (journalctl -u memory-emergency-guard | grep 'IO-PAUSE').".
Nov 14 12:20:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:20:59 evo-x2 memory-emergency-guard-check[1888761]: MEMORY EMERGENCY IO-PAUSE (trip #9911, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 12:20:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:20:59 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 724ms CPU time over 1.069s wall clock time, 12.3M memory peak, 8.9M read from disk, 47.1M written to disk.
Nov 14 12:21:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:21:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:22:28 evo-x2 memory-emergency-guard-check[2039123]: MEMORY EMERGENCY still active (I/O PSI some avg60=48.29% sustained (max disk busy 99.6%, MemAvailable=53.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 14 12:22:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:22:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:23:29 evo-x2 memory-emergency-guard-check[2108466]: MEMORY EMERGENCY IO-PAUSE (trip #9912, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 12:23:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:23:29 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 748ms CPU time over 1.405s wall clock time, 11.1M memory peak, 14M read from disk, 47.1M written to disk.
Nov 14 12:23:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:24:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:24:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:25:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:26:00 evo-x2 memory-emergency-guard-check[2214885]: MEMORY EMERGENCY IO-PAUSE (trip #9913, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 12:26:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:26:00 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.066s CPU time over 1.648s wall clock time, 10M memory peak, 15.8M read from disk, 77.2M written to disk.
Nov 14 12:26:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:26:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:27:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:27:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:28:30 evo-x2 memory-emergency-guard-check[2338341]: MEMORY EMERGENCY IO-PAUSE (trip #9914, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 12:28:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:28:30 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.066s CPU time over 1.883s wall clock time, 10.5M memory peak, 20.9M read from disk, 16.6M written to disk.
Nov 14 12:28:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:29:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:29:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:30:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:31:00 evo-x2 memory-emergency-guard-check[2459131]: MEMORY EMERGENCY IO-PAUSE (trip #9915, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 12:31:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:31:00 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 649ms CPU time over 873ms wall clock time, 10.7M memory peak, 7.7M read from disk, 43.5M written to disk.
Nov 14 12:31:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:31:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:32:29 evo-x2 memory-emergency-guard-check[2543973]: MEMORY EMERGENCY still active (I/O PSI some avg60=48.70% sustained (max disk busy 98.8%, MemAvailable=53.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 14 12:32:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:32:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:33:29 evo-x2 memory-emergency-guard-check[2568480]: MEMORY EMERGENCY IO-PAUSE (trip #9916, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 12:33:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:33:29 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 558ms CPU time over 665ms wall clock time, 10.5M memory peak, 784K read from disk, 13.9M written to disk.
Nov 14 12:33:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:34:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:34:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:35:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:36:01 evo-x2 memory-emergency-guard-check[2683374]: MEMORY EMERGENCY IO-PAUSE (trip #9917, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 12:36:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:36:01 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 622ms CPU time over 2.335s wall clock time, 11.3M memory peak, 5.6M read from disk, 33.3M written to disk.
Nov 14 12:36:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:36:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:37:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:37:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:38:30 evo-x2 memory-emergency-guard-check[2770518]: MEMORY EMERGENCY IO-PAUSE (trip #9918, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 12:38:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:38:30 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 603ms CPU time over 1.411s wall clock time, 10.4M memory peak, 2.2M read from disk, 31M written to disk.
Nov 14 12:38:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:39:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:39:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:40:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:41:01 evo-x2 memory-emergency-guard-check[2832678]: MEMORY EMERGENCY IO-PAUSE (trip #9919, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 12:41:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:41:01 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 628ms CPU time over 1.934s wall clock time, 11.6M memory peak, 5.9M read from disk, 38.1M written to disk.
Nov 14 12:41:29 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:42:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:42:30 evo-x2 memory-emergency-guard-check[2905072]: MEMORY EMERGENCY still active (I/O PSI some avg60=46.46% sustained (max disk busy 92.7%, MemAvailable=47.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (91s < 150s, 59s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 14 12:42:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:43:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:43:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:44:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:44:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:45:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:45:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:46:06 evo-x2 memory-emergency-guard-check[3170531]: MEMORY EMERGENCY IO-PAUSE (trip #9920, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 12:46:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:46:06 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 698ms CPU time over 6.654s wall clock time, 12.5M memory peak, 24.7M read from disk, 7.8M written to disk.
Nov 14 12:46:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:47:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:47:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:48:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:48:32 evo-x2 memory-emergency-guard-check[3255678]: MEMORY EMERGENCY IO-PAUSE (trip #9921, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 12:48:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:48:32 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 985ms CPU time over 1.884s wall clock time, 10.3M memory peak, 7M read from disk, 45.4M written to disk.
Nov 14 12:49:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:49:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:50:00 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:50:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:51:02 evo-x2 memory-emergency-guard-check[3361389]: MEMORY EMERGENCY IO-PAUSE (trip #9922, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 12:51:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:51:02 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 623ms CPU time over 1.568s wall clock time, 11.8M memory peak, 4.4M read from disk, 41.3M written to disk.
Nov 14 12:51:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:52:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:52:32 evo-x2 memory-emergency-guard-check[3426501]: MEMORY EMERGENCY still active (I/O PSI some avg60=49.11% sustained (max disk busy 96.8%, MemAvailable=53.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (92s < 150s, 58s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 14 12:52:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:53:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:53:35 evo-x2 memory-emergency-guard-check[3466239]: MEMORY EMERGENCY IO-PAUSE (trip #9923, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 12:53:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:53:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.239s CPU time over 2.544s wall clock time, 10.3M memory peak, 8.7M read from disk, 51.4M written to disk.
Nov 14 12:54:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:54:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:55:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:55:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:56:04 evo-x2 memory-emergency-guard-check[3552353]: MEMORY EMERGENCY IO-PAUSE (trip #9924, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 12:56:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:56:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 575ms CPU time over 1.919s wall clock time, 10.8M memory peak, 2.4M read from disk, 29.3M written to disk.
Nov 14 12:56:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:57:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:57:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:58:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:58:35 evo-x2 memory-emergency-guard-check[3638722]: /nix/store/940r1jzkfkwgbb6kahj0c0jz6fi13xfx-memory-emergency-guard-check/bin/memory-emergency-guard-check: line 630: /proc/3649453/stat: No such file or directory
Nov 14 12:58:35 evo-x2 memory-emergency-guard-check[3638722]: MEMORY EMERGENCY IO-PAUSE (trip #9925, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 12:58:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:58:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 557ms CPU time over 2.754s wall clock time, 11.8M memory peak, 1.5M read from disk, 26.4M written to disk.
Nov 14 12:59:02 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 12:59:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:00:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:00:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:01:07 evo-x2 memory-emergency-guard-check[3704969]: MEMORY EMERGENCY IO-PAUSE (trip #9926, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 13:01:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:01:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 729ms CPU time over 4.017s wall clock time, 13M memory peak, 44.2M read from disk, 94.8M written to disk.
Nov 14 13:01:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:02:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:02:33 evo-x2 memory-emergency-guard-check[3752466]: MEMORY EMERGENCY still active (I/O PSI some avg60=54.60% sustained (max disk busy 97.8%, MemAvailable=37.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 14 13:02:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:03:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:03:34 evo-x2 memory-emergency-guard-check[3774583]: MEMORY EMERGENCY IO-PAUSE (trip #9927, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 13:03:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:03:34 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 578ms CPU time over 782ms wall clock time, 11.1M memory peak, 6.8M read from disk, 18.3M written to disk.
Nov 14 13:04:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:04:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:05:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:05:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:06:04 evo-x2 memory-emergency-guard-check[3842160]: MEMORY EMERGENCY IO-PAUSE (trip #9928, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 13:06:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:06:04 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 588ms CPU time over 762ms wall clock time, 12M memory peak, 4.9M read from disk, 27M written to disk.
Nov 14 13:06:12 evo-x2 systemd[1639]: Started [systemd-run] /nix/store/jrbrr93d8zj7np9ss67p1kh9yjf3ppbc-libnotify-0.8.9/bin/notify-send -u normal -t 30000 "SEV1: UNIT CRASH LOOP; ZRAM SWAP CRITICAL; IO-PAUSE DISARMED" "A monitored service is restart-looping (tq-agent-pool) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u tq-agent-pool -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading. | zram (the ONLY swap) is nearly full AND margins are degraded (PSI some avg10=15.96%, MemAvailable=49.6%) — the memory guard is about to sacrifice FastFlowLM; shed load now. | memory-emergency-guard zone-6 IO-PAUSE matched NO pausable tree 2004 trips in a row — the storm writer is outside every ioPause.cgroupPattern and the guard CANNOT shed IO. Extend the patterns to the attributed writer (journalctl -u memory-emergency-guard | grep 'IO-PAUSE').".
Nov 14 13:06:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:07:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:07:33 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:08:03 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:08:34 evo-x2 memory-emergency-guard-check[3932262]: MEMORY EMERGENCY IO-PAUSE (trip #9929, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 13:08:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:08:34 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 549ms CPU time over 696ms wall clock time, 11.3M memory peak, 2.4M read from disk, 19M written to disk.
Nov 14 13:08:42 evo-x2 systemd[1639]: Started [systemd-run] /nix/store/jrbrr93d8zj7np9ss67p1kh9yjf3ppbc-libnotify-0.8.9/bin/notify-send -u normal -t 30000 "SEV1: ZRAM SWAP CRITICAL; IO-PAUSE DISARMED" "zram (the ONLY swap) is nearly full AND margins are degraded (PSI some avg10=15.70%, MemAvailable=51.4%) — the memory guard is about to sacrifice FastFlowLM; shed load now. | memory-emergency-guard zone-6 IO-PAUSE matched NO pausable tree 2005 trips in a row — the storm writer is outside every ioPause.cgroupPattern and the guard CANNOT shed IO. Extend the patterns to the attributed writer (journalctl -u memory-emergency-guard | grep 'IO-PAUSE').".
Nov 14 13:09:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:09:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:10:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:10:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:11:05 evo-x2 memory-emergency-guard-check[4008472]: MEMORY EMERGENCY IO-PAUSE (trip #9930, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 13:11:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:11:05 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 535ms CPU time over 609ms wall clock time, 11.3M memory peak, 1.6M read from disk, 14.9M written to disk.
Nov 14 13:11:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:12:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:12:34 evo-x2 memory-emergency-guard-check[4053673]: MEMORY EMERGENCY still active (I/O PSI some avg60=52.55% sustained (max disk busy 97.3%, MemAvailable=53.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 14 13:12:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:13:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:13:35 evo-x2 memory-emergency-guard-check[4074396]: MEMORY EMERGENCY IO-PAUSE (trip #9931, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 13:13:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:13:35 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 512ms CPU time over 776ms wall clock time, 11.1M memory peak, 2.5M read from disk, 19.9M written to disk.
Nov 14 13:14:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:14:34 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:15:04 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:15:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:16:06 evo-x2 memory-emergency-guard-check[4135118]: MEMORY EMERGENCY IO-PAUSE (trip #9932, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 13:16:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:16:06 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 511ms CPU time over 999ms wall clock time, 10.8M memory peak, 1.3M read from disk, 17.3M written to disk.
Nov 14 13:16:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:17:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:17:35 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:18:05 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:18:37 evo-x2 memory-emergency-guard-check[31910]: MEMORY EMERGENCY IO-PAUSE (trip #9933, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 13:18:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:18:37 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 515ms CPU time over 1.182s wall clock time, 11M memory peak, 3.5M read from disk, 24.8M written to disk.
Nov 14 13:19:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:19:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:20:06 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:20:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:21:07 evo-x2 memory-emergency-guard-check[122687]: MEMORY EMERGENCY IO-PAUSE (trip #9934, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 13:21:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:21:07 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 506ms CPU time over 972ms wall clock time, 20M memory peak, 1.5M read from disk, 19.4M written to disk.
Nov 14 13:21:36 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:22:07 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:22:37 evo-x2 memory-emergency-guard-check[163849]: MEMORY EMERGENCY still active (I/O PSI some avg60=58.61% sustained (max disk busy 97.8%, MemAvailable=52.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (91s < 150s, 59s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 14 13:22:37 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:22:39 evo-x2 systemd[1639]: Started [systemd-run] /nix/store/jrbrr93d8zj7np9ss67p1kh9yjf3ppbc-libnotify-0.8.9/bin/notify-send -u normal -t 30000 "SEV1: IO-PAUSE DISARMED" "memory-emergency-guard zone-6 IO-PAUSE matched NO pausable tree 2010 trips in a row — the storm writer is outside every ioPause.cgroupPattern and the guard CANNOT shed IO. Extend the patterns to the attributed writer (journalctl -u memory-emergency-guard | grep 'IO-PAUSE').".
Nov 14 13:23:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:23:40 evo-x2 memory-emergency-guard-check[180421]: MEMORY EMERGENCY IO-PAUSE (trip #9935, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 13:23:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:23:40 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 606ms CPU time over 1.808s wall clock time, 12M memory peak, 17.1M read from disk, 60.7M written to disk.
Nov 14 13:24:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:24:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:25:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:25:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:26:09 evo-x2 memory-emergency-guard-check[230701]: MEMORY EMERGENCY IO-PAUSE (trip #9936, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 13:26:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:26:09 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 518ms CPU time over 626ms wall clock time, 11.5M memory peak, 1M read from disk, 18.3M written to disk.
Nov 14 13:26:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:27:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:27:38 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:28:08 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:28:39 evo-x2 memory-emergency-guard-check[293314]: MEMORY EMERGENCY IO-PAUSE (trip #9937, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 13:28:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:28:39 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 516ms CPU time over 625ms wall clock time, 11.4M memory peak, 1.8M read from disk, 20.7M written to disk.
Nov 14 13:29:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:29:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:30:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:30:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:31:10 evo-x2 memory-emergency-guard-check[408696]: MEMORY EMERGENCY IO-PAUSE (trip #9938, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 13:31:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:31:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 589ms CPU time over 1.067s wall clock time, 12M memory peak, 31M read from disk, 47.3M written to disk.
Nov 14 13:31:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:32:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:32:39 evo-x2 memory-emergency-guard-check[454681]: MEMORY EMERGENCY still active (I/O PSI some avg60=54.20% sustained (max disk busy 97.5%, MemAvailable=40.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 14 13:32:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:33:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:33:40 evo-x2 memory-emergency-guard-check[475853]: MEMORY EMERGENCY IO-PAUSE (trip #9939, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 13:33:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:33:40 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 534ms CPU time over 691ms wall clock time, 11.2M memory peak, 3.7M read from disk, 6.2M written to disk.
Nov 14 13:34:09 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:34:39 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:35:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:35:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:36:10 evo-x2 memory-emergency-guard-check[536467]: MEMORY EMERGENCY IO-PAUSE (trip #9940, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 13:36:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:36:10 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 570ms CPU time over 890ms wall clock time, 11.4M memory peak, 16.1M read from disk, 42.6M written to disk.
Nov 14 13:36:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:37:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:37:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:38:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:38:41 evo-x2 memory-emergency-guard-check[598235]: MEMORY EMERGENCY IO-PAUSE (trip #9941, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 13:38:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:38:41 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 564ms CPU time over 772ms wall clock time, 10.8M memory peak, 4M read from disk, 37.9M written to disk.
Nov 14 13:39:10 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:39:40 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:40:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:40:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:41:11 evo-x2 memory-emergency-guard-check[657168]: MEMORY EMERGENCY IO-PAUSE (trip #9942, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 13:41:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:41:11 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 510ms CPU time over 628ms wall clock time, 10.5M memory peak, 1.5M read from disk, 25.2M written to disk.
Nov 14 13:41:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:42:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:42:41 evo-x2 memory-emergency-guard-check[697250]: MEMORY EMERGENCY still active (I/O PSI some avg60=60.09% sustained (max disk busy 98.1%, MemAvailable=53.7% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 14 13:42:41 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:43:11 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:43:42 evo-x2 memory-emergency-guard-check[714021]: MEMORY EMERGENCY IO-PAUSE (trip #9943, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 13:43:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:43:42 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 502ms CPU time over 588ms wall clock time, 12.6M memory peak, 1.3M read from disk, 18.8M written to disk.
Nov 14 13:44:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:44:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:44:52 evo-x2 systemd[1639]: Started [systemd-run] /nix/store/jrbrr93d8zj7np9ss67p1kh9yjf3ppbc-libnotify-0.8.9/bin/notify-send -u normal -t 30000 "SEV1: ZRAM SWAP CRITICAL; IO-PAUSE DISARMED" "zram (the ONLY swap) is nearly full AND margins are degraded (PSI some avg10=9.74%, MemAvailable=53.7%) — the memory guard is about to sacrifice FastFlowLM; shed load now. | memory-emergency-guard zone-6 IO-PAUSE matched NO pausable tree 2019 trips in a row — the storm writer is outside every ioPause.cgroupPattern and the guard CANNOT shed IO. Extend the patterns to the attributed writer (journalctl -u memory-emergency-guard | grep 'IO-PAUSE').".
Nov 14 13:45:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:45:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:46:13 evo-x2 memory-emergency-guard-check[766946]: MEMORY EMERGENCY IO-PAUSE (trip #9944, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 13:46:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:46:13 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 616ms CPU time over 995ms wall clock time, 11.9M memory peak, 8.3M read from disk, 55.4M written to disk.
Nov 14 13:46:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:47:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:47:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:48:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:48:43 evo-x2 memory-emergency-guard-check[832725]: MEMORY EMERGENCY IO-PAUSE (trip #9945, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 13:48:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:48:43 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 576ms CPU time over 1.333s wall clock time, 11.5M memory peak, 15.4M read from disk, 50.9M written to disk.
Nov 14 13:49:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:49:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:50:12 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:50:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:51:13 evo-x2 memory-emergency-guard-check[889023]: MEMORY EMERGENCY IO-PAUSE (trip #9946, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 13:51:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:51:13 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 543ms CPU time over 621ms wall clock time, 12.8M memory peak, 720K read from disk, 19.2M written to disk.
Nov 14 13:51:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:52:13 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:52:43 evo-x2 memory-emergency-guard-check[934156]: MEMORY EMERGENCY still active (I/O PSI some avg60=59.44% sustained (max disk busy 98.7%, MemAvailable=34.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 14 13:52:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:53:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:53:45 evo-x2 memory-emergency-guard-check[952882]: MEMORY EMERGENCY IO-PAUSE (trip #9947, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 13:53:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:53:45 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 503ms CPU time over 797ms wall clock time, 12M memory peak, 528K read from disk, 16.2M written to disk.
Nov 14 13:54:14 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:54:40 evo-x2 gatus[80249]: 2026/11/14 13:54:40 [watchdog.monitorEndpoint] Canceling current execution of group=Monitoring; endpoint=Memory Emergency Guard; key=monitoring_memory-emergency-guard
Nov 14 13:54:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:55:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:55:20 evo-x2 systemd[1639]: Started [systemd-run] /nix/store/jrbrr93d8zj7np9ss67p1kh9yjf3ppbc-libnotify-0.8.9/bin/notify-send -u normal -t 30000 "SEV1: IO-PAUSE DISARMED" "memory-emergency-guard zone-6 IO-PAUSE matched NO pausable tree 2023 trips in a row — the storm writer is outside every ioPause.cgroupPattern and the guard CANNOT shed IO. Extend the patterns to the attributed writer (journalctl -u memory-emergency-guard | grep 'IO-PAUSE').".
Nov 14 13:55:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:56:16 evo-x2 memory-emergency-guard-check[1042206]: MEMORY EMERGENCY IO-PAUSE (trip #9948, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 13:56:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:56:16 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 717ms CPU time over 1.010s wall clock time, 14.4M memory peak, 8.5M read from disk, 69.6M written to disk.
Nov 14 13:56:42 evo-x2 systemd[1639]: Started [systemd-run] /nix/store/jrbrr93d8zj7np9ss67p1kh9yjf3ppbc-libnotify-0.8.9/bin/notify-send -u normal -t 30000 "SEV1: UNIT CRASH LOOP; IO-PAUSE DISARMED" "A monitored service is restart-looping (tq-agent-pool) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u tq-agent-pool -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading. | memory-emergency-guard zone-6 IO-PAUSE matched NO pausable tree 2024 trips in a row — the storm writer is outside every ioPause.cgroupPattern and the guard CANNOT shed IO. Extend the patterns to the attributed writer (journalctl -u memory-emergency-guard | grep 'IO-PAUSE').".
Nov 14 13:56:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:57:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:57:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:58:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:58:22 evo-x2 systemd[1639]: Started [systemd-run] /nix/store/jrbrr93d8zj7np9ss67p1kh9yjf3ppbc-libnotify-0.8.9/bin/notify-send -u normal -t 30000 "SEV1: UNIT CRASH LOOP; ZRAM SWAP CRITICAL; IO-PAUSE DISARMED" "A monitored service is restart-looping (tq-agent-pool) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u tq-agent-pool -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading. | zram (the ONLY swap) is nearly full AND margins are degraded (PSI some avg10=7.99%, MemAvailable=51.1%) — the memory guard is about to sacrifice FastFlowLM; shed load now. | memory-emergency-guard zone-6 IO-PAUSE matched NO pausable tree 2024 trips in a row — the storm writer is outside every ioPause.cgroupPattern and the guard CANNOT shed IO. Extend the patterns to the attributed writer (journalctl -u memory-emergency-guard | grep 'IO-PAUSE').".
Nov 14 13:58:46 evo-x2 memory-emergency-guard-check[1118528]: MEMORY EMERGENCY IO-PAUSE (trip #9949, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 13:58:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:58:46 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 578ms CPU time over 881ms wall clock time, 12.5M memory peak, 5.9M read from disk, 21.6M written to disk.
Nov 14 13:59:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 13:59:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:00:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:00:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:01:17 evo-x2 memory-emergency-guard-check[1183937]: MEMORY EMERGENCY IO-PAUSE (trip #9950, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 14:01:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:01:17 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 695ms CPU time over 1.375s wall clock time, 11.8M memory peak, 52.6M read from disk, 89.7M written to disk.
Nov 14 14:01:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:02:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:02:45 evo-x2 memory-emergency-guard-check[1231547]: MEMORY EMERGENCY still active (I/O PSI some avg60=62.99% sustained (max disk busy 98.7%, MemAvailable=52.2% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (90s < 150s, 60s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 14 14:02:45 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:03:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:03:47 evo-x2 memory-emergency-guard-check[1282291]: MEMORY EMERGENCY IO-PAUSE (trip #9951, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 14:03:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:03:47 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 784ms CPU time over 1.343s wall clock time, 10.3M memory peak, 13.4M read from disk, 55.5M written to disk.
Nov 14 14:04:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:04:33 evo-x2 post-crash-calm-gate[1344656]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 14 14:04:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:04:48 evo-x2 post-crash-calm-gate[1372464]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 14 14:05:03 evo-x2 post-crash-calm-gate[1397575]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 14 14:05:15 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:05:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:06:17 evo-x2 memory-emergency-guard-check[1460877]: MEMORY EMERGENCY IO-PAUSE (trip #9952, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 14:06:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:06:17 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 938ms CPU time over 1.870s wall clock time, 10.5M memory peak, 6.7M read from disk, 47.8M written to disk.
Nov 14 14:06:19 evo-x2 post-crash-calm-gate[1471219]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 14 14:06:34 evo-x2 post-crash-calm-gate[1490207]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 14 14:06:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:06:49 evo-x2 post-crash-calm-gate[1514352]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 14 14:07:04 evo-x2 post-crash-calm-gate[1530098]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 14 14:07:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:07:19 evo-x2 post-crash-calm-gate[1542424]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 14 14:07:34 evo-x2 post-crash-calm-gate[1570659]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 14 14:07:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:07:49 evo-x2 post-crash-calm-gate[1601208]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 14 14:08:04 evo-x2 post-crash-calm-gate[1619694]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 14 14:08:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:08:19 evo-x2 post-crash-calm-gate[1630323]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 14 14:08:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:08:49 evo-x2 post-crash-calm-gate[1655273]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 14 14:09:04 evo-x2 post-crash-calm-gate[1669881]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 14 14:09:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:09:19 evo-x2 post-crash-calm-gate[1691680]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 3 min ago (window 60 min).
Nov 14 14:09:34 evo-x2 post-crash-calm-gate[1713347]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 3 min ago (window 60 min).
Nov 14 14:09:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:09:49 evo-x2 post-crash-calm-gate[1732753]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 3 min ago (window 60 min).
Nov 14 14:10:04 evo-x2 post-crash-calm-gate[1755289]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 3 min ago (window 60 min).
Nov 14 14:10:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:10:19 evo-x2 post-crash-calm-gate[1776994]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 4 min ago (window 60 min).
Nov 14 14:10:34 evo-x2 post-crash-calm-gate[1792000]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 4 min ago (window 60 min).
Nov 14 14:10:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:10:49 evo-x2 post-crash-calm-gate[1811349]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 4 min ago (window 60 min).
Nov 14 14:11:04 evo-x2 post-crash-calm-gate[1821338]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 4 min ago (window 60 min).
Nov 14 14:11:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:11:34 evo-x2 post-crash-calm-gate[1857974]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 5 min ago (window 60 min).
Nov 14 14:11:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:11:49 evo-x2 post-crash-calm-gate[1870473]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 5 min ago (window 60 min).
Nov 14 14:12:04 evo-x2 post-crash-calm-gate[1900922]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 5 min ago (window 60 min).
Nov 14 14:12:16 evo-x2 memory-emergency-guard-check[1907733]: MEMORY EMERGENCY IO-PAUSE (trip #9953, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 14:12:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:12:16 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 628ms CPU time over 936ms wall clock time, 10.3M memory peak, 6.3M read from disk, 32.3M written to disk.
Nov 14 14:12:46 evo-x2 memory-emergency-guard-check[1973225]: MEMORY EMERGENCY still active (I/O PSI some avg60=41.97% sustained (max disk busy 99.4%, MemAvailable=48.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 14 14:12:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:13:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:13:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:14:04 evo-x2 post-crash-calm-gate[2075077]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 14 14:14:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:14:47 evo-x2 memory-emergency-guard-check[2122064]: MEMORY EMERGENCY IO-PAUSE (trip #9954, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 14:14:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:14:47 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 854ms CPU time over 1.274s wall clock time, 9.3M memory peak, 2.4M read from disk, 31.1M written to disk.
Nov 14 14:15:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:15:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:16:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:16:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:16:50 evo-x2 post-crash-calm-gate[2270901]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 14 14:17:05 evo-x2 post-crash-calm-gate[2301207]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 14 14:17:17 evo-x2 memory-emergency-guard-check[2309587]: MEMORY EMERGENCY IO-PAUSE (trip #9955, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 14:17:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:17:17 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 857ms CPU time over 1.512s wall clock time, 9.3M memory peak, 1.4M read from disk, 27.8M written to disk.
Nov 14 14:17:20 evo-x2 post-crash-calm-gate[2319462]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 14 14:17:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:18:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:18:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:19:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:19:47 evo-x2 memory-emergency-guard-check[2377164]: MEMORY EMERGENCY IO-PAUSE (trip #9956, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 14:19:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:19:47 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 610ms CPU time over 800ms wall clock time, 10.6M memory peak, 6.6M read from disk, 31.3M written to disk.
Nov 14 14:20:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:20:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:21:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:21:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:22:17 evo-x2 memory-emergency-guard-check[2515066]: MEMORY EMERGENCY IO-PAUSE (trip #9957, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 14:22:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:22:17 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 685ms CPU time over 979ms wall clock time, 9.9M memory peak, 9.9M read from disk, 32.5M written to disk.
Nov 14 14:22:35 evo-x2 post-crash-calm-gate[2555075]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 14 14:22:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:22:50 evo-x2 post-crash-calm-gate[2566193]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 14 14:23:05 evo-x2 post-crash-calm-gate[2570848]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 14 14:23:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:23:20 evo-x2 post-crash-calm-gate[2589083]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 14 14:23:35 evo-x2 post-crash-calm-gate[2611388]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 14 14:23:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:23:50 evo-x2 post-crash-calm-gate[2626588]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 14 14:24:05 evo-x2 post-crash-calm-gate[2640649]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 14 14:24:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:24:20 evo-x2 post-crash-calm-gate[2653354]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 14 14:24:35 evo-x2 post-crash-calm-gate[2664606]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 14 14:24:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:24:50 evo-x2 post-crash-calm-gate[2685864]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 14 14:25:05 evo-x2 post-crash-calm-gate[2697824]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 14 14:25:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:25:20 evo-x2 post-crash-calm-gate[2713083]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 3 min ago (window 60 min).
Nov 14 14:25:35 evo-x2 post-crash-calm-gate[2723214]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 3 min ago (window 60 min).
Nov 14 14:25:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:25:50 evo-x2 post-crash-calm-gate[2737702]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 3 min ago (window 60 min).
Nov 14 14:26:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:26:35 evo-x2 post-crash-calm-gate[2752783]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 4 min ago (window 60 min).
Nov 14 14:26:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:27:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:27:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:28:17 evo-x2 memory-emergency-guard-check[2794996]: MEMORY EMERGENCY IO-PAUSE (trip #9958, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 14:28:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:28:17 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 651ms CPU time over 803ms wall clock time, 9.1M memory peak, 1.5M read from disk, 28.6M written to disk.
Nov 14 14:28:46 evo-x2 memory-emergency-guard-check[2814341]: MEMORY EMERGENCY still active (I/O PSI some avg60=41.69% sustained (max disk busy 96.6%, MemAvailable=46.3% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 14 14:28:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:29:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:29:24 evo-x2 sudo[2828751]:     lars : PWD=/home/lars/projects/SystemNix ; USER=root ; COMMAND=/run/current-system/sw/bin/cat /var/lib/memory-emergency-guard/last-trip
Nov 14 14:29:46 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:30:16 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:30:35 evo-x2 post-crash-calm-gate[2855213]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 14 14:30:47 evo-x2 memory-emergency-guard-check[2859289]: MEMORY EMERGENCY IO-PAUSE (trip #9959, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 14:30:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:30:47 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 618ms CPU time over 787ms wall clock time, 10.1M memory peak, 2.6M read from disk, 30.7M written to disk.
Nov 14 14:30:50 evo-x2 post-crash-calm-gate[2873648]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 14 14:31:05 evo-x2 post-crash-calm-gate[2888710]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 14 14:31:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:31:20 evo-x2 post-crash-calm-gate[2908525]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 14 14:31:35 evo-x2 post-crash-calm-gate[2942367]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 14 14:31:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:31:50 evo-x2 post-crash-calm-gate[2962964]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 14 14:32:06 evo-x2 post-crash-calm-gate[2975536]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 14 14:32:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:32:21 evo-x2 post-crash-calm-gate[2982227]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 14 14:32:36 evo-x2 post-crash-calm-gate[2986942]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 14 14:32:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:32:51 evo-x2 post-crash-calm-gate[2994869]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 14 14:33:06 evo-x2 post-crash-calm-gate[3001236]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 14 14:33:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:33:21 evo-x2 post-crash-calm-gate[3009494]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 14 14:33:36 evo-x2 post-crash-calm-gate[3013168]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 14 14:33:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:33:47 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 120ms CPU time over 183ms wall clock time, 7.5M memory peak, 1.3M read from disk, 4K written to disk.
Nov 14 14:34:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:34:21 evo-x2 post-crash-calm-gate[3039790]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 3 min ago (window 60 min).
Nov 14 14:34:36 evo-x2 post-crash-calm-gate[3051930]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 3 min ago (window 60 min).
Nov 14 14:34:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:34:51 evo-x2 post-crash-calm-gate[3065951]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 4 min ago (window 60 min).
Nov 14 14:35:06 evo-x2 post-crash-calm-gate[3073259]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 4 min ago (window 60 min).
Nov 14 14:35:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:35:21 evo-x2 post-crash-calm-gate[3082392]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 4 min ago (window 60 min).
Nov 14 14:35:36 evo-x2 post-crash-calm-gate[3088954]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 4 min ago (window 60 min).
Nov 14 14:35:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:35:51 evo-x2 post-crash-calm-gate[3106427]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 5 min ago (window 60 min).
Nov 14 14:36:06 evo-x2 post-crash-calm-gate[3112345]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 5 min ago (window 60 min).
Nov 14 14:36:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:36:21 evo-x2 post-crash-calm-gate[3119433]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 5 min ago (window 60 min).
Nov 14 14:36:36 evo-x2 post-crash-calm-gate[3144119]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 5 min ago (window 60 min).
Nov 14 14:36:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:36:51 evo-x2 post-crash-calm-gate[3156007]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 6 min ago (window 60 min).
Nov 14 14:37:06 evo-x2 post-crash-calm-gate[3171963]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 6 min ago (window 60 min).
Nov 14 14:37:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:37:21 evo-x2 post-crash-calm-gate[3179902]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 6 min ago (window 60 min).
Nov 14 14:37:36 evo-x2 post-crash-calm-gate[3183858]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 6 min ago (window 60 min).
Nov 14 14:37:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:37:51 evo-x2 post-crash-calm-gate[3191604]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 7 min ago (window 60 min).
Nov 14 14:38:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:38:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:39:19 evo-x2 memory-emergency-guard-check[3223589]: MEMORY EMERGENCY IO-PAUSE (trip #9960, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 14:39:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:39:19 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 959ms CPU time over 1.675s wall clock time, 12M memory peak, 44M read from disk, 70.7M written to disk.
Nov 14 14:39:43 evo-x2 sudo[3240151]:     lars : PWD=/home/lars/projects/SystemNix ; USER=root ; COMMAND=/run/current-system/sw/bin/cat /var/lib/memory-emergency-guard/last-trip
Nov 14 14:39:47 evo-x2 memory-emergency-guard-check[3247220]: MEMORY EMERGENCY still active (I/O PSI some avg60=40.84% sustained (max disk busy 96.8%, MemAvailable=31.5% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 14 14:39:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:40:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:40:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:40:51 evo-x2 post-crash-calm-gate[3322794]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 14 14:41:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:41:36 evo-x2 post-crash-calm-gate[3341371]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 14 14:41:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:41:51 evo-x2 post-crash-calm-gate[3350859]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 14 14:42:06 evo-x2 post-crash-calm-gate[3366667]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 14 14:42:18 evo-x2 memory-emergency-guard-check[3369775]: MEMORY EMERGENCY IO-PAUSE (trip #9961, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 14:42:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:42:18 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 631ms CPU time over 983ms wall clock time, 10.2M memory peak, 8.3M read from disk, 22.2M written to disk.
Nov 14 14:42:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:43:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:43:21 evo-x2 post-crash-calm-gate[3422979]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 14 14:43:41 evo-x2 sudo[3450493]:     lars : PWD=/home/lars/projects/SystemNix ; USER=root ; COMMAND=/run/current-system/sw/bin/cat /var/lib/memory-emergency-guard/last-trip
Nov 14 14:43:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:43:51 evo-x2 post-crash-calm-gate[3458039]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 14 14:44:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:44:47 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:45:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:45:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:45:48 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 117ms CPU time over 564ms wall clock time, 15.4M memory peak, 7.6M read from disk, 4K written to disk.
Nov 14 14:46:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:46:23 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 161ms CPU time over 5.996s wall clock time, 10.2M memory peak, 4.6M read from disk, 4K written to disk.
Nov 14 14:46:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:46:53 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 109ms CPU time over 5.441s wall clock time, 7.6M memory peak, 1.8M read from disk, 12K written to disk.
Nov 14 14:47:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:47:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:47:49 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 121ms CPU time over 2.098s wall clock time, 9M memory peak, 3.3M read from disk, 4K written to disk.
Nov 14 14:48:21 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:48:21 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 113ms CPU time over 3.892s wall clock time, 9.3M memory peak, 3.1M read from disk, 4K written to disk.
Nov 14 14:48:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:48:48 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 146ms CPU time over 544ms wall clock time, 9.3M memory peak, 1.7M read from disk, 4K written to disk.
Nov 14 14:48:52 evo-x2 systemd[1639]: Started [systemd-run] /nix/store/jrbrr93d8zj7np9ss67p1kh9yjf3ppbc-libnotify-0.8.9/bin/notify-send -u normal -t 30000 "SEV1: SYSTEM MONITORING STALE; UNIT CRASH LOOP; ZRAM SWAP CRITICAL; IO-PAUSE DISARMED" "system_health metrics missing/stale (-1s old). Most Gatus conditions are phantom right now. systemctl status system-health-metrics | A monitored service is restart-looping (tq-agent-pool) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u tq-agent-pool -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading. | zram (the ONLY swap) is nearly full AND margins are degraded (PSI some avg10=27.88%, MemAvailable=1.1%) — the memory guard is about to sacrifice FastFlowLM; shed load now. | memory-emergency-guard zone-6 IO-PAUSE matched NO pausable tree 2037 trips in a row — the storm writer is outside every ioPause.cgroupPattern and the guard CANNOT shed IO. Extend the patterns to the attributed writer (journalctl -u memory-emergency-guard | grep 'IO-PAUSE').".
Nov 14 14:49:00 evo-x2 systemd[1639]: Started [systemd-run] /nix/store/jrbrr93d8zj7np9ss67p1kh9yjf3ppbc-libnotify-0.8.9/bin/notify-send -u normal -t 30000 "SEV1: UNIT CRASH LOOP; ZRAM SWAP CRITICAL; IO-PAUSE DISARMED" "A monitored service is restart-looping (tq-agent-pool) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u tq-agent-pool -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading. | zram (the ONLY swap) is nearly full AND margins are degraded (PSI some avg10=16.21%, MemAvailable=0.6%) — the memory guard is about to sacrifice FastFlowLM; shed load now. | memory-emergency-guard zone-6 IO-PAUSE matched NO pausable tree 2037 trips in a row — the storm writer is outside every ioPause.cgroupPattern and the guard CANNOT shed IO. Extend the patterns to the attributed writer (journalctl -u memory-emergency-guard | grep 'IO-PAUSE').".
Nov 14 14:49:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:50:01 evo-x2 sudo[3595755]:     lars : PWD=/home/lars/projects/SystemNix ; USER=root ; COMMAND=/run/current-system/sw/bin/cat /var/lib/memory-emergency-guard/last-trip
Nov 14 14:50:06 evo-x2 gatus[1103084]: 2026/11/14 14:50:03 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=User Slice Memory with description='user-1000.slice memory exceeds 72G (90% of its MemoryHigh=80G). Throttling starts at 80G, hard kill at 90G. Desktop + crush-agent sessions legitimately use 40-60G; act only if PSI/zram also degrade (memory-emergency-guard owns real pressure).' has been TRIGGERED
Nov 14 14:50:06 evo-x2 gatus[1103084]: 2026/11/14 14:50:03 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=User Slice Memory with description='user-1000.slice memory exceeds 72G (90% of its MemoryHigh=80G). Throttling starts at 80G, hard kill at 90G. Desktop + crush-agent sessions legitimately use 40-60G; act only if PSI/zram also degrade (memory-emergency-guard owns real pressure).' has been TRIGGERED
Nov 14 14:50:06 evo-x2 memory-emergency-guard-check[3594213]: MEMORY EMERGENCY still active (MemAvailable=0.5% below absolute floor) but action cooldown active (462s < 600s, 138s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 14 14:49:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:49:59 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 124ms CPU time over 11.364s wall clock time, 8M memory peak, 1.3M read from disk, 4K written to disk.
Nov 14 14:50:03 evo-x2 systemd[1639]: Started [systemd-run] /nix/store/jrbrr93d8zj7np9ss67p1kh9yjf3ppbc-libnotify-0.8.9/bin/notify-send -u normal -t 30000 "SEV1: MEMORY STALL SUSTAINED; UNIT CRASH LOOP; ZRAM SWAP CRITICAL; IO-PAUSE DISARMED" "Memory-stall freeze precursor, 2026-08-31 class (avg60=58.92%, avg10-episode bucket=1). Stop heavy builds / VM tests NOW; the guard is (about to be) sacrificing FastFlowLM. journalctl -u memory-emergency-guard -n 30 | A monitored service is restart-looping (tq-agent-pool) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u tq-agent-pool -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading. | zram (the ONLY swap) is nearly full AND margins are degraded (PSI some avg10=97.24%, MemAvailable=0.5%) — the memory guard is about to sacrifice FastFlowLM; shed load now. | memory-emergency-guard zone-6 IO-PAUSE matched NO pausable tree 2037 trips in a row — the storm writer is outside every ioPause.cgroupPattern and the guard CANNOT shed IO. Extend the patterns to the attributed writer (journalctl -u memory-emergency-guard | grep 'IO-PAUSE').".
Nov 14 14:50:21 evo-x2 memory-emergency-guard-check[3606175]: MEMORY EMERGENCY IO-PAUSE (trip #9962, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 14:50:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:50:20 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 850ms CPU time over 2.623s wall clock time, 10.3M memory peak, 34.3M read from disk, 57.6M written to disk.
Nov 14 14:50:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:51:02 evo-x2 sudo[3636322]:     lars : PWD=/home/lars/projects/SystemNix ; USER=root ; COMMAND=/run/current-system/sw/bin/cat /var/lib/memory-emergency-guard/last-trip
Nov 14 14:51:03 evo-x2 gatus[1103084]: 2026/11/14 14:51:03 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Guard Collector Fresh with description='memory-emergency-guard metrics are FROZEN (no rewrite within 300s) — the automated pre-freeze protection is DOWN (crash-looped, wedged, or its timer died). The desktop channel already got the sev1 MEMORY GUARD DEAD notify. Check: systemctl status memory-emergency-guard memory-emergency-guard.timer, journalctl -u memory-emergency-guard -n 30.' has been TRIGGERED
Nov 14 14:51:03 evo-x2 gatus[1103084]: 2026/11/14 14:51:03 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Guard Collector Fresh with description='memory-emergency-guard metrics are FROZEN (no rewrite within 300s) — the automated pre-freeze protection is DOWN (crash-looped, wedged, or its timer died). The desktop channel already got the sev1 MEMORY GUARD DEAD notify. Check: systemctl status memory-emergency-guard memory-emergency-guard.timer, journalctl -u memory-emergency-guard -n 30.' has been TRIGGERED
Nov 14 14:51:03 evo-x2 systemd[1639]: Started [systemd-run] /nix/store/jrbrr93d8zj7np9ss67p1kh9yjf3ppbc-libnotify-0.8.9/bin/notify-send -u normal -t 30000 "SEV1: UNIT CRASH LOOP; IO-PAUSE DISARMED" "A monitored service is restart-looping (tq-agent-pool) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u tq-agent-pool -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading. | memory-emergency-guard zone-6 IO-PAUSE matched NO pausable tree 2038 trips in a row — the storm writer is outside every ioPause.cgroupPattern and the guard CANNOT shed IO. Extend the patterns to the attributed writer (journalctl -u memory-emergency-guard | grep 'IO-PAUSE').".
Nov 14 14:51:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:51:19 evo-x2 post-crash-calm-gate[3647843]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 14 14:51:34 evo-x2 post-crash-calm-gate[3651667]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 14 14:51:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:51:49 evo-x2 post-crash-calm-gate[3659886]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 14 14:52:02 evo-x2 sudo[3670821]:     lars : PWD=/home/lars/projects/SystemNix ; USER=root ; COMMAND=/run/current-system/sw/bin/cat /var/lib/memory-emergency-guard/last-trip
Nov 14 14:52:04 evo-x2 post-crash-calm-gate[3671961]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 14 14:52:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:52:20 evo-x2 post-crash-calm-gate[3683166]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 14 14:52:35 evo-x2 post-crash-calm-gate[3687312]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 2 min ago (window 60 min).
Nov 14 14:52:49 evo-x2 memory-emergency-guard-check[3691744]: MEMORY EMERGENCY IO-PAUSE (trip #9963, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 14:52:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:52:49 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 900ms CPU time over 1.339s wall clock time, 9M memory peak, 3.5M read from disk, 50.9M written to disk.
Nov 14 14:52:50 evo-x2 post-crash-calm-gate[3697397]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 14 14:53:02 evo-x2 sudo[3704424]:     lars : PWD=/home/lars/projects/SystemNix ; USER=root ; COMMAND=/run/current-system/sw/bin/cat /var/lib/memory-emergency-guard/last-trip
Nov 14 14:53:05 evo-x2 post-crash-calm-gate[3705943]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 14 14:53:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:53:20 evo-x2 post-crash-calm-gate[3715043]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 14 14:53:35 evo-x2 post-crash-calm-gate[3718658]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 0 min ago (window 60 min).
Nov 14 14:53:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:53:50 evo-x2 post-crash-calm-gate[3724828]: REFUSE: post-crash-calm-gate — memory-emergency-guard tripped 1 min ago (window 60 min).
Nov 14 14:54:02 evo-x2 sudo[3728210]:     lars : PWD=/home/lars/projects/SystemNix ; USER=root ; COMMAND=/run/current-system/sw/bin/cat /var/lib/memory-emergency-guard/last-trip
Nov 14 14:54:18 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:54:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:55:03 evo-x2 sudo[3752685]:     lars : PWD=/home/lars/projects/SystemNix ; USER=root ; COMMAND=/run/current-system/sw/bin/cat /var/lib/memory-emergency-guard/last-trip
Nov 14 14:55:15 evo-x2 systemd[1639]: Started [systemd-run] /nix/store/jrbrr93d8zj7np9ss67p1kh9yjf3ppbc-libnotify-0.8.9/bin/notify-send -u normal -t 30000 "SEV1: IO-PAUSE DISARMED" "memory-emergency-guard zone-6 IO-PAUSE matched NO pausable tree 2039 trips in a row — the storm writer is outside every ioPause.cgroupPattern and the guard CANNOT shed IO. Extend the patterns to the attributed writer (journalctl -u memory-emergency-guard | grep 'IO-PAUSE').".
Nov 14 14:55:19 evo-x2 memory-emergency-guard-check[3762096]: MEMORY EMERGENCY IO-PAUSE (trip #9964, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 14:55:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:55:19 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 609ms CPU time over 797ms wall clock time, 9.8M memory peak, 3.1M read from disk, 42.6M written to disk.
Nov 14 14:55:48 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:56:03 evo-x2 sudo[3793964]:     lars : PWD=/home/lars/projects/SystemNix ; USER=root ; COMMAND=/run/current-system/sw/bin/cat /var/lib/memory-emergency-guard/last-trip
Nov 14 14:56:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:56:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:57:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:57:50 evo-x2 memory-emergency-guard-check[3872290]: sort: write failed: 'standard output': Broken pipe
Nov 14 14:57:50 evo-x2 memory-emergency-guard-check[3872290]: sort: write error
Nov 14 14:57:50 evo-x2 memory-emergency-guard-check[3870408]: MEMORY EMERGENCY IO-PAUSE (trip #9965, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 14:57:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:57:50 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 862ms CPU time over 1.254s wall clock time, 8.6M memory peak, 3.9M read from disk, 30.6M written to disk.
Nov 14 14:58:19 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:58:49 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:59:20 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 14:59:50 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:00:35 evo-x2 sudo[4098888]:     lars : PWD=/home/lars/projects/SystemNix ; USER=root ; COMMAND=/run/current-system/sw/bin/cat /var/lib/memory-emergency-guard/last-trip
Nov 14 15:00:43 evo-x2 memory-emergency-guard-check[4087855]: MEMORY EMERGENCY IO-PAUSE (trip #9966, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 15:00:43 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:00:43 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 631ms CPU time over 21.610s wall clock time, 11.1M memory peak, 2.1M read from disk, 33.4M written to disk.
Nov 14 15:00:51 evo-x2 memory-emergency-guard-check[4103312]: MEMORY EMERGENCY still active (I/O PSI some avg60=58.67% sustained (max disk busy 100.0%, MemAvailable=34.1% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 14 15:00:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:01:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:01:35 evo-x2 sudo[4129065]:     lars : PWD=/home/lars/projects/SystemNix ; USER=root ; COMMAND=/run/current-system/sw/bin/cat /var/lib/memory-emergency-guard/last-trip
Nov 14 15:01:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:02:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:02:35 evo-x2 sudo[4159018]:     lars : PWD=/home/lars/projects/SystemNix ; USER=root ; COMMAND=/run/current-system/sw/bin/cat /var/lib/memory-emergency-guard/last-trip
Nov 14 15:03:17 evo-x2 memory-emergency-guard-check[4169735]: MEMORY EMERGENCY IO-PAUSE (trip #9967, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 15:03:17 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:03:17 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 805ms CPU time over 24.648s wall clock time, 9.6M memory peak, 14.5M read from disk, 10.2M written to disk.
Nov 14 15:03:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:03:35 evo-x2 sudo[23333]:     lars : PWD=/home/lars/projects/SystemNix ; USER=root ; COMMAND=/run/current-system/sw/bin/cat /var/lib/memory-emergency-guard/last-trip
Nov 14 15:03:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:04:22 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:04:35 evo-x2 sudo[50449]:     lars : PWD=/home/lars/projects/SystemNix ; USER=root ; COMMAND=/run/current-system/sw/bin/cat /var/lib/memory-emergency-guard/last-trip
Nov 14 15:04:52 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:05:35 evo-x2 sudo[81066]:     lars : PWD=/home/lars/projects/SystemNix ; USER=root ; COMMAND=/run/current-system/sw/bin/cat /var/lib/memory-emergency-guard/last-trip
Nov 14 15:05:42 evo-x2 memory-emergency-guard-check[67744]: MEMORY EMERGENCY IO-PAUSE (trip #9968, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 15:05:42 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:05:42 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 551ms CPU time over 19.822s wall clock time, 11.4M memory peak, 6.1M read from disk, 1.6M written to disk.
Nov 14 15:05:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:06:23 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:06:35 evo-x2 sudo[106140]:     lars : PWD=/home/lars/projects/SystemNix ; USER=root ; COMMAND=/run/current-system/sw/bin/cat /var/lib/memory-emergency-guard/last-trip
Nov 14 15:06:53 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:07:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:07:35 evo-x2 sudo[138159]:     lars : PWD=/home/lars/projects/SystemNix ; USER=root ; COMMAND=/run/current-system/sw/bin/cat /var/lib/memory-emergency-guard/last-trip
Nov 14 15:07:56 evo-x2 memory-emergency-guard-check[143235]: MEMORY EMERGENCY IO-PAUSE (trip #9969, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 15:07:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:07:56 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 574ms CPU time over 2.988s wall clock time, 11.6M memory peak, 17M read from disk, 35.6M written to disk.
Nov 14 15:08:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:08:36 evo-x2 sudo[163645]:     lars : PWD=/home/lars/projects/SystemNix ; USER=root ; COMMAND=/run/current-system/sw/bin/cat /var/lib/memory-emergency-guard/last-trip
Nov 14 15:08:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:09:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:09:24 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 157ms CPU time over 666ms wall clock time, 9M memory peak, 3.2M read from disk, 4K written to disk.
Nov 14 15:09:36 evo-x2 sudo[213038]:     lars : PWD=/home/lars/projects/SystemNix ; USER=root ; COMMAND=/run/current-system/sw/bin/cat /var/lib/memory-emergency-guard/last-trip
Nov 14 15:09:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:10:26 evo-x2 memory-emergency-guard-check[279778]: MEMORY EMERGENCY IO-PAUSE (trip #9970, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 15:10:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:10:26 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 789ms CPU time over 2.388s wall clock time, 13.5M memory peak, 24.5M read from disk, 49.1M written to disk.
Nov 14 15:10:36 evo-x2 sudo[293865]:     lars : PWD=/home/lars/projects/SystemNix ; USER=root ; COMMAND=/run/current-system/sw/bin/cat /var/lib/memory-emergency-guard/last-trip
Nov 14 15:10:54 evo-x2 memory-emergency-guard-check[299699]: MEMORY EMERGENCY still active (I/O PSI some avg60=41.89% sustained (max disk busy 80.1%, MemAvailable=30.4% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 14 15:10:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:11:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:11:36 evo-x2 sudo[331395]:     lars : PWD=/home/lars/projects/SystemNix ; USER=root ; COMMAND=/run/current-system/sw/bin/cat /var/lib/memory-emergency-guard/last-trip
Nov 14 15:11:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:12:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:12:36 evo-x2 sudo[385325]:     lars : PWD=/home/lars/projects/SystemNix ; USER=root ; COMMAND=/run/current-system/sw/bin/cat /var/lib/memory-emergency-guard/last-trip
Nov 14 15:12:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:13:25 evo-x2 memory-emergency-guard-check[451213]: MEMORY EMERGENCY IO-PAUSE (trip #9971, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 15:13:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:13:25 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 780ms CPU time over 1.039s wall clock time, 10.3M memory peak, 2M read from disk, 17.6M written to disk.
Nov 14 15:13:36 evo-x2 sudo[479509]:     lars : PWD=/home/lars/projects/SystemNix ; USER=root ; COMMAND=/run/current-system/sw/bin/cat /var/lib/memory-emergency-guard/last-trip
Nov 14 15:13:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:14:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:14:36 evo-x2 sudo[552306]:     lars : PWD=/home/lars/projects/SystemNix ; USER=root ; COMMAND=/run/current-system/sw/bin/cat /var/lib/memory-emergency-guard/last-trip
Nov 14 15:14:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:15:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:15:36 evo-x2 sudo[589497]:     lars : PWD=/home/lars/projects/SystemNix ; USER=root ; COMMAND=/run/current-system/sw/bin/cat /var/lib/memory-emergency-guard/last-trip
Nov 14 15:15:55 evo-x2 gatus[1103084]: 2026/11/14 15:15:55 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=User Slice Memory with description='user-1000.slice memory exceeds 72G (90% of its MemoryHigh=80G). Throttling starts at 80G, hard kill at 90G. Desktop + crush-agent sessions legitimately use 40-60G; act only if PSI/zram also degrade (memory-emergency-guard owns real pressure).' has been TRIGGERED
Nov 14 15:15:55 evo-x2 gatus[1103084]: 2026/11/14 15:15:55 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=User Slice Memory with description='user-1000.slice memory exceeds 72G (90% of its MemoryHigh=80G). Throttling starts at 80G, hard kill at 90G. Desktop + crush-agent sessions legitimately use 40-60G; act only if PSI/zram also degrade (memory-emergency-guard owns real pressure).' has been TRIGGERED
Nov 14 15:15:59 evo-x2 memory-emergency-guard-check[594797]: MEMORY EMERGENCY IO-PAUSE (trip #9972, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 15:15:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:15:59 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 1.333s CPU time over 4.945s wall clock time, 6.7M memory peak, 4.5M read from disk, 57.9M written to disk.
Nov 14 15:16:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:16:37 evo-x2 sudo[622950]:     lars : PWD=/home/lars/projects/SystemNix ; USER=root ; COMMAND=/run/current-system/sw/bin/cat /var/lib/memory-emergency-guard/last-trip
Nov 14 15:16:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:17:24 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:17:38 evo-x2 sudo[665439]:     lars : PWD=/home/lars/projects/SystemNix ; USER=root ; COMMAND=/run/current-system/sw/bin/cat /var/lib/memory-emergency-guard/last-trip
Nov 14 15:17:54 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:18:26 evo-x2 memory-emergency-guard-check[711730]: MEMORY EMERGENCY IO-PAUSE (trip #9973, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 15:18:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:18:26 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 568ms CPU time over 761ms wall clock time, 10.4M memory peak, 4.2M read from disk, 15M written to disk.
Nov 14 15:18:38 evo-x2 sudo[734005]:     lars : PWD=/home/lars/projects/SystemNix ; USER=root ; COMMAND=/run/current-system/sw/bin/cat /var/lib/memory-emergency-guard/last-trip
Nov 14 15:18:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:19:04 evo-x2 systemd[1639]: Started [systemd-run] /nix/store/jrbrr93d8zj7np9ss67p1kh9yjf3ppbc-libnotify-0.8.9/bin/notify-send -u normal -t 30000 "SEV1: UNIT CRASH LOOP; ZRAM SWAP CRITICAL; IO-PAUSE DISARMED" "A monitored service is restart-looping (audiblesync) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u audiblesync -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading. | zram (the ONLY swap) is nearly full AND margins are degraded (PSI some avg10=6.84%, MemAvailable=36.4%) — the memory guard is about to sacrifice FastFlowLM; shed load now. | memory-emergency-guard zone-6 IO-PAUSE matched NO pausable tree 2049 trips in a row — the storm writer is outside every ioPause.cgroupPattern and the guard CANNOT shed IO. Extend the patterns to the attributed writer (journalctl -u memory-emergency-guard | grep 'IO-PAUSE').".
Nov 14 15:19:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:19:38 evo-x2 sudo[760585]:     lars : PWD=/home/lars/projects/SystemNix ; USER=root ; COMMAND=/run/current-system/sw/bin/cat /var/lib/memory-emergency-guard/last-trip
Nov 14 15:19:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:20:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:20:38 evo-x2 sudo[779464]:     lars : PWD=/home/lars/projects/SystemNix ; USER=root ; COMMAND=/run/current-system/sw/bin/cat /var/lib/memory-emergency-guard/last-trip
Nov 14 15:20:56 evo-x2 memory-emergency-guard-check[782783]: MEMORY EMERGENCY IO-PAUSE (trip #9974, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 15:20:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:20:56 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 554ms CPU time over 826ms wall clock time, 11.1M memory peak, 4M read from disk, 27.9M written to disk.
Nov 14 15:21:25 evo-x2 memory-emergency-guard-check[801947]: MEMORY EMERGENCY still active (I/O PSI some avg60=61.42% sustained (max disk busy 99.5%, MemAvailable=32.0% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 14 15:21:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:21:38 evo-x2 sudo[808058]:     lars : PWD=/home/lars/projects/SystemNix ; USER=root ; COMMAND=/run/current-system/sw/bin/cat /var/lib/memory-emergency-guard/last-trip
Nov 14 15:21:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:22:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:22:38 evo-x2 sudo[832817]:     lars : PWD=/home/lars/projects/SystemNix ; USER=root ; COMMAND=/run/current-system/sw/bin/cat /var/lib/memory-emergency-guard/last-trip
Nov 14 15:22:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:23:26 evo-x2 memory-emergency-guard-check[847752]: MEMORY EMERGENCY IO-PAUSE (trip #9975, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 15:23:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:23:26 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 520ms CPU time over 598ms wall clock time, 12.1M memory peak, 2.1M read from disk, 18.9M written to disk.
Nov 14 15:23:38 evo-x2 sudo[861506]:     lars : PWD=/home/lars/projects/SystemNix ; USER=root ; COMMAND=/run/current-system/sw/bin/cat /var/lib/memory-emergency-guard/last-trip
Nov 14 15:23:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:24:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:24:38 evo-x2 sudo[880417]:     lars : PWD=/home/lars/projects/SystemNix ; USER=root ; COMMAND=/run/current-system/sw/bin/cat /var/lib/memory-emergency-guard/last-trip
Nov 14 15:24:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:25:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:25:38 evo-x2 sudo[902090]:     lars : PWD=/home/lars/projects/SystemNix ; USER=root ; COMMAND=/run/current-system/sw/bin/cat /var/lib/memory-emergency-guard/last-trip
Nov 14 15:25:56 evo-x2 memory-emergency-guard-check[905620]: MEMORY EMERGENCY IO-PAUSE (trip #9976, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 15:25:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:25:56 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 624ms CPU time over 768ms wall clock time, 11.5M memory peak, 8.2M read from disk, 17.3M written to disk.
Nov 14 15:26:25 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:26:38 evo-x2 sudo[927433]:     lars : PWD=/home/lars/projects/SystemNix ; USER=root ; COMMAND=/run/current-system/sw/bin/cat /var/lib/memory-emergency-guard/last-trip
Nov 14 15:26:55 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:27:04 evo-x2 systemd[1639]: Started [systemd-run] /nix/store/jrbrr93d8zj7np9ss67p1kh9yjf3ppbc-libnotify-0.8.9/bin/notify-send -u normal -t 30000 "SEV1: UNIT CRASH LOOP; IO-PAUSE DISARMED" "A monitored service is restart-looping (audiblesync) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u audiblesync -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading. | memory-emergency-guard zone-6 IO-PAUSE matched NO pausable tree 2052 trips in a row — the storm writer is outside every ioPause.cgroupPattern and the guard CANNOT shed IO. Extend the patterns to the attributed writer (journalctl -u memory-emergency-guard | grep 'IO-PAUSE').".
Nov 14 15:27:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:27:38 evo-x2 sudo[954245]:     lars : PWD=/home/lars/projects/SystemNix ; USER=root ; COMMAND=/run/current-system/sw/bin/cat /var/lib/memory-emergency-guard/last-trip
Nov 14 15:27:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:28:27 evo-x2 memory-emergency-guard-check[966895]: MEMORY EMERGENCY IO-PAUSE (trip #9977, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 15:28:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:28:28 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 694ms CPU time over 1.372s wall clock time, 12M memory peak, 35.4M read from disk, 57.2M written to disk.
Nov 14 15:28:38 evo-x2 sudo[979616]:     lars : PWD=/home/lars/projects/SystemNix ; USER=root ; COMMAND=/run/current-system/sw/bin/cat /var/lib/memory-emergency-guard/last-trip
Nov 14 15:28:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:29:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:29:38 evo-x2 sudo[1002635]:     lars : PWD=/home/lars/projects/SystemNix ; USER=root ; COMMAND=/run/current-system/sw/bin/cat /var/lib/memory-emergency-guard/last-trip
Nov 14 15:29:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:30:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:30:38 evo-x2 sudo[1023070]:     lars : PWD=/home/lars/projects/SystemNix ; USER=root ; COMMAND=/run/current-system/sw/bin/cat /var/lib/memory-emergency-guard/last-trip
Nov 14 15:30:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:31:27 evo-x2 memory-emergency-guard-check[1038636]: MEMORY EMERGENCY IO-PAUSE (trip #9978, zone 6): NO eligible headless tree matched the attribution (patterns: nix-daemon.service tq-agent-pool.service session- monitor365-server.service app.slice/run- llama-chat.service) — pressure persists but nothing pausable
Nov 14 15:31:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:31:27 evo-x2 systemd[1]: memory-emergency-guard.service: Consumed 562ms CPU time over 808ms wall clock time, 11.9M memory peak, 12M read from disk, 23.5M written to disk.
Nov 14 15:31:38 evo-x2 sudo[1054001]:     lars : PWD=/home/lars/projects/SystemNix ; USER=root ; COMMAND=/run/current-system/sw/bin/cat /var/lib/memory-emergency-guard/last-trip
Nov 14 15:31:55 evo-x2 gatus[1103084]: 2026/11/14 15:31:55 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=User Slice Memory with description='user-1000.slice memory exceeds 72G (90% of its MemoryHigh=80G). Throttling starts at 80G, hard kill at 90G. Desktop + crush-agent sessions legitimately use 40-60G; act only if PSI/zram also degrade (memory-emergency-guard owns real pressure).' has been TRIGGERED
Nov 14 15:31:55 evo-x2 gatus[1103084]: 2026/11/14 15:31:55 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=User Slice Memory with description='user-1000.slice memory exceeds 72G (90% of its MemoryHigh=80G). Throttling starts at 80G, hard kill at 90G. Desktop + crush-agent sessions legitimately use 40-60G; act only if PSI/zram also degrade (memory-emergency-guard owns real pressure).' has been TRIGGERED
Nov 14 15:31:56 evo-x2 memory-emergency-guard-check[1061323]: MEMORY EMERGENCY still active (I/O PSI some avg60=56.58% sustained (max disk busy 58.0%, MemAvailable=15.8% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)) but action cooldown active (30s < 150s, 120s remaining; last trip zone=6) — persistent pressure, NOT a new action: the trip already acted, this line is the guard's heartbeat
Nov 14 15:31:56 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:32:26 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:33:01 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:33:28 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:33:38 evo-x2 systemd[1639]: Started [systemd-run] /nix/store/jrbrr93d8zj7np9ss67p1kh9yjf3ppbc-libnotify-0.8.9/bin/notify-send -u normal -t 30000 "SEV1: MEMORY STALL SUSTAINED; UNIT CRASH LOOP; ZRAM SWAP CRITICAL; IO-PAUSE DISARMED" "Memory-stall freeze precursor, 2026-08-31 class (avg60=54.82%, avg10-episode bucket=2). Stop heavy builds / VM tests NOW; the guard is (about to be) sacrificing FastFlowLM. journalctl -u memory-emergency-guard -n 30 | A monitored service is restart-looping (audiblesync) — the 2026-10-20..25 nsfw class (5 days invisible). journalctl -u audiblesync -n 50; if it is a known crash, mask/stop it before it burns the disk cold-loading. | zram (the ONLY swap) is nearly full AND margins are degraded (PSI some avg10=97.57%, MemAvailable=12.3%) — the memory guard is about to sacrifice FastFlowLM; shed load now. | memory-emergency-guard zone-6 IO-PAUSE matched NO pausable tree 2054 trips in a row — the storm writer is outside every ioPause.cgroupPattern and the guard CANNOT shed IO. Extend the patterns to the attributed writer (journalctl -u memory-emergency-guard | grep 'IO-PAUSE').".
Nov 14 15:33:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:34:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:34:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:35:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:35:57 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:36:27 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:36:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:37:14 evo-x2 gatus[1103084]: 2026/11/14 15:37:14 [watchdog.handleAlertsToTrigger] Sending initial discord alert because alert for endpoint=Memory Guard PSI Episodes with description='Memory guard PSI episode bucket is at/above HALF its Zone-5 trip count — episodic avg10 stall episodes are accumulating toward an emergency trip (the 2026-08-31 pre-freeze signature: recurring spikes while avg60 stayed low). Identify the driver BEFORE the trip: journalctl -u memory-emergency-guard --since -2h | grep -iE 'episode|psi', then scripts/io-attribution.sh for the top cgroups; trip fires at 8 episodes.' has been TRIGGERED
Nov 14 15:37:14 evo-x2 gatus[1103084]: 2026/11/14 15:37:14 [watchdog.handleAlertsToTrigger] Sending initial custom alert because alert for endpoint=Memory Guard PSI Episodes with description='Memory guard PSI episode bucket is at/above HALF its Zone-5 trip count — episodic avg10 stall episodes are accumulating toward an emergency trip (the 2026-08-31 pre-freeze signature: recurring spikes while avg60 stayed low). Identify the driver BEFORE the trip: journalctl -u memory-emergency-guard --since -2h | grep -iE 'episode|psi', then scripts/io-attribution.sh for the top cgroups; trip fires at 8 episodes.' has been TRIGGERED
Nov 14 15:37:32 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:37:58 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:38:31 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:38:59 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:39:30 evo-x2 systemd[1]: memory-emergency-guard.service: Deactivated successfully.
Nov 14 15:39:42 evo-x2 systemd[1]: memory-emergency-guard.timer: Deactivated successfully.
Nov 14 15:39:43 evo-x2 gatus[1103084]: 2026/11/14 15:39:43 [watchdog.monitorEndpoint] Canceling current execution of group=Monitoring; endpoint=Memory Emergency Guard; key=monitoring_memory-emergency-guard
Nov 14 15:39:43 evo-x2 sudo[1176902]:     lars : PWD=/home/lars/projects/SystemNix ; USER=root ; COMMAND=/run/current-system/sw/bin/cat /var/lib/memory-emergency-guard/last-trip
```

## THERMAL THROTTLE lines
```
Nov 14 09:46:09 evo-x2 thermal-pstate-guard-check[311430]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=98C(hi:95/lo:80)
Nov 14 13:43:21 evo-x2 thermal-pstate-guard-check[710158]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=71C(hi:95/lo:80)
Nov 14 13:49:45 evo-x2 thermal-pstate-guard-check[863314]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=95C(hi:95/lo:80)
Nov 14 14:02:22 evo-x2 thermal-pstate-guard-check[1223624]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=75C(hi:95/lo:80)
Nov 14 14:03:12 evo-x2 thermal-pstate-guard-check[1254485]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=98C(hi:95/lo:80)
```

## Kernel panic/BUG/oops lines
```
Nov 14 09:29:52 evo-x2 kernel: Command line: initrd=\EFI\nixos\hax4lzv0p0czdmnqci6q20ywkam7cq9h-initrd-linux-7.3.3-initrd.efi init=/nix/store/xfbd8lvrkwkla7w2ffri64mnj5ssf7i4-nixos-system-evo-x2-26.11.20261107.f4a03c0/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.backend=efi pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=128M nmi_watchdog=panic softlockup_panic=1
Nov 14 09:29:52 evo-x2 kernel: Kernel command line: initrd=\EFI\nixos\hax4lzv0p0czdmnqci6q20ywkam7cq9h-initrd-linux-7.3.3-initrd.efi init=/nix/store/xfbd8lvrkwkla7w2ffri64mnj5ssf7i4-nixos-system-evo-x2-26.11.20261107.f4a03c0/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.backend=efi pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=128M nmi_watchdog=panic softlockup_panic=1
Nov 14 09:29:52 evo-x2 kernel: simple-framebuffer simple-framebuffer.0: [drm] Registered 1 planes with drm panic
Nov 14 09:29:54 evo-x2 kernel: amdgpu 0000:c6:00.0: [drm] Registered 4 planes with drm panic
```
## Remote log tail — ClickHouse death window (signoz_logs.distributed_logs_v2)

Death window per M22: [journal cut -> next boot], epoch-ns UTC. At a watchdog death the local journal loses its final ~30-90s to flush lag; when the OTel->ClickHouse pipeline is alive the remote tail is FRESHER than the journal cut (#36: newest row 5s before the cut), and when the collector died pre-death the pipeline is silently DARK (#37: 4h19m outage).
Window: 1794667278000000000 -> 1794667306000000000 epoch-ns UTC (2026-11-14 14:41:18 -> 2026-11-14 14:41:46 UTC)
PIPELINE DARK FOR THIS WINDOW — 0 rows in the window.
Per M22: ClickHouse absence is NOT evidence of absence — the collector has a fatal-at-startup failure mode that silences the whole log pipeline (proven #37). Cross-check signoz-collector liveness across this boot BEFORE trusting the gap.
```
```
