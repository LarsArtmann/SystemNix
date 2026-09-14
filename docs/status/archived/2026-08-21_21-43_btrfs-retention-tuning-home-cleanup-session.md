# Status Report: 2026-08-21 21:43 — BTRFS Retention Tuning + `@home` Cleanup Session

**Session type:** Active config changes. Follow-up to the 21:16 advisory session. Three user decisions executed: (1) local root snapshot retention quartered, (2) pool-side root backups kept FOREVER, (3) `@home` proper-setup deferred to TODO_LIST. Plus the snapshot/pool verification questions that preceded them.

---

## a) FULLY DONE

| # | Item                                                                                                                                                                                                                                                                                                                                                                              | Evidence / Location                                                             |
| - | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| 1 | **Verified pool send coverage** — all 7 local `@` snapshots exist on the pool, PLUS 2 extra (`@.20260812/13T2300`) that survive only pool-side after the user manually deleted them locally on Aug 17 20:48/20:52 (found via journalctl sudo logs — during the 96% space crisis, safely post-send). Off-schedule catch-up snapshot `20260816T2231` was sent too. 1:1 chain intact | `ls /mnt/pool/backups/root/` vs `ls /mnt/btrfs-root/.snapshots/` + `journalctl` |
| 2 | **Local root retention quartered** — `snapshot_preserve_min "7d"→"2d"`, `snapshot_preserve "14d 4w"→"3d 1w"` (root instance ONLY; /data instance untouched) with rationale comment                                                                                                                                                                                                | `snapshots.nix:84-89`                                                           |
| 3 | **Pool-side root backups = FOREVER** — `target_preserve_min = "all"`, `target_preserve` removed; comment documents the CoW extent-sharing space math + revisit trigger (~50% pool usage)                                                                                                                                                                                          | `snapshots.nix:90-95`                                                           |
| 4 | **`@home` mystery solved and disposition decided** — dead EMPTY install residue (created Dec 7 2025, never mounted, never written; real home lives in `@/home` and rides every nightly `@` send). Proper separate-subvolume layout marked in TODO_LIST Priority 7                                                                                                                 | TODO_LIST.md (new entry)                                                        |
| 5 | **Docs synced** — AGENTS.md BTRFS section (Snapshots + Backups paragraphs, both now state the new asymmetric retention + forever-pool decision + date), FEATURES.md BTRFS snapshots row                                                                                                                                                                                           | AGENTS.md:430-432, FEATURES.md:269                                              |
| 6 | **Eval verified** — `nix flake check --no-build` passed after each change round (2 runs)                                                                                                                                                                                                                                                                                          | session shells 007/008                                                          |
| 7 | **Pool headroom measured for the forever decision** — 1.5T used / 14T free (10%). At any plausible root-churn rate this is years-to-decades of runway                                                                                                                                                                                                                             | `df /mnt/pool`                                                                  |
| 8 | Explained the local-vs-pool tier design (rollback speed, incremental-send parent, nofail DAS detachability) and the extent-pinning cost model                                                                                                                                                                                                                                     | conversation                                                                    |

## b) PARTIALLY DONE

| # | Item                                                                                                                                                                                                                                                                                                                                          | What's missing         |
| - | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------- |
| 1 | **Deploy** — changes are config-only; NOT activated. btrbk picks them up at the first 23:00 run after the next `nix run .#deploy`. Expect tonight-or-next-run local pruning of snapshots older than 3d (≈ `20260814`-`20260817` dailies; weekly rule may pin one) → extent freeing right before nix-gc at 00:00, exactly the designed stagger | no deploy this session |
| 2 | **First-run validation of `target_preserve_min = "all"`** — btrbk semantics confirmed from docs knowledge, but no dry-run was possible (sudo blocked in session; btrbk dryrun needs root). The 23:00 run after deploy should be watched for `WARNING`/config-parse rejection                                                                  | sudo unavailable       |
| 3 | **`@home` deletion** — identified + user decision context given, but actual `sudo btrfs subvolume delete /mnt/btrfs-root/@home` is user-run (sudo blocked). Frees ~nothing (it's empty) — hygiene only                                                                                                                                        | user-run step          |
| 4 | **`@cache-home.regular-dir-bak` triage** — flagged last session, inspected THIS session: 3.7 MB of stale Dec-2025/Jul-2026 cache copies (activitywatch, awesome, awww, black…), lars-owned 0700. Trivial size, zero value assumed — but not trashed (not this session's mandate; user decision)                                               | pending user trash     |

## c) NOT STARTED

| # | Item                                                                                                                                 |
| - | ------------------------------------------------------------------------------------------------------------------------------------ |
| 1 | /data instance retention review (local 14d 4w + pool 30d 12w both untouched — user only decided root)                                |
| 2 | CHANGELOG.md entry for the retention change (AGENTS/FEATURES updated; repo keeps a CHANGELOG — this change is notable enough for it) |
| 3 | `nix fmt` pass over edited files (hand-formatted; alejandra may reflow — pre-commit will catch if the daemon commits)                |
| 4 | Stale `< 10%` comment fix in `btrfs-health.nix:508` (carried over unfixed from previous report's Tier 0 list)                        |
| 5 | `max-free = 100G` fix (previous session's headline risk — still awaiting user decision on deploy bundling)                           |

## d) TOTALLY FUCKED UP

Nothing destructive; no reverts needed. Honest process failures:

| # | Failure                                                                                                                                                                                                                                                                                                                                     | Why it matters                                                                           |
| - | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| 1 | **Scoped the retention change without confirming scope.** User said "Local (14d 4w) to 1/4th?" in a thread about ROOT snapshots; I changed root only and documented `/data unchanged` — correct reading of context, but I never ASKED whether /data was meant too. If the intent was both, /data stays quarter-less until the next exchange | Ambiguity resolved by assumption, not confirmation                                       |
| 2 | **Didn't inspect `@cache-home.regular-dir-bak` when I first flagged it** — last answer said "inspect and trash it too"; I only actually inspected it while writing THIS report. 24+ hours of report-claim lag                                                                                                                               | Recommended an action I hadn't done the homework for                                     |
| 3 | **No btrbk dry-run/validation path attempted** — I have no sudo, but I could have at least checked btrbk's config-parse via a non-root invocation against a copy of the config, or verified "all" is accepted by the deployed btrbk version's docs. Relied on memory of btrbk semantics                                                     | Forever-retention is a one-way-ish decision; validation belongs before deploy, not after |
| 4 | **First pool-coverage answer under-flagged the btrbk `stray subvolumes` warnings** sitting in the journal since Aug 17 ("Please delete stray subvolumes: btrbk clean /mnt/pool/backups/root") — real operational signal about pool-side hygiene that I scrolled past in my own grep output and did not report                               | Missed free finding that was literally in front of me                                    |

## e) WHAT WE SHOULD IMPROVE

1. **Watch the first 23:00 btrbk run post-deploy** — confirm (a) `target_preserve_min = "all"` parses, (b) local pruning fires (frees extents), (c) no stray-subvolume warnings regress
2. **Run `btrbk clean /mnt/pool/backups/root`** (or investigate why btrbk keeps requesting it — recurring WARNING since Aug 17): pool-side receive target has strays btrbk wants a human to bless deleting
3. **Decide /data retention symmetry** — root is now aggressively trimmed locally + forever pool-side; /data still 14d 4w local / 30d 12w pool. Docker+Immich-DB churn is the fastest-growing backup input; if pool growth needs governing, /data target retention is the control knob
4. **Add a pool-usage Gatus threshold** — forever retention makes pool growth monotonic-ish; a `>50%/70%` alert operationalizes the documented revisit trigger (currently a comment only)
5. **CHANGELOG entry** for the retention policy change (user-visible backup semantics)
6. **`nix fmt`** on touched files before the daemon auto-commits (or accept pre-commit's reflow)
7. **Carry-over Tier 0 items still open**: `max-free` fix, stale `btrfs-health.nix:508` comment, `flake.lock.feat`/`.orig` triage (from 21:16 report)
8. **User-run cleanup batch** (one sudo session): delete `@home`, trash `@cache-home.regular-dir-bak` (3.7 MB, stale), optionally `btrbk clean`

## f) UP TO 50 THINGS TO DO NEXT

**Immediate (this change-set)**

1. `nix run .#deploy`
2. Watch 23:00 btrbk-root run (journal: parse OK, local deletions, send OK)
3. Confirm `target_preserve_min = "all"` did not produce warnings
4. Verify local `.snapshots/` count drops to ~3-4 tomorrow
5. Verify pool count UNCHANGED (forever = nothing deleted pool-side)
6. Check root fs % freed after snapshot expiry + 00:00 nix-gc
7. Add CHANGELOG.md entry for retention change
8. `nix fmt` on `snapshots.nix`

**Pool hygiene**
9. Investigate recurring `stray subvolumes` warning (Aug 17→20+)
10. Run/evaluate `btrbk clean /mnt/pool/backups/root`
11. Same check for `/mnt/pool/backups/data`
12. Pool usage Gatus alert (>50% warn, >70% page) — textfile collector likely already has df data
13. Project forever-retention growth: measure nightly send size (journal) × years vs 14T

**/data decision set**
14. Decide /data local retention (keep 14d 4w vs quarter like root)
15. Decide /data pool retention (30d 12w vs forever — churn tradeoff)
16. /data EIO inode repair (P0 carry-over — gates everything /data)
17. Verify `/data/docker` nested-subvol vs plain dir (carried over, affects btrbk-data payload)

**User-run sudo batch**
18. Delete `@home` subvolume
19. Trash `@cache-home.regular-dir-bak`
20. p9 partition deletion (long-standing user decision)
21. p9 unallocated-space decision (XFS `/nix` candidate vs leave)

**Carry-over from 21:16 report (still open)**
22. `max-free = 100G` → 20-30G fix + deploy
23. Attic cache creation + substituter wiring (biggest /nix win)
24. `keep-outputs`/`keep-derivations` evaluation
25. Pull real `/nix` compression ratio from btrfs-compsite metrics
26. Stale `btrfs-health.nix:508` comment fix
27. `flake.lock.feat`/`flake.lock.orig` triage
28. Refresh `@nix` size + root % numbers (all quoted sizes are ≥4d stale)
29. fio XFS-vs-BTRFS benchmark on frozen sdf
30. sdd XFS Docker volume plan (sizing, PG quiesce, migration)
31. ClickHouse XFS relocation + before/after measurement
32. XFS pquota disk-caps + textfile collector
33. XFS monitoring parity (xfs_scrub + stats collector) before any XFS lands
34. `@cache-home` offload plan (nix eval cache 6G to buildcache)
35. SigNoz dashboard panels: nix store size, GC duration, pool usage
36. Gatus check: nix-gc duration over threshold
37. VM/qcow2 XFS policy note
38. XFS decision doc in docs/planning/ capturing the 21:16 ranking
39. AGENTS.md `/nix` sizing comment refresh
40. TODO_LIST attic entry breakdown (Tier 1 items from 21:16)
41. btrbk-data 6h TimeoutStartSec review once /data EIO repaired
42. Consider `@home` proper subvolume design doc (when that TODO activates)

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **/data symmetry:** Root local retention is now quartered and pool-side is forever. Should /data follow (quarter local, and/or forever pool-side), or stay as-is? /data is the churn-heavy one — forever-pool for it means Docker/Immich-DB churn accumulates indefinitely (~10x the growth rate of root; 14T still lasts years, but it's the knob that governs pool growth).
2. **Deploy bundling:** Deploy the retention change now, or bundle with the pending `max-free` fix (still unanswered from the last report) into one deploy tonight before 23:00 so the new policy + the store-sweep fix land together?
3. **The pool-side stray subvolumes:** btrbk has been warning `btrbk clean /mnt/pool/backups/root` nightly since Aug 17. I can't run it (root) and can't determine from logs alone WHICH subvolumes it considers strays or whether cleaning could touch the pre-forever receives. Do you want to run the investigation/clean yourself, or should I dig into btrbk's stray-detection logic and report exact candidates first?

---

**Files changed this session:** `platforms/nixos/system/snapshots.nix` (retention), `TODO_LIST.md` (+1), `AGENTS.md` (2 paragraphs), `FEATURES.md` (1 row), this report.
**Not changed:** CHANGELOG.md (miss), `btrfs-health.nix` comment (carry-over), no deploy.
**Verification:** `nix flake check --no-build` passed ×2. Runtime behavior pending deploy + first 23:00 run.
