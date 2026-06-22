# Disk Repartitioning & Recovery — Comprehensive Status

**Date:** 2026-06-22 19:49 (Monday)
**Session:** Disk layout redesign, repartitioning disaster, recovery, and Rust cache partitioning
**Host:** evo-x2 (Lexar SSD NQ790 2TB)

---

## Executive Summary

What started as a disk layout investigation evolved into a full repartitioning operation. During execution, a `parted resizepart` command was issued with the wrong semantics (END position from disk start, not partition size), causing BTRFS to extend past the partition boundary. The ext4 `mkfs` on the new p9 then overwrote ~100 GiB of BTRFS data extents. The damage was contained to 13 AI model weight files (~165 GiB) — all re-downloadable. No personal data, databases, or Docker volumes were affected.

The disk has been fully recovered to a correct, verified layout with a new 100 GiB ext4 partition for Rust cargo targets.

---

## A) FULLY DONE

| # | Task | Status | Evidence |
|---|------|--------|----------|
| 1 | Deep disk research — mapped every partition, GiB, and Nix config | ✅ Done | Full layout, usage breakdown, dead partition discovery |
| 2 | Build cleanup systemd timer (prevents 148G orphaned builds recurrence) | ✅ Committed | `scheduled-tasks.nix` — daily `nix-build-cleanup` service |
| 3 | Disk swap removal from NixOS config | ✅ Committed | `hardware-configuration.nix` — `swapDevices` removed, zram only |
| 4 | `/rust-cache` ext4 partition mount in NixOS config | ✅ Committed | `hardware-configuration.nix` — `/dev/disk/by-partlabel/rust-cache` |
| 5 | Rust cargo target → ext4 symlink mechanism | ✅ Committed | `snapshots.nix` — tmpfiles rules for `/rust-cache/{project}` |
| 6 | Dead partitions deleted (p1, p2, p3, p5) | ✅ Done | 47.3 GiB reclaimed — verified via sgdisk |
| 7 | p8 resized to wrap 1.00 TiB BTRFS correctly | ✅ Done | 1036.5 GiB partition, 12.5 GiB margin past BTRFS |
| 8 | p9 created (100 GiB ext4, PARTLABEL=rust-cache) | ✅ Done | Formatted, no overlap with p8 |
| 9 | BTRFS scrub completed — damage assessed | ✅ Done | 23.5M uncorrectable errors mapped to 13 files |
| 10 | Corrupted files identified with exact paths | ✅ Done | All 13 files logged via kernel BTRFS warnings |
| 11 | Diagnosis + fix scripts written (diagnose, fix, create-p9) | ✅ Done | `scripts/disk-{diagnose,fix,create-p9}.sh` |

---

## B) PARTIALLY DONE

| # | Task | Status | What Remains |
|---|------|--------|-------------|
| 1 | NixOS deploy of new config | ⏳ Config committed, **not deployed** | Run `nix run .#deploy` to activate `/rust-cache` mount, swap removal, build cleanup timer |
| 2 | Cargo target migration | ⏳ p9 ready, symlink mechanism wired | After deploy: `rm -rf ~/projects/monitor365/target` — tmpfiles creates symlink |
| 3 | Orphaned build cleanup | ⏳ Timer wired, not yet running | First run after deploy will clean `/nix/var/nix/builds/*` |
| 4 | Disk scripts cleanup | ⏳ New scripts work, old ones need git tracking | `disk-diagnose.sh`, `disk-fix.sh`, `disk-create-p9.sh`, `find-corrupted-files.sh` untracked |

---

## C) NOT STARTED

| # | Task | Why It Matters |
|---|------|----------------|
| 1 | Re-download 13 corrupted AI model files (~165 GiB) | Files have I/O errors — unusable until replaced |
| 2 | Delete corrupted files to free space + clear BTRFS error state | 165 GiB locked in damaged extents |
| 3 | Consolidate root → single BTRFS with subvolumes (Phase 3 redesign) | Would eliminate the root/data split problem permanently |
| 4 | Move monitor365 (67 GiB project) off root partition | Root still at 96% — monitor365 is the biggest consumer |
| 5 | BTRFS balance on /data to reclaim damaged chunks | Scrub marked chunks bad; balance reclaims space |
| 6 | Grow BTRFS on /data to use full p8 (1 TiB) | Currently 1.00 TiB in a 1.00 TiB partition — no growth needed, but verify |
| 7 | Update AGENTS.md with new disk layout + gotchas | Current docs reference old partition layout |

---

## D) TOTALLY FUCKED UP

### D1. The `parted resizepart 8 1024GiB` Disaster

**What happened:** The command was meant to shrink p8's size to 1 TiB. Instead, `resizepart` interpreted `1024GiB` as the END POSITION from disk start (sector 0). Since p8 starts at sector 1,097,861,120 (523 GiB into the disk), the partition was shrunk to only 500 GiB — cutting through 523 GiB of the 1 TiB BTRFS filesystem.

**Root cause:** I (the AI) did not verify `parted resizepart` semantics before instructing the user. A single `parted help resizepart` would have clarified. I assumed SIZE semantics; parted uses END-POSITION semantics.

**Impact:** 523 GiB of BTRFS data was left outside the partition boundary.

### D2. The `mkfs.ext4` Compounding Error

**What happened:** After the bad resize, the user created p9 in the freed space and formatted it ext4. This overwrote the first ~100 GiB of the BTRFS data that was sitting outside p8's boundary.

**Root cause:** No verification step between the resize and p9 creation. Should have checked: "Does p8 end sector ≥ BTRFS end sector?" before any subsequent operations.

**Impact:** 23,549,416 uncorrectable checksum errors. 13 AI model files (~165 GiB) permanently damaged. All are re-downloadable — no irreplaceable data lost.

### D3. Script Iteration Failures

| Bug | Cause |
|-----|-------|
| `! part_exists 9` in assert() | Bash passes `!` as literal arg, not negation — needed `bash -c '! part_exists 9'` |
| `parted -s` didn't suppress prompts | The "partition is being used" prompt ignores `-s`; `nix shell` ate the `echo "Yes"` pipe |
| `YEL` instead of `YLW` color variable | Typo, failed on first run |
| `repartition-evo-x2.sh` assumed live USB | User correctly pushed back — online operations were possible |

---

## E) WHAT WE SHOULD IMPROVE

### E1. Verify Tool Semantics Before Destructive Operations

Every fuckup traces to acting on assumptions about tool behavior. The parted END-vs-SIZE confusion was the root cause. **Always read the man page or `--help` output before issuing destructive commands.**

### E2. Assert Between Operations

Between the resize and the mkfs, there should have been: `if p8_end < btrfs_end: ABORT`. The fix scripts now have this, but it didn't exist during manual execution.

### E3. Never Chain Destructive Commands Without Verification

Resize → verify → create → verify → format → verify. Each step should gate the next.

### E4. Test Scripts Before Presenting

The `YEL` typo and `!` assertion bug should have been caught by a syntax check (`bash -n`) or dry run.

### E5. Don't Trust AI-Generated Commands Blindly

The user ran `parted resizepart 8 1024GiB` on my instruction. A human reviewing the parted docs would have caught the semantics error. **Always verify AI-generated destructive commands.**

---

## F) Top 25 Things To Do Next

| # | Priority | Task | Effort | Impact |
|---|----------|------|--------|--------|
| 1 | 🔴 | **Deploy updated NixOS config** (`nix run .#deploy`) | 10 min | Activates /rust-cache mount, swap removal, build cleanup timer |
| 2 | 🔴 | **Delete 13 corrupted AI model files** | 5 min | Frees ~165 GiB, clears BTRFS error state |
| 3 | 🔴 | **Re-download corrupted models** (or defer if not urgently needed) | Hours | Restores AI model availability |
| 4 | 🔴 | **Clean orphaned build sandboxes** (`sudo rm -rf /nix/var/nix/builds/*`) | 1 min | Frees ~148 GiB on root (96% → ~68%) |
| 5 | 🔴 | **Move cargo target to ext4** (`rm -rf ~/projects/monitor365/target`) | 1 min | After deploy — tmpfiles creates symlink |
| 6 | 🟠 | **BTRFS balance on /data** to reclaim damaged chunks | 30 min | Reclaims space from corrupted extents |
| 7 | 🟠 | **Clean `~/.cache.pre-subvol`** (2.1 GiB migration leftover) | 1 min | Frees space |
| 8 | 🟠 | **Commit new disk scripts** to git | 5 min | Track diagnose, fix, create-p9, find-corrupted scripts |
| 9 | 🟠 | **Run BTRFS scrub on /** (root partition, never scrubbed) | 45 min | Verify root filesystem health |
| 10 | 🟠 | **Update AGENTS.md** with new disk layout + partition gotchas | 15 min | Keep docs accurate |
| 11 | 🟡 | **Add more Rust projects** to `rustCacheProjects` list | 5 min | faceswap, anime-comic-pipeline, etc. |
| 12 | 🟡 | **Move Steam library** off root (5.9 GiB in ~/.local) | 10 min | Frees root space |
| 13 | 🟡 | **Move ActivityWatch data** (7.3 GiB) to /data | 10 min | Frees root space |
| 14 | 🟡 | **Review monitor365 (67 GiB)** — should the whole project be on /data? | 20 min | Biggest root consumer |
| 15 | 🟡 | **Run `nix-collect-garbage --delete-older-than 7d`** | 10 min | Frees 20-40 GiB from /nix/store |
| 16 | 🟡 | **Fix `part_exists` bug** in disk-fix.sh `bash -c` assertions | 5 min | Script correctness |
| 18 | 🟡 | **Write corrupted file cleanup script** (delete + log) | 15 min | Automated recovery |
| 19 | 🟢 | **Grow BTRFS on /data** if needed after balance | 5 min | Maximize usable space |
| 20 | 🟢 | **Add `/rust-cache` to `autoScrub` exclusion** | 5 min | ext4 doesn't need BTRFS scrub |
| 21 | 🟢 | **Document partition layout** in a dedicated doc | 15 min | Future reference |
| 22 | 🟢 | **Consider BTRFS RAID1 for /data** if second NVMe added | Planning | Data redundancy |
| 23 | 🟢 | **Add disk health monitoring** (smartd alerts) | 15 min | Early warning for SSD failure |
| 24 | 🟢 | **Update FEATURES.md** with rust-cache partition | 5 min | Feature inventory accuracy |
| 25 | 🟢 | **Plan single-BTRFS consolidation** (Phase 3 from original design) | Research | Eliminate root/data split permanently |

---

## G) Top Question I Cannot Answer Myself

**Should we delete the 13 corrupted files now (before deploy), or wait until after deploy?**

The files have BTRFS checksum errors and will return I/O errors on read. Deleting them now would:
- Free ~165 GiB on /data immediately
- Clear the BTRFS error state (no more csum errors on scrub)
- But: the models would need re-downloading before they can be used again

I don't know if any running service (ComfyUI, Ollama, etc.) is actively trying to read these files. If a service is polling them, deletion would cause read errors in logs. I also don't know which of these models are actually in active use vs. just stored on disk "just in case."

**I need to know: which of these 13 models are actively used, and which can be deleted + re-downloaded later?**

---

## Current Disk Layout (Verified 2026-06-22 19:45)

```
Lexar SSD NQ790 2TB (1.8 TiB)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
p6   512 GiB   btrfs   /           (96% full, 22 GiB free)
p7     2 GiB   vfat    /boot       (12% used)
p8  1024 GiB   btrfs   /data       (77% used, 237 GiB free)
p9   100 GiB   ext4    /rust-cache (NEW, empty, not mounted yet)
free 212 GiB   unallocated          (future use)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Swap: zram only (9.4 GiB compressed)
Dead partitions: ALL REMOVED (p1, p2, p3, p5 — 47.3 GiB reclaimed)
```

## Corruption Summary

| Metric | Value |
|--------|-------|
| Scrub duration | 18 min 47 sec |
| Total data scrubbed | 786.03 GiB |
| csum_errors | 23,549,416 |
| uncorrectable_errors | 23,549,416 |
| corrected_errors | 0 |
| Files affected | 13 |
| Total damaged data | ~165 GiB |
| Data type | AI model weights + Steam shader cache |
| Personal data affected | NONE |
| Databases affected | NONE |
| Docker volumes affected | NONE |
