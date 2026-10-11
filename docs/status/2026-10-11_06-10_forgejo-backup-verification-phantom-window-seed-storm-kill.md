# forgejo backup verification: 0B-snapshot phantom window explained; first real seed storm-killed by guard trip #2663

Date: 2026-10-11 05:10–06:10 CEST. Trigger: owner pasted the pool target listing (25× `[error opening dir]`) plus `btrfs filesystem du -s` reading 0.00B on every `forgejo.*` snapshot, asking "does this look good?". Continuation of the G1 window close-out (`2026-10-11_02-17_*`, `2026-10-11_05-05_*`).

## a) FULLY DONE

1. **0B verdict — NOT corruption:** all 25 pool snapshots (10-01..10-10) are received snapshots of the then-EMPTY `hot/forgejo` subvol (the pre-finalize window; the family condition-skipped = designed DOWN state, real data safe on the QLC `forgejo.qlc-pre-subvol`). `[error opening dir]` = root-owned 0700 subvol dirs vs a non-root tree walker (benign); the in-dir `git status` fatal is a category error (btrfs subvols are not a worktree). Confirms the TODO_LIST G1-gate-VOID row and its 03:46/04:18 premise updates.
2. **Seed attempt 1 root cause (journal-verified to the second):** local snapshot + incremental send (parent 10-10T2140) started 05:40:00; at 05:42:33 `memory-emergency-guard` Zone-6 trip #2663 (io PSI some avg60 43.34%, disk busy 100%, MemAvailable 59.5% — crash-#3 class) TERMed `btrbk-forgejo` mid-receive at 2m33s (16.9G read / 17G written of ~67G). NOT a timeout (`TimeoutStartSec=6h` in the live unit; no "timed out" line). Unit Failed + OnFailure paged. The ~17G partial pool target `forgejo.20261011T0540` self-heals (btrbk invalid-target delete on the next run / `btrbk-pool-clean`).
3. **Guard coverage verified — no module gap:** `btrbk-forgejo` is in BOTH the guard's ioChurnUnits (`memory-emergency-guard.nix:1047`) and the backup-class starvation/catch-up list (`:1080`) — the kill is the designed storm mitigation. Side observation: `backup_starved 0` — the leg "succeeded" 24× instantly on the empty subvol, so phantom successes also suppressed catch-up-slot eligibility.
4. **Freshness metric has TWO live phantom modes (both observed this session):** (a) received-subvol root mtime is INHERITED from the source subvol — pre-seed, the metric read `last_age 875656s` (~10.1 days) off the frozen empty-root mtime; (b) after the kill, the aborted receive bumped the received-root mtime to the kill moment → `forgejo_subvol_backup_fresh 1` on an INCOMPLETE receive. mtime-based freshness proves neither content nor completeness → feeds `docs/todo/services.md` content-sanity row (size/entry floor or receive-completeness detection).
5. **Live storm mapped:** oscillating Zone-6 storm — 3 trips in the hour (#2663 05:42:33, #2664 05:57:36, +1), dips to avg60 5.3% (05:47) and back to 44.75% (05:58); per-trip attribution system.slice +80GB / user.slice +20GB.

## b) PARTIALLY DONE

1. **Pool seed: LANDED (attempt 2, owner-manual).** Attempt 1 (05:40 timer) aborted by trip #2663 (see §a.2); re-arm never fired (`memory_emergency_guard_churn_rearms_total 0` EVER, incl. a 14-min sub-bar drain 05:43–05:57 where the flm-restore branch DID evaluate 05:52:38 — production-gate divergence, queued to stability.md; VM scenario 8a green). Owner-manual `systemctl start btrbk-forgejo` in the ~07:06 calm window succeeded: `forgejo.20261011T0706` received clean (incremental from 10-10T2140), **70.4G read / 70.6G written in 6m37s (~180 MB/s)**, du-verified **Total 70.41GiB** (≈ the 71.75G finalize measure). RESIDUAL: unit exit-10 because the killed attempt left a 17G STRAY partial (`forgejo.20261011T0540`, the `!!!` line) — btrbk never auto-deletes received subvols; cleanup is btrbk's own prescribed `btrbk clean` — until then every run exit-10s and pages OnFailure on a SUCCEEDED backup.
2. **Burn-in legs: 1/2 clean.** Application leg green (dump zip 03:43:03, 24.9G, unit Finished); subvol seed landed 07:13 (du 70.41GiB) — leg 2 = the next clean slot (13:40), a seconds-long incremental.

## c) NOT STARTED (owner)

1. After the seed lands: `sudo btrfs filesystem du -s /mnt/pool/backups/forgejo-subvol/$(ls -1 /mnt/pool/backups/forgejo-subvol | tail -1)` — expect **Total ≈67G** (Exclusive will read ≈67G too on the newest snapshot — received extents share with nothing else on the pool; the live subvol lives on the Samsung fs. CORRECTED 06:35: the earlier "Exclusive ≈0" guess was wrong — sharing only counts within the scanned pool fs). Live-confirmed baseline: the killed partial reads Total 17.00GiB / Exclusive 17.00GiB / Set shared 0 (owner du 06:2x — exactly the 05:42:33 SIGTERM point). That closes the content-floor assertion. **VERIFIED: seed LANDED 07:13 — forgejo.20261011T0706 du 70.41GiB Total; assertion CLOSED.**
2. Stray cleanup (the exit-10 + OnFailure noise source): `sudo btrbk -c /etc/btrbk/forgejo.conf clean /mnt/pool/backups/forgejo-subvol` then optional `sudo systemctl reset-failed btrbk-forgejo` — btrbk's own prescription from the 07:13 run summary.
3. Burn-in leg 2 = the next clean slot (13:40) → THEN `sudo trash /var/lib/forgejo.qlc-pre-subvol` (67G QLC reclaim; 02-17 §g.3 timing stands).
4. Optional manual seed in a calm window: `cat /proc/pressure/io` (some avg60 < 25) + `journalctl -t memory-emergency-guard-check --since '-15min'` clean, then `sudo systemctl start btrbk-forgejo`.
5. Dump-zip spot check: `sudo ls -la /mnt/pool/backups/forgejo | tail` (the 03:43 zip is forgejo-owned 0700 — not agent-readable).

## f) NEXT (self-harvested)

1. **[done]** Seed landing + content verification — CLOSED 07:13/08:35: attempt 2 landed (owner-manual), du 70.41GiB, services.md G1-evidence row updated to the landed state; residual = the stray-clean owner command (§c.2).
2. **[ready]** Guard churn re-arm never fired in production (counter 0 ever) while flm-restore evaluated on the same drain — root-cause the gate divergence. *(stability.md + TODO_LIST)*
3. **[ready]** Freshness-metric content floor now evidenced by two live failure modes. *(services.md content-sanity row updated)*
