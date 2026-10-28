# Status Report: Root-Ledger Segment — Brutal Self-Review #2

**Date:** 2026-10-28 22:03 CEST
**Session scope:** Self-review #2 of this session's later segments (19:0x: the pool-backup inventory answer; 19:4x: the root-partition ledger). The deploy-fix work (15:35–19:00) is reported and self-reviewed at [18-50](2026-10-28_18-50_projects-subvol-cutover-deploy-fix.md) and [19-01](2026-10-28_19-01_deploy-fix-brutal-self-review-status.md) — not re-derived here, only carried forward.
**Standing state:** projects subvol live + anchored (gen-958), first pool receive landed, writer fleet active, plan EXECUTING (Phase F burn-in). **The first nightly btrbk-projects ladder run fires at 23:10 tonight (~1 h from this report).**

---

## Self-review verdict — what I got wrong in THIS segment

1. **What did I forget?** The **harvest discipline failed again, immediately after being preached**: I found the monitor365-server anomaly (110 G, tripled since 10-26), flagged it to the owner verbally ("want me to dig?") — and **queued no TODO row**. If the owner hadn't asked for this report, the finding would live only in a chat scroll. Harvested now (§f NEW).
2. **What could I have done better?** I published a **ledger with its biggest unknown still unknown** — `~/.cache` timed out twice under throttling and shipped as "big — was 80 G on 10-26". A ledger whose second-largest line is a two-day-old number with a question mark is not a ledger. Alternatives existed and I tried none: a longer background window, per-child depth-1 decomposition (timeouts per child), or the storage collector's own metrics. Same for `~/tmp`: my `du -x` returned **"0 + timeout" through the failed automount** — an inconclusive measurement I glossed over with 10-26's 25 G figure instead of stating "unmeasured".
3. **What did I notice and NOT flag?** The subvol inventory showed **test-residue subvols** (`zz-test-delete`, `zz-test-snap` under `.rescue/`) and the **empty `@home` (ID 257)** — the 10-26 report already named @home a deletion candidate, it's STILL there, and I saw it again without re-queueing. Small, but that's exactly how permanent residue happens.
4. **Precision shipped:** the pool answer and its table were fully live-verified (receive dirs listed, config targets grepped, fresh receives shown) — that segment met the bar. The root ledger met it for 6 of 8 rows.
5. **Did I lie?** No claims were false, but two were **weaker than they looked**: "big — walk timed out twice" reads like knowledge; it is the absence of knowledge formatted as a table row. Corrected in this report's §b.

## a) FULLY DONE

1. **Pool-backup question answered live** (no memory-claims): 23 receive-target dirs listed on `/mnt/pool`, the 5 configured btrbk instances with targets + cadences grepped from `snapshots.nix`, fresh receives shown for projects (`20261028T1803`) and forgejo (3, incl. the known stray), retention classes contrasted (projects bounded 7d/14d/8w vs root FOREVER), and the two honest caveats given (same-chassis only, offsite-borg disabled; monitor365-pool-copy among the failed units).
2. **Root ledger measured, not guessed, where measurement succeeded**: df 483 G/723 G; throttled depth-1 walks for `/var/lib` (127 G: monitor365-server **110 G**, inboxclean 14 G) and the mid-size home dirs (.local 30 G, go 4.5 G, Downloads 2.4 G, Desktop 1.4 G); snapshot/subvol inventory (1× `@`, 2× active `.rescue @`, 4× hermes, test residue, empty `@home`); metadata cost (~29 G real, DUP) reconciled against btrfs usage.
3. The 19-01 report's harvests landed and were daemon-swept; todo gate clean at last check.

## b) PARTIALLY DONE

1. **The root ledger's two holes**: `~/.cache` (likely the 2nd-or-3rd largest chunk — 80 G on 10-26, unmeasured now) and `~/tmp` (349 k files, size between ~10–25 G, unmeasured now). The monitor365 110 G number is du-apparent — **reflink-sharing means real extent usage may be far lower**; the two interpretations were given, not resolved.
2. **Carried from 19-01** (unchanged): D6 boot proof unrun; calm-box post-deploy re-run pending; storm-suspect CV renders unverified; whisper-cli drain outcome unconfirmed; §11 FOD blind spot + §18 sanity false-flags documented, not mechanized.
3. **First nightly ladder (23:10 tonight)** — not yet due at report time; the queued watch row covers it.

## c) NOT STARTED (pre-existing, noticed, untouched)

- monitor365 110 G decomposition (now queued, §f).
- `zz-test-*` residue subvols + empty `@home` cleanup (now queued, §f).
- Everything carried at 19-01 §c (~/tmp prepare owner-gated, 145 unharvested reports, the 12 failed units batch).

## d) TOTALLY FUCKED UP (this segment, owned)

1. **Verbal flag instead of a row** for the session's own biggest new finding (monitor365) — the harvest rule violated one report after being written down as a lesson. Process conclusion: my §f checklist must run BEFORE answering the user, not at the next report.
2. **Timeout-shaped holes shipped as table rows** (.cache, tmp) — measurements that failed were formatted like measurements that succeeded.

## e) WHAT WE SHOULD IMPROVE

1. **A throttled-du helper that decomposes instead of dying**: one `du -d1` with a global timeout guarantees the biggest dir times out first (it's the slowest). Per-child budgets (or the existing `io-psi-crosscheck`-style delta tooling) would have produced the full ledger in the same wall time. The 10-26 session wanted exactly this (`io-psi-crosscheck.sh` delta mode, §e.2 of its report — still unimplemented).
2. **Storage-collector could own the ledger**: `storage_collector_fs_used_percent` exists — per-subvol/per-dir apparent-vs-real accounting (du + `compsize`-style) as a periodic collector would replace every ad-hoc session walk, including this one's holes.
3. **Residue hygiene**: test subvols under `.rescue/` and the empty `@home` should be a lint row (the eval-time audits catch config shapes; nothing catches filesystem residue).

## f) NEXT — honest count 19 (15 carried from 19-01; 4 NEW, harvested with this report)

Carried (queue + libraries, see 19-01 §f): calm-box post-deploy re-run; first-night ladder verify (fires 23:10); CV push→float→shim-drop; crush-daily fix→push→float; §18 sanity redesign; node-exporter journal rate; ~/tmp prepare (owner-gated); wevisone ruling (owner); QLC baseline watch; D6 boot proof; §11 FOD widening; float-register build leg; btrbk-forgejo stray heal; failed-units batch triage; daemon-git-death watch.

NEW:
1. [ready] Decompose `/var/lib/monitor365-server` 110 G (du 2 days ago was 39 G): DB vs WAL vs CHECKPOINT/reflink backup chain vs corpses; separate apparent (du) from real (extents) — if the reflink backups dominate apparent, that's by design; if corpses, that's the old partial-backup class again.
2. [ready] Measure `~/.cache` and `~/tmp` for real (background per-child throttled walk) — close the root-ledger holes.
3. [ready] Delete test-residue subvols `.rescue/zz-test-delete` + `zz-test-snap` (owner-visibility trivial) and the empty `@home` (ID 257; 10-26 already named it).
4. [decision] Throttled-ledger tooling: per-child du budgets in a `scripts/` helper vs a periodic storage-collector surface (pick one; the session-walk class dies either way).

## g) QUESTIONS FOR THE OWNER (cannot be figured out from here — carried, still unanswered)

1. **Push permission** for CV (`de9821878`) + crush-daily (vendored tone) — the only thing holding both rollback shims in place.
2. **Reboot window** for the D6 boot proof (~15 min with you present — the cutover's last untested path).
3. **wevisone-spike** (14 G bare venv): trash or keep — 14 G of nightly pool sends until ruled.

---

**Waiting for instructions.** Next system event regardless: the 23:10 btrbk ladder (root / projects / forgejo — the forgejo leg needs its heal row done first to go green).
