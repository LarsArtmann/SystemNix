# Session status: DAS pool replug self-heal + SSD-2 filesystem research

_Date: 2026-08-31 23:05. Session window: ~19:00–23:05. Author: Crush (glm-5.3-flash)._
_Commits (auto-daemon): `03f158fb`, `2f84bd47`, `545a102b` + staged fix round awaiting daemon._
_Context: PSI io some avg10 sat at ~70% nearly the whole session (parallel docs-health session + btrbk catch-up + flm v1.0.2 resident). One crush-adjacent storm, no freezes._

## 0. TL;DR

Two deliverables. (1) **SSD-2 filesystem research** → recommendation: XFS for any cache-disk reformat, VDA doesn't exist (VDO is the real neighbor and is a NO here), btrfs rejected with this-drive-pair numbers, Docker-on-SSD2 analyzed and superseded by prune-first. (2) **`services.pool-recovery` — the /mnt/pool replug self-heal**, mirroring the proven buildcache stack: implemented, VM-tested green (3 nodes), eval-green, wired into configuration.nix + deploy.sh + Gatus… **and NOT deployed yet.** The session also accidentally proved `tests/test-cv.nix` has a latent mount bug (filed TODO_LIST).

## a) FULLY DONE

| Item | Evidence |
| --- | --- |
| SSD-2 fs research + recommendation (XFS; ext4-recipe equal-second; btrfs/VDO/VDA rejected with sources) | `docs/planning/2026-08-31_go-cache-ssd2-filesystem-research.md` |
| Docker-on-SSD2 tenant analysis + prune-first counter-proposal (data-root truth: `/data/docker`, overlay2-on-btrfs, ~20.5 GB / 88% garbage) | addendum in same doc; AGENTS.md stale-claim fix |
| "buildcache ext4→XFS" doctrine: convert at next natural reformat, never as scheduled migration | follow-up section in same doc |
| `modules/nixos/services/pool-recovery.nix` — udev rules (both Toshiba `ID_SERIAL`s), recovery oneshot (settle → scan → real-IO + UUID health gate → fstab remount **never degraded** → is-failed service restarts → counters), metrics collector + 5-min timer (always-write `.prom`, `-` ReadWritePaths = 226-proof) | VM-tested, flake-check green |
| Wiring: `configuration.nix` enable, `deploy.sh` post-switch convergence, Gatus "Pool RAID1 Membership" (gated `pool-recovery.enable`), tests registered in `tests/default.nix` | `nix eval` verified: unit oneshot/burst=5, timer config, 2 udev serial rules, endpoint present |
| `tests/test-pool-recovery.nix` — 3 nodes: healthy no-op ✓, foreign-mount UUID reaping + remount ✓, partial-member loud-fail with nothing mounted ✓, absent clean-exit ✓, fail-closed metrics ✓ | `nix build .#checks.x86_64-linux.pool-recovery` → exit 0 |
| Gatus-pattern test extension (new mock metrics + verbatim-pattern endpoint, proves the anchored `\n` patterns match) | `.#checks.x86_64-linux.gatus-patterns` → exit 0 |
| Two new AGENTS.md gotchas: btrfs `findmnt MAJ:MIN` = anonymous devt (never comparable to members); VM tests must use `virtualisation.fileSystems` (qemu-vm `mkVMOverride` replaces the whole option) | AGENTS.md, both negative-tested this session |
| `AGENTS.md` stale-fact fix: `/data/docker` IS the live data-root (old "EMPTY, docker in /var/lib" claim deleted) | verified via `docker info` live |
| deploy.sh syntax check (`bash -n` OK); fmt/statix/deadnix clean on all touched files; `mountUnitName` derived from option (not hardcoded) | final eval + proven derivation `mnt-pool` |

## b) PARTIALLY DONE

1. **pool-recovery is committed but NOT DEPLOYED** — the single biggest open item. Nothing is live on evo-x2; production coldplug trigger (real `ID_SERIAL` add events) is designed but never observed.
2. **SSD-2 tenant decision** — analysis complete, decision NOT made (Go cache vs Docker vs split vs leave). TODO_LIST P2 conflict unresolved in practice.
3. **Docker garbage prune (~16 GB reclaimable)** — recommended, quantified, NOT executed (`docker builder prune -a`, old images, 125 orphan volumes). Needs allowlist decision (TODO 88 exists from parallel session).
4. **Buildcache ext4 live re-benchmark** — deferred ALL session: IO PSI ~70% storm made results garbage and the load anti-social. Rerun snippet sits in the planning doc.
5. **Sev1 wiring** — pool metrics exist but are NOT fed into `sev1-escalation` (the desktop-paging bridge). Gatus/Discord coverage only.
6. **"XFS at next reformat" doctrine** — recorded in the planning doc only; not yet in AGENTS.md policy section (offered; awaiting user word).
7. **`restartUnits` names** — inferred from module sources (atticd/immich/paperless/bank-sync); not cross-checked against the deployed unit list. cv-backup (also a pool consumer via RequiresMountsFor) is NOT in the default list.
8. **planning doc** — covers research fully; no docs/services runbook (das-recovery runbook is a TODO_LIST item owned elsewhere).

## c) NOT STARTED (deliberately out of scope this session)

1. Deploy (needs coordination — tree carries parallel session's staged work).
2. Real-replug verification + recording the outcome in AGENTS (N=1 rule from the Aug-31 bridge recovery).
3. SSD-2 photos salvage (`btrfs restore` of 22 files, user-run sudo) — runbook in the doc.
4. SSD-2 `wipefs` + `mkfs.xfs` — user-run.
5. `test-cv` conversion to `virtualisation.fileSystems` — filed in TODO_LIST, not fixed (changing another area's test semantics unilaterally was judged out of scope).
6. Samsung GOCACHE-slice option (the only path that buys real build speed) — decision item, untouched.
7. SigNoz numeric rule for `pool_usb_recovery_device_errors > 0` (`_signoz-alerts.nix` was mid-edit by the parallel session — collision-avoided).
8. Any SigNoz dashboard entry for the new metrics.
9. Docker-gc guarded oneshot (only if accumulation recurs after prune).
10. Stale mountpoint cleanup (`/mnt/ssd`, `/mnt/ssd-ext4`, `/mnt/ssd-btrfs`) — sudo, post-decision.
11. bench-disk.sh hardcoded store-path FIO fallback hardening — noticed, untouched.
12. Post-deploy smoke additions for pool recovery in `scripts/post-deploy-check.sh`.

## d) TOTALLY FUCKED UP (honest list — what shipped broken / nearly shipped broken)

1. **The first health-gate design was production-hostile and ONLY the VM test caught it**: comparing `findmnt -o MAJ:MIN` (btrfs anonymous superblock devt, `0:48`) against member devts can NEVER match — every healthy mount would have been torn down and remounted on EVERY recovery run (every replug AND every deploy). If I had shipped without the VM test, that's a self-inflicted remount storm on a production pool. Root cause: I pattern-matched from the ext4 zombie story without checking btrfs's devt semantics.
2. **`throw` in `memberSerials`** made ANY non-by-id member a hard eval error — broke `nix flake check` the moment the VM test listed `/dev/vdb`. Over-defensive validation with a destructive failure mode; replaced with filtering.
3. **VM test bootstrap churn**: 3 wasted build cycles (`name` attr missing; formatter `wantedBy` on the mount unit vs chicken-and-egg device dependency; the `fileSystems`-vs-`virtualisation.fileSystems` discovery). The last one cost the most but produced the test-cv latent-bug finding — net positive, but it should have been the FIRST thing checked (upstream VM-test convention).
4. **`ReadWritePaths` 226/NAMESPACE** in the metrics unit — the exact trap AGENTS.md documents ("ReadWritePaths entries must exist BEFORE the unit starts"). I re-stepped on a documented landmine; fixed with the `-` prefix.
5. **Test assertion that couldn't pass**: expecting udev `ID_SERIAL` rules for bare `/dev/vdX` VM members (no serial exists). Wrong expectation, one wasted cycle.
6. **Not fucked up but worth owning**: the session opened with me half-remembering "Valve VDA filesystem" as likely-real; the research sub-agent's hard zero-hit sweep is the only reason that didn't become confident fiction in the planning doc.

## e) WHAT WE SHOULD IMPROVE

1. **Deploy discipline**: "implemented + VM-tested" ≠ "delivered". Nothing this session is live; the report is the reminder.
2. **Upstream-convention check before building VM fixtures**: reading nixpkgs VM tests for 5 minutes would have surfaced `virtualisation.fileSystems` immediately (cost: ~4 debug cycles).
3. **btrfs semantics at design time**: any code comparing mount metadata to member devices must start from "what does this return for btrfs" — anon devt, shared UUID, source path vs backing path.
4. **Reuse the tested helper, don't reinvent**: `mountUnitName` existed in buildcache.nix; I hardcoded the string in v1.
5. **Sev1 integration by default**: any new "is the box's storage alive" metric should be evaluated for sev1 paging at design time, not later.
6. **Pre-commit can't see inline bash**: the 100-line recovery script never passes shellcheck (inline Nix string). Consider `writeShellApplication` + `passAsFile` pattern or a `shellcheck` flake check that extracts unit scripts.
7. **Shared-surface staging**: my configuration.nix/gatus-config.nix/deploy.sh edits landed in files the parallel session also owns mid-flight — flake check passed on the union, but the coupling is real; keep inserts surgical and re-read immediately before every edit (done, but it stayed risky all session).

## f) NEXT ACTIONS (prioritized, ~50)

**Deploy & verify (P0)**
1. Deploy `nix run .#deploy` (coordination decision — see Q1).
2. Post-deploy: confirm `pool-usb-recovery` + `pool-recovery-metrics` units exist and the timer registers.
3. Post-deploy: Gatus "Pool RAID1 Membership" green with both members; `pool_usb_recovery_mounted 1`.
4. Verify `notify-failure@` template actually pages on an injected recovery failure (document the injection procedure).
5. Cross-check `restartUnits` names against the DEPLOYED unit list; add `cv-backup.service` (pool consumer via RequiresMountsFor).
6. Add pool-recovery convergence to `scripts/post-deploy-check.sh` (unit presence + metrics file + mounted).
7. Observe production coldplug: next boot, confirm the udev `SYSTEMD_WANTS` fires for both serials (journal).
8. Next REAL DAS replug: record outcome in AGENTS.md (N=1 rule).
9. Wire `pool_usb_recovery_mounted`/`members_present` into `sev1-escalation` sources (desktop paging for stale pool — Q3).
10. Add `TriggerLimitIntervalSec`/`TriggerLimitBurst` thinking for udev wants during enclosure flap storms.

**SSD-2 decision execution (P0/P1, user decisions first)**
11. Final SSD-2 tenant call: Go cache / Docker / split / leave (Q2).
12. Regardless of tenant: run the Docker prune (~16 GB): builder prune -a, old-image prune, orphan-volume allowlist then `docker volume prune`.
13. If Go cache wins: user-run photo salvage (`btrfs restore`, runbook in doc) → `wipefs` → `mkfs.xfs -L gocache`.
14. Implement the gocache module (mirrors pool-recovery structure: automount stack + GC + metrics) — plan §Migration.
15. Repoint `home.nix` env (GOCACHE/GOMODCACHE/GOLANGCI_LINT_CACHE/goimports symlink); one-time module re-download accepted.
16. Extend/clone `buildcache-gc` coverage for the new mount (90% watermark).
17. Update smartd comment + AGENTS drive table + kill/keep TODO P2 accordingly.
18. Remove stale `/mnt/ssd*` mountpoint dirs (sudo, post-decision).
19. Quiet-window benchmark rerun (PSI < 20%): polite fio + 20k-file metadata test on buildcache ext4 (baseline) and post-mkfs SSD-2 (XFS), per doc snippet.
20. Encode "cache disks default to XFS at next reformat" into AGENTS.md policy section (one line, awaiting user word).

**Pool hardening (P1)**
21. Convert `test-cv` to `virtualisation.fileSystems` and re-verify cv-backup under a REAL mount (TODO filed).
22. SigNoz numeric rule: `pool_usb_recovery_device_errors > 0` (after `_signoz-alerts.nix` frees up).
23. Add the four `pool_usb_recovery_*` metrics to a SigNoz dashboard.
24. Feed pool metrics into `sev1-escalation` sev1-bridge source list (with module-presence gating like the others).
25. `buildcache-usb-recovery` parity: add the same UUID identity gate (ext4 source node + fs UUID) so a wrong-fs mount there is also caught.
26. docs/services runbook: fold pool-recovery + buildcache recovery into the das-recovery runbook (TODO 134(9)).
27. Eval-time assertion idea: warn when `pool-recovery` is enabled but NO member parses to a by-id serial (production misconfig signal — VMs are the legitimate exception).
28. `buildcache-metrics`/`pool-recovery-metrics`: consider one shared textfile-writer lib to stop copy-pasting the atomic `.prom` pattern.
29. Deploy-time guard: eval assertion that `restartUnits` entries exist as declared units (typo class).
30. Confirm `mnt-pool.mount` unit name derivation holds if `mountPoint` ever changes (done in code; add a VM variant with a custom mountPoint to lock it).

**FS/doctrine follow-through (P1/P2)**
31. Buildcache ext4 → XFS conversion at the next natural reformat (per doctrine; TRIM-less drive needs it eventually anyway).
32. When SSD-2 is formatted: `-n ftype=1` IF docker tenant, optional `-m reflink=0` if cache tenant (doc has both runbooks).
33. Keep `compress` OFF any SandForce tenant fs (DuraWrite double-compression — doctrine recorded).
34. Revisit bench-disk.sh pinned FIO store path (brittle across bumps; has fallback, but tidy).
35. Samsung plan: explicitly decide the GOCACHE-slice question (only real speed lever; competes with /nix headroom).

**Repo hygiene (P2)**
36. CHANGELOG/FEATURES entries for pool-recovery (docs-health session owns — hand off).
37. AGENTS.md: fold the session's mount-option explainer knowledge (data=writeback/commit semantics already in module comments; consider a docs/services/filesystem-mount-options.md if ever asked again).
38. Remove the `hierarchical-errors`-style check noise? (unrelated flake-check line observed — verify it's expected).
39. Watch the parallel docs-health session's TODO_LIST rework (461-line diff staged) — re-base my one TODO item if it collides.
40. After the daemon's next commit: `git log` review of the batch for accidental inclusion of others' mid-flight edits (concurrent-session rule).

**Upstream/nice-to-have (P2)**
41. Upstream nixpkgs docs PR idea: qemu-vm `fileSystems` override is a silent-footgun (verify-before-filing: check upstream docs/tests first).
42. btrfs device stats: consider periodic `btrfs device stats -z` reset policy after acknowledged errors (user decision).
43. Consider `SystemCallFilter` additions for the recovery unit (it stays deliberately unfiltered for mount ops — document why in-line, already partly done).
44. Metrics: add `pool_usb_recovery_last_success_age_seconds` gauge (Gatus-friendly staleness signal).
45. Gatus: add `[RESPONSE_TIME]` budget to the node-exporter-backed checks? (consistency sweep, low value).
46. VM test: add an eval-level check asserting by-id serial rule GENERATION (pure runCommand over a synthetic config).
47. Consider pool-recovery behavior when `/mnt/pool` is mounted but READ-ONLY (btrfs forced readonly) — probe passes (reads work!), so currently a no-op; decide if remount-rw attempt is wanted (probably NOT automatic).
48. Fold the "why we didn't arm pool recovery before" history into the das-recovery runbook (context for future sessions).
49. Sweep for other places comparing devts of btrfs mounts (repo-wide grep `MAJ:MIN`) — confirm no sibling of the anon-devt bug exists.
50. Post-incident: if the JMS567 wedges again, add the wedge signature (zero connect events + pinned controllers) to das-link-recovery-check.sh decision tree.

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **Deploy timing**: pool-recovery is tested but NOT live. `nix run .#deploy` ships the WHOLE tree — including the parallel session's staged, possibly mid-flight work (signoz-coverage, bank-sync, dns-blocker…). Do I deploy now, or wait for a quiescent window / their explicit done?
2. **SSD-2 final tenant**: Go cache (XFS, my recommendation), Docker, split partition, or leave as-is? And is the 22-photo copy on its btrfs (`/me/`) disposable — it determines whether salvage-before-wipe is required?
3. **Alert escalation for the pool**: is Discord (Gatus) enough for stale/degraded pool states, or should they page the desktop via sev1-escalation like guard-dead/DAS-link already do? (I can wire it either way; the urgency call is yours.)

— END OF REPORT. Waiting for instructions.
