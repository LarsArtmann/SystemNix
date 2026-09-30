# Status Report 2026-09-30 05:40 — Emergency-Reserve-in-Snapshots Question & Self-Review

**Session scope:** Answered "why is /btrfs-emergency-reserve in btrfs snapshots?" + this self-review. No changes made to the repo this session.

---

## a) FULLY DONE

1. **Root-cause answer delivered.** The reserve is a plain fallocate'd file at the root of `@` (`btrfs-health.nix:529`), and `@` is snapshotted nightly by the root btrbk instance (`snapshots.nix:240-247`, 23:00, retain 3d 1w / min 2d). Every snapshot therefore references its 10 GiB of extents. Verified live: file exists (`-rw-r--r-- 1 root root 10G`, mtime Sep 13 15:37), snapshot layout confirmed via config + `.snapshots` dir listing.
2. **Named the design wart explicitly.** Same-fs is a requirement (chunk-headroom margin); same-**subvolume** is not. A nested `@reserve` subvol mounted at `/btrfs-emergency-reserve` would keep the reserve on the QLC filesystem while being invisible to `@` snapshots (mount point = empty dir in `@`), making `rm` genuinely instant instead of 2w-pinned.
3. **Impact quantified from existing knowledge, not re-derived.** T14 caveat (AGENTS.md): root pin window = **2 weeks sharp, calendar-anchored** (3d buckets + first-of-week weeklies, min 2d). "Instant 10 GiB" only holds when the newest snapshots predate the file's extents (cold provision); at steady state the `rm` frees ~nothing until the window drains.
4. **Fix options Pareto-ordered and offered, not unilaterally executed** — owner-gated because it is a maintenance-deploy-shaped change (subvol bootstrap + one-time rm/re-provision cycle; the old extents still drain over 2w either way).

## b) PARTIALLY DONE

1. **Live snapshot-side verification.** I confirmed the file exists and read the btrbk config, but could NOT run `sudo` (blocked in this sandbox) — so I never directly confirmed that a given `.snapshots/@.20260929T2300` tree contains `btrfs-emergency-reserve` inside it, nor measured how many live snapshots actually pin the extents. The inference (file in `@` + `@` snapshotted → pinned) is airtight, but the *count* of pinning snapshots (4-6 live per the 2026-09-25 reconciliation) is cited from AGENTS.md, not re-probed.
2. **Pool-side pinning unaddressed.** Root receives on the pool are FOREVER (`target_preserve_min = "all"`). The reserve's extents are therefore ALSO pinned pool-side since 2026-08-21 policy — the fix options I gave only discussed the LOCAL window. Deleting the reserve frees NVMe chunks only after local expiry; the pool copy is permanent by design (16T headroom makes it acceptable, but the report should have said so).

## c) NOT STARTED

1. **Option 1 implementation** (`@reserve` subvol + mount-gated bootstrap unit + unit-aware reserve service + tmpfiles/mount wiring). Not started — awaiting owner go/no-go.
2. **Stale-mtime investigation.** Reserve mtime Sep 13 15:37 with `mtime`-only change suggests it was re-provisioned ~17 days ago (or touched). If it was re-provisioned mid-window on Sep 13, its extents are pinned only by snapshots from Sep 13+ — worth checking whether a re-provision event (guard/balance flow) rotated it, which affects how much is currently pinned.
3. **Eval-time guard idea.** No assertion exists (or was proposed) that the reserve path never becomes a snapshot-pinned artifact — e.g., a check that `/btrfs-emergency-reserve` is a mountpoint if the subvol fix lands. If option 1 is implemented, this belongs in the same change (the house pattern: every fix ships with its guard).

## d) TOTALLY FUCKED UP

1. **First response under "Interpretation & Follow-ups"? Not an error per se, but the initial answer was Exploration-shaped (explained + offered fix), which was correct for a "why" question — but I did NOT proactively surface the pool-side pinning (b.2) or the Sep-13 re-provision question (c.2) in that answer. They surfaced only under this self-review. A top-tier first answer would have flagged "your reserve was re-provisioned Sep 13" as an observation the user likely did not know.
2. **No preflight `readlink -f /btrfs-emergency-reserve`.** Cheap check skipped: if the path had already been a symlink (it is not — plain file), my whole answer would have needed rework. Verified implicitly via `ls -lh` (shows file, not link), so no harm — but the explicit check is the disciplined form.

## e) WHAT WE SHOULD IMPROVE (session-derived)

1. **The T14 caveat should live in CODE, not only in AGENTS.md.** The reserve unit's own comment block (`btrfs-health.nix:529-532`) says "Delete it for instant free space" — which is the *lie* the AGENTS.md caveat corrects. Anyone reading the module learns the wrong semantics. Fix: correct the in-module comment to state the 2w pin window, or implement option 1 and make the comment true.
2. **Balance/gc-guard recovery runbooks embed the same "instant" claim** (`btrfs-health.nix:136`, `:462`, `:517` — "Free extents: rm /btrfs-emergency-reserve (instant 10 GiB)"). In a real ENOSPC emergency, an operator following that line would `rm`, see ~0 GiB freed, and lose trust in the runbook. These strings should say "frees as snapshots expire (up to 2w); for TRUE instant headroom use the emergency-reserve ONLY if chunk-unalloc is already the binding constraint and the balance skip-gates are the real lever" — or, with option 1 landed, they become correct as written.
3. **The `btrfs_emergency_reserve_present` metric cannot see pinning.** Gatus asserts presence, nothing asserts effectiveness. If option 1 lands, add a companion gauge (e.g., `btrfs_emergency_reserve_unpinned_estimate`) or at minimum a comment linking the metric to the pin-window semantics.
4. **Runbook-line hygiene generally:** three separate echo strings in btrfs-health.nix repeat the same recovery advice — a single sourced helper (the offsite-borg-smoke.sh lib-extraction pattern) would keep them from drifting, which they demonstrably did relative to AGENTS.md.

## f) UP TO 50 NEXT THINGS (ranked; session-scoped)

**The fix itself:**
1. Owner decision: implement `@reserve` subvol option 1? (yes/no/defer)
2. If yes: declare subvol creation in disk/mkFilesystem layer or bootstrap-unit pattern (hot-user-caches precedent — but note its 2026-09-29 D-state lesson: provisioning state belongs in disko, nothing runtime between automount and mount).
3. If yes: add `fileSystems."/btrfs-emergency-reserve"` subvol mount (nofail, noauto-automount unnecessary — wanted by the reserve unit).
4. If yes: rework `btrfs-emergency-reserve.service` to fallocate INSIDE the subvol, mount-gated (`RequiresMountsFor`), with a one-time transition that `rm`s the old in-`@` file.
5. If yes: fix the three "instant" runbook strings (e.2) in the same commit.
6. If yes: add the eval guard — assertion that the reserve path is a mountpoint when the module is enabled (mirror mount-gating-audit shape).
7. If yes: extend `btrfs-verify-pool-backups`/btrbk config awareness if snapshot sets change (they should not — `@reserve` gets NO btrbk entry).
8. If yes: VM-test or extend `tests/test-scripts.nix` with the transition (old file present → migrated → old rm'd).
9. If yes: update AGENTS.md T14 + Snapshot-pinning doctrine table row (`/btrfs-emergency-reserve` row changes from "root = 2w sharp" to "no pin").
10. If yes: update the btrfs-health metrics help-text to reflect the new semantics.

**Regardless of decision:**
11. Correct the in-module comment (e.1) — 2-line change, no deploy risk.
12. Live-verify (needs sudo): `sudo ls /mnt/btrfs-root/.snapshots/@.20260929T2300/btrfs-emergency-reserve` to close b.1.
13. Count pinning snapshots: `ls /mnt/btrfs-root/.snapshots | grep -c '^@\.2'` (expect 4-6).
14. Investigate the Sep 13 15:37 re-provision: `journalctl -u btrfs-emergency-reserve --since 2026-09-12` (needs sudo) — was it a deliberate recovery or an unnoticed delete+recreate?
15. Note the pool-side forever-pin of reserve extents in AGENTS.md T14 (one sentence, b.2).
16. Consider whether `btrfs-rescue` read-only snapshots (`/mnt/btrfs-root/.rescue`) ALSO pin the reserve — they are `@` snapshots too (2 kept) and are pruned on their own cadence; the effective pin floor is rescue-tier retention, not just btrbk (verify retention cadence in btrfs-rescue.nix).
17. If 16 reveals a longer floor, the option-1 value proposition strengthens — fold into the decision.

**General hygiene noticed en route:**
18. btrbk root instance comment block in snapshots.nix is excellent (calendar-anchor math documented) — no action, just a pattern to keep.
19. `.snapshots` listing showed `@home-hermes.*` entries — consistent with config; no drift observed. No action.

(19 concrete items — the rest of the 50 slots would be padding unrelated to this session, which the brief forbids.)

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **Go/no-go on option 1** (`@reserve` subvol migration)? It costs one maintenance deploy + a one-time rm/re-provision cycle; the benefit is genuinely-instant reserve deletes. Alternatively defer and just fix the lying comments (item 11).
2. **Do you know why the reserve was re-provisioned Sep 13 15:37?** If that was you (or a recovery flow), the current pin set starts there; if nobody knows, it deserves the journal dig (item 14) — I cannot read the journal without sudo.
3. **Is the pool-side forever-copy of the reserve's extents acceptable** (16T headroom says yes, but it is ~10 GiB per re-provision generation, forever)? If the reserve is re-fallocated occasionally, the pool accumulates those generations; a `@reserve` fix does not change pool behavior — excluding it would need a btrbk exclude mechanism that does not exist for received-forever policy. Accept, or does this change the calculus?

---

**Bottom line:** The question is fully answered; the design wart is real, known (T14), and cheaply fixable. Nothing was changed this session. The worst self-inflicted gap: the first answer omitted the pool-side pinning and the Sep-13 re-provision observation, both of which were knowable from data I already had.
