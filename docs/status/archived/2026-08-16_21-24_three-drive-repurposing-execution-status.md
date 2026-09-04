# Three-Drive Repurposing — Execution Status (interrupted for status report)

**Date:** 2026-08-16 21:24 CEST
**Session:** "I give up, let's use these 3 drives effectively" → user-approved pivot from the abandoned media hunt
**Inputs:** `docs/planning/2026-08-16_20-22_three-drive-repurposing.md` (as committed), user's live decision overrides (see §d-6)

---

## a) Fully done

1. **Hunt closure, documented and pushed** (commit `0d310822`): H5 overclaim corrected in `2026-08-16_19-12_…final-verification.md` (live immich is 2026-only, NOT the Mac's server — origin unresolved), ENDGAME plan annotated ABANDONED-BEFORE-EXECUTION.
2. **Full drive inventory + SMART (read-only):** 2× Toshiba MG08ACA16TE 16 TB (sdb/sde) — **912 power-on hours, zero reallocated/pending/uncorrectable, PASSED** (near-new enterprise disks); WOOACME W3A894 512 GB (sdf) covered by the Aug-10 assessment (~14 TB TBW implied). Clone-manifest spot-check 10/10 OK (22,325 files). All /data forensic backups confirmed file-level.
3. **User architecture decisions captured** (question rounds): mirrored BTRFS pool (16 TB usable is enough) doubling as bulk service storage AND safety net **via btrfs send** (not borg); **sdf + both SanDisks untouched** ("do not touch them; yet"); immich + paperless data on pool; per-service independently snapshottable subvols; paperless behind SSO subdomain; own-tools (monitor365/DiscordSync/browser-history) migration deferred, subvols reserved.
4. **Pool built** (destructive step user-approved ×2, guarded): serial+mount verification → zap → `mkfs.btrfs -L pool -m raid1 -d raid1` (uuid `f981fc51-e1c2-419d-8c5f-e7b2a6f6c00f`, 2×14.55 TiB). Subvols created: `services/{immich,paperless,monitor365,discordsync,browser-history}`, `backups`, `archive/forensic-snapshots`, dir `archive/private-cloud-forensics`.
5. **Immich data migrated to pool with immich stopped:** rsync `-aHAX`, verified **byte-exact: 20,705 files / 17,241,720,562 bytes both sides**. Old copy intentionally intact at `/var/lib/immich` as rollback safety.
6. **Config edits applied (uncommitted in working tree):** `lib/ports.nix` `paperless = 2892` (no collision); `hardware-configuration.nix` `/mnt/pool` fstab (by-id member, btrfs, `noatime,nofail,compress=zstd,commit=300`, comment with both serials); `immich.nix` `mediaLocation = "/mnt/pool/services/immich"` + `RequiresMountsFor` on server + ML units.

## b) Partially done

_2026-08-17: all resolved by the 00-59 continuation session — b.1 (forensics fully relocated, verified), b.2 (all Phase-2 config deployed), b.3 (plan amendment done by docs-health)._
## c) Not started

_All items in this section were completed by the 00-59 continuation session (paperless module+secret+enable, btrbk safety net, smartd, Caddy/Homepage/Gatus, backup-coordination, deploy, verification, old-immich removal, docs) — see the Resolution appendix._

## d) Fucked up / went wrong

1. **Concurrent-session collision (top risk):** the working tree contains foreign uncommitted edits I did not make — `flake.nix`, `modules/nixos/services/gatus-config.nix`, `scripts/post-deploy-check.sh`, `CHANGELOG.md`, `TODO_LIST.md`, and new doc `docs/status/2026-08-16_20-41_sdf-unmount-m1-final-state.md` (someone executed my "M1 sdf-unmount" task at 20:41). Additionally `/mnt/pool` is currently mounted with systemd fstab semantics (`x-systemd.automount`, `compress=zstd:3`) that match neither my manual mount nor my uncommitted fstab edit → **a deploy appears to have run in the last ~30 min from a mixed tree.** I touched none of their changes; reconciliation required before any further deploy.
2. **Immich is DOWN right now** (`inactive` since ~21:00): stopped for the migration; new config not deployed; not restarted. User-facing outage.
3. `build-pool.sh` died silently **twice** before any destructive step: (1) `sudo: sgdisk: command not found` under `set -e`; (2) `pipefail` + unmatched store glob inside `$(ls …)` → nonzero substitution → `set -e` exit with zero output. Cost 3 tool rounds; fixed with `{ ls … || true; } | head -1`.
4. `rsync --info=progress2` spam made tool output nearly unreadable (verification lines survived only via grep).
5. Root fs now **93% (52 G free)** — the promised 17 G relief from removing the old immich copy is not yet realized; /data still 85% until the forensics move completes.
6. **Plan doc committed+pushed before the user's decision changes** — public doc says "borg + sdf offsite vault"; actual direction is "btrfs send, sdf untouched". Misleading until amended (was on my todo when interrupted).

## e) What to improve

- **Ops-script discipline:** `command -v` / `shopt -s nullglob` in destructive scripts; never trust `$(ls glob…)` under `pipefail`; echo-mode dry-run before destructive sections.
- **Session coordination:** with the auto-commit daemon AND at least one other session active, run `git status` + recent-file mtime check before EVERY edit batch (I skipped this mid-session and got colliding edits).
- **rsync in tool-run scripts:** `--info=stats2`, never `progress2`.
- **Minimize service downtime:** after a verified byte-exact rsync I could have restarted immich on the old config immediately; instead it sits down pending deploy.

## f) Next items (grouped, with rough estimates)

**Immediate stabilization**
1. ~~Check forensics-move job completion; verify all 4 dirs relocated + /data freed (2 min)~~ done — verified in the 00-59 continuation (§a.2: all 4 dirs, count+size verified, /data 85%→82%)
2. ~~Reconcile foreign edits: read `flake.nix`, `gatus-config.nix`, `post-deploy-check.sh`, the 20-41 status doc; keep intentional work, merge with mine (15 min)~~ done — the 00-59 session resolved all 3 open questions autonomously (§a.1)
3. ~~Identify the live generation + why immich is inactive (10 min)~~ done — deployed generation verified to predate the config edits; went straight to pool deploy
4. ~~Restore immich (restart on old generation or complete the deploy) (10–90 min)~~ done — immich serves from `/mnt/pool/services/immich`, byte-exact verified (00-59 §a.3)
5. ~~Amend the repurposing plan with the decision record (10 min)~~ done 2026-08-17 (docs-health: plan annotated + archived)

**Finish Phase 2 config**
6. ~~`paperless.nix` module (30 min)~~ done — deployed live end-to-end (00-59 §a.4); one wasted deploy cycle from the untracked-module trap (§d.1)
7. ~~sops secret `paperless_admin_password` + `sops.nix` declaration (15 min)~~ done
8. ~~configuration.nix: paperless enable + smartd MG08 entries (10 min)~~ done (smartd runtime verification still open — TODO_LIST)
9. ~~snapshots.nix: btrbk-pool instance + send/receive targets on root/data instances~~ done — exactly as specced (00-59 §a.5); `btrfs-verify-pool-backups` seed-race false-positive noted (§d.4)
10. ~~Caddy protectedVHost paperless (5 min)~~ done
11. ~~Homepage tile + dns-local subdomain (10 min)~~ done
12. ~~Gatus: paperless health + pool-mounted check (30 min)~~ done
13. ~~backup-coordination: immich entry → `${mediaLocation}/database-backup` (5 min)~~ done (00-59 §a.6: entries updated for all)

**Verify + deploy**
14. ~~`nix flake check --no-build` (5 min)~~ done
15. ~~`nix eval` toplevel (5 min)~~ done
16. ~~`nix run .#deploy` (30–60 min)~~ done — four deploys, 44–45 PASS / 0 FAIL each (00-59 §a.8)
17. ~~Post-deploy verify: pool mounted via by-id fstab, immich active with 20,705 files, paperless login 200 on LAN, Gatus green (20 min)~~ done (00-59: integrity re-confirmed at deploy time; paperless pipeline proven live)
18. ~~Run btrbk-pool once manually; validate snapshots exist (10 min)~~ done (btrbk-pool live at 23:45)
19. ~~Seed btrbk root/data sends (manual start or let tonight's 23:00/23:30 timers; ~3 h background) (5 min)~~ done — seeds ran (424G received at 00-59 write time; monitoring TODO_LIST)
20. ~~`post-deploy-check` run (10 min)~~ done (×4)

**Cleanup + docs**
21. ~~After verified deploy: trash old `/var/lib/immich` (frees 17 G) (10 min)~~ done — removed after service-active + API-ping pre-checks (00-59 §a.3)
22. ~~AGENTS.md storage section (20 min)~~ done 2026-08-17 (docs-health: "HDD Backup Pool & DAS Topology")
23. ~~TODO_LIST: own-tools→pool migration entries (10 min)~~ done 2026-08-17 (docs-health)
24. ~~CHANGELOG entry (10 min)~~ done 2026-08-17 (docs-health)
25. ~~Commit + push everything (10 min)~~ done — auto-commit `26beaf0c` + concurrent-session commits
26. Retire stale ZFS-VM scripts/workflow remnants (15 min). ← open — TODO_LIST Priority 3
27. ~~Reconcile sdf mount state with the 20-41 M1 doc (10 min)~~ done — sdf unmounted, frozen by user decision (AGENTS.md drive-freeze note)

**Hardening / follow-up**
28. hd-idle spin-down policy for MG08s (optional) (30 min). ← open — optional, TODO_LIST
29. Pool usage metric + Gatus >80% alert (30 min). ← open — TODO_LIST Priority 3
30. Document paperless admin-password location + consumption workflow (15 min). ← done in AGENTS.md storage section 2026-08-17
31. Decide on excluding re-downloadable subtrees (models, SteamLibrary) from btrbk sends (30 min). ← open (user decision, untracked)
32. Offsite leg: user states everything important already lives in Google Photos/Drive — decide whether 3-2-1 is satisfied or the sdf vault returns later (decision, no work). ← open — TODO_LIST P0 off-site decision
33. Check tomorrow: first nightly btrbk send completed (journalctl) (10 min). ← open — TODO_LIST (seeds/verify-cycle monitoring)
34. Boot-resilience test: pool absent (DAS off) → services fail gracefully, boot not hung (30 min). ← open — TODO_LIST Priority 2
35. smartd alert path verification for the MG08s (10 min). ← open — TODO_LIST Priority 2
36. Paperless exporter (`services.paperless.exporter`) + backup-coordination entry (20 min). ← done — exporter on, pool-side via dataDir (00-59 §a.4/b)
37. ~~Update `deploy.sh` provisioner-restart list if paperless grows one (10 min)~~ not needed — paperless needs no provisioner oneshot

## g) Questions (max 3)

_All three answered by the 00-59 continuation session: (1) foreign edits treated as intentional and built upon; (2) immich brought up directly on the pool (deploy-first chosen); (3) paperless admin password generated randomly into sops (handover pending — TODO_LIST Priority 2)._

---

## Resolution (2026-08-17, docs-health pass)

This interrupted-execution snapshot is fully superseded by `docs/status/2026-08-17_00-59_pool-backups-completion-status.md` (the resumed session completed Phase 2, all deploys verified 44–45 PASS, forensic move verified, immich byte-exact on the pool, paperless live). Docs follow-ups (plan amendment, AGENTS.md storage section, TODO_LIST, CHANGELOG) completed by the 2026-08-17 docs-health pass. Remaining open work (ZFS-VM script retirement, pool-usage alert, boot-resilience test, smartd runtime verification, hd-idle, off-site decision) lives in TODO_LIST. Archived as resolution-complete.
