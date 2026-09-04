# Session Status: Samsung 970 EVO Plus 1TB — USB wipe + internal-install prep

**Date:** 2026-08-30 11:15 CEST
**Scope:** User attached an old 1TB BitLocker Windows M.2 (Samsung 970 EVO Plus, serial `S4EWNX0RA01856V`) via front USB-C (RTL9210B-CG NVMe→USB bridge) and asked to clean it, with the stated goal of installing it inside evo-x2 soon. This report covers only this session's run and what I noticed in passing.

---

## a) FULLY DONE

1. **Device identified unambiguously.** `sda` = Samsung 970 EVO Plus 1TB, 931.5G, serial `S4EWNX0RA01856V`, `TRAN=usb` behind Realtek RTL9210B-CG (`0bda:9210`, serial `012345679039`) on `usb 6-1` → xHCI `0000:c7:00.3`, SuperSpeed Plus Gen 2x1 (10 Gbps), attached via UAS at 08:53:16. Classic Windows layout: 100M EFI + 16M MSR + 930.9G (BitLocker C:) + 509M recovery. Nothing mounted from it.
2. **Front USB-C mass-storage PROVEN and recorded.** First objective data-point that the front USB-C ports work for mass storage (previously "UNTESTED — do NOT call them dead" in AGENTS.md). Updated the DAS hardware-instability bullet in AGENTS.md with the enumeration evidence.
3. **Bridge capability limits established.** The RTL9210B does NOT expose TRIM/discard over UAS (`lsblk -D` = 0B for sda) → `blkdiscard` is impossible through this bridge. Documented in the same AGENTS.md edit.
4. **Destructive-target hardening after user challenge.** When challenged ("Are you sure it's /dev/sda?"), re-verified the mapping live and switched all commands to the disk-serial by-id handle `ata-Samsung_SSD_970_EVO_Plus_1TB_S4EWNX0RA01856V` (SAT passthrough exposes the real disk serial, better than the bridge-serial `usb-Realtek_…` link and immune to sd-letter reshuffles).
5. **Disk wiped clean (user-executed).** `sudo wipefs -a` erased primary GPT header (0x200), backup GPT header (0xe8e0db5e00), and PMBR boot signature; ioctl re-read succeeded. Verified: `lsblk /dev/sda` shows ZERO partitions. Disk is blank at the partition level.
6. **Post-wipe verification.** Kernel partition table re-read confirmed; the non-root `wipefs` probe failing with EPERM is expected (needs root to open the device).
7. **Explained why `nvme format` cannot run now.** Verified only `/dev/nvme0` (internal Lexar) exists — over USB the drive is a SCSI/UAS block device with no NVMe admin-queue passthrough; the bridge doesn't even forward TRIM, let alone Format NVM. SCSI substitutes (`sg_format`, `hdparm` ATA secure erase) are wrong/unreliable here (NVMe behind SAT emulation). Deferred to internal install (seconds, guaranteed).
8. **AGENTS.md knowledge updated** (front port proof + bridge TRIM limitation) per the memory protocol.

## b) PARTIALLY DONE

1. **"Clean" is 90% done.** Partition table gone (both GPT headers + PMBR). NOT done: the old BitLocker-encrypted blocks inside the former sda3 extents still physically exist as unreferenced data — deliberately left for the seconds-long `nvme format -s 1` (cryptographic erase) at internal-install time. Optional deep-clean zero pass (`dd if=/dev/zero …`, ~30-50 min over 10 Gbps) was offered and skipped (correct call for a drive staying in-house, but it IS an open option until the nvme format happens).
2. **Pre-wipe signature inventory incomplete.** Intended a read-only `wipefs /dev/sda` listing + BitLocker metadata probe (`cryptsetup bitlkDump`) for the record; the listing got lost (see d) and the bitlkDump was never attempted. The user's erase output retroactively documented the disk-level signatures, so nothing actionable is missing — but the pre-state record is thinner than it should be.
3. **AGENTS.md edit is written but uncommitted** (auto-commit daemon will batch it; concurrent sessions are active in this tree — see d.4).

## c) NOT STARTED

1. `sudo nvme format /dev/nvme1n1 -s 1` — blocked until the drive is on the native NVMe bus (internal M.2).
2. Any partitioning / filesystem / mount wiring for the internal role.
3. SMART health check of the drive before internal install (see e/f).
4. Safe eject / power-off of the USB enclosure (cosmetic; nothing is mounted).

## d) TOTALLY FUCKED UP (or near-misses worth owning)

Nothing destructive went wrong — the target verification held up under challenge. Process failures, honestly:

1. **Pre-flight command chain silently truncated, only partially recovered.** My pre-flight batch ran `sudo -n true` mid-chain; the session's sudo block killed the WHOLE command at that point, so the `wipefs` signature listing and USB-controller sysfs reads after it never executed. I noticed the missing controller lookup and re-ran it separately — but I never noticed/re-ran the missing signature inventory. Lesson: after any intercepted/aborted command, diff what you expected to see against what you got BEFORE moving on; a truncated pipeline is a partial blindfold.
2. **Sloppy grep hid the best device handle in the first pass.** My initial by-id listing used `grep -iE 'sat|nvme|usb'` — which does NOT match `ata-…` links, so I presented only the bridge-serial `usb-Realtek_…` handle as if it were the only stable path. The `ata-Samsung_SSD_970_EVO_Plus_1TB_…` link (the disk's REAL serial) existed all along and surfaced only when the user challenged and I grepped broader. The wrong-ish handle was still target-correct (same disk), but a destructive-op inventory must not filter away identity links: `ls -l /dev/disk/by-id/ | grep -v part` (or no grep) is the right inventory.
3. **Used the volatile `sd` letter in the first command set.** I gave `/dev/sda`-based commands first and only hardened to by-id after the user's challenge. Correct from the start would have been: identify via lsblk, then IMMEDIATELY translate to by-id for anything destructive. The user should not have to be the safety net.
4. **Concurrent-session tree state not flagged promptly.** During this session `flake.nix`, `flake.lock`, `gatus-config.nix`, `pre/post-deploy-check.sh` accumulated staged modifications from OTHER sessions (cv-funnel thread). I only surfaced this now, in the report, instead of flagging it the moment I saw it in git status. Critical Rules require immediate flagging.
5. **DAS still offline — noticed but never said aloud.** Both lsblk runs showed NO pool Toshiba members and NO buildcache SanDisk — the DAS (down since 2026-08-22, root-caused 2026-08-29 to the `KERNEL=="sd[ab]"` hdparm rule + never-VBUS-power-cycled JMS567 bridge) is STILL not attached/recovered. I silently used its absence as a "sda is unambiguous" safety argument without telling the user their backup pool is still down on a backup-relevant day. Should have been one flag line at first observation.

## e) WHAT WE SHOULD IMPROVE (from this run)

1. **Destructive-op doctrine: by-id from the first command.** Never present an `sdX`-based destructive command, even when the letter is currently unambiguous. The repo already learned this for udev rules (`udev-block-letter-audit.nix`); the same instinct must apply to interactive ops.
2. **A reusable wipe runbook script.** `scripts/wipe-external-disk.sh <by-id>`: resolves the device, prints model/serial/size + mounted-partition check, requires interactive confirmation of the printed serial, then `wipefs -a` (+ optional zero pass). This is at least the second disk repurposed here; the pattern (identify → prove → confirm → wipe → verify) should be encoded, not improvised. Include the "TRIM passthrough?" check (`lsblk -D`) and print whether blkdiscard is possible.
3. **Aborted-command recovery habit.** When a tool intercept kills a chain (sudo block, banned command), enumerate the remaining intended steps and re-run them explicitly instead of continuing with a thinner picture.
4. **Flag observations that are out-of-scope but operationally loud** (DAS down, concurrent tree edits) immediately, not in the end-of-session report.
5. **Pre-destruction forensics snapshot.** Before wiping any disk: one command capturing lsblk tree, `wipefs` listing, and (if BitLocker suspected) `cryptsetup bitlkDump` — appended to the session report. Cheap insurance against "wait, what exactly was on that disk?".
6. **SMART/firmware check BEFORE committing an old SSD to internal duty.** A 970 EVO Plus with unknown TBW/health belongs in the same pre-flight as the wipe. Samsung firmware updates are Windows-only (Magician) — if firmware is old and the drive shows the known slow-read degradation era, decide BEFORE it's inside.

## f) NEXT THINGS (up to 50, roughly ordered)

**This drive's lifecycle:**
1. SMART health read over USB now (`sudo smartctl -d sat -a /dev/sda`): TBW, % used, reallocs, power-on hours — go/no-go for internal install.
2. Check firmware version in SMART output (970 EVO Plus known-issue era) — note Windows-only update path.
3. Safe-eject the USB enclosure when done with SMART (`udisksctl power-off -b /dev/sda` or unplug).
4. User: physically install into free M.2 slot (which slot + heatsink — see questions).
5. On first native boot: confirm enumeration (`lsblk`, `/dev/nvme1n1` expected).
6. `sudo nvme format /dev/nvme1n1 -s 1` — the definitive crypto-erase (kills residual BitLocker blocks).
7. Decide the drive's ROLE (see questions) — this gates everything below.
8. Partition per role (GPT via sgdisk/parted or the installer).
9. If data disk: BTRFS per house doctrine — `compress=zstd`, `commit=300`, `noatime`, `nofail` + automount, `mkFilesystem` helper (`lib/filesystems.nix`) for eval-time option validation.
10. Register the mount in `hardware-configuration.nix`/module — by-label or by-id (label preferred; the pool precedent), NEVER kernel letters.
11. If it replaces buildcache (240G SanDisk) or absorbs its role: re-point `services.buildcache` consumers (`GOCACHE`, `GOMODCACHE`, `CARGO_HOME`, pnpm store symlinks) — much bigger, faster NVMe over the dying SandForce SSD.
12. If it becomes the Docker/XFS SSD role previously earmarked for the spare SanDisk (sdc): revisit that plan.
13. btrbk coverage decision: snapshot it or exclude it (cache-like content should be excluded — the `@nix` precedent).
14. Add to `system-health`/Gatus monitoring if it hosts anything user-facing (mount presence, usage %, SMART via smartd).
15. smartd entry for the new internal NVMe (by-id, `-d sat` not needed natively).
16. If used for VMs/tests: consider ioTier implications and zram interaction (the 2026-08-22 freeze lessons).
17. Consider `fstrim` coverage — already global daily; verify the new device appears in fstrim unit scope.
18. Update AGENTS.md hardware table / storage layout section after install (evo-x2 disk inventory changes for the first time since the BTRFS section was written).

**Repo/tooling from this session:**
19. Write `scripts/wipe-external-disk.sh` runbook (see e.2).
~~20. Add the "by-id for destructive ops" rule to AGENTS.md Critical Rules or the wipe script docstring (currently only implied by the udev lesson).~~ done — AGENTS.md carries the never-match/by-id doctrine (udev-block-letter-audit enforces the class)
~~21. Commit/settle the AGENTS.md front-port edit (daemon batches it; verify wording survived).~~ done — settled in the daemon batches
~~22. The USB NVMe enclosure (RTL9210B) is now a proven 10 Gbps external NVMe dock — worth keeping noted in AGENTS.md hardware inventory for future disk surgery (it already earned its mention via the TRIM caveat).~~ done — AGENTS.md 2026-08-30 front-USB4-C bullet records the RTL9210B proof + TRIM caveat

**Out-of-scope-but-noticed (one line each, NOT researched further per instructions):**
23. DAS still fully offline (no pool, no buildcache disks attached) — recovery procedure per AGENTS.md root-cause section (USB cable VBUS + enclosure power, 60s+, replug front USB-C preferred) still pending a user run; pool backups/monitor365-class exposure continues.
24. Concurrent session left staged changes (flake.nix/flake.lock/gatus-config.nix/pre+post-deploy-check.sh — cv-funnel thread); expect their deploy/commit to race mine (AGENTS.md only, no overlap).
25. `nvme list` (nvme-cli) is NOT installed on the host PATH — `nvme list` printed nothing and only the /dev nodes proved enumeration; for the internal-install `nvme format` step, ensure nvme-cli is available (`nix shell nixpkgs#nvme-cli` or add to systemPackages) — do NOT discover this after the drive is already inside.

(Not padding to 50 — 25 real items; everything else would be invented.)

## g) QUESTIONS I CANNOT ANSWER MYSELF (max 3)

1. **What role is this 1TB drive getting internally?** (extra data disk / build-cache replacement / dedicated VM or test slab / dedicated service data / something else) — this decides partitioning, filesystem, btrbk inclusion, monitoring, and whether `services.buildcache` migrates onto it.
2. **Which M.2 slot is free on the evo-x2, and does it share PCIe lanes with anything (or the second slot's width), and do you have a heatsink for it?** I cannot see the board; lane-sharing and thermals matter for a PCIe 3.0 drive next to the Lexar.
3. **Is there ANY data on the old BitLocker Windows install you might still want?** The partition table is gone but the encrypted blocks survive until the `nvme format`. If anything on that old Windows install matters (and you hold the recovery key), say so BEFORE internal install + format — after that it is unrecoverable, full stop.

---

**Bottom line:** disk identified, safely wiped, verified blank, knowledge recorded; the real cryptographic erase + role wiring wait for the physical install. My process had two real bruises (truncated pre-flight not fully recovered; filtered grep hiding the better identity handle) and one etiquette miss (late flagging of DAS-offline + concurrent-session tree state) — all documented above so they become doctrine, not repeats.
