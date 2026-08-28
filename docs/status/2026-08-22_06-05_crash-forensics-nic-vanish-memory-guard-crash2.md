# Crash Forensics, NIC Vanish, Memory Guard — and Crash #2 That Beat the Guard

**Date:** 2026-08-22 06:04 CEST (supersedes the 05:46 report that was lost in crash #2 before reaching disk)
**Session window:** 00:50 – 06:04
**Machine:** evo-x2 (NixOS, kernel 7.1.8), current boot 0 started 05:55:36

---

## Executive Summary

The machine crashed **three times** around midnight and once again at **05:49:56** — the last one **while my new memory-emergency-guard was deployed and running** (it did not trip: thresholds too lax). The original crash at 00:27 was a memory-thrash kernel freeze; the 00:31 recovery boot had **no wired networking because the RTL8125 NIC fell off the PCIe bus** (user's second reboot retrained it); at 00:59 the **DAS dropped off USB entirely mid-write** and has **never come back** — as of 06:04, in the current boot, **ALL external disks are absent** (pool, buildcache, both SanDisks) and systemd is still "Expecting device" for them.

Shipped and deployed this session: memory-emergency-guard module, LAN-NIC presence metric + watchdog, forgejo OIDC full gate, 2 Gatus checks, AGENTS.md incident docs. The guard **tripped 7 times overnight and kept the machine alive for ~4.5 hours** — then the flm/socket-activation cycle re-pinned the model, zram refilled to 98%, and the box froze anyway at ~05:50 because the guard's combined threshold (MemAvailable <10% AND zram ≥92%) never fired at 30% available. **The guard is a bridge, not the fix — and its thresholds need retuning as P0.**

Physical action is the blocking item: the DAS (one USB link, 4 disks) is fully offline.

---

## 1. Forensics

### 1.1 Crash #1 — 00:27:09 kernel freeze (memory-thrash death spiral)

Boot `f6448713` (20:55–00:27). Evidence chain:

1. **22:25:36 kernel global OOM dump:** `Free swap = 0kB` of 29.5 GB (zram 100%), `unevictable: 24,967,388 kB`, `shmem: 24,903,652 kB` — flm's fully-resident 21.6 GB model was locked in as **shmem, which can only evict via swap — and swap was full**. Once zram fills, the model is permanently unevictable. THE trap.
2. **22:25–22:28 OOM cascade:** flm killed 4× (each cold-load retry re-read 21.6 GB; peaks 6.1G→8.1G→9.7G), ollama killed 2×, flm `start-limit-hit` 22:28:58. Restarts show `Scheduled restart job immediately on client request` — **socket-activation client-request restarts bypass the RestartSec=60 exponential backoff** deployed 2026-08-21. Known remaining hole.
3. **23:00–00:27 nightly I/O window:** btrbk sends + nix-gc (27+ min of deletes) + zram-refault CPU burn (ClickHouse `100% busy for 600s` = the decompression storm). journald `Under memory pressure, flushing caches` at 23:53.
4. **00:27:09.6 journal stops mid-activity.** No panic, no shutdown sequence. Hard freeze. User power-cycled ~00:31.
5. **Gatus alerted "Memory pressure CRITICAL" to Discord at 23:44 and 23:50** — 37–43 min of warning, no automated action existed.

### 1.2 The no-IP boot (00:31–00:47) — NIC fell off the PCIe bus

PCI enumeration diff across boots:

| Device                          | Boot -3 (healthy) | Boot -2 (no network)     | Boot -1 / 0 |
| ------------------------------- | ----------------- | ------------------------ | ----------- |
| Root port `00:02.1`             | present           | **ABSENT**               | present     |
| RTL8125 `10ec:8125` @ `c1:00.0` | present           | **ABSENT**               | present     |
| SDHCI `17a0:9755`               | `c2:00.0`         | **shifted to `c1:00.0`** | `c2:00.0`   |
| Buses c2..c7                    | —                 | renumbered −1            | normal      |

r8125 loaded but had **no device to probe**; `eno1` never existed; static IPs (192.168.1.150/.200/.53) never configured → **not even .150 answered on LAN**. The user's second reboot retrained the link. Warm reboot does NOT reliably fix this; power-cycle does.

### 1.3 DAS drop — 00:59:15, still ongoing

`usb 8-1: USB disconnect`, no reconnect. All four external disks went offline simultaneously mid-write (ext4 `lost async page write` + journal abort on buildcache sda1). Only ONE pool Toshiba (`72U0A005FWTG`) enumerated at 00:48; mirror partner (`72U0A0ZUFWTG`) never appeared; smartd died on it. `/mnt/pool` never mounted (fstab waits on missing member; RAID1 needs `degraded` for single-member).

**Timeline of the DAS across the night:** sda (buildcache) came back ~01:0x and stayed; both Toshibas absent all night. In boot 0 (05:55) systemd logged `Expecting device` for the SanDisk buildcache AND the Toshiba — **as of 06:04 `/sys/block` contains ONLY `nvme0n1`: every USB disk is gone, including buildcache.** The single shared USB link/enclosure power is the prime suspect (4-for-4 simultaneous drop).

### 1.4 Crash #2 — 05:49:56, WITH the guard deployed (it did not trip)

Boot -1 (00:48–05:49:56) ran my deployed guards all night:

- `memory-emergency-guard` ran every minute; **tripped 7 times overnight** (state file persisted across reboots — `tripped_total 7` confirmed in boot 0).
- At 05:46 the metrics read: **avail 30.3%, zram 98.2%** — flm was running again (pid found; socket activation revived it after the last guard stop), the user session still held its ~40 GB anon (4× bun @ ~18.4 GB total-vm, chromium).
- Guard logic: trip if avail <10% AND zram ≥92%, or avail <5%. At 30% avail → **no trip**.
- 05:49:44–56 journal tail: normal systemd churn (buildcache device timeouts, automount retries, nvme monitor) — then the journal **stops silently at 05:49:56.681**, same no-panic signature as crash #1. User power-cycled; boot 0 at 05:55:36.

**Conclusion: the freeze does not require MemAvailable <10%.** With zram ~full, the unevictable shmem + refault-decompression CPU storm + any I/O burst can kill the kernel while "available" still reads 30% (available counts reclaimable cache the box cannot actually reclaim fast enough — and shmem pages in the model are not counted as pressure until touched). The guard's AND-condition is too conservative. **zram ≥95% (or ≥92%) ALONE should trip**, or pair with a much higher avail ceiling (e.g. <30%).

Also: the guard is fighting a war of attrition it eventually loses — it stops flm, a client (PMA go-commit / papdashboard enricher / paperless-ai) reconnects, socket activation cold-loads 21.6 GB again, zram refills. 7 trips ≈ 7 cold loads ≈ ~150 GB of QLC reads overnight (the 2026-08-18 I/O-bomb class, now merely bounded by the 10-min cooldown). The real fix is on the anon/consumer side, or keeping flm unloaded while memory is tight.

### 1.5 Memory consumers (partial attribution, from OOM dump)

flm (24.7 GB shmem — killed, by design the sacrifice), chromium (large), **4× `bun` @ ~18.4 GB total-vm / ~1.9 GB RSS each, uid 1000, oom_score_adj −1000 (protected)**, ollama (adj 500, killed 2×). The ~56 GB active_anon was user-session dominated while flm held the unevictable 24 GB. Which services own the bun processes is **unverified** — see question 3.

### 1.6 Boot-failure cascade on the 00:48 recovery boot

- `forgejo-oidc-setup` FAILED at boot+39s: `dial tcp 192.168.1.150:443: connection refused` — DNS fine, **Caddy hadn't bound :443 yet**. Old gate was DNS-only. **Fixed this session** (full `mkOidcGate`); unproven until next restart.
- oauth2-proxy / browser-history / gatus failed at 00:50 on 120s OIDC-wait timeouts during the slow boot; **all self-recovered** by 00:56.
- atticd-bootstrap / btrfs-verify-pool-backups: failed **correctly** (pool absent).
- activitywatch + theme: start-limit-hit (user units) — not investigated.
- btrfs-compsite: timeout — not investigated.
- dnsblockd-cert-import (user unit): failed — not investigated.
- smartd: died on the absent Toshiba, self-recovered by 00:50.

---

## 2. Status by Category

### a) FULLY DONE

1. **Crash #1 full diagnosis** — zram-full→shmem-unevictable→OOM-cascade→nightly-I/O→freeze, evidence-backed.
2. **NIC-vanish diagnosis** — PCI enumeration diff proving RTL8125 absent + bus renumbering; remediation rule (power-cycle) documented.
3. **DAS-drop diagnosis** — usb 8-1 disconnect identified, missing pool member by serial, buildcache journal abort, smartd failure explained.
4. **`memory-emergency-guard.nix`** (new module) — written, eval-checked, script dry-run-verified, deployed, running at 1-min cadence, `onFailure` wired, state persists across boots, **7 real overnight trips kept the box alive for 4.5 h**.
5. **`system_lan_nic_present` metric + `lan-nic-watchdog`** unit/timer — deployed; metric live (`1` in current boot; NIC present).
6. **forgejo-oidc-setup full OIDC gate** (`mkOidcGate`, 120 s curl poll) — deployed.
7. **Gatus checks** "LAN NIC Present" + "Memory Emergency Guard" — deployed, render-verified in `services.gatus.settings.endpoints`.
8. **pre-deploy-check.sh** — `system_lan_nic_present` added to `KNOWN_NEW_METRICS` (unblocked the chicken-and-egg gate).
9. **AGENTS.md** — "Hardware Instability (post-crash, evo-x2)" section: freeze narrative + guard, NIC power-cycle rule, DAS drop + degraded-mount-is-human-decision rule, forgejo gate fix.
10. **Deploy executed** (3rd attempt, see §d) — config active, guards live.
11. **Crash #2 characterized** (this rewrite): guard-miss analysis with thresholds-vs-reality numbers.

### b) PARTIALLY DONE

1. **Post-deploy verification** — 58 PASS / 10 FAIL / 4 SKIP / 3 WARN; I only reviewed Immich 502 (pool) and Bank-Sync 502; **8 failures never reviewed**. Not re-run (and crash #2 invalidated the run anyway).
2. **Guard efficacy** — proven to bridge, proven beatable (crash #2 at 30% avail / 98% zram). Threshold retune NOT done.
3. **Guard early-life bug** — unit crash-failed ~01:27–01:30+ (`mv: Operation not permitted`, see §d-1), recovered overnight by an unverified mechanism; trip count still reached 7.
4. **Root consumer attribution** — bun×4/chromium anon side identified, not attributed, not capped.
5. **DAS remediation** — diagnosed fully; physical fix NOT done; situation WORSENED (buildcache also gone in boot 0).
6. **KNOWN_NEW_METRICS** cleanup — metric confirmed live; stale allowlist entry not removed.

### c) NOT STARTED

1. Re-run post-deploy-check and review ALL failures (post crash #2, on the current boot).
2. **Guard threshold retune** (P0 — zram-alone trip) — not implemented.
3. Bank-Sync 502 root cause (not pool-dependent).
4. forgejo-oidc-setup success proof (needs restart/reboot).
5. Immich/atticd/pool restore after physical DAS fix.
6. activitywatch start-limit, btrfs-compsite timeout, dnsblockd-cert-import — uninvestigated.
7. buildcache sda1 ext4 integrity check post-journal-abort (now moot until disk returns, then relevant).
8. Pool RAID1 degraded check + `btrfs device stats` + scrub after remount.
9. flm socket-activation immediate-restart bypass fix.
10. zram 80% early-warning Gatus check.
11. Non-flm consumer guards / session memory caps.
12. PSI-gating nix-gc.
13. smartd liveness Gatus check; pool member-count metric.
14. TODO_LIST.md harvest of this report.
15. Post-crash health-sweep runbook script.
16. Guard VM test (thresholds, cooldown, metrics).

### d) TOTALLY FUCKED UP

1. **My manual dry-run poisoned the guard's first production minutes.** Dry-ran the guard script as user `lars` (~01:12) → created `memory-emergency-guard.prom` **owned by lars** in the 1777 sticky textfile dir → deployed sandboxed-root unit (empty CapabilityBoundingSet, no CAP_FOWNER) could not `mv` over it → unit FAILED every minute from 01:27 (`Operation not permitted`), firing OnFailure each time. Recovered overnight by an unverified path. **Lesson: never dry-run a collector script manually into the production textfile dir; the unit must be the only writer, or the script must `rm -f`/`install` the target.**
2. **Deploy attempt 1 wasted:** new Gatus metric not pre-added to `KNOWN_NEW_METRICS` → phantom-metric gate (correctly) blocked. I had read that gate's code earlier in the same session.
3. **Deploy attempt 2 wasted:** shellcheck **SC2157** (`[ -n "eno1" ]` literal) in the MODIFIED system-health script — I dry-ran the NEW scripts but never built/linted the modified one. `writeShellApplication` build-time linting is a documented repo gotcha class.
4. **The 05:46 report was written 3 minutes before crash #2 and lost.** Nothing different was possible in hindsight, but the sequence cost a rewrite (this file).
5. Minor: early calls burned on sandbox-banned commands (`ip`, `systemctl`, `sudo`) before pivoting to journalctl/`/proc`.

### e) WHAT WE SHOULD IMPROVE (systemic)

1. **The guard thresholds are wrong-shaped:** the freeze needs neither low MemAvailable nor an AND — **zram-full alone is the cliff** (unevictable shmem + refault storm). Retune: trip on zram ≥95% regardless of avail, keep <5% absolute as backstop. (AGENTS.md already says "act at ≥92%" — the module didn't follow its own doctrine.)
2. **Socket activation makes flm un-killable-by-proxy:** every LLM consumer reconnect re-cold-loads 21.6 GB within minutes of a guard stop. The guard + socket revival = attrition war (7 trips overnight). Real fix: bridge-level refusal while `memory_emergency_guard_last_trip_recent 1`, or flm idle-TTL aware of memory state, or fix the consumers' retry loops.
3. **The anon side is untouched:** 4× bun @ 18.4 GB total-vm each with `oom_score_adj −1000` (protected!) under uid 1000 — the kernel could NOT reclaim them and would not kill them. Protected user processes that co-occupy the box with a 24 GB unevictable model is a recipe for exactly this freeze.
4. **The monitoring→action gap is closed for exactly one unit.** Generalize: every CRITICAL alert should have a defined automated mitigation or an explicit human-only label.
5. **Post-crash boot is a distinct operational state** (~10 cascade failures). A `post-crash-sweep` command would collapse the manual triage.
6. **DAS single-USB-link topology** is a 4-disk single point of failure, now proven twice in one night.
7. **Crash → PCIe training failure:** if NIC vanish recurs, BIOS/AGESA update + `pcie_aspm=off`/`pci=realloc` experiments.
8. **Dry-run hygiene:** collector scripts must only ever be exercised as the unit user / with output redirected to /tmp.

### f) Next Tasks (prioritized, ~50)

**P0 — now:**

1. **Guard retune:** zram ≥95% trips ALONE (drop the AND), keep <5% absolute; consider avail <30% + zram ≥92% as middle band. Eval + deploy.
2. **PHYSICAL: power off, reseat DAS USB cable + enclosure power, power on.** Verify `ls /sys/block` shows sdb/sdc/sdd/sda again. Try a different USB port/cable if not.
3. After disks return: pool mount, `btrfs device stats` both members, restart atticd-bootstrap / btrfs-verify-pool-backups / immich / smartd.
4. Re-run `nix run .#post-deploy-check` on the current boot; review ALL failures (last full review pending).
5. Remove `system_lan_nic_present` from `KNOWN_NEW_METRICS` (metric confirmed live).
6. Bank-Sync 502 root cause (independent of pool).
7. Decide flm policy while memory is tight: keep the backend stopped (mask `fastflowlm.service` or stop the socket) until the anon side is attributed — otherwise crash #3 is a coin flip.
8. Watch `memory_emergency_guard_*` on the current boot (fresh boot: avail 42%, zram ~0%).
9. Investigate the guard's EPERM recovery window (01:30→05:43) — confirm no silent wedge periods.
10. Check root disk usage + nix-gc state (interrupted twice by crashes now).
11. Verify no wedged `switch-to-configuration` lock after the deploy attempts.
12. buildcache sda1 ext4 error counters + fsck decision once it reappears.

**P1 — this week:**
13. flm socket-activation restart-bypass fix (bridge refuses revival while guard recently tripped / memory tight).
14. zram 80% early-warning Gatus check (pre-trip heads-up).
15. Attribute the 4× bun processes; cap or schedule them; review why they carry `oom_score_adj −1000`.
16. Consider stopping flm during the 23:00–01:00 nightly window (timer) — both near-death events happened inside it.
17. PSI/memory-gate nix-gc and btrbk sends (like btrfs-gc-guard gates on space).
18. Gatus check for smartd liveness.
19. Pool member-count / by-id presence metric (expect 2 Toshibas).
20. activitywatch + theme start-limit recovery.
21. btrfs-compsite timeout root cause.
22. dnsblockd-cert-import failure root cause.
23. `scripts/post-crash-sweep.sh` runbook (failed units + kernel grep + mounts + disk inventory in one command).
24. ollama OOMScoreAdjust=500 review (killed 2× — intended?).
25. Verify Gatus "LAN NIC Present" + "Memory Emergency Guard" are green in the UI.
26. Controlled guard test (stress-ng under watch) incl. cooldown behavior.
27. hermes.service 3-min timeout at 00:27:00 — pre-freeze symptom or independent bug?
28. btrbk interrupted-receive cleanup check (garbled target subvol class).
29. backup freshness / forgejo dump after two crash nights.
30. Guard metrics: also emit `zram_fill` even when .prom write path had errors (robustness).

**P2 — backlog:**
31. DAS enclosure/USB upgrade (powered hub, split links).
32. BIOS/AGESA update research (PCIe retrain-after-crash).
33. Kernel bump evaluation (7.1.8; r8125 9.016.01 out-of-tree pin).
34. `pcie_aspm=off` / `pci=realloc` experiment if NIC vanish recurs.
35. Raise zramSwap memoryPercent (30 → 40) headroom math vs ~110 GiB visible.
36. User-session MemoryHigh enforcement review (bun sessions escaped 56G/64G ceilings).
37. flm v1.0.2 heap-bug recurrence watch (SIGABRT class, 2026-08-21).
38. VM test for memory-emergency-guard.
39. system-health `lanInterface = ""` disabled-path test.
40. Gatus check: per-disk by-id presence (Toshibas, SanDisks).
41. Bridge-level ExecStartPre guard for fastflowlm@ (revival refusal).
42. TODO_LIST.md harvest of this report.
43. Batch PMA/papdashboard LLM calls away from the nightly window.
44. flm restart-churn watch (7 cold loads ≈ 150 GB QLC reads overnight).
45. PMA go-commit prompt-size audit (flm ctx checkpoints 6152 seen).
46. Immich `RequiresMountsFor` fail-fast hardening.
47. smartd per-device tolerance (`-d removable`) so one missing disk doesn't kill the daemon.
48. Quiet-by-design pool-dependent oneshots (Condition/skip-with-warning states).
49. Hard-reboot drill: validate crash-recovery boot converges green unattended (forgejo gate, lan-nic-watchdog @90s, guard @2min).
50. Consider a tiny always-on RAM headroom reserve for PID 1 + journald (earlyoom-style userspace killer as defense-in-depth behind the guard).

### g) Questions (cannot be answered from the machine)

1. **DAS hardware:** have you power-cycled/reseated the 4-disk enclosure since 05:49? In the current boot even buildcache (sda) is gone — all four disks, one USB link, dropped 4-for-4. Do you want `/mnt/pool` mounted **degraded** (single Toshiba) to restore Immich/atticd/backups while the second member is missing? (Human decision per repo rules — never automated.)
2. **The 00:47→00:48 reboot that fixed the NIC:** was it a full power-off (power button, PSU drain) or a warm `reboot` command? The PCI evidence says warm reboot did NOT retrain the NIC at 00:31 — knowing what you actually did calibrates how hard the "power-cycle, not warm reboot" rule should be stated in AGENTS.md.
3. **The 4× bun processes (~18.4 GB total-vm each, protected by oom_score_adj −1000, uid 1000):** do you know what they are (qmd? crush sessions? something else left running overnight)? They are the un-attributed ~40 GB anon side of both freezes, and I will not kill or cap anything in your session without your say-so.

---

## Appendix: Deployed Artifacts This Session

| Artifact                      | File                                                | State                                                                     |
| ----------------------------- | --------------------------------------------------- | ------------------------------------------------------------------------- |
| Memory emergency guard module | `modules/nixos/services/memory-emergency-guard.nix` | deployed; 7 overnight trips; **thresholds need P0 retune after crash #2** |
| LAN NIC metric + watchdog     | `modules/nixos/services/system-health.nix`          | deployed; `system_lan_nic_present 1` live                                 |
| forgejo OIDC full gate        | `modules/nixos/services/forgejo.nix`                | deployed (unproven until next restart)                                    |
| Gatus checks ×2               | `modules/nixos/services/gatus-config.nix`           | deployed (runtime green-state unconfirmed)                                |
| Guard enablement              | `platforms/nixos/system/configuration.nix`          | deployed                                                                  |
| Phantom-metric allowlist      | `scripts/pre-deploy-check.sh`                       | deployed (entry now stale — remove)                                       |
| Incident documentation        | `AGENTS.md` (Hardware Instability section)          | written                                                                   |

All eval gates green (`nix flake check --no-build`), formatted, committed by the auto-commit daemon.
