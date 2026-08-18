# Status: /data → HDD Pool Migration — atticd live, monitor365 mid-flight

**Date:** 2026-08-18 13:14 CEST
**Scope:** This session only — migrate `/data/{atticd,monitor365,monitor365-archive}` to the HDD pool, plus fallout fixes (smartd, concurrent-session race). Crash at 03:30 mid-session; rebooted 06:57; resumed 12:38.

---

## a) FULLY DONE ✓

1. **`/data/monitor365-archive` (32G) → `/mnt/pool/archive/monitor365-archive`** — `rsync -aHAX` copy + `rsync -c` checksum dry-run verified ZERO differences, source then deleted (run 2, ~01:0x). Provenance `README-migration.md` written into the archive (house rule: sidecar at creation time). Tier note: `archive/` is NOT btrbk-pool snapshotted — RAID1 is the only redundancy for this copy (deliberate, documented in the README).
2. **`/data/atticd` → LIVE on the pool** (`/mnt/pool/services/atticd/storage`):
   - `services.attic-config.storagePath` default flipped (attic.nix)
   - atticd verified serving `127.0.0.1:8200` from the pool path; survived the 03:30 crash, came up clean at boot 06:57
   - Full gating shipped: `RequiresMountsFor` on `atticd-storage-dir` oneshot + `atticd` itself (detached DAS fails loudly instead of contaminating the root fs); **tmpfiles rule REMOVED** (tmpfiles can pre-date the pool mount → dir on root fs); deploy.sh restarts the oneshot post-switch (oneshot+RemainAfterExit ignores restartTriggers)
   - `services/atticd` added to the btrbk-pool snapshot list (snapshots.nix)
   - Gatus alert text + `docs/setup/nix-binary-cache-setup.md` path updated
3. **smartd fixed and verified live**: was dead since boot 06:57 (`Unable to register device … no Directive -d removable`, exit 16 — post-crash USB DAS re-enumeration transiently set the kernel removable flag). Now: `Monitoring 4 ATA/SATA, 0 SCSI/SAS and 1 NVMe devices`. Added systemd-level resilience (`Restart=on-failure`, `RestartSec=2min`, start-limit at [Unit] level — the systemd 261 rule) in configuration.nix.
4. **Q2 decision conflict resolved properly**: the 2026-08-17 master plan recorded "/data copy is never deleted" (user decision Q2) and guard 06a ("no deletion before map + user sign-off"). Surfaced to the user before the irreversible step; user chose **full migrate (delete)**. This supersedes Q2 for `/data/monitor365`.
5. **Instrumentation shipped** (deploy D version, live now): 120s-capped `find` count probe → journal shows **`/data/monitor365 entries: 1888382`** (1.9M files!), `--info=progress2` on rsync, `TimeoutStartSec=12h` (was 4h — wrongly sized for a metadata-bound copy).
6. **Migration unit design proven across 3 runs**: idempotent, ConditionPathExists self-neutralizing, checksum-gate-before-delete caught run 1's capability bug exactly as designed, sources kept on every failure, onFailure Discord routing wired, deploy.sh starts it `--no-block` post-switch.

## b) PARTIALLY DONE ⏳

1. **`/data/monitor365` (1,888,382 entries, ~31G) — copy RUNNING** (started ~13:0x). rsync is in the file-list build phase (lstat-bound; 1.9M inodes takes tens of minutes before byte one flows). Then copy → checksum verify (both sides re-read) → source delete. Realistic total: hours. Zero pool-write deltas observed during list build are EXPECTED, not a hang (run-3 count probe proves scale).
   - **Corruption probe rides along free**: the tree is corrupt-adjacent (triage doc: "sits in one of the corrupt-adjacent regions"). Zero csum errors this boot so far. If rsync hits EIO it fails safe (source kept) and the journal names the unreadable files — a partial T05 map for this tree at zero extra cost.
2. **First btrbk-pool snapshot of the populated subvols** — automatic tonight 23:45 (atticd + monitor365 now in the list); not yet observed.
3. Working tree carries all session edits (module, attic.nix, snapshots.nix, monitor365.nix, gatus-config.nix, configuration.nix smartd, deploy.sh, docs) — uncommitted, awaiting the auto-commit daemon / user commit decision. NOTE: working tree ALSO carries a concurrent session's edits (see d.6) — commit carefully.

## c) NOT STARTED ○

1. monitor365 re-enable preconditions (stale uid 966:956 re-chown decision on re-enable if the recreated user differs — documented in module comment; wireguard-collector build blocker = TODO_LIST G7).
2. Post-migration /data balance/space reclaim (none of the freed space is reclaimed until 14d snapshots expire — known CoW semantics; and /data is 82% with 187G free, no pressure).
3. `btrfs check --mode=low-risk` maintenance window (master plan T07 — unchanged by this session).

## d) TOTALLY FUCKED UP ✗ (all caught, all instructive)

1. **Shipped unverified smartd syntax** (`-d sat,removable` → smartmontools 7.5 rejects it: "unsupported device type"). Cost: one aborted deploy + extended the SMART-monitoring outage I was fixing. The binary's `strings` output had `removable` and `sat,` as SEPARATE tokens — I concatenated them on hope. Second violation of the "test the harness on synthetic input first" rule (BitLocker session e.1).
2. **Run-1 capability bug**: `CapabilityBoundingSet = CAP_SYS_ADMIN` only — every rsync chown EPERM'd (foreign numeric owners need `CAP_CHOWN CAP_FOWNER CAP_DAC_OVERRIDE`, reading 0750 uid-966 trees needs `CAP_DAC_READ_SEARCH`). The checksum verify caught it and kept all sources — but the bug was mine, not the gate's. Fixed + AGENTS.md gotcha recorded (applies to ALL future hardened root oneshots doing rsync/chown).
3. **Assumed `set -u` alone governed the script** — NixOS PREPENDS `set -e` to unit scripts; run 1 died mid-function at `rm` (after successful verify+message!) leaving the run half-done. Every fallible statement now explicitly `if !`-guarded with its own failure message.
4. **Wrong timeout for the workload** (4h for a 1.9M-file tree: 3 full walks ≈ copy + verify×2) and **two diagnosis cycles burned theorizing** ("wedged rsync? D-state? USB storm?") when a 30-second instrumentation probe (the count) would have explained everything. Instrumented only after the second occurrence.
5. **Editing sloppiness**: duplicated the smartd block in configuration.nix mid-edit (caught + cleaned before eval); `ps | head -2` truncation briefly hid the receiver process.
6. **Raced a concurrent session's live edits** (btrfs-health.nix 13:09, pre-deploy-check.sh 13:11 — their `btrfs_health_critical` emitter + checker bypass). Deploy D was blocked transiently by the phantom-metric check mid-edit, cleared once their bypass landed. Their work is intact and verified live (`btrfs_health_critical` now emitting, 3 lines in btrfs.prom). Lesson: re-run the gate before concluding a blocker is mine; check file mtimes vs my edit times to attribute.
7. **Misread `du` output as "0 bytes copied"** — after rsync applied source perms the dest dir was mode 0750 uid 966, unreadable to my unprivileged probe; `du` printed 0 for a dir it couldn't enter. (The df-delta probe then compensated correctly.)

## e) WHAT WE SHOULD IMPROVE (process, from this session)

1. **Instrument before diagnosing** — the 120s count probe answered in 2 minutes what 2 diagnosis cycles theorized about. Default: measure scale (count/size/rate) FIRST on any "slow/stuck" IO mystery.
2. **Verify tool syntax against the actual binary/man before shipping config** (smartd `-d` types; the repo already has this lesson recorded — I repeated it).
3. **Unit scripts get `set -e` prepended by NixOS** — design every script as fail-e-safe from the start (explicit guards, no bare fallible statements). Worth an AGENTS.md line.
4. **Concurrent-session etiquette**: before treating a failed gate as my bug, `stat` the files involved — mtime newer than my last edit = someone else is mid-flight; re-run the gate once before deep-diving.
5. **Capability arithmetic for hardened oneshots**: enumerate EVERY syscall-adjacent need (chown/chmod/read-foreign/create-subvol) when writing CapabilityBoundingSet — the failure mode is silent EPERM deep inside rsync.
6. **Timeouts scale with metadata, not bytes** — 1.9M files × 3 walks is not a GB problem.

## f) NEXT UP TO 50 THINGS

**Immediate (this session's thread)**
1. Watch monitor365 copy to completion: `journalctl -u data-to-pool-migration -f`
2. On success: confirm all three sources gone (`ls /data`), unit skips on next boot, sources recoverable only via snapshots
3. On COPY FAILED with EIO: extract the unreadable-file list from the journal — that's the corrupt-file map (T05 partial) for this tree
4. Verify tonight's 23:45 btrbk-pool run snapshots the populated atticd + monitor365 subvols
5. Verify btrbk-data 23:30 behaves as expected (fails loudly on known /data corruption — standing state, not caused by us)
6. Commit the session's changes (mind the concurrent session's files — separate carefully)

**Derived from what I noticed (in passing)**
7. smartd runtime-verification TODO (TODO_LIST P2) can now be closed — verified live this session ("Monitoring 4 ATA/SATA + 1 NVMe")
8. Consider an eval-time or pre-commit lint: assert every Gatus pat() metric in NEW modules ships an emitter in the same deploy (the concurrent session hit the same phantom-metric wall — systemic)
9. Consider `ConditionPathIsMountPoint` instead of `RequiresMountsFor` where the semantics differ (we want fail-loudly, which RequiresMountsFor gives — document the choice pattern once)
10. The 1.9M-entry monitor365 buffer is fs-salt: when monitor365 is re-enabled, evaluate whether its buffer format (millions of tiny chunks) belongs on HDD at all vs. fewer larger segment files (upstream concern)
11. After monitor365 lands: consider excluding `services/monitor365` from btrbk-pool until re-enabled (1.9M-inode snapshot churn nightly for a disabled service is pure IO) — cheap toggle in snapshots.nix
12. Pocket-id SQLITE_BUSY bursts at every deploy restart (pre-existing: 16 on 08-16, 55 on 08-17, 24 on 08-18 — provisioner-loop contention). Post-deploy-check FAILs on it intermittently. Worth a look at busy_timeout/serialization in the provisioner path
13. smartd: nvme0n1 uses bare device node (no by-id) — fine, but note /dev/nvme0n1 vs the boot-disk identity convention used elsewhere
14. The `tmp-crush-test` dir spotted in `/data` listing — session debris? verify + clean
15. AGENTS.md: add the NixOS `set -e` prepend gotcha (e.3) — it cost a half-run
16. Post-crash boot-failure cluster (07:00-07:25: browser-history-agent start-limit loop, hermes timeouts, btrfs-compsite timeout, forgejo-oidc-setup) — all self-recovered; if the pattern recurs on every crash-boot, harden the boot-order/gates once, holistically

## g) QUESTIONS ONLY YOU CAN ANSWER

1. **`/data/monitor365` delete-after-verify is confirmed (you answered "delete").** But given the tree is corrupt-adjacent and the copy doubles as the corruption probe: if the checksum verify FAILS (corrupt source files), do you want the source kept on /data until the corrupt-file map is reviewed (my default: yes, keep), or deleted anyway since the pool copy is then "the best that exists"?
2. **Commit hygiene:** the working tree now interleaves MY session's edits with a concurrent session's (niri-config, fastflowlm, browser-history, home.nix, post-deploy-check, session-boot-audit…). One mixed commit by the daemon, or do you want to review/split first?
3. **btrbk-pool snapshots of the disabled monitor365 subvol (f.11):** exclude the 1.9M-inode subvol from nightly snapshots until re-enable (saves nightly IO churn), or keep snapshotting for consistency with the other subvols?

---

**Bottom line:** 2 of 3 trees fully migrated and verified (archive 32G, atticd live flip), monitor365 (1.9M files) mid-copy with instrumentation and a 12h ceiling, smartd restored + made crash-resilient, zero data loss at every failure point — every bug I shipped was caught by a gate I'd built, which is the system working, but several were avoidable by testing syntax and measuring scale up front.

---

## ADDENDUM 2026-08-18 ~16:10 — COMPLETE (all three trees migrated; g.1-3 resolved by evidence)

**Final state:** `data-to-pool-migration.service` exited 0 at 16:02 — `complete — all sources migrated, verified and removed`. `ls /data` shows none of the three sources; `/mnt/pool/services/monitor365/` carries the stale uid 966:956 root ownership (permission-denied for the session user — correct; re-chown on service re-enable per the standing caveat). atticd still live on :8200 from the pool throughout.

**g.1 — resolved by evidence, no decision needed.** The verify diff (`>fc........ buffer/seg_000298774886_000298775141.zst`, 1 file of 1,888,382) was NOT source corruption: md5 of the SOURCE was deterministic across two passes (`5273b872…` = `5273b872…`), filefrag showed a single clean extent outside the known corrupt windows, and the pool-side copy held the odd hash. Root cause: the first copy run was SIGTERM'd mid-transfer (deploy restart), leaving a fully-sized but stale file; later runs' quick-check (size+mtime match) never rewrote it. The migration's heal pass (`--ignore-times` forced re-copy + root diagnostics, added after the first failed verify) fixed it; post-heal full re-verify initially flagged only `.d..t...... buffer/` — dir mtime drift caused by the heal write itself — which the next run's plain `-a` copy re-synced before a fully clean verify (31G identical) and source deletion. The /data corruption question for THIS tree is closed: source reads were deterministic; the corrupt windows belong to other regions of /data (unchanged triage scope).

**g.2 — moot:** the concurrent sessions + auto-daemon committed everything in interleaved commits (`34217be3` carries the heal + smartd; `c6f91f33` the fastflowlm template fix); tree verified clean, content spot-checked in HEAD.

**g.3 — keep snapshotting (no action):** `services/monitor365` was already in the committed btrbk-pool list before the question; CoW snapshots of static data are near-free once taken (first-night cost only). Coherent with the other subvols.

**Operational notes from the completion run:**
- 5 runs total (1 SIGTERM'd by a concurrent deploy's unit restart, 2 verify-failed pre-heal-fix, 1 post-heal dir-mtime iteration, 1 clean). Every restart was cheap after the bulk landed (64 MB delta + one verify walk each) — the idempotent design paid for itself under a hostile concurrent-deploy environment.
- Memory: verify walks peaked at the old 512M cap (483M swap); raised to 1G — peak then 1G/457M swap. A 1.9M-inode `rsync -c` walk wants ~1.5G headroom.
- Verify walks took 20-60 min depending on concurrent build IO (same-machine contention is the dominant variable, not the tree).
- The migration unit self-neutralizes via `ConditionPathExists` (OR-prefixed): the next deploy's post-switch start should SKIP instantly — verified in the post-completion deploy.
- Freeing /data space is snapshot-gated: 14d of nightly /data snapshots still reference the monitor365 extents, so the NVMe relief accrues over the retention window rather than immediately (relevant to the root-space TODO and the live `btrfs_health_critical` alert).
