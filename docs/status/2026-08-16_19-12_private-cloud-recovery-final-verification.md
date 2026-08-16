# Private-Cloud Local-Disk Recovery — FINAL VERIFICATION & EXHAUSTION — 2026-08-16 19:12

> Continuation session. Goal per user: **"I do not want to lose ANY data"** from the three
> local disks of the dead private-cloud box (sdf = 500G SSD, sdb+sde = 2×16TB ZFS mirror).
> GCP-era data explicitly OUT of scope ("if it was there it's still there").
> This session verified, fixed, and completed the extraction. Every disk is now
> bit-perfect verified or provably exhausted.

---

## Executive Summary

**All three local disks are now fully extracted and cryptographically verified.**

| Disk | Contents | Backup | Verification |
|---|---|---|---|
| sdf2 (442G ext4 root) | Full system | `/data/backup-2026-08-11-private-cloud-ssh/` | **373,491/373,491 files SHA256-matched, 0 missing** |
| sdf1 (512M vfat EFI) | Boot + Secure Boot keys + kernel 6.6.116 | `/data/backup-2026-08-11-private-cloud-ssh-boot/` | **12/12 bit-perfect** |
| datapool (sdb+sde ZFS) | All live user data (20 real files) | `/data/backup-2026-08-11-private-cloud-hdds/` | **20/20 SHA256-matched, 0 missing** |

**The definitive data verdict stands: the machine never held user photos/documents.**
Immich DB = zero tables (migrations never ran). Paperless = 0 documents. K8s = empty
skeleton. datapool user datasets = empty scaffolding; the pool's ~46 GiB was Docker
image layers + ZFS benchmark garbage. The only irreplaceable items: SSH keys, sops age
key, Secure Boot keys, bash histories, journal, service configs — all recovered.

---

## A) FULLY DONE

### 1. Proved the "4 GB gap" is not missing data
- Apparent transferred (63.98 GiB) == apparent on dest; on-disk 47 GiB = BTRFS zstd:3
- Second rsync pass sent only 14.98 MiB (99.99% identical) — nothing left to copy
- Corrected the earlier misleading framing in the prior report (§H)

### 2. Located where Immich/Paperless data was SUPPOSED to live
- Read `private-cloud/nixos/hosts/onprem/nixos-0/disko-config.nix`: intended ZFS
  datasets at `/storage/media/photos`, `/storage/documents/paperless`, `/storage/databases`, …
- sdf2's `/storage` = empty mountpoint scaffolding; `/storage-backup-ssd` = 119 MiB
  (the databases + configs); `storage-backup-ssd{2,3,4}` = always-empty scaffolding

### 3. Kubernetes hunt — CLOSED: no data ever in K8s
- `/tmp/hunt-k8s-data.sh` (sudo-in-script): RKE2 manifests = system addons only;
  no `rke2/storage` (zero PVCs ever provisioned); kubelet = 4.8 MiB; etcd = 142 MiB
  system state, strings-probe negative for PVC/immich/paperless; Longhorn = 0 bytes
- Journal (Nov 27–Dec 22): ZERO rke2/kubelet/containerd units — cluster dead before window

### 4. Database contents — PROVEN never used (throwaway PG15 probes)
- immich: DB exists, **zero tables** — server never ran migrations
- paperless: fully migrated, 2 users, **`documents_document = 0`**
- n8n: 56-byte config skeleton
- Probe scripts: `/tmp/probe-immich-db*.sh`, `/tmp/probe-other-dbs.sh`; temp copies cleaned

### 5. datapool FULL audit via NixOS VM (`/tmp/zfs-full-audit.sh`)
- Imported pool, mounted EVERYTHING incl. `mountpoint=legacy` children and `snapdir=visible`
- Full recursive send dry-run per dataset: **49.45 GB total** = `cache` 16.1 GiB
  (`health_check.0.0` 10 GiB + `zfs_*test` 6 GiB benchmarks) + `apps` ≈30 GiB Docker
  graph-driver layers + user datasets ≈0
- Snapshot browsing of newest (Dec 21 23:00) snapshper dataset: media/photos = 1 KiB,
  databases = empty dirs, paperless = 11 KiB scaffolding — **empty in history too**
- zpool history: last ZFS op `2025-12-21 23:40:38` (mid Docker-layer churn), journal end
  `2025-12-22 00:40:38` — machine died mid-operation
- Host-side `/tmp/audit-disks.sh`: exactly ONE pool exists (datapool, sdb1+sde1 mirror);
  no hidden pools on any attached disk

### 6. Definitive sdf2 clone verification — 373,491/373,491
- `/tmp/verify-clone-definitive.sh`: sudo manifests BOTH sides (closing the permission gap:
  v1 user-run manifest saw only 20,490 files)
- Result: **0 files missing, 373,491 hash-matched**; 1,901 dest-extras = git objects from
  earlier sync pass; 498,047 rsync entries − 373,491 files = dirs/symlinks

### 7. datapool final extraction — 20/20 bit-perfect
- v1 (`/tmp/zfs-final-extract.sh`) FAILED (see D-2); v2 (`/tmp/zfs-final-extract2.sh`)
  fixed: explicit includes, no `--one-file-system`, SHA256 verify both sides
- All real live files now in `-hdds`: `apps/n8n/config`, 8 Redis stubs
  (`cache/{immich,paperless}`), 10 config/portainer/homepage files,
  `documents/paperless/data/migration_lock`
- The 1,821-path live list = 20 real files + 1,801 `.zfs/snapshot` virtual views of the
  same 56-byte file (all snapshots verified to contain nothing beyond live state)

### 8. sdf1 (EFI) — found missing and cloned
- User's `du` output exposed `./boot = 0`; root cause: sdf1 was NEVER part of any backup
- `/tmp/clone-sdf1.sh`: 12/12 bit-perfect — **custom Secure Boot keys (PK/KEK/db/dbx)**,
  systemd-boot, kernel 6.6.116 bzImage.efi, initrd, loader entries (gen-161)

### 9. Empty-dirs worry — resolved with evidence
- `/tmp/check-empty-dirs.sh`: every empty top-level dir in the clone was verified empty
  ON SOURCE too; 71,145 source dirs containing files all have files on dest
- Zeros explained: virtual FS mountpoints, `/nix` (deliberate exclude), `/storage`
  (ZFS mountpoint → pool extracted separately), `lost+found` (ext4 artifact), `/boot`
  (separate sdf1 → now cloned)

### 10. Git-history timeline of the dead project (local-scope context)
- Repo began **2025-01-19 on Google Cloud** (paperless Jan 19, immich Jan 23)
- `bdda5a3` (2025-10-30) "cloud → locally-owned" = config-only pivot, no data migration
- On-prem nixos-0 stack assembled Nov–Dec 2025, died 2025-12-21/22 **before any real
  data entered it** — consistent with empty DBs/pool

### 11. Documentation
- Prior report updated with §H (size-metrics correction), §I (K8s/DB/datapool verdict),
  §J (extraction-complete tables + bug log)

---

## B) PARTIALLY DONE

### 1. Verification manifests not persisted with the backups
- Definitive manifests live in `/tmp` (`def-src.sha256`, `def-dst.sha256`,
  `pool-src.sha256`) — **lost on reboot**
- `-hdds/.source-manifest.sha256` is STALE (1100 bytes, from the failed v1 run — missing
  the 9 files v2 added)
- `-ssh/.clone-manifest.sha256` is STALE (v1-era, 20k-file partial manifest — misleading)

### 2. sdf mount housekeeping
- sdf1 mounted at `/tmp/sdf1-mount`, sdf2 at `/tmp/sdf-mount` (both ro) — still up
- sdf3 (33.9G swap) never examined (swap = no recoverable data, but never stated/verified)
- Drives still attached and spinning; no decommission decision executed

### 3. Prior report §I contains an ERROR now superseded
- §I says "datapool: 267 MiB total (definitive)" — that was ONLY the `datapool/apps`
  subtree from the first hunt. Full-pool truth (from full audit): 49.45 GB send size
  (16.1 GiB cache benchmarks + ~30 GiB Docker layers + ~0 user data). Not yet corrected
  in that file.

---

## C) NOT STARTED

1. Persisting fresh SHA256 manifests INSIDE each backup dir (gzip'd) for future re-verify
2. Deleting/merging the old incomplete `/data/backup-2026-08-11-private-cloud/` (72 KiB
   duplicate of what `-hdds` now fully contains)
3. Unmounting sdf1/sdf2 and physically decommissioning the three disks (user decision)
4. GCP-era data check (explicitly deferred by user — "not my Goal")
5. Second-copy backup of the three backup dirs to another device (all currently on the
   single `/data` NVMe; btrbk snapshots of `/data` DO cover them at the toplevel —
   but no offbox copy exists; `#1 data loss risk` flag from AGENTS.md still applies)
6. Checking for leftover `nixos.qcow2` in SystemNix dir after the VM runs

---

## D) TOTALLY FUCKED UP

### 1. Ran the ZFS VM concurrently with sdf2 verification
- The VM VFIO-binds the USB controller → sdf (same controller!) vanished → the first
  definitive verification silently hashed NOTHING and reported "Source files: 1"
- I should have known: the disks share one USB controller. Serialized all later runs.

### 2. `tar --one-file-system` never crosses ZFS mounts — extraction v1 archived emptiness
- Every dataset mounts UNDER `/storage`; v1 tarred an empty directory skeleton and
  reported "tar exit: 0" (success!). The 82 KB stream size should have screamed.
- Caught only because the user asked "how are we doing on this?" — my Phase-3 verifier
  then ALSO aborted on its own bug (`find storage mnt` — `mnt/` never existed locally,
  `set -e` killed the script before printing results)
- Lesson: post-transfer file-count sanity check is mandatory, success exit codes lie

### 3. Glob-expansion bug in the definitive verifier
- `$EXC` patterns (`./nix/*`) expanded against the REAL filesystem inside
  `sudo bash -c "cd … find . …"` → find got garbage args → 1-file manifest
- Worse: I initially presented that run's output ("373,491 vs 1") without flagging the
  obvious 1-file absurdity. Fixed with `set -f` + re-ran. Sanity-check counts BEFORE
  comparing.

### 4. The 267 MiB datapool claim in §I was wrong
- Reported `zfs send` dry-run of ONE subtree (apps-init chain) as "pool total".
- Real total: 49.45 GB (mostly benchmarks + Docker layers — still zero user data, so
  the VERDICT was right, the NUMBER was wrong). Report not yet corrected.

### 5. sdf1 was missed for the ENTIRE engagement
- Every script targeted sdf2 only. The EFI partition (with irreplaceable Secure Boot
  keys) survived on luck until the user's `du` output exposed `./boot = 0` near the end.
- "Full disk backup" must mean ALL partitions: sdf1/sdf2/sdf3 enumerated from the start.

### 6. Early-session permission blindness (carried from previous session)
- v1 clone verification read the source as regular user → 20,490 of 373,491 files.
  The user's "Could there have been a permissions problem?" was the trigger to audit
  ALL /tmp scripts — the assumption "manifest ≈ complete" was never validated by count
  against rsync's own 498,047 entry count until this session.

---

## E) WHAT WE SHOULD IMPROVE

1. **Sanity-check every metric before comparing** — a 1-file source manifest or an
   82 KB "full pool" tar must fail loudly, not flow into comparisons
2. **Never co-schedule VM runs with host-side disk work** — one USB controller serves
   both; VFIO passthrough starves the host disks
3. **Verify excludes with positive file lists** — after every exclude-heavy copy, diff
   `find | wc -l` source-vs-dest before declaring victory
4. **Persist manifests INTO the backup dir** — `/tmp` is not evidence; evidence belongs
   next to the data it proves
5. **Partition enumeration before "whole disk" claims** — `lsblk <disk>` first, every time
6. **User's du/apparent-size instincts were right twice** (--apparent-size comparison,
   boot=0 catch) — treat user observations as test failures, not noise
7. **Cross-controller awareness** — document the USB topology (sdb..sdf on ONE
   controller, `0000:c7:00.4`) in the recovery scripts themselves

---

## F) UP TO 50 THINGS WE SHOULD GET DONE NEXT

### Immediate (minutes)
1. Copy definitive manifests into their backup dirs: `def-{src,dst}.sha256` → `-ssh/`,
   `pool-src.sha256` → `-hdds/` (gzip), remove stale `.clone-manifest.sha256` +
   stale `-hdds/.source-manifest.sha256`
2. Regenerate one fresh authoritative manifest per backup dir (self-contained re-verify
   without the source disks)
3. Correct §I in the 17-24 report (267 MiB → 49.45 GB with correct breakdown)
4. `ls` SystemNix dir for leftover `nixos.qcow2` from VM runs; trash if present
5. Unmount `/tmp/sdf1-mount` and `/tmp/sdf-mount`
6. State-and-verify sdf3 (swap) truly has no data (`blkid`, no signature beyond swap)

### Short-term (this week)
7. User decision: wipe/repurpose sdf (476G SSD) — clone verified, keys preserved
8. User decision: datapool decommission path (2×16 TB: sell / BTRFS reformat / backup target)
9. If drives stay attached: add SMART/Gatus monitoring for sdf, sdb, sde
10. Consolidate `/data/backup-2026-08-11-private-cloud/` (72 KiB stale) into `-hdds` or delete
11. Second-copy the three backup dirs (rsync to sdd btrfs or an external target) —
    single-NVMe risk; btrbk covers `/data` but no offbox copy
12. Extract usable artifacts: SSH keys (test/use `id_ed25519`), sops age key (decrypt any
    leftover secrets), portainer.db, homepage configs
13. Catalog Ollama blobs (~31 GiB): delete the 15G `-partial`, import intact models into
    current Ollama if wanted, else delete
14. Archive the journal (4 GiB) — compress (zstd) + index; it's the only forensic record
15. Update SystemNix AGENTS.md with the 5-USB-disk reality + controller topology
16. Write `scripts/clone-whole-disk.sh` codifying: enumerate partitions → clone each →
    verify each (the pipeline this session built ad hoc)

### Medium-term (next 1-2 weeks)
17. Decide on paperless/immich going forward: current SystemNix native services are the
    live ones; recovered DBs are irrelevant (empty) — mark recovery CLOSED
18. GCP-era data check (deferred by user; revisit if any memory of real photos/documents
    persists — GCP project may still hold Jan–Oct 2025 immich/paperless data)
19. Restore+test Secure Boot key backup (PK/KEK/db) — can they re-enroll on new hardware?
20. Document the private-cloud death postmortem (disk/controller failure mid-Docker-op,
    no ACPI events, services failing 11+ min before journal cutoff)
21. Fold the /tmp recovery scripts (audit-disks, zfs-full-audit, zfs-final-extract2,
    verify-clone-definitive, clone-sdf1, check-empty-dirs, hunt-k8s-data) into
    `scripts/` with cleanup, or archive them in the report dir
22. Btrbk coverage check for `/data` includes the three backup dirs (snapshot retention)
23. TODO_LIST.md entry: decommission private-cloud hardware end-to-end
24. Review remaining USB SSDs (sdc buildcache, sdd ssd-btrfs) SMART health — never probed
25. Consider `zfs send` full-archive of datapool to a FILE before wiping (belt+suspenders,
    49.45 GB — cheap insurance if any doubt remains)
26. Verify the recovered etcd snapshot restores (rke2 etcd-snapshot-…-1761955203) — only
    if cluster history matters
27. Extract docker volume metadata (`var/lib/docker/volumes/*/…`) index for the record
28. Confirm no OTHER machines hold private-cloud data (user memory check)

### Long-term / hygiene
29. Test-restore sdf2 clone into a VM (boot gen-161) to prove the backup is bootable
30. Document the three-backup-dir layout in README or docs/runbooks
31. Add "backup completeness checklist" (all partitions, all datasets, all snapshots,
    manifests persisted) to docs/CONTRIBUTING.md recovery section
32. Sell/donate decommissioned hardware; record serials (WX2511WX00357, 72U0A005FWTG,
    72U0A0ZUFWTG) as recovered-and-wiped
33. Revisit GCP project teardown (billing!) if data there is confirmed unneeded
34. SystemNix `pre-deploy-check.sh`: nothing to change — but note USB controller
    passthrough pattern for future VFIO work
35. Purge /tmp recovery scripts after archival (session hygiene)
36. Post-recovery retro with the user: what memory cues ("100 GB") map to which real
    artifacts (full-HDD snapshot copies) — calibrate future incident intake
37. Consider triplicate rule for the irreplaceables (keys, journal): NVMe + USB SSD +
    encrypted cloud (age-encrypted tar)
38. If datapool drives become a backup target: design zfs/btrfs + rotation there
39. Mark `docs/gotchas-archive.md` entry for the tar --one-file-system ZFS trap
40. Add unit test / example to `scripts/zfs-vm-backup.sh` docs: never schedule with
    host-side disk jobs
41. Timebox review of `-ssh/var/log/journal` for the Dec 21-22 failure window (root-cause
    writeup support)
42. Verify `home/art/.ssh` key fingerprints against known hosts (any servers still
    trusting them?)
43. Rotate/revoke old keys where the dead box was trusted (Forgejo deploy keys etc.)
44. Delete stale status-report TODO items superseded by this report (docs-health pass)
45. If Secure Boot keys are custom: document enrollment procedure for successor hardware
46. Archive `private-cloud` repo (already git; consider final tag `EOL-2026-08`)
47. Check whether `projects-management-automation` should stop tracking the dead repo
48. One-page executive summary for the recovery (what existed, what died, what was saved)
49. Schedule follow-up: 30-day re-verify of all three backup manifests (bit-rot check)
50. Celebrate: the data that existed is safe; the data that didn't exist can't be lost

---

## G) UP TO 3 QUESTIONS I CANNOT FIGURE OUT MYSELF

1. **Decommission now?** All three disks are verified exhausted (sdf clone bit-perfect,
   datapool = layers/benchmarks only). Do you want them wiped/repurposed/sold now —
   or should I first do item F-25 (full 49.45 GB `zfs send` to file as belt-and-suspenders
   before wiping the pool)?

2. **The irreplaceables need a second home.** SSH keys, sops age key, Secure Boot keys,
   journal (4 GiB) currently live only on the `/data` NVMe. Where do you want the
   second copy — sdd (the btrfs 240G SSD), one of the 16 TB drives before decommission,
   or an external/offsite target?

3. **GCP, final answer?** You said it's not the goal — but the git history shows immich
   + paperless ran there Jan–Oct 2025. Do you remember actually uploading photos or
   scanning documents in that era? If yes, the GCP project is the last place data could
   exist; if no, we close the book on private-cloud data recovery permanently.

---

*Session scripts (evidence): /tmp/{audit-disks,hunt-k8s-data,zfs-snapshot-hunt,zfs-full-audit,zfs-final-extract,zfs-final-extract2,verify-clone-definitive,check-empty-dirs,clone-sdf1}.sh + logs /tmp/zfs-full-audit.log, /tmp/zfs-final2.log*
