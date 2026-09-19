# Hermes Backup Leg Proven; Cache Migration Assessed — Session Status

**Date:** 2026-09-18 22:17 CEST
**Host:** evo-x2
**Session scope:** (1) feasibility assessment of moving `@cache-home` (`~/.cache`, 37G) to the Samsung hot disk; (2) at user direction, prerequisite first: prove the hermes backup leg (`@home-hermes` → `/mnt/pool/backups/root`), which had **zero pool receives since its 2026-09-15 creation**.
**Point-in-time report:** all figures verified live 2026-09-18 20:30–22:15; will age.

---

## TL;DR

The hermes dedicated-subvolume migration (2026-09-15) worked operationally (mount, service, local snapshots) but its **pool backup leg had never delivered a single receive** — two nightly sends were Zone-6 guard-killed during IO storms, each stop pushing the send +24h, and the verify gate correctly showed `FAIL: no received backups for prefix '@home-hermes'`. This session root-caused that, walked the user through a manual `btrbk run` (with one mid-receive Ctrl-C garble, healed by `btrbk clean`), and landed the leg end-to-end: **full Sep-16 send + incremental chain through Sep-18, verify gate green on both prefixes, zero failures.** The original `@cache-home` → Samsung migration was fully assessed and planned but deliberately NOT executed (prerequisite consumed the session). Data loss: **zero**. The one deletion (garbled `@.20260917T2300` pool-side copy) was verified junk — local source intact.

---

## Timeline (all 2026-09-18)

| Time        | Event                                                                                                                                                                                    |
| ----------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| ~17:30      | Cache migration feasibility research: `~/.cache` = **37G** (docs say ~16G — stale), QLC root 81% full, `/mnt/hot` 744G free; plan delivered, not executed                                |
| ~17:45      | User asked whether the hermes migration worked. Live checks: mount ✓, service ✓, local snapshots Sep 16+17 ✓, **pool receives: 0**, verify gate red since 2026-09-17 fix                 |
| 20:42:15    | User-run `sudo ionice -c 3 btrbk -c /etc/btrbk/root.conf run` — appeared "stuck" (btrbk is silent during send/receive)                                                                   |
| 20:42–20:50 | First transfer (@.20260915→.16 incremental) completed successfully (8m19s); journal sudo lines were the only progress signal                                                             |
| 21:01:14    | User Ctrl-C mid-second-transfer → **garbled `@.20260917T2300` left in pool** (receive creates the target subvol immediately; interrupt = incomplete data that blocks re-sending forever) |
| 21:16:17    | User-run `btrbk clean` deleted exactly the garbled subvol (output's `@.*` line is a config section header, not a glob — caused a user alarm, see §d)                                     |
| 21:24:32    | Re-run completed (**38m6s**): root chain caught up (.17 re-sent, .18 ×3) + **first hermes receives**: `***` full @home-hermes.20260916T2300 + incrementals .17/.2042/.2124               |
| 22:08:20    | `btrfs-verify-pool-backups` started manually: **OK `@` 0d, OK `@home-hermes` 0d, zero failures** (WARN `data` prefix = known /data EIO leg, decided stance)                              |
| 22:10       | AGENTS.md updated (first-receive milestone + btrbk silent-send gotcha)                                                                                                                   |

**Final state:** pool = 33 receives (was 26 incl. garble), 4 hermes. Local: retention pruned @.20260914T2300 (pool copy safe).

---

## a) FULLY DONE

1. **Cache migration feasibility assessment** — exact automount location (`snapshots.nix:25-45`), current size (37G vs documented 16G), top components (nix eval 8.7G, uv 3.1G, inboxclean 2.3G, qmd 2.2G, buildflow 2.2G, Helium 1.5G, + 4G `fio-eval-root.bin` benchmark junk), target disk shape (`by-label/tlc`, `/nix` subvol `nix` + `/mnt/hot` toplevel precedents), gotcha list (degraded-mode semantics change, HM symlinks into /mnt/buildcache survive, `commit=300` drop per TLC doctrine, snapshot-exclusion carries over trivially), ~41G QLC reclaim estimate. Delivered in-chat, not written to a doc.
2. **Hermes backup leg root-cause** — zero-receives explanation chain: 09-16 23:00 send Zone-6 guard-killed (trip #299 era) → garbled/no-target → `btrbk-pool-clean` heal came 23:50 but send had fired → +24h push → 09-17 send killed again pre-freeze-5. Verified the verify gate was no longer phantom (Sep 17 findmnt→`is-active` fix live: it correctly FAILs).
3. **First hermes pool receive landed** — full (non-incremental) Sep-16 send + 3 incrementals, uuid chain intact.
4. **Root backup chain un-stuck** — pool was stale at Sep 15; now complete through Sep 18 (three snapshots that day from the interrupted + clean runs).
5. **Garbled-target incident closed** — `btrbk clean` removed exactly the one incomplete subvol; verified local sources and remaining 25 receives untouched before re-run.
6. **Verify gate green end-to-end** — both prefixes OK at 0 days, unit exit clean, no OnFailure.
7. **Memory updates** — AGENTS.md subvolume-layout line (first-receive milestone + heal path) and Backup-tier bullet (btrbk silent-send behavior, journal as progress signal, Ctrl-C→clean heal recurrence).
8. **btrbk "stuck" false alarm diagnosed** — silent sends are normal; journal sudo lines + exit transaction summary are the real signals.

## b) PARTIALLY DONE

1. **`@cache-home` → Samsung migration** — planned in detail, zero execution steps. Deliberately gated behind the hermes prerequisite (user's call, correct order: the plan leaned on the house migrate-script pattern whose one open wrinkle was the unproven backup leg).
2. **High io-PSI mystery** — observed 42–56% avg60 across the evening with sparse actual disk IO in my (flawed, see §d) samples; never root-caused. Matters because Zone-6 guard trust (and tonight's autonomous send) ride on PSI semantics.
3. **Operational knowledge capture** — the btrbk gotchas landed in AGENTS.md (one line each); no proper runbook exists in `docs/services/` for manual btrbk operations (silent-send progress, clean heal, ionice tradeoff).

## c) NOT STARTED

1. `@cache-home` migration execution (subvol create → copy → config swap → deploy → old-subvol delete → ~41G freed).
2. `fio-eval-root.bin` trash (4G benchmark artifact inside `~/.cache`).
3. Doc size refresh: `snapshots.nix` comment + AGENTS.md cache paragraph still say "~16 GB" (actual 37G). Noticed, deliberately deferred to the migration change — still debt today.
4. First autonomous 23:00-cycle verification (tonight is the first storm-exposed run with the leg now proven).
5. Cache degraded-mode tripwire (if tlc mount fails, `~/.cache` silently rebuilds on QLC — planned system-health/Gatus line, not designed).
6. Hermes `search_files`/ripgrep failures (recurring in journal since Sep 1, predates the migration, unrelated to it) — upstream issue candidate, not investigated.

## d) TOTALLY FUCKED UP (honest)

1. **Set up the user for the "DELETE WHAT?!" scare.** I prescribed `btrbk clean` without pre-explaining its output shape (the `@.*` line reads like a wildcard deletion of all root backups; only `---` lines are deletions). The deletion itself was correct and necessary — the communication was not. Fix: always pre-explain destructive-looking output format before suggesting the tool.
2. **My silence handling caused the Ctrl-C.** I said "20-50 min, silent" but did not hand over a live progress command (`journalctl -f` showing the send/receive sudo lines) alongside the run. The user stared at a dead terminal ~19 min and interrupted mid-receive — the exact failure mode the runbook warns about. The garble was cleanly healable (zero loss), but the incident was preventable.
3. **Sloppy "phantom PSI" claim.** My 20:49 diskstats sample used a regex starting at `sd[b-e]` — it **missed sda** (a pool member after today's post-freeze letter shuffle) and briefly led me to call real receive IO "phantom". Caught it one step later via lsblk/by-id; conclusion corrected before any action was taken on it. Lesson already in AGENTS.md (never trust kernel sd-letters) — I half-followed it myself.
4. **Flailed on the first "stuck" diagnosis** — `pgrep btrbk` missed the `btrfs send|receive` children; I hypothesized ioctl-wedge/stale-lock before checking the journal, which had the answer in one grep. Journal-first would have cost one command instead of four.

## e) WHAT WE SHOULD IMPROVE

1. **Always pair long-running commands with a live progress one-liner** (`journalctl -f --grep "btrfs (send|receive)"` class) at prescription time, not after the user asks if it's stuck.
2. **Journal-first diagnosis** for any systemd-managed tool (unit-managed CLI state is in the journal; process-tree guesses lose to it).
3. **Pre-explain destructive-looking tool output** (section headers vs action lines) before recommending the tool.
4. **Disk attribution discipline:** resolve pool members by-id before reading `/proc/diskstats` — post-crash reboots shuffle sd-letters (bit me within this very session).
5. **Estimate with checkpoints** ("transfer 1 of 6 lands every ~8 min") rather than a bare total — bare totals invite interrupts.
6. **Bias to the imperative:** when the user says "fix that" / "just run it", lead with the runnable command and compress the analysis.

## f) NEXT (up to 50, prioritized; all traceable to this session's observations)

**Cache migration program (the standing ask):**

1. GO/NO-GO + window for the `@cache-home` → Samsung execution (needs a quiet window; ends in a deploy).
2. Confirm `fio-eval-root.bin` is user-trashable, then trash (4G).
3. Write `scripts/migrate-cache-subvol.sh` per house pattern BEFORE the window (create `cache-home` subvol on tlc toplevel, copy, verify).
4. `rsync -aHAX ~/.cache/ /mnt/hot/cache-home/` under heavy-job at the quiet moment (exclude nothing else; HM symlinks into /mnt/buildcache ride along).
5. Retarget `cacheFileSystems` in `snapshots.nix`: `device = /dev/disk/by-label/tlc`, `subvol=cache-home`, keep noauto+automount+idle-timeout, add `nofail`, **drop `commit=300`** (TLC doctrine), keep `compress=zstd noatime nodiscard space_cache=v2`.
6. Rewrite the `snapshots.nix` why-comment (size figure + the "revisit only if off-NVMe home exists" note — that condition is now met).
7. Deploy at the quiet window (stc swaps the automount; browsers hold open cache fds — best idle).
8. Post-swap verification: nix eval cache hit, gopls, browser warm start.
9. After a soak: `btrfs subvolume delete /mnt/btrfs-root/@cache-home` → ~41G freed on the 81%-full QLC root.
10. Update AGENTS.md subvolume-layout cache paragraph (37G figure dies with the move; new home on tlc).
11. Degraded-mode tripwire: system-health line or Gatus check for "cache on hot disk" (silent QLC-rebuild detection).
12. CHANGELOG entry for the migration.
13. Re-check QLC root % after reclaim; update any planning docs that assumed ~16G.
14. Decide folding into the future `services.hot-db` Phase-2 module vs standalone (the @cache-home mount is HM/user-scope, the module is service-scope — likely standalone, document the boundary).

**Backup-leg hardening (this session's aftermath):**
15. Verify tonight's 23:00 autonomous `btrbk-root` run (first storm-exposed cycle with the proven leg).
16. Watch the Zone-6 interplay: today's elevated PSI vs the guard's disk-corroboration requirement — confirm phantom-PSI alone doesn't kill the send.
17. Verify hermes local-snapshot retention pruning (volume-level 2d / 3d 1w) actually prunes hermes snaps.
18. Verify pool-side hermes retention (7d min / 14d 4w) at the first 7d boundary (~Sep 23).
19. Root-cause the unknown io-PSI driver (45-56% avg60 with sparse disk activity) — or instrument it (PSI + real-disk-busy composite metric in system-health).
20. Decide storm-resilience design: second-chance btrbk send window (e.g. 03:00 retry) vs current +24h-push doctrine — needs an owner call.
21. Write the btrbk ops runbook (`docs/services/` or append to hermes.md): silent sends, journal progress, clean-heal, manual-run ionice tradeoff.
22. Document the monitoring split: dump-style backups ride backup-coordination; subvol-send freshness rides `btrfs-verify-pool-backups` prefixes (hermes is the second prefix user).
23. /data EIO inode repair (standing `data` WARN; decided stance is keep-failing-until-repair — the only leg left red by choice).
24. Check `/var/lib/memory-emergency-guard` churn-stopped state for stale pre-freeze-5 entries (boot-surviving state file hygiene).
25. Confirm btrbk systemd units' IO class (did the units already run idle-class, or was tonight's manual `ionice -c 3` a policy the units lack?).
26. Baseline hermes workspace size (post-first-send) for retention/transfer-time forecasting.
27. Note the `T2124_1` same-minute collision naming is handled correctly by gate freshness parsing (verified today) — no action, recorded.

**Hermes follow-ups noticed:**
28. Investigate the recurring `search_files failed ... ripgrep` errors (since Sep 1; reproduce, then verify-before-filing if upstream-worthy).
29. Update `docs/services/hermes.md` with the backup-leg-proven milestone + manual-restore pointer (receives are plain btrfs send/receive round-trips).
30. Consider a restore drill: receive one `@home-hermes.*` snapshot into a scratch subvol and diff against live (untested restore path is not a backup).

**Session-process (mine):**
31. Codify items e1–e6 into my standing practice (progress-命令 pairing, journal-first, output-format pre-explanation).
32. When prescribing ops the user will run: include expected duration + "silent is normal" + the interrupt-safety note in ONE message.

_(stopped at 32 — the remainder would be filler; the honest list is these.)_

## g) Questions for the user (only you can answer)

1. **Cache migration GO/timing:** shall I execute the `@cache-home` → Samsung move, and in which window (it ends in a deploy; quiet moment needed)? Also: standalone now, or fold into the eventual `services.hot-db` Phase-2 module?
2. **Storm-resilience preference:** accept the +24h-push doctrine for guard-killed sends, or do you want a designed second-chance send window (e.g. nightly 03:00 retry)?
3. **`fio-eval-root.bin` (4G, inside `~/.cache`):** yours? Safe to trash during the migration prep?

---

## Evidence appendix (commands used, all verified live)

- `ls /mnt/btrfs-root/.snapshots/` — local snapshots incl. `@home-hermes.20260916/17/18`
- `ls /mnt/pool/backups/root/` — 26→25 (post-clean) → 33 (post-run), 4 hermes
- `journalctl -u btrfs-verify-pool-backups --since 22:00` — OK `@` 0d, OK `@home-hermes` 0d, WARN `data`, 0 failures
- `journalctl --since 20:40 --grep "btrfs send|receive"` — transfer starts/successes with timestamps
- btrbk exit transaction summary (user paste, 38m6s run) — `***` full hermes + `>>>` incrementals
- `sudo btrbk -c /etc/btrbk/root.conf clean` output — exactly one `---` deletion
- `du -sh /home/lars/.cache` — 37G; per-dir breakdown; `df` — QLC 81%, `/mnt/hot` 19%
- AGENTS.md edits: subvolume-layout line, Backup-tier bullet
