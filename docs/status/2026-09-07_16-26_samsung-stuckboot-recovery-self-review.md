# Samsung flip live + stuck-boot recovery — honest self-review & full status (2026-09-07 16:25)

Session scope: the 02:11 stuck-boot diagnosis + recovery ONLY (per instruction:
no unrelated research). Basis: this session's run log, `dep*.log`, evidence dumps.

---

## a) FULLY DONE

1. **Stuck boot root-caused with hard evidence** (not theory): parallel 09-06
   deploys (QLC-side gens 762–775) advanced the loader default past the 09-05
   `--final` Samsung sync; flipped fstab mounts `/nix` from the Samsung → default
   entry's `init=` path never existed there → frozen pre-journald. Proven via:
   zero journal boots + zero wtmp entries in the hang window (pre-journald
   signature), `loader.conf` default = gen 775, per-entry `init=` existence
   audit vs the live store (14 MISSING, everything ≤761 OK), Samsung profile
   ending at `system-760`.
2. **Corrected the user's mental model**: the hand-picked "older derivation" is
   gen 761 = `p0ccbqj5` = the flip generation — the migration itself is LIVE and
   healthy since 14:10 (`findmnt /nix` → `nvme1n1p2[/nix]`).
3. **Immediate reboot-safety**: loader default hand-pointed at a store-verified
   entry (with backup `loader.conf.bak-stuckboot`), before any risky operation.
4. **nix-daemon stale-fetch cache healed** (`…storage-collector-prepared-source.drv
   is not valid`) via daemon restart — storage-collector FOD then built clean.
5. **Repo HEAD deployed onto the live Samsung store** — run 1 exit-4'd
   (inboxclean-sync failed during activation; nh skipped profile/bootloader);
   deploy.sh's anchoring warning caught it; run 2 (cached) completed: profile
   `system-761` → `zkaacn2a` (26.11.20260905.c043004), `/run/current-system`
   anchored, default entry `nixos-efc4051e…` init verified on the live store.
6. **All 14 dead boot entries pruned** (by `stc boot` itself during the good run;
   my explicit prune pass found removed=0 — belt already fastened).
7. **Post-state verified**: 0 failed units (all six pre-existing failures
   cleared), post-deploy smoke 95 PASS / 0 FAIL / SKIP 5 / WARN 2.
8. **Docs**: status report (`16-05` file), TODO_LIST Phase-1 rewrite, AGENTS.md
   gotcha (migration reboot-gate + boot-chain audit pattern) — daemon-committed
   `9d417fa5`.
9. **Cleanup**: stale `/mnt/samsung-nix` removed; entries backed up to
   `/root/stuckboot-entry-backup` before any pruning.

## b) PARTIALLY DONE

1. **Boot-chain verification is STATIC, not LIVE** — entry/default/profile/init
   all consistent on paper, but I never rebooted to prove the new default boots.
   The 09-05 near-miss taught exactly this lesson ("activation alone proved
   insufficient"); my static checks are much stronger but the confirming reboot
   is still outstanding (user's call — machine in use).
2. **deploy.sh exit-4 rescue** — detection + warning exists and worked twice
   (09-05 + today), but the FIX (assert profile advanced / auto `stc boot`
   repair) is still unwritten; I manually re-ran the deploy instead.
3. **Samsung monitoring** — smartd already watches it (by-id self-test logged
   09-06), but btrfs-health metrics + Gatus mount/space checks are absent.
4. **Smoke WARN/SKIP triage** — classified the 2 WARNs as known-benign
   (InboxClean `auth_expired`, quickshell 1 error line) without deep dives; the
   5 SKIPs were never enumerated.

## c) NOT STARTED (carried, per TODO_LIST)

- 3-day soak (~09-10) → attic store-rebuild verification → delete QLC `@nix`
- exec-latency-under-buildstorm acceptance + fio/cold-cache spot benchmarks
- `checks.mail-relay` VM regression (still forces `--no-verify` on docs commits)
- deploy.sh migration-window guard; `system_current_system_profiled` wiring
- phantom io PSI root cause; llama-rag restart leak; Phase 2 hot DBs

## d) TOTALLY FUCKED UP (session-local, honest)

1. **First privileged evidence script ran UNPRIVILEGED** — I forgot `exec sudo
   bash` inside the runner; wasted a round trip and produced misleading
   "Permission denied / MISSING" output I had to mentally discard.
2. **Accepted deploy.sh's "known-benign" classification of run-3's flake-check
   failure without independent verification** — run 3's `nix flake check
   --no-build` still showed a `path is not valid`-class error (I never pinned
   down WHICH path after the daemon restart). The toplevel eval + smoke passing
   makes it very likely benign, but that's the "trust the gate" pattern AGENTS
   explicitly warns about. `nix flake check` may STILL be red → pre-commit/CI
   health unverified.
3. **Chased the "Samsung NVMe warm-reboot enumeration" theory** for two
   evidence rounds before the loader-entries audit killed it. Cheap here, but
   the discipline is: enumerate boot entries vs store FIRST for any
   post-store-move boot failure.
4. **Did not prominently tell the user "the next reboot is the real test"** —
   buried in the follow-up list instead of leading with it.
5. **Stray artifacts left**: `loader.conf.bak-stuckboot` on the ESP (kept
   deliberately until a confirming reboot — but undocumented in TODO) and
   `/root/stuckboot-entry-backup` (documented only in this report's predecessor).
6. **pstore audit was theater** — hard power cuts leave no EFI dump; I knew
   `pstore.max_reason=3` excludes it mid-investigation and checked anyway.

## e) WHAT WE SHOULD IMPROVE (process, this session)

1. **Store-migration windows must gate deploys** — the 09-05 sync was
   invalidated 18 h later by routine parallel deploys. Either deploy.sh
   hard-fails while a migration flag exists, or the final sync auto-runs
   post-deploy until the reboot completes. This is the SECOND self-inflicted
   near-miss in this migration (first: exit-4 no-generation; this: stale sync).
2. **A boot-chain lint belongs in the repo**: audit every systemd-boot entry's
   `init=` against the live store at eval/deploy time (`scripts/audit-boot-entries.sh`
   or a flake check) — today's diagnosis took 6 evidence rounds; the check is
   10 lines of shell.
3. **Recovery-run discipline**: "deploy again after exit-4" worked, but it is
   folklore; encode it (deploy.sh auto-retry once when the only cause is
   failed-at-activation units + profile didn't advance).
4. **Smoke SKIP/WARN items should be enumerated in the summary line**, not just
   counted — "SKIP: 5" with names would have forced triage.
5. **Confirming-reboot is part of migration completion** — define it as a
   checklist item with a smoke (the machine self-verifies via
   `system_current_system_profiled` + post-deploy-check after boot).

## f) NEXT — up to 50 things

**Boot/migration closure**

1. Confirming reboot (user) — then remove `loader.conf.bak-stuckboot` from ESP
2. Verify `system_current_system_profiled` green after that reboot
3. `scripts/audit-boot-entries.sh` — per-entry init-exists-on-live-store guard (pre-deploy + flake check)
4. deploy.sh: post-switch assertion that the numbered profile advanced (exit-4 rescue)
5. Wire `system_current_system_profiled` into post-deploy-check as a hard fail
6. deploy.sh migration-window guard (or auto final-sync post-deploy until reboot)
7. auto-retry-once logic for exit-4-with-failed-units in deploy.sh
8. Delete `/root/stuckboot-entry-backup` after soak
9. Update the plan doc (`2026-08-31_samsung-role-assignment…`) with the incident + Phase-2 readiness
10. Gen-number collision note (Samsung 761 ≠ QLC 761) → boot-menu/rollback docs

**Samsung monitoring + storage**
11. Samsung → btrfs-health metrics (scrub, space, csum, chunk health)
12. Samsung → Gatus checks (mounted, usage %, scrub error-free)
13. Verify smartd coverage is complete for nvme1 (self-test seen; error-log/attr alerts?)
14. Verify fstrim covers nvme1n1p2 (mounts carry `nodiscard` — TRIM must come from the timer)
15. tlc usage-growth watch (first weeks; store writes all land there now)
16. 3-day soak → attic store-rebuild story verified → delete QLC `@nix` (~129 G)
17. Attic substituter cold-start drill (rebuild one path from cache after @nix deletion)
18. fio/cold-cache spot benchmark on tlc vs the 620-IOPS QLC baseline
19. exec-latency-under-buildstorm acceptance test (the actual point of the migration)
20. `nix store verify` / DB health check on tlc after the first GC cycle
21. Confirm nix-gc timer healthy against the Samsung DB (next 00:00 run)
22. SAMSUNG-EFI 4 G partition: decide future boot-migration vs repurpose
23. Retire/mark `scripts/samsung-nix-sync.sh` obsolete (target mount gone — misuse hazard)
24. Re-check zram/PSI baseline now that /nix IO moved off the QLC

**Known-failure hygiene (all six cleared post-deploy — confirm stays green)**
25. Triage WHY inboxclean-sync failed during run-1 activation (transient vs config)
26. cv-scan failure cause (pre-deploy state)
27. btrfs-balance-data failure cause (chunk gate? gawk class recurred?)
28. blocklist-auto-update failure cause (HaGeZi mirror drift?)
29. nix-build-cleanup failure cause (CAP fix landed only in the new gen?)
30. Investigate the quickshell 1-error-line WARN
31. InboxClean OAuth runbook (`auth_expired` WARN — 7-day testing-mode bomb class?)
32. mail-relay go-live: verify `larsartmann.cloud` in Resend (pending user step since 09-06)

**Repo/CI health**
33. Pin down run-3's `nix flake check` failing path (`not valid` class) post-daemon-restart
34. Fix `checks.mail-relay` VM regression ("expected exactly 1 queued message, got 2")
35. CI dark-state check (`NIX_GITHUB_RO_TOKEN` secret still missing?)
36. Pre-commit no longer needs `--no-verify` for docs once 33+34 land

**Carried P0/P1 (context-noticed only)**
37. /data corruption: csum-error growth-rate discriminator (corrupt counter 4.2e9 seen in boot-0 kmsg)
38. btrbk-data EIO abort on the known inode — repair decision
39. Phantom io PSI root cause (corpse-inflated, survives reboots)
40. llama-rag restart-leak (TimeoutStopSec/kill-escalation; may ease post-migration)
41. Phase 2: hot DBs → nodatacow `hot` subvol (pocket-id, postgres, forgejo, docker data-root)
42. Pre-journald hang observability (netconsole/serial console, or pstore.max_reason bump)
43. Post-deploy smoke: enumerate SKIP units by name in the summary
44. niri eval-realization gotcha: confirm the fix rode today's deploy (it deployed clean — verify the guard)
45. dnsblockd restart-order fix (09-06): confirm browser-history gate green across a cold boot
46. Watch for exit-4 recurrence during soak deploys (manual re-run discipline until #4 lands)
47. Consider labeling boot menu entries (sort-key/title) for store-era clarity
48. `systemd-boot.configurationLimit` sanity (16 entries now — fine, revisit at 20+)
49. btrbk-root boot catch-up `--no-block` trigger (existing TODO item, unchanged)
50. Time-box a "parallel-session deploy ledger" — the 09-06 session never knew a migration window was open (process fix, cheap: a flag file deploy.sh reads)

## g) Questions I cannot answer myself

1. **When do you want the confirming reboot?** The chain is statically verified,
   but only a real reboot proves the new default boots — and until then
   `loader.conf.bak-stuckboot` stays as insurance. Your call on timing.
2. **Retro-approval of today's recovery actions** (hand-edit of `loader.conf`
   default, mid-day nix-daemon restart, deploy re-run after exit-4) — same class
   as the unanswered 09-05 question about the manual `nix-env --profile --set` /
   `stc boot` pattern. OK to keep as the standard recovery play?
3. **Should deploy.sh HARD-FAIL on exit-4** (no re-run, no activation-with-failed-
   units) until the profile-advance assertion lands — blocking every deploy on
   chronic unit failures — or keep warn + manual re-run? Policy decision; both
   defensible.
