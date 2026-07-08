# discard=async Fix Applied — NVMe I/O Choke Remediation

**Date:** 2026-07-08 09:47
**Session scope:** Diagnosed SSH disconnect during `nh os boot`, identified `discard=async` as root cause, applied fix
**System:** evo-x2 (NixOS, AMD Ryzen AI Max+ 395, 128GB RAM)
**Hardware:** Lexar SSD NQ790 2TB (QLC NVMe, PCIe 4.0 x4)

---

## a) FULLY DONE

### 1. Root cause identified: `discard=async` destroying I/O performance
- Continuous TRIM on QLC NAND causes **253ms per discard operation**, 86 ops/sec
- BTRFS commit stalls of **17.7 seconds** on root filesystem
- Under nix build load, I/O queue depth hit 71 → system freeze → hardware watchdog reset (30s timeout)
- Confirmed via `iostat`: when TRIM stops, `r_await` drops from 22ms to 0.5ms (44x improvement)

### 2. Confirmed: System hard-crashed (not graceful reboot)
- Previous boot logs stop abruptly at 06:57:30 (mid-watchdog-heartbeat)
- 73-second gap before next boot = hard reset via SP5100 TCO timer
- Root filesystem needed **tree-log replay** = dirty shutdown
- No pstore entries = system froze before kernel could panic

### 3. Confirmed: `nh os boot` does NOT reboot or switch
- `nh os boot --help`: "Build the new configuration and make it the boot default"
- The **nix build** I/O load was the trigger, not activation or reboot
- `fstrim.enable = true` was already set in `configuration.nix:296` — root filesystem never had `discard=async` and relied solely on fstrim

### 4. Fix applied to `hardware-configuration.nix`
- **Removed `discard=async`** from `/data` (BTRFS, `nvme0n1p8`)
- **Removed `discard`** from `/rust-cache` (ext4, `nvme0n1p9`)
- Added explanatory comments on both referencing the investigation report
- `fstrim.enable = true` already present in `configuration.nix:296` — covers all filesystems weekly

### 5. Flake validation passed
- `nix flake check --no-build` — all checks passed
- `mkFilesystem` validation guard in `lib/filesystems.nix` still happy (no dangerous options remaining)

### 6. Status report from investigation written
- `docs/status/2026-07-08_08-38_NVME-DISCARD-ASYNC-IO-CHOKE-INVESTIGATION.md`

---

## b) PARTIALLY DONE

### I/O fix — config changed but NOT deployed
- `hardware-configuration.nix` edited, flake check passes
- **Change requires deploy OR reboot to take effect** — mount options are baked into systemd mount units at activation time
- Current running system still has `discard=async` active on `/data` and `discard` on `/rust-cache`

### BTRFS corruption assessment — identified but not remediated
- **91,561 csum failures** in the crash boot (boot -1), zero in all other boots
- All returned same wrong checksum `0x8941f998` = NVMe controller returned garbage under pressure
- Device stats counter persists at `corrupt 3603676277` across reboots
- No scrub run, no SMART checked, no device stats checked — all need `sudo`

---

## c) NOT STARTED

1. **Deploy the fix** — not deployed, `discard=async` still active right now
2. **Post-deploy I/O verification** — need to confirm latency improvement after remount
3. **SMART check** — `sudo smartctl -a /dev/nvme0n1` — drive health unknown
4. **BTRFS scrub** — `sudo btrfs scrub start -r /data` and `/` — corruption extent unknown
5. **BTRFS device stats** — `sudo btrfs device stats /data` and `/` — need baseline
6. **Firmware check** — Lexar NQ790 firmware `QBC838R010854P220C` — update availability unknown
7. **AGENTS.md update** — `discard=async` QLC gotcha not documented yet
8. **Model dedup on /data** — ~280G reclaimable in duplicate AI models (identified earlier in session)
9. **Root filesystem full** — 85% (571G/723G) — stale nix build sandboxes in `/nix/var/nix/builds/`

---

## d) TOTALLY FUCKED UP — Honest Self-Criticism

### 1. Initial response was generic, useless speculation
**What I said:** "The remote host stopped responding... likely causes: crash, network interruption, NAT timeout, sshd died"
**Reality:** I had `journalctl` and `iostat` available and used neither. Presented 4 theories as a list instead of investigating. The user had to explicitly tell me to read the logs.

### 2. Blamed BTRFS ENOSPC / disk fullness — WRONG TWICE
**First attempt:** "btrfs-gc-guard caught /data at 2% device-unallocated — that caused the corruption"
**Reality:** The user corrected me — 341 GiB free, 283 GiB unallocated. The 2% warning was from a **different boot** (Jul 07 17:17). I conflated boots.

**Second attempt:** Kept pushing BTRFS corruption as root cause despite the user telling me `nh os boot` triggered it.
**Reality:** The user was right every time. I ignored their direct testimony.

### 3. Wasted time on unrelated `/data` space analysis
**What I did:** 4 tool calls analyzing AI model dedup, HuggingFace cache, duplicate models
**Reality:** Completely unrelated to the SSH disconnect. Went down a rabbit hole.

### 4. Ran `iostat` last instead of first
**What I should have done:** `iostat -x nvme0n1 1 3` immediately after seeing "system froze/disconnected"
**What I did:** 15+ journal queries before finally running the one command that immediately revealed the problem (253ms discard latency)

### 5. Claimed 91K corruption blocks were "new" without verifying
**What I said:** Implied the corruption was fresh and accumulating
**Reality:** When the user challenged me, I checked and found zero csum failures in boots -2 through -5. The corruption was isolated to boot -1. The device stats counter is cumulative/persistent, so I cannot tell if those blocks were corrupted in that boot or pre-existing.

### 6. Didn't listen to the user
The user told me the trigger (`nh os boot`) and the symptom (SSH disconnect on LAN). I spent 3 responses blaming BTRFS corruption and disk space instead of investigating what `nh os boot` actually does (heavy I/O build) and what that I/O would reveal (`iostat`).

---

## e) WHAT WE SHOULD IMPROVE

### Process / Behavior
1. **Run `iostat` FIRST** for "system slow/crashed/disconnected" reports — before journal diving. Disk I/O is the #1 cause of system freezes on this hardware.
2. **Listen to the user's trigger** — if they say "I ran X and then Y happened," investigate X first
3. **Never present theories as facts** — early responses were stated with false confidence
4. **Check current system state** (`iostat`, `free`, `ps`, `cat /proc/pressure/*`) before reading historical logs
5. **Don't go down rabbit holes** — the `/data` space analysis was completely unrelated

### Technical
1. **Deploy the fix** — the config change is useless until activated
2. **Verify I/O improvement post-deploy** — need before/after `iostat` comparison
3. **Run BTRFS scrub** to assess corruption extent on `/data`
4. **Check SMART** to determine if the drive is physically degrading or if this is purely firmware/software
5. **Document the `discard=async` QLC gotcha** in AGENTS.md — this will recur on any QLC NVMe
6. **Consider separate physical NVMe** for Docker — same controller shares I/O queue between nix builds and containers
7. **Add I/O latency monitoring** to Gatus/Prometheus — this was invisible until manual `iostat`
8. **Add pre-build I/O health check** to `pre-deploy-check.sh` — abort if `r_await > 5ms`
9. **The `ext4 discard` gotcha** is already in AGENTS.md, but the BTRFS `discard=async` QLC problem is NOT — needs adding
10. **Root filesystem is 85% full** — should trigger cleanup before it becomes a problem

---

## f) Up to 50 Things We Should Get Done Next

### Critical (P0 — do today)
1. **Deploy the `discard=async` fix** — `nix run .#deploy` or `nh os switch`
2. Verify I/O latency after deploy — `iostat -x nvme0n1 1 5` (expect sub-millisecond)
3. Run `sudo smartctl -a /dev/nvme0n1` — check media errors, wear, spare blocks
4. Run `sudo btrfs device stats /data` — baseline corruption counter
5. Run `sudo btrfs device stats /` — check root corruption
6. Run `sudo btrfs scrub start -r /data` — read-only scrub to map bad blocks
7. Run `sudo btrfs scrub start -r /` — read-only scrub on root
8. Check Lexar NQ790 firmware update availability (current: `QBC838R010854P220C`)

### High Priority (P1 — this week)
9. Add `discard=async` QLC gotcha to AGENTS.md non-obvious gotchas table
10. Clean stale nix build sandboxes (`/nix/var/nix/builds/` — 10 dirs, some from Jul 1-4)
11. Deduplicate AI models on `/data` (~280G reclaimable)
12. Consolidate three model dirs into one (`/data/models`, `/data/ai/models`, `/data/llamacpp-models`)
13. Clean HuggingFace cache (`/data/ai/cache/huggingface` — 55G)
14. Monitor I/O pressure over 24h after fix to confirm stability
15. Run `sudo btrfs filesystem usage /` — check root chunk allocation health
16. Add I/O latency check to `pre-deploy-check.sh` (abort if `r_await > 5ms`)
17. Verify `fstrim.timer` is active and running weekly — `systemctl status fstrim.timer`
18. Check if `/rust-cache` (ext4) also benefited from removing `discard`

### Medium Priority (P2 — this month)
19. Add I/O latency monitoring to Gatus/Prometheus (node-exporter textfile or custom)
20. Add BTRFS device stats monitoring (alert on corrupt counter increase)
21. Add SMART metrics collection to nvme-metrics service
22. Evaluate replacing the Lexar NQ790 (QLC on a homelab server is risky)
23. Consider separate physical NVMe for Docker (isolate from nix builds)
24. Add `commit=600` (10min commit interval) to `/data` mount to reduce journal pressure
25. Evaluate `bfq` scheduler vs `mq-deadline` for this QLC drive
26. Check if `zram` swap (16G) is optimal under I/O pressure scenarios
27. Add disk health dashboard to Homepage or Grafana panel
28. Consider `nocow` for Docker volumes on `/data` (reduce CoW overhead for large container layers)
29. Review GPUActive memory (30.5 GiB) — reduces effective RAM, worsens swap thrash under I/O pressure
30. Consider `ionsice`/`nice` on nix-daemon to reduce I/O priority during builds
31. Add BTRFS corruption counter to monitoring (alert if >0 after scrub)
32. Document crash recovery runbook ("system froze during nix build" diagnostic steps)
33. Evaluate NVMe over-provisioning (allocate spare blocks via partition gap)
34. Check PCIe link speed stability under load (currently PCIe 4.0 x4)
35. Review whether `compress=zstd:3` adds too much CPU overhead during heavy I/O (consider `zstd:1`)

### Lower Priority (P3 — when time permits)
36. Consider BTRFS RAID1 for `/data` with a second NVMe
37. Review kernel 7.1.3 BTRFS changes for performance regressions
38. Consider switching root from BTRFS to ext4 (eliminate CoW for nix store)
39. Audit systemd timers doing I/O (btrfs-health, nix-gc, nix-build-cleanup) for scheduling conflicts
40. Review `watchdogd` meminfo thresholds (warning 95%, critical 98%) — 98% may be too late
41. Consider `kernel.watchdog_thresh=10` (default) since 20s delays soft-lockup detection
42. Evaluate `amd_pstate=performance` thermal impact under sustained I/O
43. Add documentation for watchdog reset recovery procedure
44. Consider `fstrim.timer` frequency — weekly may be too infrequent for this drive
45. Review `space_cache=v2` optimization on both BTRFS filesystems
46. Monitor Docker container I/O patterns after fix
47. Add `/rust-cache` ext4 health monitoring
48. Consider `commit=600` on root filesystem too
49. Review OOM/memory pressure correlation with I/O freeze
50. Create automated alert for BTRFS csum errors (kernel log monitor → Discord)

---

## g) Top 2 Questions I Cannot Answer Myself

### 1. Is the Lexar NQ790 physically failing, or is this purely a `discard=async` software issue?

I cannot run `sudo smartctl -a /dev/nvme0n1` to check:
- Media and data integrity errors
- Available spare blocks (below threshold = drive dying)
- Percentage used / wear level
- Error log entries
- Firmware update availability

The 91K csum errors with identical wrong checksum suggest the controller returned garbage under I/O pressure. But I can't confirm whether this is a **firmware bug** (fixable with update + removing `discard=async`) or **NAND degradation** (drive replacement needed). **SMART data is the only way to know.**

### 2. Should we deploy now (risky — same I/O conditions) or wait for a manual `fstrim` + reboot?

The config change requires a deploy or reboot to take effect. But:
- Deploying runs `nh os switch`, which does a nix build (heavy I/O) — the exact thing that triggered the crash
- The current system still has `discard=async` active
- A safer path might be: manually run `sudo fstrim -v /data` to clear the TRIM backlog, then reboot (which activates the new mount options without a build)

I don't know if the nix build for this change will be heavy enough to re-trigger the I/O choke, or if it'll substitute from cache and be trivial. **The user needs to decide: deploy now (and risk another freeze) vs. reboot now (safe, activates fix) + deploy later.**
