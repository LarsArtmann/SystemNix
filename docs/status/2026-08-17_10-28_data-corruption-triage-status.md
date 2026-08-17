# Status Report: Overnight Pool Cycle Results + /data Corruption Discovery

**Task:** Resume after the first full overnight backup cycle; verify results; free root disk; deploy stranded config. Halted by user STOP mid-diagnosis.
**Date:** 2026-08-17 10:28
**Working copy:** 3 modified files (undeployed fixes, see §b); everything else captured by auto-commit daemon in `184c6599` + `26beaf0c`.

---

## a) FULLY DONE

1. **Overnight application backups: ALL GREEN.** First full cycle on the pool: immich-db-backup (01:00), twenty-db-backup (02:00), manifest-db-backup (02:30), forgejo-backup (03:30, 3.7G zip), pocket-id-backup (04:00), paperless-exporter (01:30) — every unit `success`. `backup_healthy` = 1 for all seven monitored backups. The user's "all backups on the HDDs" request is functionally complete and proven for a full night cycle.
2. **btrbk-pool nightly: success.** All 5 `services/*` subvols snapshotted on-pool at 23:45 (immich, paperless, monitor365, discordsync, browser-history).
3. **btrfs-verify-snapshots: success** (NVMe root snapshot freshness intact).
4. **Root-seed progress:** 468G now received on the pool (was 424G at 01:00) — `backups/root` holds @.20260812–20260814 (3 of 6 catch-up snapshots). Raid1 mirror healthy, no pool-side errors.
5. ~~**Config fixes written (in tree, undeployed — see §b):**~~ **Deployed via `2fbb69f9`** (btrbk 24h timeout, byte-gate, disk-growth preStart) — annotation 2026-08-17:
   - `snapshots.nix`: btrbk-root/data `TimeoutStartSec` 6h → **24h** (observed ~17 MB/s seed throughput through the USB DAS; 6h covered only ~60% of the root send before systemd killed it mid-stream).
   - `scripts/pre-deploy-check.sh`: disk gate converted from **percentage to bytes** (FAIL < 5G free, WARN < 15G). 95% of a 723G disk = 41G free — the old gate blocked deploys that could not cause its stated emergency-shell failure mode.
   - `scheduled-tasks.nix`: `disk-growth-check` gets `preStart = mkdir /var/lib/disk-growth` — its `ReadWritePaths` namespace setup hard-fails with 226/NAMESPACE when the state dir is missing.

## b) PARTIALLY DONE

1. **/data corruption triage — root cause scoped, file identification incomplete.**
   - **What:** weekly scrub (00:00, finished 06:27) found **1,351,271 uncorrectable csum errors (~1.3MB) across 22 extents** on /data. This is what aborted last night's `btrbk-data` send ("Failed to send/receive subvolume", exit 10) — `btrfs send` EIOs on unreadable extents.
   - **NVMe hardware is healthy** (SMART PASSED, 0 media/data-integrity errors, 13% wear, 100% spare). Corruption is torn-write/bitrot class — consistent with the box's history of 58 unsafe shutdowns and 114 critical over-temperature events.
   - **Extent layout:** 22 bad physical addresses cluster in 3 windows (~595G, ~627–639G region of the 1.1T partition). All resolve attempts (`logical-resolve` ENOENT, first fiemap scan) failed so far — first scan had a real bug (`filefrag -v1` is not a valid flag; every call silently failed). Fixed script queued as background job 01A when the user stopped the session; **it never produced results**.
   - **Content risk assessment:** /data = docker volumes (nightly pg_dumps now also on pool), AI models (redownloadable), llamacpp models, monitor365 DuckDB (backed up until the service was disabled), attic cache. Nothing irreplaceable-only-on-/data identified so far, but file-level confirmation is still missing.
2. ~~**Stranded deploy (3rd attempt):** the fixes in §a.5 are written, formatted, flake-checked — not deployed.~~ Deployed via `2fbb69f9` (byte-gate unblocked it).

## c) NOT STARTED

1. Completing the corrupt-file identification (job 01A interrupted).
2. Recovery decision + execution (delete/rewrite affected files, or `btrfs check --repair` as last resort).
3. Retrying the btrbk-data seed after /data is clean.
4. Re-provisioning `/btrfs-emergency-reserve` (I removed the file for space; it never actually freed bytes — see §d.4 — and the service is `active` with no file, so it must be re-run once space allows).
5. Docs debt from yesterday, still open: plan-doc decision record, AGENTS.md storage section, TODO_LIST/CHANGELOG entries, stray `/var/lib/paperless` cleanup.

## d) TOTALLY FUCKED UP

1. **The 6h btrbk timeout was my own misestimate.** I sized it "6h covers seeds" without measuring DAS throughput; the seed died at 60% at 05:00 and its 537G of partial write IO was wasted (received subvols are kept, so not a total loss — btrbk resumes from the last complete snapshot). Fixed to 24h.
2. **Concurrent IO storm was self-inflicted:** the manual seed kick (23:00+) ran head-on into the weekly scrub window (00:00) + nightly GC + all dump timers. Effective seed throughput halved (~17 MB/s), scrub ran 6h37m. Future seeds should check for scheduled IO-heavy units first (or seeds should be kicked in the morning, not at midnight).
3. **First fiemap scan was silently broken** (`filefrag -v1`: no such option; `2>/dev/null` ate the usage error; the while-loop emitted nothing and I initially read "no matches" as "no big files affected" instead of verifying tool output). Caught only when spot-checking the tool by hand. Corrected script exists but was stopped before results.
4. **Emergency-reserve release freed nothing** — the 10G reserve file was Aug-2 era, so every root snapshot since pins its extents; `rm` was a no-op for free space (df unchanged). The AGENTS.md claim "delete for instant 10G" is only true for freshly-written reserves. Reserve not yet re-provisioned.

## e) WHAT WE SHOULD IMPROVE

1. **Verify tool syntax before wrapping it in a silent-error pipeline** — the fiemap bug cost the critical-path answer. `|| continue` on inner commands must log, never swallow.
2. **Seeds and scheduled IO-heavy maintenance must not overlap.** Candidate: a pre-deploy/seed check for active scrub/balance/GC timers, or simply scheduling seed kicks for late morning.
3. **The `%`-threshold gate bug class:** any threshold meant to protect a fixed-size failure mode (activation headroom) must be expressed in the units of that failure mode (bytes). Same review owed to any other percentage gates (pool 85% usage alert is arguably fine — it models a fill-rate concern, not a fixed-size need).
4. **Reserve-file freshness:** the emergency-reserve service should touch/rewrite the file periodically (or docs must state the pinning caveat) — a months-old reserve is emotional support, not headroom.
5. **Scrub finding corruption should page louder:** the scrub failure surfaced only as a failed unit + journal line; Gatus has no check on scrub results for /data (`btrfs_scrub_error_free` covers `/`?). Verify wiring; if missing, add.

## f) NEXT THINGS

1. ~~Re-run the fixed corrupt-file mapping scan (job 01A, script at /tmp/find-corrupt2.sh) and identify affected files.~~ progressed past this report — 13 corrupted files identified (recorded in TODO_LIST P0 root-scrub item, 2026-08-17); recovery decision still open (g.1)
2. Decide recovery per file: redownloadable models → delete + re-fetch; docker/pg data → restore from pool dumps; DuckDB → verify latest backup usable.
3. After /data clean: re-kick `btrbk-data` seed (morning, not midnight; confirm no scrub running).
4. ~~Deploy the 3-file fix batch (24h timeouts, byte gate, disk-growth preStart)~~ done — `2fbb69f9`.
5. Re-provision `/btrfs-emergency-reserve` and fix its freshness semantics (e.4).
6. Re-run scrub on /data post-repair to confirm 0 csum errors; then re-enable nightly data sends.
7. Watch `btrfs-verify-pool-backups` turn green once both targets have fresh received snapshots.
8. ~~Check/extend scrub-error Gatus coverage (e.5).~~ verified in config — the collector iterates `/` AND `/data` (`platforms/nixos/system/btrfs-health.nix:197`); composite `btrfs_scrub_error_free 1` + Gatus alert cover both.
9. ~~Yesterday's doc debt (plan decision record, AGENTS.md storage section, TODO_LIST, CHANGELOG).~~ done — `46b5ffdb` (AGENTS.md pool section + TODO_LIST/CHANGELOG rewrites) + three-drive Decision Record archived.
10. Remove stray `/var/lib/paperless` from the misconfigured first deploy. ← open — TODO_LIST Priority 3
11. Longer term: own-tools migration into prepared pool subvols; sdf/SanDisk decisions; hd-idle. ← open — TODO_LIST P3 (own-tools), P2 (Docker→SSD2), P3 (hd-idle alongside pool-usage alert)

## g) QUESTIONS (cannot resolve alone)

1. **/data recovery posture:** given NVMe SMART is clean and the damage is ~1.3MB in 22 extents, do you want (a) minimal: identify + delete/rewrite affected files only, or (b) aggressive: also run a full `btrfs check --mode=low-risk` review of /data? I recommend (a) — check --repair is the riskier tool.
2. **Monitor365 DuckDB on /data (23G, `monitor365-server` currently disabled):** it sits in one of the corrupt-adjacent regions and its service is off. May I verify its latest `*.backup_*.db` (on NVMe /var/lib) is intact and treat /data's copy as disposable?
3. **The reserve service is `active` but its file is gone** (my removal). Re-provision now (writes 10G onto a 41G-free root during active triage), or after the /data situation resolves?

---

**Standing state at write time:** pool healthy (468G received, all app backup timers green); /data has known-readability corruption pending file mapping; root seed ~60% behind a 24h-timeout fix that is written but undeployed; 3 files modified in tree; all diagnosis scripts in /tmp (`find-corrupt2.sh` ready to re-run).
