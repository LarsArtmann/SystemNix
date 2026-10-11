# forgejo backup verification: 0B-snapshot phantom window explained; first real seed storm-killed by guard trip #2663

Date: 2026-10-11 05:10–06:10 CEST. Trigger: owner pasted the pool target listing (25× `[error opening dir]`) plus `btrfs filesystem du -s` reading 0.00B on every `forgejo.*` snapshot, asking "does this look good?". Continuation of the G1 window close-out (`2026-10-11_02-17_*`, `2026-10-11_05-05_*`).

## a) FULLY DONE

1. **0B verdict — NOT corruption:** all 25 pool snapshots (10-01..10-10) are received snapshots of the then-EMPTY `hot/forgejo` subvol (the pre-finalize window; the family condition-skipped = designed DOWN state, real data safe on the QLC `forgejo.qlc-pre-subvol`). `[error opening dir]` = root-owned 0700 subvol dirs vs a non-root tree walker (benign); the in-dir `git status` fatal is a category error (btrfs subvols are not a worktree). Confirms the TODO_LIST G1-gate-VOID row and its 03:46/04:18 premise updates.
2. **Seed attempt 1 root cause (journal-verified to the second):** local snapshot + incremental send (parent 10-10T2140) started 05:40:00; at 05:42:33 `memory-emergency-guard` Zone-6 trip #2663 (io PSI some avg60 43.34%, disk busy 100%, MemAvailable 59.5% — crash-#3 class) TERMed `btrbk-forgejo` mid-receive at 2m33s (16.9G read / 17G written of ~67G). NOT a timeout (`TimeoutStartSec=6h` in the live unit; no "timed out" line). Unit Failed + OnFailure paged. The ~17G partial pool target `forgejo.20261011T0540` self-heals (btrbk invalid-target delete on the next run / `btrbk-pool-clean`).
3. **Guard coverage verified — no module gap:** `btrbk-forgejo` is in BOTH the guard's ioChurnUnits (`memory-emergency-guard.nix:1047`) and the backup-class starvation/catch-up list (`:1080`) — the kill is the designed storm mitigation. Side observation: `backup_starved 0` — the leg "succeeded" 24× instantly on the empty subvol, so phantom successes also suppressed catch-up-slot eligibility.
4. **Freshness metric has TWO live phantom modes (both observed this session):** (a) received-subvol root mtime is INHERITED from the source subvol — pre-seed, the metric read `last_age 875656s` (~10.1 days) off the frozen empty-root mtime; (b) after the kill, the aborted receive bumped the received-root mtime to the kill moment → `forgejo_subvol_backup_fresh 1` on an INCOMPLETE receive. mtime-based freshness proves neither content nor completeness → feeds `docs/todo/services.md` content-sanity row (size/entry floor or receive-completeness detection).
5. **Live storm mapped:** oscillating Zone-6 storm — 3 trips in the hour (#2663 05:42:33, #2664 05:57:36, +1), dips to avg60 5.3% (05:47) and back to 44.75% (05:58); per-trip attribution system.slice +80GB / user.slice +20GB.

## b) PARTIALLY DONE

1. **Pool seed: NOT landed.** Designed convergence paths, in order: guard churn re-arm on sustained sub-bar drain → 13:40 timer slot (Persistent; `TimeoutStartSec=6h` provisions the ~10-min seed at ~110 MB/s) → post-6h-starvation catch-up slot (trip-protected). Watched through 06:06: **re-arm never fired — `memory_emergency_guard_churn_rearms_total 0` EVER**, including a 14-min sub-bar drain (05:43–05:57) during which the flm-restore branch DID evaluate (05:52:38 restore-capped line). Queued to stability.md — VM scenario 8a is green, so this is a production-gate divergence, not a missing feature.
2. **Burn-in legs: 0/2 clean.** Application leg green (dump zip 03:43:03, 24.9G, unit Finished); subvol seed pending a storm-free ~10-min window.

## c) NOT STARTED (owner)

1. After the seed lands: `sudo btrfs filesystem du -s /mnt/pool/backups/forgejo-subvol/$(ls -1 /mnt/pool/backups/forgejo-subvol | tail -1)` — expect **Total ≈67G** (Exclusive will read ≈67G too on the newest snapshot — received extents share with nothing else on the pool; the live subvol lives on the Samsung fs. CORRECTED 06:35: the earlier "Exclusive ≈0" guess was wrong — sharing only counts within the scanned pool fs). Live-confirmed baseline: the killed partial reads Total 17.00GiB / Exclusive 17.00GiB / Set shared 0 (owner du 06:2x — exactly the 05:42:33 SIGTERM point). That closes the content-floor assertion.
2. Burn-in leg 2 = the next clean slot → THEN `sudo trash /var/lib/forgejo.qlc-pre-subvol` (67G QLC reclaim; 02-17 §g.3 timing stands).
3. Optional manual seed in a calm window: `cat /proc/pressure/io` (some avg60 < 25) + `journalctl -t memory-emergency-guard-check --since '-15min'` clean, then `sudo systemctl start btrbk-forgejo`.
4. Dump-zip spot check: `sudo ls -la /mnt/pool/backups/forgejo | tail` (the 03:43 zip is forgejo-owned 0700 — not agent-readable).

## f) NEXT (self-harvested)

1. **[watch]** Seed landing + ~67G verification (re-arm or 13:40), then close the services.md G1-evidence row's seed clause. *(services.md:151 + TODO_LIST mirror updated with the abort state)*
2. **[ready]** Guard churn re-arm never fired in production (counter 0 ever) while flm-restore evaluated on the same drain — root-cause the gate divergence. *(stability.md + TODO_LIST)*
3. **[ready]** Freshness-metric content floor now evidenced by two live failure modes. *(services.md content-sanity row updated)*
