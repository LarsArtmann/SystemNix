# Disk Review → Samsung Role Assignment → /nix Filesystem Deep Research (Full Session Report)

_2026-08-31, started ~14:30, reported 20:02. All times same-day. Live session on evo-x2 (booted 14:30)._

---

## 1. What this session did, in order

1. **Full disk inventory + health review** (the original ask: "review what disks are available")
2. Found + fixed two production bugs discovered during the review (broken balance jobs, monitoring enumeration shift)
3. Benchmarked the Samsung raw (user-assisted sudo, then scripted)
4. Diagnosed the "shell slow under IO pressure" pain live (caught the QLC wedge in the act)
5. First-principles role assignment for the Samsung + design doc
6. `/nix` filesystem deep research: web + community research, on-target fs benchmarks, real compression measurement, verdict
7. Recorded everything in AGENTS.md + design doc; two reusable benchmark scripts committed

---

## 2. FULLY DONE (a)

### Disk inventory & health (the original review)
- Full inventory: nvme1n1 Lexar QLC 1.8T (system: `/` 81% w/ 135G free, `/data` 87%, clickhouse XFS p9 31%), **nvme0n1 Samsung 970 EVO Plus 1TB (blank, internal, new)**, DAS all four targets back (pool RAID1 both members, **zero device errors**, 8% used), buildcache USB (81%, SMART ok), sdc spare SanDisk unmounted
- **DAS fully recovered this boot (14:30)** after the 9-day outage — recorded the outcome in AGENTS.md as instructed by the runbook
- Pool-dependent services all started (atticd, immich, paperless, bank-sync); btrbk-pool snapshotted fresh at boot
- Hardware temps live: Lexar 54°C under load, Samsung 44°C idle
- smartd config parsed + onecheck-verified with both NVMe by-id entries

### Production bugs found & fixed (in tree, flake-check-verified)
1. **Both weekly btrfs balance jobs dead since ~Aug 25** — `fa9e56b7` added an awk Guard 0 without `gawk` in runtimeInputs → exit 127 every run while root sat at 6.4G chunk-unalloc CRITICAL. Fixed (`gawk`+`coreutils`+`gnugrep` in both scripts); built artifact verified to contain gawk in PATH
2. **System disk lost ALL SMART/nvme telemetry** — hardcoded `/dev/nvme0n1` in smartd + nvme-health-monitor silently pointed at the new Samsung after enumeration shift; Lexar unmonitored. Fixed with by-id paths for BOTH NVMe drives
3. AGENTS.md: DAS recovery outcome recorded; enumeration-shift gotcha; balance awk recurrence; Samsung facts section

### Benchmarks (all on-target, measured)
- Samsung raw (scripts/bench-disk.sh): 4K QD1 rr 35.3k IOPS/27.8µs, rw 79.2k/12.2µs, QD32 304k/1.19GB/s, **fsync 0.78ms**, seq 2.4/2.7 GB/s, PCIe 3.0 x4 (= drive max)
- QLC root under same load: 620/295 IOPS QD1, **fsync ~200ms**, live wedge captured (0.3 MB/s @ PSI 47-79%, `blk_mq_get_tag`, `folio_wait_bit_common`, stuck btrfs delayed-meta kworkers)
- USB buildcache: 461 IOPS QD1, fsync 1.7ms
- Per-service real IO volumes via cgroup io.stat (btrbk-data 86G/130G since boot, discordsync 11.8G reads, DBs all tiny)
- **Filesystem comparison on the Samsung** (scripts/bench-nix-fs.sh, 629 real store paths / 1.7G sample): ext4 vs XFS(reflink) vs BTRFS(zstd) — performance a wash under load variance; **BTRFS compression measured 1.89×** (1727 MiB apparent → 913 MiB physical, compsize-verified)

### Research & decisions
- Web research (discourse topics 3566/28486/75795/61199 + Nix PR #4094 + wiki): no official fs recommendation; btrfs+zstd is the community standard for /nix; nix disabled preallocate-contents FOR btrfs compression; ZFS excluded (5s sqlite txg stalls); f2fs excluded (power loss); XFS has NO compression (verified empirically + VDO explanation)
- **/nix filesystem DECIDED: BTRFS `noatime,compress=zstd`** — rationale + full table in design doc
- Design doc written: `docs/planning/2026-08-31_samsung-role-assignment-first-principles.md` — three-tier model (RAM/Samsung/QLC+pool), allocation table, mount-options doctrine (Samsung gets default commit interval, not 300), 4 migration phases with gates, risks
- /data composition corrected by measurement: **589G AI models** + 106G Steam; `/data/docker` EMPTY (docker actually in /var/lib/docker on root)
- QLC-as-HDD-cache question: answered no (tiering not caching) with reasons

### Tooling left behind
- `scripts/bench-disk.sh` — raw-device fio suite, mounted-device guards, self-healing fio path
- `scripts/bench-nix-fs.sh` — ext4/XFS/BTRFS head-to-head with nix-like workloads (fio + 20k-file metadata + real-store-copy + compression), same guards
- Enduring gotcha recorded: `rsync --files-from` silently drops `-a`'s recursion (needs explicit `--recursive`) — cost 4 benchmark runs to find

---

## 3. PARTIALLY DONE (b)

- **Deploy of the two production fixes: NOT deployed.** In working tree only (flake check passed, artifacts verified). deploy.sh pressure gate (exit 12) would block right now anyway (PSI was 26-79% all session). Needs: `nix run .#deploy` when quiet, then `sudo systemctl start btrfs-balance-metadata btrfs-balance-data`
- **Design doc: PROPOSED, not ratified.** Awaiting user decisions: partition layout sign-off (64G XFS + ~860G BTRFS), phase order, Phase-1 reboot window
- **Samsung still blank/unformatted** — intentional (awaiting layout ratification); benchmark runs left it wiped
- Benchmark caveats: QD32 file-based numbers were CPU-contention-bound (~19k vs 300k raw) — usable comparatively, not absolutely; fs-to-fs deltas within load noise (honestly labeled in the doc)
- store growth observation: /nix grew 129→152G during the session (build activity) — design doc numbers updated in chat but the doc's "129 G" mentions not all re-baselined

## 4. NOT STARTED (c)

- Phase 0: fix the /data EIO inode (`sudo btrfs inspect-internal inode-resolve 1331118 /data` → delete/restore the file) — nightly btrbk-data still aborting; also the biggest recurring QLC IO storm
- Phase 1: partition + mkfs + `/nix` migration (rsync -aH runbook, fileSystems entry, neededForBoot verification, reboot)
- Phase 2: hot-DB moves to XFS partition (pocket-id → postgres → forgejo, one at a time)
- Phase 3 decision + Phase 4 (Go caches) — explicitly deferred to post-Phase-1/2 data
- cv-backup: NEVER succeeded (999h sentinel) — flagged, not investigated
- The interactive-shell ionice quick-win (fish init BE/2) — discussed, never implemented
- smartd lacks the Lexar in smartd-test/alerting flow verification post-deploy (unit restart + journal check)

## 5. TOTALLY FUCKED UP (d) — honest accounting

1. **Four consecutive benchmark runs with silently-empty copies** — root cause chain: (i) `du --files0-from` fed newline-separated input (NUL separator bug), (ii) sample selection picked `.drv` files instead of real package dirs, (iii) stale root-owned sample files in sticky /tmp couldn't be replaced by lars, (iv) the final boss: `rsync --files-from` drops `-a`'s implied recursion — exits 0 having copied empty skeletons. Each found by measurement-parity checks (du vs rsync totals), each fixed, final run verified clean
2. **Measurement harness bugs that produced fake numbers I initially showed as real**: `m0*` glob matched 1 of 40 dirs (metadata read/delete phases measured nothing, leftovers poisoned df ratios — the "19G XFS" mystery); `btrfs filesystem du` reports LOGICAL bytes (my "1.03× compression" was wrong — real answer 1.89× via compsize + df-free-delta). Corrected publicly before they could mislead the decision
3. **Pipe-blind exit codes**: `t=$( { time (rsync && sync); } | awk ...)` — pipelines into awk masked rsync failures from `set -e` (in my script AND my first probe). Classic, should have known
4. **Probe scripts without elevation** — twice wrote "root probes" that ran as lars (wrapper lacked sudo), generating misleading permission errors that sent me down wrong paths
5. **Env/sudo archaeology spiral**: sudo VAR=val env-restriction, stale root-owned /tmp files, uid-suffix races — ~6 iterations on script plumbing instead of the actual research; should have xtrace'd the root context on the FIRST silent failure instead of the fourth
6. **Deleted-then-rebuilt fio store path** — unrooted `nix build` output eaten by GC mid-session; self-heal added afterward (should have rooted it initially)

## 6. WHAT WE SHOULD IMPROVE (e)

- **Deploy discipline**: two verified production fixes sat undeployed for ~5h while the box ran with broken balance + no system-disk SMART. The "deploy when quiet" pattern needs a trigger — consider a sev1-bridge-style reminder or a standing rule: session that verifies a fix deploys it before ending (or explicitly hands off)
- **Benchmark methodology**: establish baseline-parity assertions in harnesses from the start (du/rsync/df totals must agree; sample composition must be asserted) — would have caught all four copy bugs on run 1. Also: pin CPU load context or note it per-phase (done late)
- **GC-root all session-built tools** (`nix build -o /tmp/root` or `nix-store --add-root`) — fio loss cost a rebuild + script rework
- **The sudo-via-script pattern** works but is fragile (timestamp windows): if this becomes routine, a proper NOPASSWD entry for narrow read-only/bench commands beats borrowing the user's timestamp
- **QD32 under load**: fio file-mode QD32 was submission-bound — future harness should pin (taskset) or use separate cores to decouple from box load
- Store-size drift: design doc hardcodes sizes; a one-liner `du` refresh at migration time will re-baseline (152G today, may differ at execution)

## 7. NEXT: up to 50 things (f), priority order

**P0 — this week**
~~1. Deploy the staged fixes (balance awk + by-id smartd/nvme) when PSI < 20%~~ done — deployed (gawk+coreutils runtimeInputs; smartd/nvme-health by-id; AGENTS.md 2026-08-31 entries)
2. Post-deploy: verify smartd monitors BOTH NVMe (journal), nvme.prom shows nvme1n1 (Lexar)
3. Run `btrfs-balance-metadata` when quiet; data-balance per its printed runbook (reserve rm → quiet → ionice -dusage=5 -dlimit=2 → re-provision reserve)
4. Fix the /data EIO inode (inode-resolve 1331118; delete/restore file; confirm btrbk-data green next night)
~~5. Ratify Samsung layout (XFS 64G + BTRFS ~860G zstd) + pick Phase-1 reboot window~~ done — Rev 2 RATIFIED (layout + hot-DBs-to-nodatacow decision; `aa88a30a`); migration window pending (TODO_LIST)
~~6. Investigate cv-backup never-success (999h sentinel)~~ done — three stacked bugs root-caused + fixed + VM-proven (16-29/17-22 reports)
7. Root-fs chunk-unalloc re-check after balance (was 6.4G CRITICAL; GC freed extents, verify >10G before declaring safe)

**P1 — migration (once ratified)**
8. Write Phase-1 migration script (partition, mkfs.btrfs -L nix, initial rsync -aH live)
9. Quiesce builds → final rsync --delete → add fileSystems."/nix" (by-label, neededForBoot=true verified against NixOS default) → deploy → reboot
10. Post-migration verification: readlink /run/current-system, nixos-rebuild dry, fio sanity on /nix, exec-latency-under-buildstorm acceptance test (the actual point of all this)
11. Delete old @nix subvol contents AFTER 3-day soak; confirm root frees; balances finally run clean
12. Update btrbk root.conf? (NO — /nix not snapshotted today; zero backup topology change — document this in the runbook)
13. Add Samsung to btrfs-health metrics (second device; btrfs.prom assumes root fs only)
14. smartd/nvme-health coverage for the new partitions; Gatus checks for /nix mount presence + space
15. attic: confirm store rebuild story works (atticd serving, substitute test) before deleting old subvol

**P2 — hot DBs (Phase 2)**
16. pocket-id dataDir → XFS partition (stop, rsync, option flip, restart, gatus green)
17. postgres (immich+paperless) dataDir → XFS (peer-auth socket unchanged; verify backups land pool-side via existing dumps)
18. forgejo dataDir → XFS (forgejo dump backup already location-agnostic)
19. Consider gatus/discordsync/browser-history/inboxclean/bank-sync DBs: measure their fsync pain post-Phase-1 first (they're background — maybe they stay)
20. dnsblockd 1.3G tracking DB: assess query-path latency before/after (probably stays on QLC — hot path is RAM)

**P3 — polish + hardening**
21. Fish interactive shells ionice BE/2 (quick-win, was designed never implemented)
22. QD32 benchmark re-run on an idle box for honest absolute numbers
23. bench-nix-fs.sh: add parity assertions + taskset pinning (the improvements above)
24. gc-root the bench tooling
25. /nix store growth tracking metric (grew +23G in one afternoon — alert at threshold)
26. Move `/var/lib/docker` off root fs (sdc ssd-btrfs earmarked — check capacity vs images)
27. Revisit monitor365/discordsync/browser-history pool subvols (reserved, uid-stale) — migrate or delete reservations
28. zram back to ~30% after the OOM-era sizing review (28.1G now)
29. Immich thumbnails promotion decision (HDD pool serving) — only if photo browse feels slow
30. flm cold-load rate re-measure on the QUIET QLC post-migration (the control experiment promised)
31. Re-check ClickHouse write endurance math once telemetry stays on QLC long-term
32. btrfs-verify-pool-backups should FAIL when received-backup freshness is 10d stale — confirm it did (it did: red) and that tonight's runs clear it
33. Consider `auto-optimise-store = true` debate now that fs supports it well (hardlink dedup 25-35% vs zstd 1.89× — probably NOT both, decide once)
34. Design doc: re-baseline all sizes at execution time
35. Session hygiene: the parallel-session files (niri-wrapped.nix, home.nix, btrfs-snapshot-bloat-fix.html, flake.lock, visualization HTML) — confirm ownership/attribution with other session before any batch commit touches them

**P4 — bigger ideas**
36. Phase 3: /home → Samsung decision (268G; trigger = post-Phase-1 git-status latency data)
37. Phase 4: GOCACHE+GOMODCACHE → Samsung (78G)
38. erofs read-only store experiment? (interesting, low priority)
39. Second Samsung as cold-spare (or mirror the hot-DB partition?) — hardware question for user
40. Document the full two-disk topology in a proper architecture diagram (architecture-visualization skill exists)

(40 items — the list is honest, not padded to 50.)

## 8. Questions I cannot answer myself (g)

1. **Reboot window for Phase 1**: when may I take the box down for the /nix cutover (single reboot, ~30-60 min including verification)? Any day/time constraints this week?
2. **Layout sign-off**: 64G XFS (hot DBs) + ~860G BTRFS-zstd (/nix) as proposed — or do you want a different split (e.g. single BTRFS with noCoW DB dirs, or a third partition for future Go caches)?
3. **The 17G `/mnt/buildcache/swapfile-emergency`**: it appeared in the buildcache breakdown (not in AGENTS.md anywhere I found) — what is it, and is it load-bearing for anyone before we touch buildcache layouts in Phase 4?

---

## Appendix: files this session created/modified

- `platforms/nixos/system/btrfs-health.nix` — balance runtimeInputs fix (2 scripts)
- `platforms/nixos/system/configuration.nix` — smartd by-id × 2 NVMe + nvme-health-monitor by-id
- `AGENTS.md` — DAS outcome, balance recurrence, enumeration gotcha, Samsung section + fs decision, rsync gotcha
- `docs/planning/2026-08-31_samsung-role-assignment-first-principles.md` — design doc + benchmark tables + verdict
- `scripts/bench-disk.sh`, `scripts/bench-nix-fs.sh` — reusable benchmark harnesses (guards included)
- This report
- Parallel-session files NOT mine (flagged, untouched): flake.lock, niri-wrapped.nix, home.nix, btrfs-snapshot-bloat-fix.html, samsung-disk-layout-visualization.html
