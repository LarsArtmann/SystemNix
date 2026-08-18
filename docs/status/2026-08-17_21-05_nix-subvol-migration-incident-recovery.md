# Status: @nix Subvolume Migration — Incident, Recovery & Pending Pivot

**Date:** 2026-08-17 21:05 CEST
**Scope:** This session only — `/nix` subvolume migration, the empty-`@nix` shadow incident, live recovery, and disk-space triage.
**System state at report time:** Booted gen 678-era system (safe fstab), `/nix` served from old `@/nix` dir (78,903 store paths), `@nix` subvol populated with store+var, **pivot NOT yet executed**.

---

## Timeline (what happened)

1. **~15:20** — Added `"/nix"` `subvol=@nix` entry to `hardware-configuration.nix`; wrote `scripts/migrate-nix-subvol.sh` (v1, with a fatal bug: `rsync --reflink=always` — no such flag in rsync 3.4.4).
2. **~16:31** — TWO racing deploys (parallel `nh os switch`) activated a system whose fstab mounted `@nix` — **before** the migration script had copied anything (rsync had died instantly on the bad flag).
3. **16:35+** — `@nix` (EMPTY) mounted over `/nix`. Every binary on the system broke (all live under `/nix/store`): no sudo, no systemctl, no login shells, no TTY gettys, fish prompt broken (starship gone). **Nothing was lost** — real store intact at `/mnt/btrfs-root/@/nix`; all running processes kept running (this SSH session survived).
4. **16:35–19:00** — Live recovery campaign (me): docker CLI executed via explicit-loader trick (`ld.so --library-path` + intact store paths); docker root-escape blocked (daemon fork/execs shim from shadowed store; host-writes confined to world-writable paths); polkit/run0 auth dead (no agent reachable — desktop session later found dead too); nix-daemon repair dead (`trusted-users = root`); unit-drop via docker cp into `/run/systemd/system` blocked (dockerd unprivileged on root-owned paths).
5. **~19:00** — User power-button clean shutdown (systemd PID 1 alive), rebooted via systemd-boot into **Generation 678** (verified safe fstab pre-boot). System fully back.
6. **~19:30–20:00** — User manually ran `sudo cp -a --reflink=always @/nix/store → @nix/store` (succeeded; 78,826 entries at that moment).
7. **~20:00** — I built the new closure from the repo: `0vrbv90q...-nixos-system` (10 derivations, cached) — lands in the OLD store, hence delta sync required before pivot.
8. **~20:30** — Disk triage: NVMe 96-97% data + 98% metadata. Freed `/btrfs-emergency-reserve` (+10 G). Deleted local snapshot 0812 (pool-verified). Discovered **corrupt partial `@.20260814T2300` on the pool** (btrbk-root 6h timeout killed receive mid-stream 04:31) — 0815/0816 never sent. Journal confirms.
9. **~21:00** — User copied `var` via cp. My `store` delta cp suggestion was replaced by rsync delta (cp has no delta mode; re-churns 79k dirs × millions of files). `--delete` dropped from the command after user challenge (correct call — nix GC tonight does authoritative cleanup).

---

## a) FULLY DONE

- **Config**: `fileSystems."/nix"` entry (`subvol=@nix`, same opts as `/`) in `hardware-configuration.nix` — eval-verified.
- **Migration script v2**: `scripts/migrate-nix-subvol.sh` rewritten — `cp -a --reflink=always` (correct FICLONE usage), refuses to run while `/nix` shadowed, wipes partial staging, incident header documenting the mount-before-copy trap. **Untracked-by-git status: committed in e5edf0bd/25790607 era? NO — needs verify; script was rewritten this session.**
- **AGENTS.md**: `/nix` bullet updated (was already partially done pre-session; now describes migrated state + script + `/home`-stays-in-`@` rationale). NOTE: AGENTS.md bullet claims migration as done — **it is not; pivot pending**. Doc is ahead of reality.
- **New system closure built**: `0vrbv90qhi69hla95sps2w4f9ikj9ay6-nixos-system-evo-x2-26.11.20260816.e5bdc4a` at `/tmp/nixfix/toplevel` (symlink).
- **@nix populated**: store (user's reflink cp + my earlier partial) + var (user's cp).
- **Recovery knowledge encoded**: wrapper binaries die with the store; loader trick works; dockerd confined to world-writable host paths; run0 needs TTY+agent; `sysrq=1` enabled; power button = clean ACPI shutdown path; pool corrupt-snapshot diagnosis.
- **Snapshot 0812 local deletion** (pool-verified first) + **emergency reserve deletion** (+10 G).

## b) PARTIALLY DONE

- **Store delta sync**: NOT yet run — 77 paths (new closure + 16:3x racing builds) exist only in old store. Command ready (rsync -aH, no --delete).
- **Pool backup catch-up**: corrupt `@.20260814T2300` on pool NOT yet deleted; btrbk-root catch-up NOT yet started; local 0813/0815/0816 must survive until sent.
- **Disk space**: 28.6 G free (was 18.8). Metadata still 96.8% — real relief comes from deleting local snapshots AFTER pool catch-up.

## c) NOT STARTED

- **The pivot** (5-command block): daemon stop → rsync store delta → rsync var (re-sync, daemon-stopped consistency) → `switch-to-configuration switch` → daemon start.
- **Post-pivot deploy** (`nix run .#deploy`) to mint proper gen 683 + boot entry + profile.
- **Old `@/nix` dir deletion** (after days of stable boots — frees only metadata; extents stay reflink-shared with `@nix`).
- **Emergency reserve re-provisioning** (`systemctl start btrfs-emergency-reserve` — NOT auto-recreated after deletion, per AGENTS.md).
- **btrbk timeout fix**: `btrbk-root` needs `TimeoutStartSec` raised (seed sized; catch-up sends of 0814-0816 could hit the same 6h wall — though incrementals should be ≤1h each).
- **Pool-side 0812 protection**: it's the ONLY pool copy of that era (user said it's the one they care about) — 0813's pool copy is complete; chain parent intact.

## d) TOTALLY FUCKED UP (owned, with root causes)

1. **The incident itself — my rsync flag bug.** `--reflink=always` is cp syntax, not rsync (rsync gained `--reflink` never; coreutils owns FICLONE). Script v1 died instantly → deploy mounted EMPTY `@nix` over the store → total binary lossage on a running production box. Cost: ~2.5 h downtime of new-process capability, user had to physically reboot.
2. **Deploy-order trap not anticipated.** I added the fstab entry to the repo while deploys run continuously (PMA auto-commit daemon + user-initiated) — ANY deploy would mount `@nix`. The entry should have been staged in a branch/unpushed commit until the subvol was populated, or the script should have been run FIRST. I even answered "run script BEFORE deploy" when asked, but then built/deploy activity raced ahead anyway (two parallel deploys at 16:31 — load avg 129 at the time I checked "quiescence" and said CLEAR, which was also wrong: I saw no builds at that instant but missed the queue/second deploy).
3. **Recovery drift.** After docker-escape failed I burned cycles hunting `libsystemd-shared`/python/busctl/readlink lib-paths instead of immediately pivoting to the two guarantees: (a) power-button clean shutdown, (b) boot-menu generation select. User had to pull me back ("why did you not just try your docker workaround?").
4. **My delta-sync commands had source==destination** (identical `@/nix/store/` → `@/nix/store/` no-op) — user caught it ("Are you SURE these are the RIGHT commands?!"). Had they run it, silent no-op → pivot would have mounted `@nix` missing 77 paths → partial re-incident.
5. **Bad snapshot advice sequence.** I told the user to delete 0813/0815/0816 BEFORE checking whether they'd been sent to the pool. They hadn't (corrupt 0814 pool-side). Following my advice would have permanently lost 0815/0816 backup points AND broken the send chain (parent gone). Caught in time by the journal check when user asked why they weren't on the HDDs.
6. **ftrim answer was over-cautious mush** — right conclusion (skip it) but the reasoning mixed the immediate pivot question with general policy; could have been 3 lines.
7. **AGENTS.md/docs drift**: status doc claimed the migration "migrated 2026-08-17" as done before it was; auto-commit daemon committed docs describing a state that didn't exist yet (and hardware-configuration change possibly rode along in e5edf0bd). Living docs must not be written ahead of the change being live.

## e) WHAT WE SHOULD IMPROVE (systemic, from this session)

1. **Eval-time guard for empty-subvol mounts**: a NixOS assertion/activation check that a `subvol=@x` mount for `/nix` has non-empty `store/` at activation time (or switch-to-configuration pre-flight in deploy.sh). This class of incident is cheap to prevent, expensive to live through.
2. **deploy.sh pre-flight**: before `nh os switch`, diff current fstab subvols vs new; if a NEW subvol mount appears, verify the subvol exists AND is populated; abort with instructions otherwise.
3. **Script testing discipline**: I wrote a sudo-root migration script and let the user run it without a dry-run/shellcheck pass. The rsync flag error would have been caught by `shellcheck`-adjacent review or testing the copy line standalone first.
4. **Quiescence check = point-in-time lie**: `pgrep nix build` shows a snapshot; nh queues. Deploy-safety checks must look at nh/nix-daemon job state, not just running PIDs (or simply never race a migration with the PMA auto-deploy daemon — disable it during surgery).
5. **btrbk observability**: a 6h-timeout-killed receive left a corrupt subvol on the pool silently. Add a post-receive verification (btrfs subvolume show + du compare) or btrbk's own resume handling; alert on "aborted" lines (the OnFailure fired but nobody looked until 16h later).
6. **TimeoutStartSec sizing for seed-sized jobs**: the 6h timeout was tuned for one seed; catch-up runs of 3 snapshots could exceed it. Make it `infinity`-with-journal-heartbeat or sized per-job-class.
7. **Docs-before-reality anti-pattern**: status/AGENTS entries describing migrations should be written AFTER the pivot/verify step, or explicitly marked PENDING. The auto-commit daemon makes premature docs permanent.
8. **Recovery playbook**: the loader trick (`ld.so --library-path` + absolute store paths via `/mnt/btrfs-root/@/nix`) worked perfectly and is worth a gotcha entry — it's the universal "store is shadowed but disk is fine" tool. Ditto: power-button clean shutdown when binaries are gone.
9. **Single-path communication under stress**: user got 4 different one-liners across messages (some with typos — a missing space `--library-path"..."` in the run0 paste). Under incident conditions, emit ONE canonical command block per step, nothing inline-fragile.

## f) NEXT — up to 50 items, ordered

**Immediate (tonight, blocking):**
1. Delete corrupt pool subvol: `sudo btrfs subvolume delete /mnt/pool/backups/root/@.20260814T2300`
2. ~~Start pool catch-up: `sudo systemctl start btrbk-root.service` (sends 0814/0815/0816; monitor journal)~~ done (seeds completed; first overnight cycle green 2026-08-18)
3. ~~Run the 5-command pivot block (daemon stop → rsync store delta → rsync var → switch → daemon start)~~ done at `d4a59d4d`
4. ~~Verify pivot: `findmnt /nix` → `/@nix`; `ls /nix/store | wc -l` ≈ 78,903; `nix store verify --all --no-contents` spot check; `systemctl status nix-daemon`~~ done at `d4a59d4d`
5. ~~`nix run .#deploy` from repo → gen 683 + boot entry + profile (normal flow, now safe)~~ done (system-683 switched 2026-08-17; generations progressed to 690)
6. ~~Re-provision emergency reserve: `sudo systemctl start btrfs-emergency-reserve`~~ done (reserve file present, 10 GiB @ Aug 17 21:41)

**Short-term (tomorrow):**
7. After tonight's 23:00 snapshot lands: delete local 0814, 0813, 0815, 0816 (pool-verified)
8. ~~Confirm tonight's btrbk 0817 snapshot EXCLUDES @nix extents (first slim snapshot — the whole point)~~ done at `d4a59d4d`
9. `nix store gc` manual pass post-verify (zombie path sweep if any)
10. ~~Fix `btrbk-root` TimeoutStartSec for catch-up-class runs~~ done at `e5edf0bd`
11. Verify `fstrim` ran overnight (journalctl) — expect longer run (real deletions happened)
12. Re-check `btrfs filesystem usage` — target metadata < 90%
13. Check `system_gatus_meta_scrape_errors`/Gatus didn't fire phantom alerts during the outage window (16:35–19:00); annotate if so
14. Audit WHICH deploy raced (PMA auto-commit daemon? user?) — the hardware-configuration.nix edit went out with an auto-commit; confirm the daemon didn't ALSO deploy it independently
15. Mark `docs/planning/2026-08-17_rustfs-evaluation.md` untouched-by-me (it was in git status pre-session — not mine)

**This week:**
16. ~~After 2–3 stable boots: `sudo rm -rf /mnt/btrfs-root/@/nix` (old dir) — the 102 G unpinned-from-future-snapshots milestone~~ done (AGENTS.md: old @/nix deleted post-verification)
17. Add eval-time/activation guard for unpopulated subvol mounts (see e.1)
18. deploy.sh pre-flight subvol-population check (see e.2)
19. ~~btrbk post-receive verification + OnFailure alert routing to Discord (not just journal)~~ done at `184c6599`
20. Write gotcha entries: (a) loader trick, (b) power-button shutdown when binaries dead, (c) mount-new-subvol-before-populate incident, (d) docker cp host-write confinement, (e) run0 needs TTY+agent
21. ~~Reconcile AGENTS.md `/nix` bullet with ACTUAL state once pivot done (remove premature "migrated" claim if pivot slips)~~ done at `d4a59d4d`
22. ~~Verify pool-side 0812/0813 still intact post-catch-up (`btrfs subvolume show`, du spot-check)~~ done at `e5edf0bd`
23. ~~Cache-subvol reclaim batch (deferred): `@cargo/registry/src` (1.6 G), `@npm`, `@cache-home` — only if disk pressure persists~~ done at `71256d6f`
24. Old `/rust-cache` partition (98 GiB raw) deletion + root-partition grow (pre-existing TODO_LIST item)
25. Revisit `@home` subvol split (flat-layout recommendation from wikis, deferred at install)
26. ~~Balance check after deletions settle (`btrfs balance status`; the Monday 04:00 `-musage=50` will consolidate)~~ done at `d4a59d4d`
27. Consider `nix.settings.min-free` raise during migration windows (we run min-free 5 G; 97% full breached comfort)
28. ~~ZRAM fill + memory pressure sanity check post-incident (25 G peak RSS in btrbk runs per journal — heavy)~~ done at `8ffb2762`
29. Review the SECOND racing deploy's output (PID 2096307 built to completion — its closure may be a GC-able orphan; check `nix-store --gc --print-orphans` equivalent post-pivot)
30. Status-report self-review pass (docs/status/2026-08-17_16-33* was modified pre-session — not mine, leave alone)

**Later / backlog alignment:**
31. ~~Gatus check for "btrbk pool target freshness" (currently only root+data local freshness alert exists — extend to pool sends)~~ done at `e5edf0bd`
32. Docs: this incident deserves a `docs/gotchas-archive.md` full narrative entry (timestamps, PIDs, the shadow mechanics, recovery decision tree)
33. Test the systemd-boot generation-select procedure ONCE calmly (while system healthy) so it's muscle memory — document in gotchas
34. Pre-create a "surgery mode": `systemctl stop projects-management-automation` (or timer mask) before any filesystem surgery — the auto-deploy daemon is a live wire during migrations
35. `scripts/migrate-nix-subvol.sh`: add final self-verification (compare store path counts old vs new, diff var profiles) before printing "Done"
36. Consider making hardware-configuration changes require TWO-stage review (config branch + explicit populate step) — social/CI guard, even a reminder banner
37. The pool `btrbk-pool` instance (23:45) snapshotting pool-side `services/*` — verify unaffected by the corrupt-0814 dance
38. Pool-side retention: 0812 is 30d/12w-locked — if user cares about it specifically, note its expiry (mid-Sept) and consider a longer-tagged archive copy
39. `backup-coordination` registration: nothing new to register (no new backup dirs created this session), but VERIFY the module didn't alert on missing snapshots during the chaos
40. Kernel `sysrq=1` — consider tightening to a safer mask now that we know it's our last-resort reboot (mask 1 = all; 176 is the safer common set) — or leave as-is deliberately (homelab, single user)
41. Double-deploy prevention: nh lockfile/nix-daemon queueing means two simultaneous `nh os switch` can interleave builds — consider `flock` in deploy.sh around the whole build+switch
42. Document that `switch-to-configuration` on the NEW closure is the pivot mechanism deploy can't safely do pre-population — link from the migration script header
43. ~~Post-pivot: run `nix flake check --no-build` from repo to confirm no eval drift after the day's churn~~ done (full flake checks green in subsequent sessions)
44. Check Forgejo-runner/CI didn't fire builds into the broken window (16:35–19:00) — orphans/cache pollution possible
45. Monitor next 2-3 btrbk runs for correct parent selection post-snapshot-deletions (btrbk bookkeeping can re-seed if confused — watch for "resume" lines)
46. The `@.20260814T2300` corrupt copy taught: pool `TimeoutStartSec=6h` interacts with `x-systemd.device-timeout` on USB — document interplay in gotchas if it recurs
47. ~~User's `/mnt/@` manual mount evaporated mid-session (idle timeout) — standardize on `/mnt/btrfs-root` (automount-managed) in ALL docs/scripts (migration script already does)~~ done (AGENTS.md standardizes on /mnt/btrfs-root)
48. ~~Verify `home-manager-lars` activation ran clean on next deploy (the shadow window could have left stale HM state)~~ done (subsequent deploys activated HM clean)
49. If pivot goes smoothly: close out `docs/planning` migration notes; if it doesn't boot-menu rollback remains gens 678-682 — all verified SAFE fstab
50. Celebrate appropriately. The store survived a mount-over with zero data loss, reflinks made the whole recovery possible, and the pool had a verified-full copy before anything was deleted.

## g) Questions I cannot answer myself

1. **Should the PMA auto-commit/auto-deploy daemon be paused during the remaining surgery** (pool catch-up + pivot tonight), or do you want it live? It raced us once today; I can't tell if you consider it essential to leave running.
2. **Pool catch-up now vs. tonight's timer**: start `btrbk-root.service` manually now (~2–3 h USB transfer, IO contention during pivot prep) — or let tonight's 23:00 run handle it (pivot can proceed regardless; catch-up is independent)? Your IO-budget call.
3. **After pool catch-up: is losing local 0815/0816 acceptable** (pool will then have 0814 + 0817; the 0815/0816 home-state moments exist only locally until deleted)? Or do you want them sent first even though that extends the USB transfer? (Pool retention will eventually drop them anyway at 30d/12w.)
