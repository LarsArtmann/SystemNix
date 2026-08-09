# Status Report: Root Disk (94%) Investigation + Brutal Self-Review

**Date:** 2026-08-01 22:01 CEST
**Session scope:** Single-session investigation — "Why is my `/` disk 93-94% full, where did all the GBs go?"
**Host:** `evo-x2` (NixOS, BTRFS `/` = nvme0n1p6, 723 GB; ext4 `/rust-cache` = nvme0n1p9; BTRFS `/data` = separate)
**Verdict:** Diagnosis was largely correct in direction, but **I missed documented consumers and presented a guessed number as a measured one.** See §d.

---


## Executive Summary

`/` is at **656 GB / 723 GB (94%)**, 49 GB free. The disk is NOT failing and there is no runaway process. The space is consumed by the normal accumulation of a heavy Go-development + daily-deploy NixOS workstation: a 89 GB nix store, a 43 GB `go-build` cache, a 13 GB DuckDB, 12 GB activitywatch, plus BTRFS snapshots pinning old CoW extents.

**What I told the user:** accurate on the major categories, and the key insight (snapshots + subvolume mounts are invisible to `du -x`) was correct and non-obvious.

**What I got wrong / omitted — the honest version is in §d below.**

---

## The Numbers (as measured this session)

### Top-level `du -x /` (live `@` subvolume only — 241 GB visible)
| Path | Size |
|---|---|
| `/nix/store` | 89 GB (72,498 paths; 11,759 reclaimable by `nix-collect-garbage`) |
| `/home/lars/projects` | 78 GB (Go/Rust artifacts: faceswap 5G, monitor365, DiscordSync, go-cqrs-lite, …) |
| `/home/lars/.local` | 23 GB (activitywatch 12 GB, Steam 5.9 GB, containers 3.3 GB) |
| `/var/lib/monitor365-server` | 13 GB (DuckDB) |
| `/var/log/journal` | 9.3 GB |
| `/home/lars/tmp.*` (10 dirs) | ~6 GB |
| `/home/lars/.gotmp` | 5.3 GB |
| `/home/lars/.cache.pre-subvol` | 2.1 GB |

### Invisible to `du -x /` (separate subvolume mounts — the trick)
| Consumer | Size | Why `du` hides it |
|---|---|---|
| `@cache-home` (`~/.cache`) | 63 GB | separate `subvol=` mount |
| └─ `go-build` | **43 GB** | single biggest reclaimable item |
| `@go` (`~/go`) | 8.0 GB | separate mount |
| `@npm` (`~/.npm`) | 2.6 GB | separate mount |
| `@cargo` (`~/.cargo`) | 2.0 GB | separate mount |
| BTRFS root snapshots (3× daily) | **~290 GB (ESTIMATE — see §d)** | CoW extents; `du` double-counts |
| BTRFS metadata (DUP) | 23 GB allocated / 23 GB used | |

> `/rust-cache` (50 GB) is on **ext4** (nvme0n1p9) — a different physical allocation, NOT counted against the 723 GB `/` device.

### BTRFS device health (`btrfs filesystem usage /`)
```
Device size:        722.52 GiB
Device allocated:   695.50 GiB   (only 27 GB unallocated — documented ENOSPC risk zone)
Device unallocated:  27.02 GiB
Data used:          609.65 GiB / 631.44 GiB (96.55%)
Metadata used:       23.06 GiB /  32.00 GiB (72.07%)
Free (statfs):       48.80 GiB
```

---

## Work Classification

### a) FULLY DONE
- **High-level root-cause narrative:** correctly explained *why* `du` shows 241 GB but `df` shows 656 GB used (snapshots pin CoW extents + cache subvolumes are separate mounts).
- **Identified the single biggest reclaimable item:** 43 GB `go-build` cache.
- **Mapped the documented subvolume layout** by reading `platforms/nixos/system/snapshots.nix` rather than guessing — confirmed `@cache-home`, `@go`, `@npm`, `@cargo` are separate mounts.
- **Provided an actionable, ordered quick-wins list.**
- **Correctly excluded `/rust-cache`** (different ext4 device) from the `/` accounting.

### b) PARTIALLY DONE
- **"Quick wins" were listed, not executed or quantified in GB-freed terms.** I told the user *what* to clean, never offered to *do* it and never estimated total reclaim.
- **Snapshot cost was estimated, not measured.** Three snapshots reported `du -shx` of 354/410/480 GB — these share CoW extents and are NOT additive, but I published "~290 GB" without explaining the methodology or confidence interval.
- **GC dry-run** confirmed 11,759 reclaimable paths but I never summed their sizes.

### c) NOT STARTED
- Executing ANY cleanup (`go clean -cache`, `nix-collect-garbage`, `journalctl --vacuum`, tmp.* removal).
- Writing a reusable cleanup script or a Gatus/disk-threshold alert.
- Checking the automated `nix-build-cleanup` timer's health.
- Verifying whether disk-pressure is already being alerted on by the existing monitoring stack.

### d) TOTALLY FUCKED UP / MAJOR OMISSIONS
- **I MISSED `/nix/var/nix/builds/`** — a documented gotcha in AGENTS.md that can accumulate to **100+ GB** of orphaned build sandboxes after OOM/crash. I never checked it until this self-review. *(Post-check: it's only 1.9 GB today because the `nix-build-cleanup` timer is doing its job — but I had NO right to assume that. I should have checked it in the original investigation.)*
- **I MISSED `/btrfs-emergency-reserve`** — a documented 10 GiB `fallocate`d file created on boot. *(Post-check: it is MISSING, meaning either it was consumed during a past recovery and never re-provisioned, OR the `btrfs-emergency-reserve.service` never ran. With only 27 GB unallocated, that missing 10 GB reserve is a real ENOSPC concern — exactly the documented crash mode. This is a finding I completely failed to surface in the original answer.)*
- **I presented a guessed snapshot cost (~290 GB) with too much confidence.** I did not measure marginal snapshot cost (the delta extents snapshots pin beyond live data). The honest statement is "snapshots are the largest hidden consumer; precise marginal cost unmeasured."
- **I never quantified device-unallocated (27 GB) against the documented ENOSPC threshold.** AGENTS.md documents the 2026-06-26 metadata ENOSPC crash that fires when device-unallocated hits ~0. At 27 GB unallocated with `nix-gc` + builds churn, this is genuinely close to the danger zone — and I said "the disk isn't broken" without flagging this risk. That was irresponsible.
- **I didn't cross-reference the existing monitoring.** AGENTS.md says `btrfs-health.nix` collects Prometheus metrics and Gatus alerts on device-unallocated. I didn't check whether the system is ALREADY screaming about this.

### e) WHAT WE SHOULD IMPROVE (process, from this session)
- **Cross-reference AGENTS.md gotchas BEFORE concluding a diagnosis.** The builds dir and emergency reserve are literally documented and I skipped them. A checklist grep of AGENTS.md for "GB"/"space"/"reserve"/"builds" would have caught both.
- **Never publish an estimated number without a confidence label.** "~290 GB (estimate)" is fine; implying it's measured is not.
- **Offer to execute, don't just lecture.** The user asked a question; the natural follow-through is "want me to reclaim ~60 GB now?"
- **Always close the monitoring loop.** Before saying "it's fine," verify the existing alerting isn't already firing on the condition.
- **Quantify wins.** "Reclaims ~X GB" is actionable; "run go clean" is not.

---

## f) Next Things To Get Done (up to 50, in impact order)

### Immediate reclaim (high impact, low risk)
1. **`go clean -cache`** → ~43 GB (single biggest win).
2. **`nix-collect-garbage --delete-older-than 7d`** → frees stale store paths; lets snapshots shed pinning faster.
3. **`journalctl --vacuum-size=2G`** → ~7 GB.
4. **`rm -rf /home/lars/tmp.*`** → ~6 GB (10 leftover temp dirs).
5. **Investigate `/btrfs-emergency-reserve` MISSING** → either re-provision it (`systemctl start btrfs-emergency-reserve`) or document why it's gone. This is also a safety issue (documented ENOSPC cushion).
6. **Delete `/home/lars/.cache.pre-subvol`** → ~2.1 GB (stale pre-subvolume-migration backup).
7. **Verify `/nix/var/nix/builds/` cleanup timer** is enabled and running (currently only 1.9 GB — keep it that way).
8. **Run `nix-store --optimise`** (hardlink dedup, `auto-optimise-store` equivalent) — may reclaim several GB across similar store paths.

### Monitoring & prevention
9. **Add/verify a Gatus disk-usage threshold alert** (e.g. warn at 90%, critical at 95%) with Discord notification.
10. **Add a Prometheus metric + Gatus alert for `/nix/var/nix/builds/` size** (catch the documented 100+ GB accumulation early).
11. **Add a metric for `/btrfs-emergency-reserve` presence** (AGENTS.md already tracks this — verify it's wired and alerting on Discord when missing).
12. **Verify the existing `btrfs-health` device-unallocated alert** is firing given only 27 GB unallocated — confirm we're not already in a silent alert state.
13. **Add disk-pressure tile to Homepage** (current `df` %) — currently Homepage is navigation-only per AGENTS.md, so this goes in Gatus.
14. **Track BTRFS device-unallocated trend** over time (is it ratcheting down toward the ENOSPC cliff?).

### Periodic automation
15. **Add a systemd timer for `go clean -cache`** (weekly) — prevents the 43 GB from silently re-accumulating.
16. **Set `nix.settings.min-free` / `max-free`** so the Nix daemon auto-triggers GC before the disk fills (e.g. `min-free = 10G`).
17. **Increase `nix-gc` frequency or shorten retention** if deploys are this frequent (596 generations!).
18. **Cap GOCACHE via a periodic prune or `GOMAXCACHE`** if such an option exists; otherwise a size-bounded wrapper.
19. **Add a nightly "biggest dirs" report** emailed/Discord'd so disk creep is visible early.

### Data hygiene review (decide what to keep)
20. **Audit activitywatch 12 GB** — is all historical data needed? Can it be pruned/exported?
21. **Audit Steam 5.9 GB** — uninstall unused games.
22. **Audit `/home/lars/.local/share/containers` 3.3 GB** — prune unused images/layers.
23. **Audit `monitor365-server` DuckDB 13 GB** — retention policy for historical telemetry?
24. **Audit `~/forks` 2.9 GB** — stale forks to remove.
25. **Audit `~/paid-engagements` 1.3 GB** and `~/Downloads` 1.3 GB**.
26. **Audit `~/.gotmp` 5.3 GB** — likely safe to clear.
27. **Caddy logs 298 MB** — verify rotation is enabled.
28. **Run `docker system prune -a --volumes`** (on `/data`) to reclaim unused container data.

### Architecture / longer-term
29. **Move `go-build` cache onto its own subvolume** (like `@go`/`@cargo`) so it's snapshot-excluded and separately bounded.
30. **Consider a dedicated `@nix` subvolume** (AGENTS.md notes `/nix` currently lives inside `@`, so btrbk snapshots include the full store — deferred to next reinstall).
31. **Reconsider snapshot retention** (14d+4w) given deploy frequency — shorter retention = less extent pinning.
32. **Evaluate BTRFS quotas (qgroups)** for per-subvolume visibility (AGENTS.md notes overhead vs QLC NAND tradeoff).
33. **Document the snapshot marginal-cost measurement methodology** so future investigations don't hand-wave.
34. **Write a reusable `disk-audit.sh`** in `scripts/` that reproduces this breakdown in one command.
35. **Add the builds/emergency-reserve checks to `pre-deploy-check`** so a full disk blocks a deploy before it fails mid-way.
36. **Profile which Go repos produce the most build-cache churn** and consider `GOFLAGS=-trimpath` / module cache sharing.

### Operational hardening
37. **Confirm `nix-build-cleanup` timer interval** (every 4h per AGENTS.md) is actually scheduled.
38. **Confirm `btrfs-emergency-reserve.service`** is enabled and the file gets recreated on boot.
39. **Re-provision the emergency reserve now** (`rm` is wrong per rules — but the file is already missing; recreate via the service).
40. **Review whether the 596 system generations** (many identical "No changes" deploys) can be consolidated.
41. **Set a deploy hygiene rule:** no-op deploys shouldn't create new generations (verify `nh` behavior).

### Session-process improvements (meta)
42. **Add "disk space" to the standard AGENTS.md gotcha-grep checklist** for future investigations.
43. **Always verify existing monitoring before declaring a state "fine."**
44. **Never conclude a diagnostic without quantifying total reclaimable GB.**
45. **Always check the documented worst-case consumers** (builds dir, emergency reserve) even when `du` looks benign.

### Stretch / nice-to-have
46. **Visual disk-usage treemap** (e.g. `ncdu` on `/`) committed as a reference snapshot.
47. **BTRFS balance status check** (documented weekly balance; verify it's freeing chunks).
48. **Estimate how much snapshot expiry alone will free** over the next 14 days.
49. **Consider zstd compression level** (currently `:3` on `/data`) — higher level = more CPU, less space.
50. **Document this session's findings into AGENTS.md** as a "disk pressure baseline" entry so the next investigation starts informed.

---

## g) Questions I Cannot Answer Myself (max 3)

1. **How frequently do you genuinely need to roll back a deploy?** This determines safe snapshot retention. 14d+4w may be wildly excessive for your actual rollback cadence — but only you know how far back you've ever needed to go. Shortening retention is the highest-leverage space win I can't size without this.

2. **Is the missing `/btrfs-emergency-reserve` intentional?** AGENTS.md documents it as a 10 GiB crash-cushion auto-created on boot, and it's GONE. Either you deleted it during a past ENOSPC recovery and never re-provisioned, or the boot service isn't running. I can't tell which from the filesystem state alone, and whether you WANT it back is a policy call (10 GB cushion vs 10 GB free space).

3. **Do you want me to execute the cleanup autonomously, or only ever report + await explicit go-ahead?** The reclaimable total is ~60+ GB with near-zero risk (`go clean -cache`, nix GC, journal vacuum, tmp.* removal) — but several involve deletion, and your global rule is "trash not rm / never revert without asking." I need your policy on autonomous cleanup before acting.

---

_This report is based solely on this session's investigation and verification. No unrelated codebase research was performed._

---

> **RESOLVED — Resolved. Work captured in CHANGELOG.md.**
> All forward-looking items in this report were completed in subsequent sessions.
