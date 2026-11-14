# Freeze #54 autopsy: memory-cliff led — a single 78 GB session hog, the swap-escape of every RAM bound, and oomd executing the desktop unit-by-unit

**2026-11-14 16:06 CET · session scope: owner ask "why did we fucking end up crashing from too much memory?" (post power-button) → full autopsy of boot `abaf0f51` → root-cause the memory-defense failures → fix them in-tree**

**Verified this session (command/capture cited):** full journal census of the died boot (466,607 lines captured to `~/.cache/freeze54/boot-abaf0f51.txt` before anything else); all 4 OOM invocations + victims; all 16 oomd "Marked" kill events; session-scope memory peaks from systemd teardown accounting; the live `/etc/systemd/system/user.slice.d/overrides.conf` + `/etc/systemd/system/user-1000.slice` unit files; live `memory.swap.max` = `max`; `grep -rl ManagedOOMSwap /etc/systemd/system/` → empty; the node_exporter 14:45:11 whole-file rejection line; canonical evidence pull (`docs/status/tasks/2026-11-14_14-59_boot-abaf0f51-evidence-pull.md`).

**NOT verified / not attempted:** the identity of the process inside `session-115.scope` (leader died with the boot, journal keeps no session-leader line, process census did not exist yet — the fix below exists precisely for this); SigNoz cgroup-census series for the death window (box storm-gated post-reboot, CH query deliberately not run); swap-limit sizing beyond first-principles (48G chosen, owner-tunable).

---

## a) Boundary and family

| Fact | Value |
|---|---|
| Boot | `abaf0f51` 09:29:52 → 15:41:18 (**6 h 11 m**; the freeze-#53 recovery boot) |
| Reset | `0x00200800` ACPI power state transition — **owner power-button**, logind ran a CLEAN poweroff ceremony (same class as #51; NOT WDT, NOT software reset) |
| Next boot | 15:41:46 (28 s gap — clean poweroff) |
| Census | 126 guard trips #9853→#9978 (**all** "NO eligible headless tree matched"); 200 DEEP THROTTLE ENTERs 09:47:11→15:38:50 (k10temp 98 °C, never-cooled, 3rd consecutive boot); 4 OOM inv / 4 kills; trips/h ≈ 20.4 |
| Family | **C — memory-cliff-led finish, first since #43** |

## b) Timeline (all times CET, from the journal capture)

- **09:32** first guard trip #9853 (3 min post-boot — storm re-armed immediately).
- **09:38** monitor365 cloud-sync crash-loop alert (the SIGSYS class — fixed in-tree same day by the parallel crash-loop-fix-wave session, `2026-11-14_16-20` report).
- **10:00:08 + 10:02:41** memcg OOM kills of two `nix` builds (8.3 G + 8.2 G anon, user scope).
- **~10:02** `session-115.scope` starts (teardown accounting: 5 h 37 m wall).
- **10:08:06** first SEV1 "ZRAM SWAP CRITICAL" — **zram ≥90% from here to death, 5 h 33 m**.
- **11:43–11:59** parallel deploy attempt fails on gate legs (zram 97.6%, PSI, phantom metric — correctly refused, exit 12).
- **12:05** fuzz swarm load 1095 (self-exited; per the 12-08 report).
- **13:21:58 + 13:43:49** oomd memory-pressure kills `cvagent.service` ×2 (system.slice 63.89%/62.78% > 60%).
- **14:45:11** **node_exporter REJECTS the entire `system_health.prom`** — "line 926: expected float as value, got \"\"" — every `system_*` metric dark for the death window (**4th whole-file incident**: 2026-09-20, 10-03, 10-12, now).
- **14:47:29** `kswapd0` invoked the **global OOM killer** (GFP_KERNEL); after a 69 s thrash scan it killed at 14:48:38: `llama-server` (16.8 G VM) **and `helium`** (1.5 TB total-vm GPU mappings) — both `oom_score_adj 300`, OUR sacrifice ranking.
- **14:49:58 → 15:39:32** **oomd user-slice kill spiral — 15 cgroups executed, including the desktop itself**: `session-46.scope` (67.9 G hog #2) 14:49; `helium.service` 15:33:24; chromium scope 15:34:24; **`niri.service` 15:34:40 (the compositor — this is the black screen)**; `app-niri-ghostty-*` scopes ×5 (the agent terminals); `nextd` 15:39:16; sessions 57/431/194/579. Trigger each time: "memory pressure for /user.slice being 82–97% > 60% for > 30s".
- **15:31:56** guard heartbeat names it itself: IO PSI avg60 56.58%, **MemAvailable 15.8%** — "the crash #3 class".
- **~15:39:5x** owner holds the power button ("nothing worked anymore" = compositor, terminals and browser all oomd-killed, box thrashing at 98 °C) → logind clean poweroff, last line 15:41:18.

## c) The memory topology at death (systemd teardown accounting)

| Scope | RAM peak | Swap peak | Notes |
|---|---|---|---|
| `user.slice` / `user-1000.slice` | **81.7 G / 80.9 G** | **60 G** | 450 G read / 446 G written in 6 h 11 m |
| `session-115.scope` | **77.9 G** | **53.6 G** | ONE session; 2 h 52 m CPU, 54.2 G written, 820 M network out; started ~10:02 — right after the nix memcg kills |
| `session-46.scope` | 67.9 G | — | hog #2, oomd-killed 14:49 |
| ~8 more session scopes | 23–27 G each | — | the agent fleet |
| `nix-daemon.service` | 14.5 G | — | builds |

## d) Why every defense failed (the actual root causes)

1. **MemoryHigh=80G / MemoryMax=90G on `user-1000.slice` are swap-blind.** Swapped pages LEAVE `memory.current`; under MemoryHigh reclaim the hog's anon went to zram, resident stayed under 80 G, and `memory.swap.max` was `max` (live-verified). The ceiling that was supposed to catch "runaway user allocations" (2026-06-19/2026-08-03 classes) instead **accelerated global swap exhaustion**. Logical footprint of the slice: 81 G RAM + 60 G swap ≈ 141 G on a 124 G box.
2. **The oomd swap trigger was NEVER ARMED.** `SwapUsedLimit=90%` is global oomd config, but the kill only acts on units carrying `ManagedOOMSwap=kill` — and NO unit on this box has it (live `grep` of `/etc/systemd/system/` empty; the NixOS `enableUserSlices` module writes only `ManagedOOMMemoryPressure=kill` + limit into `user.slice.d/overrides.conf`). So **4 h 51 m above the 90% swap limit produced zero swap kills** — dead policy since the day it was configured.
3. **The oomd pressure trigger fires only at the cliff, then kills blind.** Slice-level PSI avg10 >60% for 30 s wasn't met until global thrash (14:49). From there oomd killed the highest-PSI/swap candidates — which after the hog had swapped out was… the desktop: niri, ghostty, helium. oomd's candidate ranking (swap+pressure per cgroup, no per-process badness) cannot prefer "the 78 G hog" over "the compositor" once the hog's pages sit in zram. **The kernel global OOM at 14:47 showed the same bias** (adj-300 ranking picked the browser).
4. **The guard was structurally powerless** — 126/126 trips no-match: TTY-holding session scopes are outside every pausable pattern (2026-10-07 license revocation). Known gap, not new today.
5. **Monitoring was dark exactly when needed** — the 4th whole-file `.prom` rejection (empty value, line 926) blinded every `system_*` metric from 14:45. Gatus caught the rejection itself (worked), but the fix class has now repeated 4× because emitters are unguarded and node_exporter is all-or-nothing per file.

## e) Fixes landed this session (in-tree, deploy-gated — riding the same calm window as the crash-loop-fix wave)

1. **`MemorySwapMax = "48G"` on `user-1000.slice`** (boot.nix) — closes root cause #1. When the slice crosses 48 G swap, the SLICE's own memcg OOM kills its biggest task (the hog, by rss+swap badness) instead of the kernel picking the browser globally. 48 G leaves ~14 G of the 62 G zram for system.slice + kernel. Deliberately did NOT arm `ManagedOOMSwap=kill` on user slices: oomd's swap kill executes the WHOLE marked unit — on this single-user box that means the entire desktop (all sessions + niri), strictly worse than the memcg bound. Documented in-module.
2. **`.prom` publish gate** (system-health.nix) — validates the file after write, before `mv`: drops malformed lines, emits `system_health_prom_dropped_lines`, logs the offenders to the journal. One bad emitter line can never blind every `system_*` metric again (kills incident class #4 at the mechanism, not per-emitter whack-a-mole).
3. **Per-process memory census** (system-health.nix) — top-12 tasks by RSS+swap (`system_process_mem_bytes{pid,comm}`, comm only — argv carries secrets), flowing into the existing census durability ring. Next freeze answers "which process was the 78 G hog" from the dashboard instead of dying with the boot.

## f) Follow-ups (harvested at authoring time — see TODO rows)

1. **[blocked:deploy]** Deploy + verify the freeze-54 hardening: live `memory.swap.max` reads 48G, `system_process_mem_bytes` exists in SigNoz, a deliberately-corrupted line gets dropped not whole-file-rejected. → docs/todo/stability.md
2. **[decision]** Single-scope memory-hog desktop notification (warn-tier DMS banner, once, when one session scope holds >40 G): owner's 2026-09-02 rule bans memory overlays; the #54 wrinkle is that a warn ONCE at 10:08 named the killer 5 h before the cliff. Owner call. → docs/todo/stability.md
3. **[watch]** session-115 leader attribution stays open until the next incident — if the process census (fix #3) shows the same comm ballooning post-deploy, that closes it. → docs/todo/stability.md
4. Swap-limit sizing (48 G) is a first-principles pick; revisit with one boot of `system_process_mem_bytes` + `memory.swap.current` telemetry.

**Sources:** journal capture `~/.cache/freeze54/boot-abaf0f51.txt` · `docs/status/tasks/2026-11-14_14-59_boot-abaf0f51-evidence-pull.md` · ledger row #54 in `docs/agents/stability.md` · morning context: `2026-11-14_10-12_freeze-52-53-thermal-ceiling-morning-storm-double-cut.md`, `2026-11-14_12-08_buildflow-fleet-toolchain-install-and-boot-metrics-livelock.md`
