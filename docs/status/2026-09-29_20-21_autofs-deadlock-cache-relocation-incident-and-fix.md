# Status Report — autofs Deadlock: Cache-Relocation Incident & Proper Fix

**Report time:** 2026-09-29 20:21 CEST
**Scope:** This session only (started ~13:08, gap ~13:45→20:10 — user asleep; machine sat wedged the whole time)
**Live system state at report time:** STILL WEDGED — 84 D-state processes, load 86.91, boot transaction incomplete (boot 09:56, now 10h25m). Recovery commands provided but NOT yet executed.

---

## The Incident (one paragraph)

`hot-user-caches-nix-bootstrap.service` — the runtime oneshot that was supposed to create the `~/.cache/nix` subvolume on the Samsung TLC disk before its automount fired — **hung pre-exec on 4 consecutive boots (Sep 24, Sep 27 ×2, Sep 29) and never completed successfully even once.** Kernel-proven mechanism (`/proc/10158/stack`): systemd's sandbox namespace builder calls `umount2(path, MNT_DETACH)` on autofs mounts in every forked service child; the umount's path lookup blocked on the _pending_ direct autofs at `/home/lars/.cache/nix`, whose mount job was queued _behind that same service_ (`before=`) — a kernel-level self-deadlock. Every process touching the path parked in `autofs_wait` D-state forever: all `nix flake check` / `nix build` / `nix print-dev-env` / direnv invocations — i.e., **every AI agent on the host appeared "stuck on outputs"**, 84 D processes, load 86, `multi-user.target` never reached. The original goal (relocate ~8.7 GB nix caches off the saturated QLC root NVMe, IO audit 2026-09-18/19) was never delivered — worse, nix was broken at the touch of `~/.cache/nix` since Sep 24.

---

## a) FULLY DONE

1. **Root cause diagnosed end-to-end with kernel-level proof.** Chain: automount trigger (btop, 09:58:05) → `.mount` job pulls bootstrap (`wantedBy`/`before`) → child forked, sandbox namespace construction → `umount2(MNT_DETACH)` on autofs → lookup → `d_manage` → `autofs_wait` → mount can't complete (queued behind the waiting child) → deadlock. Confirmed by user-supplied `/proc/10158/stack`, empty `/proc/cmdline` (fork-not-exec), job states via busctl, journal forensics across boots −1…−4.
2. **PROPER fix implemented** in `modules/nixos/services/hot-user-caches.nix`: the runtime bootstrap **deleted entirely**. Doctrine: subvolumes are provisioning state — `disko/samsung-tlc.nix` declares `/users/lars/cache/nix` (flake geometryGuards assert it at eval time); fstab mounts directly. Pattern precedent: `snapshots.nix` `cacheSubvolumes` (@cache-home) — same shape, running clean since forever. Kept `x-systemd.mount-timeout=90s` on the fstab entry so even a pathological future mount job fails fast instead of parking autofs waiters.
3. **Same-bomb armor for forgejo** (`modules/nixos/services/forgejo.nix`): `forgejo-subvol-bootstrap` has identical `wantedBy`/`before` wiring against its mount. Since its subvol is deliberately NOT disko-owned (runtime-created service state), it keeps the bootstrap but now carries `JobTimeoutSec` + `JobRunningTimeoutSec = 4min` (job-level cancel frees the mount even though a D-state process is unkillable) + `TimeoutStartSec = 2min`.
4. **Regression test rewritten** (`tests/test-hot-user-caches.nix`): provisioning moved into `hot-fmt` (disko stand-in creates the subvol); tripwires: tmpfiles-active probe (Sep 24 class), **`systemctl cat hot-user-caches-nix-bootstrap.service` must FAIL** (pins the deletion), first access must mount within 30s (nothing in the transaction), mount-timeout posture assert, writes land on the hot disk. Full VM-test derivation evaluates green (`vm-test-run-hot-user-caches`).
5. **AGENTS.md gotcha written** (Non-Obvious Gotchas): full mechanism, incident history, the doctrine ("never order a runtime service between an automount and its mount"), job-timeout recipe for unavoidable cases, and the `XDG_CACHE_HOME=/tmp/x nix …` live-wedge mitigation.
6. **Module inline documentation**: complete incident history (2026-09-20 → 09-29, 4 failure modes) + provisioning-ownership doctrine in the module header.
7. **Two broken Crush skills fixed and validated**: `naming-review` (unquoted `:` in YAML description — never loaded at all; fixed to quoted scalar, YAML-parses, 848 chars) and `go-cqrs-lite` (description 1362 → 1020 chars, under the 1024 limit). Warning spam in crush logs confirmed gone.
8. **Emergency no-root mitigation discovered & verified**: `XDG_CACHE_HOME=/tmp/x <nix cmd>` bypasses the wedged automount entirely — all nix eval/build commands in this session ran this way.
9. **Earlier same-day (pre-"proper fix") patch** — job timeouts on the hot-user-caches bootstrap + mount-timeout — was committed, then **superseded by the deletion** (timeouts survive only on forgejo + as the general recipe).

## b) PARTIALLY DONE

1. **Full-flake validation** (`nix flake check --no-build`, running with cache redirect since ~20:19): still running at report time. Parse checks + module eval + full VM-test derivation eval: green. Flake-wide result (covers forgejo.nix + evo-x2 config + geometryGuards assertions): **pending**.
2. **VM test executed**: only _evaluated_, not _run_ (QEMU on a load-86 box = bad idea; also all nix-build work needs the XDG_CACHE_HOME workaround). Must run post-recovery.
3. **Deployment**: fix is in the repo (auto-committed by the daemon: `477f9c8f`, `17dc3916`, `0bd8cd59`) but **NOT deployed** — `nh os switch` / `nix run .#deploy` requires a working nix environment (or redirect) and ideally post-recovery.
4. **Live-system recovery**: exact commands delivered twice (cancel job → start mount; or reboot). NOT executed — user went to bed; wedge persists (84 D procs, load 86.91 at 20:21).

## c) NOT STARTED

1. Pool btrfs health work: `/mnt/pool` metadata RAID1 97.9% chunk-fullness (74.41/76 GiB) with 24.88 TiB unallocated — balance + root-cause of 74 GiB metadata bloat for 2 TiB data. (Gatus "BTRFS Chunk Health" has been red.)
2. Gatus alert calibration review (`modules/nixos/services/gatus-config.nix:673`) — chunk-fullness runs high _by design_ between allocations; the rule may flap false-positives.
3. The 12 pre-existing `nix-checker` port-collision error findings in `tests/` (unrelated to this work; surfaced by buildflow dry-run).
4. Root filesystem cleanup (`/` at 92%, 60G free).
5. Fleet-wide audit for other services ordered against `.mount`/`.automount` units (only forgejo checked so far).
6. Fleet-wide `x-systemd.mount-timeout` on all automount fstab entries (snapshots.nix family lacks it).
7. Boot-transaction watchdog alerting ("jobs stuck > 10 min" / sustained load > 20 gatus checks) — would have caught this on Sep 24 instead of Sep 29.
8. Post-deploy verification that the cache relocation actually delivers the IO-audit goal (nvme0n1 QLC write reduction measurement).
9. `docs/gotchas-archive.md` full narrative entry (AGENTS.md gotcha points there; archive not yet updated).

## d) TOTALLY FUCKED UP!

1. **The live host, still, right now**: 84 D-state processes, load 86.91, boot transaction incomplete for 10h25m, every nix command touching `~/.cache/nix` hangs. Nothing I could do without root — recovery is a copy-paste away and has not been run.
2. **The cache-relocation feature itself (Sep 24–29)**: 0-for-4 boots, never worked, actively broke every agent's nix usage for 5 days while looking like "agents being slow". The original IO problem (QLC saturation) remains unsolved until deploy + verification.
3. **My first root-cause theory was wrong and confidently stated**: "btrfs ioctl window at 09:58". Corrected after the empty-cmdline evidence → pre-exec namespace hang. The timeout-only fix that followed was a patch, not the proper fix — the user had to demand "fix it PROPERLY" before the bootstrap deletion happened. Should have questioned the design after incident #2, not after #4.
4. **My clock-jump theory was wrong**: sddm's 10h11m etime confused me into hypothesizing an NTP step; reality was simply that hours passed while the user slept. Should have run `date` before theorizing.
5. Small self-inflicted fumbles: wrong awk pattern for PID lookup (comm truncates at 15 chars — user hit the empty result), 2 edit-tool refusals on skill files (edited without View first), go-cqrs-lite description took 3 trim passes, naming-review first "fix" (indent) wasn't the real bug (unquoted colon).

## e) WHAT WE SHOULD IMPROVE!

1. **Incident-driven design review cadence**: two boot incidents (Sep 20, Sep 24) on the same wiring produced patches, not a design challenge. Rule worth adopting: second failure of the same unit = redesign, not repair.
2. **Alerting on the boot transaction itself**: nothing watched `systemctl list-jobs` depth or sustained load. Five days of "slow agents" went undiagnosed. A gatus check on stuck-jobs-count would have paged on Sep 24.
3. **The "cache mount never mounted" fact was observable**: gatus/storage-collector read chunk stats daily but nothing asserted `home-lars-.cache-nix.mount` active. Mount-state assertions for every declared cache mount.
4. **Time-to-root-cause tooling**: `/proc/<pid>/stack` required sudo + my prompting. A tiny `stuckproc` diagnostic script (stack/syscall/wchan/cmdline of all D-state processes) in SystemNix would compress this class of investigation to minutes.
5. **Skill-file validation**: two skills silently failed to load for weeks/months (one never loaded at all). A `crush doctor`-style check or pre-commit YAML/frontmatter lint on SKILL.md files would prevent silent skill loss.
6. **My own discipline**: verify before asserting (wrong theory #1, wrong clock theory), read before edit (2 refusals), and push to the proper fix the first time.

## f) NEXT — up to 50 things, impact-sorted

**Recovery & deploy (do these first)**

1. Run recovery: `sudo systemctl cancel <bootstrap-job-id>` then `sudo systemctl start home-lars-.cache-nix.mount` — or simply reboot (run `nix run .#pre-reboot-check` first per house rule)
2. Deploy the fix: `cd ~/projects/SystemNix && nh os switch`
3. Post-recovery: verify `systemctl list-jobs` empties, load < 10 within minutes
4. Post-recovery: the 3 stuck `nix flake check`, 1 stuck `nh os switch`, 3 stuck direnv `print-dev-env`, `trash count` should complete or die — verify none linger
5. Post-deploy: `ls ~/.cache/nix` mounts instantly; `findmnt /home/lars/.cache/nix` shows the tlc subvol
6. Post-deploy: `nix flake check` works WITHOUT the XDG_CACHE_HOME redirect
7. Run the VM test for real: `nix build .#checks.x86_64-linux.hot-user-caches` (or buildflow)
8. Confirm the residual D-zombie (PID 10158) is gone after reboot

**Verification & measurement**
9. Measure the original goal: nvme0n1 (QLC root) write pressure with caches on tlc — did relocation deliver?
10. iostat re-baseline after recovery (compare against the 2026-09-19 audit)
11. Check crush sessions (22+) resume working nix commands

**btrfs pool health (gatus already red)**
12. `sudo btrfs balance start -musage=50 /mnt/pool` (metadata consolidation; 24.9 TiB unallocated headroom)
13. Root-cause 74 GiB metadata for 2 TiB data — `btrfs subvolume list` count, snapshot audit (btrbk-pool legs)
14. Review gatus "BTRFS Chunk Health" rule (gatus-config.nix:673) — chunk fullness runs high by design between allocations; recalibrate or alert on absolute metadata used
15. Root fs (/) 92% full — nix-gc run + large-path audit
16. Document or wipe sdc1 (`ssd-btrfs`, 223G, unmounted) and sdd (14.6T, unmounted, ex-pool member?)

**Systemic hardening (this incident class)**
17. Fleet-wide grep: any other `wantedBy = [ "<something>.mount" ]` / `before = [ "*.mount" ]` services — audit each for the autofs-pending class
18. Add `x-systemd.mount-timeout` to ALL automount fstab entries (snapshots.nix cacheSubvolumes family, mnt-buildcache)
19. Decide doctrine for `forgejo-subvol-bootstrap`: disko-declare `hot/forgejo` and delete the runtime bootstrap (then zero runtime mount-gating services remain) — needs migration of live subvol ownership
20. Consider `JobTimeoutSec`/`JobRunningTimeoutSec` in `serviceOneshotDefaults` (fleet-wide armor) — weigh against services with legitimately long starts
21. gatus: stuck-jobs-count check (`systemctl list-jobs | wc -l > 10 for 10min`)
22. gatus: sustained load-average check (> 20 for 15min)
23. gatus/storage-collector: assert `home-lars-.cache-nix.mount` (and every cacheSubvolume mount) is active — mount-state tripwire
24. Add `stuckproc` diagnostic script (D-state stack dump) to SystemNix
25. `docs/gotchas-archive.md`: full narrative entry for this incident (AGENTS.md already points there)
26. Consider the cross-project lesson for crush-config `references/lessons.md` (boot-transaction deadlock class) — commit, not in-session write

**Quality debt surfaced but untouched**
27. Fix the 12 nix-checker port-collision errors in tests/ (ports shared across test-catalog/test-integration)
28. Run full `buildflow` in SystemNix post-recovery (last dry-run: 12 error findings, 45 warnings)
29. The earlier timeout-patch commit history is superseded — consider a CHANGELOG/commit note clarifying final design (history currently shows patch-then-delete)
30. Verify `naming-review` + `go-cqrs-lite` skills now LOAD in crush (`crush_info` skills list / restart sessions)
31. Commit/push SKILLS repo (`naming-review` fix) and go-cqrs-lite repo (description fix) if the auto-daemon doesn't cover them
32. Verify skill fix survives symlink redeployment (~/.config/crush/skills → project repos)

**Forensics leftovers (optional, before reboot erases evidence)**
33. Read `/proc/10158/mem` to extract the exact umount path string (confirm it was `/home/lars/.cache/nix` and not `.cache`)
34. Dump stacks of 2–3 of the ~45 other D services (psi-metrics, storage-collector) to confirm they share the identical autofs_wait stack — closes the "why did ALL metrics services hang" question with the same rigor as the bootstrap
35. Capture `journalctl -b 0 > /var/tmp/boot-wedge-journal.txt` before reboot for the archive

**Go-build PARKED integration (documented in module)**
36. Design the HM-symlink-gated go-build cache relocation (needs boot ordering that never loads the automount while the symlink exists)

**Housekeeping**
37. Status-report follow-up: docs-health HARVEST of section (f) into TODO_LIST.md
38. Close the loop on the morning's earlier status reports (07-05, 07-33, 10-09, 11-34) — out of scope here, listed for completeness only

## g) Questions I can NOT figure out myself

1. **Cancel-and-mount, or straight reboot?** The surgical path preserves your 25 sessions (the stuck nix commands will simply _complete_ once the mount lands); reboot is guaranteed-clean but kills everything including the residual unkillable child (PID 10158). The evidence for both is ready; the call on your running work is yours. (If reboot: run `nix run .#pre-reboot-check` first.)
2. **Forgejo doctrine**: should `hot/forgejo` become a disko-declared subvolume so its runtime bootstrap can be deleted too (making the fleet 100% free of runtime mount-gating services), or does runtime-created service state on the hot disk stay intentional? Its subvol isn't disko-declared today, so I did not delete its bootstrap — armor only.
3. **Forensics before reboot?** Once you reboot, the D-state evidence (stacks, `/proc/*/mem`) is gone forever. Want the full capture (items 33–35) first, or is the bootstrap's kernel-proven stack enough and we close the case?

---

_Point-in-time snapshot. Machine still wedged at time of writing; recovery commands in d).4 / f).1. Written by Crush (glm-5.3) during the 2026-09-29 autofs-deadlock session._
