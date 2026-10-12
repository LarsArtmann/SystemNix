# Freeze #27 autopsy evidence — boot -2 (ebad051b, Oct 10 23:15:25 → hard cut Oct 11 11:07:59)
Pulled 2026-10-13 00:37 BEFORE any journal vacuum (the Oct-3 triage lost its journal this way). Source task: freeze-28 report §c/§f.4.

## Boot -2 first/last lines
```
Oct 10 23:15:25 evo-x2 kernel: Linux version 7.2.9 (nixbld@localhost) (gcc (GCC) 16.2.0, GNU ld (GNU Binutils) 2.46) #1-NixOS SMP PREEMPT_DYNAMIC Sat Oct  3 10:43:16 UTC 2026
Oct 10 23:15:25 evo-x2 kernel: Command line: initrd=\EFI\nixos\axl3v57y89q5di0p990h016fw4kk39wq-initrd-linux-7.2.9-initrd.efi init=/nix/store/cyanjjkrhvpinsl59zp7zlnknrzdqr3c-nixos-system-evo-x2-26.11.20261008.e7439b6/init iommu.passthrough=0 tpm.disabled=1 amdgpu.lockup_timeout=30000 amdgpu.gpu_recovery=1 amd_pstate=active amdgpu.ttm.pages_limit=31457280 amd_iommu=on pstore.backend=efi pstore.record_console=true pstore.max_reason=3 module_blacklist=serial8250 nvme_core.default_ps_max_latency_us=0 console=tty2 console=tty1 delayacct root=fstab loglevel=7 lsm=landlock,yama,bpf crashkernel=128M nmi_watchdog=panic softlockup_panic=1
Oct 10 23:15:25 evo-x2 kernel: x86/split lock detection: #DB: warning on user-space bus_locks
   [...]
Oct 11 11:07:47 evo-x2 systemd[1768]: Detect niri DRM zombie state and restart niri skipped, unmet condition check ConditionEnvironment=XDG_SESSION_ID
Oct 11 11:07:51 evo-x2 pma[2619]:  processing batch component=service project=/home/lars/projects/CV events=1 files=1 project=/home/lars/projects/CV events=1 files=1
Oct 11 11:07:59 evo-x2 pma[2619]:  processing batch component=service project=/home/lars/projects/CV events=1 files=1 project=/home/lars/projects/CV events=1 files=1
```

## Guard trips — all 37, zone 6, with IO attribution
```
Oct 10 23:17:25 evo-x2 memory-emergency-guard-check[11492]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2635, zone 6)
Oct 10 23:27:32 evo-x2 memory-emergency-guard-check[77260]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2636, zone 6) — top io since last trip: system.slice/io.stat +34817MB, system.slice/llama-chat.service/io.stat +3348MB, system.slice/papdashboard.service/io.stat +3207MB
Oct 10 23:37:36 evo-x2 memory-emergency-guard-check[198427]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2637, zone 6) — top io since last trip: system.slice/io.stat +34276MB, system.slice/llama-chat.service/io.stat +11359MB, user.slice/io.stat +6346MB
Oct 10 23:48:40 evo-x2 memory-emergency-guard-check[491200]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2638, zone 6) — top io since last trip: system.slice/io.stat +16589MB, user.slice/io.stat +10568MB, user.slice/user-1000.slice/io.stat +10567MB
Oct 10 23:58:42 evo-x2 memory-emergency-guard-check[905036]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2639, zone 6) — top io since last trip: user.slice/io.stat +13827MB, user.slice/user-1000.slice/io.stat +13795MB, system.slice/io.stat +13238MB
Oct 11 00:15:19 evo-x2 memory-emergency-guard-check[1335420]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2640, zone 6) — top io since last trip: system.slice/io.stat +77052MB, user.slice/io.stat +19123MB, user.slice/user-1000.slice/io.stat +18864MB
Oct 11 00:28:03 evo-x2 memory-emergency-guard-check[1826357]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2641, zone 6) — top io since last trip: system.slice/io.stat +31919MB, system.slice/nix-daemon.service/io.stat +17775MB, user.slice/io.stat +9681MB
Oct 11 00:38:04 evo-x2 memory-emergency-guard-check[2391053]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2642, zone 6) — top io since last trip: system.slice/io.stat +52817MB, user.slice/io.stat +24836MB, user.slice/user-1000.slice/io.stat +24506MB
Oct 11 00:48:08 evo-x2 memory-emergency-guard-check[2740872]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2643, zone 6) — top io since last trip: system.slice/io.stat +175218MB, system.slice/tq-agent-pool.service/io.stat +146792MB, user.slice/io.stat +10161MB
Oct 11 00:58:10 evo-x2 memory-emergency-guard-check[3223361]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2644, zone 6) — top io since last trip: system.slice/io.stat +177264MB, system.slice/tq-agent-pool.service/io.stat +155362MB, user.slice/io.stat +12393MB
Oct 11 01:08:14 evo-x2 memory-emergency-guard-check[3866822]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2645, zone 6) — top io since last trip: user.slice/io.stat +148823MB, user.slice/user-1000.slice/io.stat +148807MB, user.slice/user-1000.slice/session-213.scope/io.stat +136816MB
Oct 11 01:18:14 evo-x2 memory-emergency-guard-check[399006]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2646, zone 6) — top io since last trip: system.slice/io.stat +47719MB, system.slice/nix-daemon.service/io.stat +29020MB, user.slice/io.stat +14911MB
Oct 11 01:28:27 evo-x2 memory-emergency-guard-check[824488]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2647, zone 6) — top io since last trip: system.slice/io.stat +41179MB, user.slice/io.stat +29173MB, user.slice/user-1000.slice/io.stat +28942MB
Oct 11 01:38:34 evo-x2 memory-emergency-guard-check[1048905]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2648, zone 6) — top io since last trip: system.slice/io.stat +52537MB, user.slice/io.stat +49585MB, user.slice/user-1000.slice/io.stat +48600MB
Oct 11 01:48:40 evo-x2 memory-emergency-guard-check[1767271]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2649, zone 6) — top io since last trip: user.slice/io.stat +39456MB, user.slice/user-1000.slice/io.stat +38712MB, system.slice/io.stat +34630MB
Oct 11 01:58:43 evo-x2 memory-emergency-guard-check[2521394]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2650, zone 6) — top io since last trip: system.slice/io.stat +69932MB, system.slice/nix-daemon.service/io.stat +27522MB, user.slice/io.stat +18170MB
Oct 11 02:08:43 evo-x2 memory-emergency-guard-check[3174669]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2651, zone 6) — top io since last trip: system.slice/io.stat +51942MB, system.slice/nix-daemon.service/io.stat +15490MB, user.slice/io.stat +13724MB
Oct 11 02:19:22 evo-x2 memory-emergency-guard-check[3770427]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2652, zone 6) — top io since last trip: system.slice/io.stat +201781MB, system.slice/tq-agent-pool.service/io.stat +170928MB, user.slice/io.stat +16946MB
Oct 11 02:29:21 evo-x2 memory-emergency-guard-check[375021]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2653, zone 6) — top io since last trip: system.slice/io.stat +63234MB, system.slice/nix-daemon.service/io.stat +25103MB, system.slice/tq-agent-pool.service/io.stat +22022MB
Oct 11 02:39:22 evo-x2 memory-emergency-guard-check[1242752]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2654, zone 6) — top io since last trip: system.slice/io.stat +120644MB, system.slice/tq-agent-pool.service/io.stat +85780MB, system.slice/nix-daemon.service/io.stat +14908MB
Oct 11 02:49:22 evo-x2 memory-emergency-guard-check[1830845]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2655, zone 6) — top io since last trip: system.slice/io.stat +218699MB, system.slice/tq-agent-pool.service/io.stat +182559MB, system.slice/nix-daemon.service/io.stat +26350MB
Oct 11 03:19:28 evo-x2 memory-emergency-guard-check[3197385]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2656, zone 6) — top io since last trip: system.slice/io.stat +479244MB, system.slice/tq-agent-pool.service/io.stat +389456MB, user.slice/io.stat +29139MB
Oct 11 03:34:00 evo-x2 memory-emergency-guard-check[4017349]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2657, zone 6) — top io since last trip: system.slice/io.stat +161848MB, system.slice/tq-agent-pool.service/io.stat +124945MB, user.slice/io.stat +18095MB
Oct 11 03:44:00 evo-x2 memory-emergency-guard-check[191021]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2658, zone 6) — top io since last trip: system.slice/io.stat +275176MB, system.slice/tq-agent-pool.service/io.stat +212933MB, user.slice/io.stat +17684MB
Oct 11 03:54:04 evo-x2 memory-emergency-guard-check[559067]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2659, zone 6) — top io since last trip: system.slice/io.stat +66032MB, user.slice/io.stat +19575MB, user.slice/user-1000.slice/io.stat +19554MB
Oct 11 04:16:38 evo-x2 memory-emergency-guard-check[1510999]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2660, zone 6) — top io since last trip: system.slice/io.stat +83312MB, user.slice/io.stat +20416MB, user.slice/user-1000.slice/io.stat +20238MB
Oct 11 05:02:14 evo-x2 memory-emergency-guard-check[2513930]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2661, zone 6) — top io since last trip: system.slice/io.stat +64390MB, system.slice/inboxclean-web.service/io.stat +28107MB, user.slice/io.stat +25945MB
Oct 11 05:23:24 evo-x2 memory-emergency-guard-check[3448650]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2662, zone 6) — top io since last trip: system.slice/io.stat +45891MB, system.slice/nix-daemon.service/io.stat +19472MB, user.slice/io.stat +19346MB
Oct 11 05:42:33 evo-x2 memory-emergency-guard-check[4132252]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2663, zone 6) — top io since last trip: system.slice/io.stat +80104MB, user.slice/io.stat +20294MB, user.slice/user-1000.slice/io.stat +19402MB
Oct 11 05:57:38 evo-x2 memory-emergency-guard-check[1969602]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2664, zone 6) — top io since last trip: system.slice/io.stat +38011MB, user.slice/io.stat +9861MB, user.slice/user-1000.slice/io.stat +9831MB
Oct 11 06:34:17 evo-x2 memory-emergency-guard-check[3694191]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2665, zone 6) — top io since last trip: system.slice/io.stat +89911MB, user.slice/io.stat +23993MB, user.slice/user-1000.slice/io.stat +23744MB
Oct 11 07:36:42 evo-x2 memory-emergency-guard-check[949229]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2666, zone 6) — top io since last trip: system.slice/io.stat +206481MB, system.slice/inboxclean-web.service/io.stat +39161MB, user.slice/io.stat +16672MB
Oct 11 09:21:45 evo-x2 memory-emergency-guard-check[2888300]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2667, zone 6) — top io since last trip: system.slice/io.stat +100156MB, system.slice/inboxclean-web.service/io.stat +64192MB, user.slice/io.stat +21848MB
Oct 11 10:28:44 evo-x2 memory-emergency-guard-check[836035]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2668, zone 6) — top io since last trip: system.slice/io.stat +66467MB, user.slice/io.stat +31090MB, user.slice/user-1000.slice/io.stat +30543MB
Oct 11 10:38:56 evo-x2 memory-emergency-guard-check[1031244]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2669, zone 6) — top io since last trip: user.slice/io.stat +51843MB, user.slice/user-1000.slice/io.stat +50964MB, user.slice/user-1000.slice/session-1386.scope/io.stat +41552MB
Oct 11 10:49:03 evo-x2 memory-emergency-guard-check[1281421]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2670, zone 6) — top io since last trip: system.slice/io.stat +36977MB, user.slice/io.stat +33271MB, user.slice/user-1000.slice/io.stat +32135MB
Oct 11 11:03:42 evo-x2 memory-emergency-guard-check[2072954]: MEMORY EMERGENCY action taken: sockets + sacrifice units stopped (trip #2671, zone 6) — top io since last trip: system.slice/io.stat +27674MB, user.slice/io.stat +17715MB, user.slice/user-1000.slice/io.stat +17702MB
```

## Thermal pstate guard events
```
Oct 10 23:16:25 evo-x2 thermal-pstate-guard-check[4588]: thermal-pstate-guard: adopted externally-set mode: active (state said guided); streaks reset
Oct 10 23:37:09 evo-x2 thermal-pstate-guard-check[194325]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=96C(hi:95/lo:80)
Oct 10 23:47:12 evo-x2 thermal-pstate-guard-check[436403]: thermal-pstate-guard: throttled (guided), still hot: k10temp=95C(hi:95/lo:80)
Oct 10 23:57:12 evo-x2 thermal-pstate-guard-check[813503]: thermal-pstate-guard: throttled (guided), still hot: k10temp=98C(hi:95/lo:80)
Oct 11 00:07:21 evo-x2 thermal-pstate-guard-check[1176958]: thermal-pstate-guard: throttled (guided), still hot: k10temp=96C(hi:95/lo:80)
Oct 11 00:17:25 evo-x2 thermal-pstate-guard-check[1396761]: thermal-pstate-guard: throttled (guided), still hot: k10temp=95C(hi:95/lo:80)
Oct 11 00:27:32 evo-x2 thermal-pstate-guard-check[1811273]: thermal-pstate-guard: throttled (guided), still hot: k10temp=95C(hi:95/lo:80)
Oct 11 00:38:22 evo-x2 thermal-pstate-guard-check[2408744]: thermal-pstate-guard: throttled (guided), still hot: k10temp=95C(hi:95/lo:80)
Oct 11 00:48:25 evo-x2 thermal-pstate-guard-check[2757851]: thermal-pstate-guard: throttled (guided), still hot: k10temp=95C(hi:95/lo:80)
Oct 11 00:58:27 evo-x2 thermal-pstate-guard-check[3254503]: thermal-pstate-guard: throttled (guided), still hot: k10temp=98C(hi:95/lo:80)
Oct 11 01:08:36 evo-x2 thermal-pstate-guard-check[3901824]: thermal-pstate-guard: throttled (guided), still hot: k10temp=99C(hi:95/lo:80)
Oct 11 01:18:37 evo-x2 thermal-pstate-guard-check[433411]: thermal-pstate-guard: throttled (guided), still hot: k10temp=99C(hi:95/lo:80)
Oct 11 01:29:03 evo-x2 thermal-pstate-guard-check[841981]: thermal-pstate-guard: throttled (guided), still hot: k10temp=95C(hi:95/lo:80)
Oct 11 01:39:03 evo-x2 thermal-pstate-guard-check[1067243]: thermal-pstate-guard: throttled (guided), still hot: k10temp=95C(hi:95/lo:80)
Oct 11 01:49:26 evo-x2 thermal-pstate-guard-check[1834026]: thermal-pstate-guard: throttled (guided), still hot: k10temp=99C(hi:95/lo:80)
Oct 11 01:59:32 evo-x2 thermal-pstate-guard-check[2576849]: thermal-pstate-guard: throttled (guided), still hot: k10temp=99C(hi:95/lo:80)
Oct 11 02:09:36 evo-x2 thermal-pstate-guard-check[3210608]: thermal-pstate-guard: throttled (guided), still hot: k10temp=99C(hi:95/lo:80)
Oct 11 02:19:38 evo-x2 thermal-pstate-guard-check[3799488]: thermal-pstate-guard: throttled (guided), still hot: k10temp=99C(hi:95/lo:80)
Oct 11 02:29:47 evo-x2 thermal-pstate-guard-check[428731]: thermal-pstate-guard: throttled (guided), still hot: k10temp=98C(hi:95/lo:80)
Oct 11 02:39:51 evo-x2 thermal-pstate-guard-check[1270403]: thermal-pstate-guard: throttled (guided), still hot: k10temp=97C(hi:95/lo:80)
Oct 11 02:49:52 evo-x2 thermal-pstate-guard-check[1877780]: thermal-pstate-guard: throttled (guided), still hot: k10temp=98C(hi:95/lo:80)
Oct 11 03:00:00 evo-x2 thermal-pstate-guard-check[2282785]: thermal-pstate-guard: throttled (guided), still hot: k10temp=97C(hi:95/lo:80)
Oct 11 03:10:03 evo-x2 thermal-pstate-guard-check[2711518]: thermal-pstate-guard: throttled (guided), still hot: k10temp=99C(hi:95/lo:80)
Oct 11 03:20:04 evo-x2 thermal-pstate-guard-check[3239635]: thermal-pstate-guard: throttled (guided), still hot: k10temp=98C(hi:95/lo:80)
Oct 11 03:30:11 evo-x2 thermal-pstate-guard-check[3742510]: thermal-pstate-guard: throttled (guided), still hot: k10temp=98C(hi:95/lo:80)
Oct 11 03:40:11 evo-x2 thermal-pstate-guard-check[4166323]: thermal-pstate-guard: throttled (guided), still hot: k10temp=98C(hi:95/lo:80)
Oct 11 03:50:47 evo-x2 thermal-pstate-guard-check[454221]: thermal-pstate-guard: throttled (guided), still hot: k10temp=97C(hi:95/lo:80)
Oct 11 04:01:56 evo-x2 thermal-pstate-guard-check[934138]: thermal-pstate-guard: throttled (guided), still hot: k10temp=96C(hi:95/lo:80)
Oct 11 04:12:13 evo-x2 thermal-pstate-guard-check[1219304]: thermal-pstate-guard: throttled (guided), still hot: k10temp=95C(hi:95/lo:80)
Oct 11 04:22:32 evo-x2 thermal-pstate-guard-check[1710967]: thermal-pstate-guard: throttled (guided), still hot: k10temp=98C(hi:95/lo:80)
Oct 11 04:32:39 evo-x2 thermal-pstate-guard-check[1970586]: thermal-pstate-guard: throttled (guided), still hot: k10temp=95C(hi:95/lo:80)
Oct 11 04:38:45 evo-x2 thermal-pstate-guard-check[2090329]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=69C(hi:95/lo:80)
Oct 11 04:41:17 evo-x2 thermal-pstate-guard-check[2183249]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=97C(hi:95/lo:80)
Oct 11 04:49:24 evo-x2 thermal-pstate-guard-check[2315421]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=67C(hi:95/lo:80)
Oct 11 05:01:20 evo-x2 thermal-pstate-guard-check[2488128]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=98C(hi:95/lo:80)
Oct 11 05:11:42 evo-x2 thermal-pstate-guard-check[3073985]: thermal-pstate-guard: throttled (guided), still hot: k10temp=96C(hi:95/lo:80)
Oct 11 05:21:44 evo-x2 thermal-pstate-guard-check[3411010]: thermal-pstate-guard: throttled (guided), still hot: k10temp=98C(hi:95/lo:80)
Oct 11 05:31:48 evo-x2 thermal-pstate-guard-check[3659315]: thermal-pstate-guard: throttled (guided), still hot: k10temp=98C(hi:95/lo:80)
Oct 11 05:41:48 evo-x2 thermal-pstate-guard-check[4089979]: thermal-pstate-guard: throttled (guided), still hot: k10temp=99C(hi:95/lo:80)
Oct 11 05:51:54 evo-x2 thermal-pstate-guard-check[1387297]: thermal-pstate-guard: throttled (guided), still hot: k10temp=98C(hi:95/lo:80)
Oct 11 06:01:59 evo-x2 thermal-pstate-guard-check[2327022]: thermal-pstate-guard: throttled (guided), still hot: k10temp=98C(hi:95/lo:80)
Oct 11 06:12:03 evo-x2 thermal-pstate-guard-check[3016328]: thermal-pstate-guard: throttled (guided), still hot: k10temp=98C(hi:95/lo:80)
Oct 11 06:22:07 evo-x2 thermal-pstate-guard-check[3310107]: thermal-pstate-guard: throttled (guided), still hot: k10temp=98C(hi:95/lo:80)
Oct 11 06:32:13 evo-x2 thermal-pstate-guard-check[3592064]: thermal-pstate-guard: throttled (guided), still hot: k10temp=98C(hi:95/lo:80)
Oct 11 06:42:20 evo-x2 thermal-pstate-guard-check[4158592]: thermal-pstate-guard: throttled (guided), still hot: k10temp=97C(hi:95/lo:80)
Oct 11 06:52:53 evo-x2 thermal-pstate-guard-check[132282]: thermal-pstate-guard: throttled (guided), still hot: k10temp=95C(hi:95/lo:80)
Oct 11 07:03:27 evo-x2 thermal-pstate-guard-check[300723]: thermal-pstate-guard: throttled (guided), still hot: k10temp=96C(hi:95/lo:80)
Oct 11 07:13:34 evo-x2 thermal-pstate-guard-check[504577]: thermal-pstate-guard: throttled (guided), still hot: k10temp=95C(hi:95/lo:80)
Oct 11 07:23:35 evo-x2 thermal-pstate-guard-check[717545]: thermal-pstate-guard: throttled (guided), still hot: k10temp=97C(hi:95/lo:80)
Oct 11 07:33:39 evo-x2 thermal-pstate-guard-check[840998]: thermal-pstate-guard: throttled (guided), still hot: k10temp=96C(hi:95/lo:80)
Oct 11 07:50:07 evo-x2 thermal-pstate-guard-check[1103310]: thermal-pstate-guard: throttled (guided), still hot: k10temp=95C(hi:95/lo:80)
Oct 11 08:01:26 evo-x2 thermal-pstate-guard-check[1227188]: thermal-pstate-guard: throttled (guided), still hot: k10temp=96C(hi:95/lo:80)
Oct 11 08:11:42 evo-x2 thermal-pstate-guard-check[1329941]: thermal-pstate-guard: throttled (guided), still hot: k10temp=97C(hi:95/lo:80)
Oct 11 08:21:59 evo-x2 thermal-pstate-guard-check[1426780]: thermal-pstate-guard: throttled (guided), still hot: k10temp=96C(hi:95/lo:80)
Oct 11 08:36:44 evo-x2 thermal-pstate-guard-check[1636996]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=78C(hi:95/lo:80)
Oct 11 09:00:11 evo-x2 thermal-pstate-guard-check[2176865]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=97C(hi:95/lo:80)
Oct 11 09:10:15 evo-x2 thermal-pstate-guard-check[2498199]: thermal-pstate-guard: throttled (guided), still hot: k10temp=97C(hi:95/lo:80)
Oct 11 09:20:44 evo-x2 thermal-pstate-guard-check[2854697]: thermal-pstate-guard: throttled (guided), still hot: k10temp=96C(hi:95/lo:80)
Oct 11 09:31:09 evo-x2 thermal-pstate-guard-check[3407615]: thermal-pstate-guard: throttled (guided), still hot: k10temp=95C(hi:95/lo:80)
Oct 11 09:41:11 evo-x2 thermal-pstate-guard-check[3823864]: thermal-pstate-guard: throttled (guided), still hot: k10temp=95C(hi:95/lo:80)
```

## OOM / panic / MCE / BTRFS errors
OOM-pattern lines: 1 — inspected: it is a udev sysfs write error, NOT an OOM (zero oom-kill/invoked-oom/Out-of-memory events in the boot)
```
Oct 10 23:15:59 evo-x2 (udev-worker)[813]: sdb: /etc/udev/rules.d/99-local.rules:37 ATTR{queue/scheduler}="bfq": Failed to write "bfq" to sysfs attribute "queue/scheduler", ignoring: Device or resource busy
Oct 10 23:15:59 evo-x2 (udev-worker)[813]: sdb: /etc/udev/rules.d/99-local.rules:39 ATTR{queue/nr_requests}="128": Failed to write "128" to sysfs attribute "queue/nr_requests", ignoring: Device or resource busy
Oct 10 23:15:59 evo-x2 (udev-worker)[792]: sda: /etc/udev/rules.d/99-local.rules:37 ATTR{queue/scheduler}="bfq": Failed to write "bfq" to sysfs attribute "queue/scheduler", ignoring: Device or resource busy
Oct 10 23:15:59 evo-x2 (udev-worker)[792]: sda: /etc/udev/rules.d/99-local.rules:39 ATTR{queue/nr_requests}="128": Failed to write "128" to sysfs attribute "queue/nr_requests", ignoring: Device or resource busy
Oct 10 23:15:59 evo-x2 (udev-worker)[813]: sdb1: /etc/udev/rules.d/99-local.rules:39 ATTR{queue/nr_requests}="128": Could not chase sysfs attribute "/sys/devices/pci0000:00/0000:00:08.3/0000:c8:00.4/usb8/8-1/8-1:1.0/host0/target0:0:0/0:0:0:1/block/sdb/sdb1/queue/nr_requests", ignoring: No such file or directory
Oct 10 23:15:59 evo-x2 (udev-worker)[773]: sdd: /etc/udev/rules.d/99-local.rules:37 ATTR{queue/scheduler}="bfq": Failed to write "bfq" to sysfs attribute "queue/scheduler", ignoring: Device or resource busy
Oct 10 23:15:59 evo-x2 (udev-worker)[773]: sdd: /etc/udev/rules.d/99-local.rules:39 ATTR{queue/nr_requests}="128": Failed to write "128" to sysfs attribute "queue/nr_requests", ignoring: Device or resource busy
Oct 10 23:15:59 evo-x2 (udev-worker)[813]: sda: /etc/udev/rules.d/99-local.rules:37 ATTR{queue/scheduler}="bfq": Failed to write "bfq" to sysfs attribute "queue/scheduler", ignoring: Device or resource busy
Oct 10 23:15:59 evo-x2 (udev-worker)[813]: sda: /etc/udev/rules.d/99-local.rules:39 ATTR{queue/nr_requests}="128": Failed to write "128" to sysfs attribute "queue/nr_requests", ignoring: Device or resource busy
Oct 10 23:15:59 evo-x2 (udev-worker)[773]: sdc1: /etc/udev/rules.d/99-local.rules:39 ATTR{queue/nr_requests}="128": Could not chase sysfs attribute "/sys/devices/pci0000:00/0000:00:08.3/0000:c8:00.4/usb8/8-1/8-1:1.0/host0/target0:0:0/0:0:0:2/block/sdc/sdc1/queue/nr_requests", ignoring: No such file or directory
Oct 10 23:16:06 evo-x2 dbus-broker-launch[1399]: Ignoring duplicate name 'org.opensuse.CupsPkHelper.Mechanism' in service file '/nix/store/jw1r2r08vn79rck1jh8f1xxb5j2w8068-cups-pk-helper-0.2.6/share/dbus-1/system-services/org.opensuse.CupsPkHelper.Mechanism.service'
Oct 10 23:16:06 evo-x2 dbus-broker-launch[1399]: Ignoring duplicate name 'org.freedesktop.nm_dispatcher' in service file '/nix/store/vxlcffmhw7wsis0ib871ppnb88l437is-networkmanager-1.58.1/share/dbus-1/system-services/org.freedesktop.nm_dispatcher.service'
Oct 10 23:16:06 evo-x2 dbus-broker-launch[1399]: Ignoring duplicate name 'org.freedesktop.nm_priv_helper' in service file '/nix/store/vxlcffmhw7wsis0ib871ppnb88l437is-networkmanager-1.58.1/share/dbus-1/system-services/org.freedesktop.nm_priv_helper.service'
Oct 10 23:16:06 evo-x2 dbus-broker-launch[1399]: Ignoring duplicate name 'org.freedesktop.ModemManager1' in service file '/nix/store/4vj8rc4mpy3mjsnp8aajf0gycr1hfmlh-modemmanager-1.24.2/share/dbus-1/system-services/org.freedesktop.ModemManager1.service'
Oct 10 23:16:06 evo-x2 dbus-broker-launch[1399]: Ignoring duplicate name 'net.connman.ead' in service file '/nix/store/fydp26fflh3qqlxfl56dxg0bgglhfzii-iwd-3.12/share/dbus-1/system-services/net.connman.ead.service'
Oct 10 23:16:06 evo-x2 dbus-broker-launch[1399]: Ignoring duplicate name 'net.connman.iwd' in service file '/nix/store/fydp26fflh3qqlxfl56dxg0bgglhfzii-iwd-3.12/share/dbus-1/system-services/net.connman.iwd.service'
Oct 10 23:16:06 evo-x2 dbus-broker-launch[1399]: Ignoring duplicate name 'org.freedesktop.UDisks2' in service file '/nix/store/d78q0sf14y857fhnlp1xxxwhl18rkfxg-udisks-2.11.2/share/dbus-1/system-services/org.freedesktop.UDisks2.service'
Oct 10 23:16:06 evo-x2 dbus-broker-launch[1399]: Ignoring duplicate name 'org.bluez.mesh' in service file '/nix/store/8l7syi03wm19x41yvarswrqzz7jq404r-bluez-5.87/share/dbus-1/system-services/org.bluez.mesh.service'
Oct 10 23:16:06 evo-x2 dbus-broker-launch[1399]: Ignoring duplicate name 'org.bluez' in service file '/nix/store/8l7syi03wm19x41yvarswrqzz7jq404r-bluez-5.87/share/dbus-1/system-services/org.bluez.service'
Oct 10 23:16:06 evo-x2 dbus-broker-launch[1399]: Ignoring duplicate name 'org.blueman.Mechanism' in service file '/nix/store/28xc0qkaa113bbvr8ai393y1a61pv9yg-blueman-2.4.6/share/dbus-1/system-services/org.blueman.Mechanism.service'
Oct 10 23:16:06 evo-x2 dbus-broker-launch[1399]: Ignoring duplicate name 'org.freedesktop.Accounts' in service file '/nix/store/iyrwy64z830wa0w4hcpy5am5pfwdcx96-accountsservice-26.27.3/share/dbus-1/system-services/org.freedesktop.Accounts.service'
Oct 10 23:16:06 evo-x2 dbus-broker-launch[1399]: Ignoring duplicate name 'org.freedesktop.RealtimeKit1' in service file '/nix/store/06j4y7fqi4m3ynfwbpd9s7mr6infgn5f-rtkit-0.14/share/dbus-1/system-services/org.freedesktop.RealtimeKit1.service'
Oct 10 23:16:06 evo-x2 dbus-broker-launch[1399]: Ignoring duplicate name 'org.freedesktop.PolicyKit1' in service file '/nix/store/d527hwwggm2wz18p4v8cr39amcpx3g4c-polkit-127/share/dbus-1/system-services/org.freedesktop.PolicyKit1.service'
Oct 10 23:16:07 evo-x2 bluetoothd[1408]: profiles/audio/bap.c:bap_adapter_probe() BAP requires ISO Socket which is not enabled
Oct 10 23:16:07 evo-x2 bluetoothd[1408]: bap: Operation not supported (95)
Oct 10 23:16:18 evo-x2 dbus-broker-launch[3948]: Ignoring duplicate name 'com.mitchellh.ghostty' in service file '/etc/profiles/per-user/lars/share/dbus-1/services/com.mitchellh.ghostty.service'
Oct 10 23:16:18 evo-x2 dbus-broker-launch[3948]: Ignoring duplicate name 'ca.desrt.dconf' in service file '/nix/store/h18hwr54bvkgjbi5fbnrd6cx3ip3kwq7-system-path/share/dbus-1/services/ca.desrt.dconf.service'
Oct 10 23:16:18 evo-x2 dbus-broker-launch[3948]: Ignoring duplicate name 'com.feralinteractive.GameMode' in service file '/nix/store/h18hwr54bvkgjbi5fbnrd6cx3ip3kwq7-system-path/share/dbus-1/services/com.feralinteractive.GameMode.service'
Oct 10 23:16:18 evo-x2 dbus-broker-launch[3948]: Ignoring duplicate name 'org.openobex' in service file '/nix/store/h18hwr54bvkgjbi5fbnrd6cx3ip3kwq7-system-path/share/dbus-1/services/obex-data-server.service'
Oct 10 23:16:18 evo-x2 dbus-broker-launch[3948]: Ignoring duplicate name 'org.blueman.Applet' in service file '/nix/store/h18hwr54bvkgjbi5fbnrd6cx3ip3kwq7-system-path/share/dbus-1/services/org.blueman.Applet.service'
```

## SEV1 bridge (syslog identifier `-t sev1-bridge-check`): SEV1 ACTIVE the whole boot at notify tier
4037 "SEV1 active (2 condition(s), severity=notify): MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED" vs 7 "SEV1 cleared"; still ACTIVE at the last pre-cut run (11:07:33, 26 s before the cut). No page-tier condition ever fired. (The earlier `-g 'action taken'`-adjacent grep noise was nix-gc store-path matches.)
```
      1     nix-gc-start[981074]: deleting '/nix/store/s0a97z3j9sinipnvmnash614p1aq7rif-sev1-bridge-check.drv'
      1     nix-gc-start[981074]: deleting '/nix/store/p76ffxrmqz0yvvsip0h73fpnkdv8rjz6-sev1-bridge-check.drv'
      1     nix-gc-start[981074]: deleting '/nix/store/1zl6v8yn09jrmbd6apasj6df0zfak7h0-sev1-bridge-check'
```

## Journal rate at cut (livelock check)
lines 11:00–11:01: 1031
lines 11:07:00→cut: 1114

## Counter continuity
boot -2 last trip: trip #2671
boot -1 first trip: trip #2672
boot -1 trip count: 132 (the freeze-#28 boot)
