# Status: Rust-Cache SSD Split — Config Landed, Maintenance Window Pending

**Date:** 2026-10-06 20:18 CEST (Tuesday)
**Session scope:** only the rust-cache direction ("the single empty 240GB SSD we should use for Rust cache") — design, implementation, docs, verification. No deploys, no disk operations (both sudo/maintenance-window-gated).
**Verdict:** the config side is COMPLETE and green (`nix flake check --no-build` all checks passed, evo-x2 toplevel evals clean). The physical setup is NOT done — it requires the owner's maintenance window.

---

## Context

The 2026-09-22 decision ("merge both SanDisk SDSSDA240G into ONE btrfs at /mnt/buildcache") is SUPERSEDED by the owner's 2026-10-06 direction: the empty second SanDisk (serial `174244451713`) becomes a dedicated Rust cache at `/mnt/rust-cache`. Decision record: `docs/planning/2026-10-06_rust-cache-ssd-decision.md`.

## a) FULLY DONE

1. **New service module** `modules/nixos/services/rust-cache.nix` (508 lines): btrfs `noatime,compress=zstd:1,space_cache=v2,commit=120` + `nofail` + automount + `device-bound` + 2s device-timeout; `rust-cache-init` (idempotent dir provisioning, harden + CAP_CHOWN/FOWNER/DAC_OVERRIDE); `rust-cache-usb-recovery` (zombie reaper, btrfs `findmnt`, `~/.cargo/registry` reap, real-I/O verify, deliberately NOT harden{} — umount/namespace lesson); `rust-cache-metrics` (always-writes `rust-cache.prom` with `rustcache_*` gauges, mktemp + CAP_FOWNER textfile pattern); `rust-cache-gc` (stale target dirs >14d, cold-prune all at watermark) + timers; JMS567 udev power rules (duplicated for self-containment) + `SYSTEMD_WANTS` keyed to the disk's `ID_SERIAL`; integration-registry entry with 2 anchored-pat Gatus checks ("Rust Cache SSD" / "Rust Cache Usage").
2. **home.nix rewired**: `SCCACHE_DIR=/mnt/rust-cache/sccache`, `CARGO_HOME=/mnt/rust-cache/cargo`, `.cargo/registry` symlink → `/mnt/rust-cache/cargo/registry`; the HM activation block now pre-creates the cargo target on the rust-cache mount and reaps when EITHER cache mount is up.
3. **snapshots.nix**: `~/projects/monitor365/target` symlink → `/mnt/rust-cache/rust/monitor365`; `services.rust-cache.rustProjects` carries the project list.
4. **buildcache.nix trimmed to Go/JS/Python**: `rust`/`sccache`/`cargo`/`cargo/registry` removed from `buildcacheDirs`; `rustProjects` option + rust-target GC leg removed (owned by rust-cache now); GC path list slimmed (findutils/gnused dropped — unused).
5. **configuration.nix**: `services.rust-cache = { enable = true; gc.enable = true; }` + smartd comment corrected (SSD 2 = Rust cache, was "future Docker storage").
6. **Migration script** `scripts/migrate-rust-cache.sh` (111 lines): content-gated reformat (refuses anything not btrfs/`ssd-btrfs` or already `rust-cache`; refuses mounted devices), production mount options, `cargo` → `rust` → `sccache` rsync-move with file-count verification, source removal to free buildcache. Flake app `nix run .#migrate-rust-cache` (Linux-gated, btrfs-progs input).
7. **das-link-recovery-check.sh**: the "frozen spare" concept is GONE — `RUSTCACHE_DISK`/`RUSTCACHE_PART` constants, presence check, fstab-drift check, `[4]` `check_mount /mnt/rust-cache btrfs`, `[6]` debris scan against new `KNOWN_RUSTCACHE_ENTRIES`.
8. **deploy.sh**: post-switch `rust-cache-usb-recovery` + `rust-cache-gc` convergence blocks.
9. **stray-unit-audit.nix**: `rust-cache-usb-recovery` allowUnits entry (eval WARNING verified gone).
10. **Docs**: `docs/agents/storage.md` — new "Rust cache SSD" section + 5 in-place corrections (device identification, consumers, sccache path, monitoring, GC, freeze-lifted note, merge-superseded note); `docs/todo/storage.md` — 2-disk-merge row rewritten as the rust-cache setup row, btrfs-conversion row closed as superseded; `scripts/buildcache-btrfs-convert.sh` header marked SUPERSEDED/do-not-run; `hardware-configuration.nix` stale comment updated.
11. **Verification**: `nix flake check --no-build` → **all checks passed** (twice: after the module and after the audit allowUnits change); evo-x2 toplevel `nix eval` → drvPath, zero failed assertions, stray-unit warning cleared; `check-buildcache-known-parity.sh` → PARITY OK (11 literals ⊆ 18 KNOWN); `check-todo-system.sh` → structure OK; shellcheck clean on both touched scripts; repo treefmt run on all 8 changed .nix files (1 whitespace fix applied).

## b) PARTIALLY DONE

1. **The physical setup itself** — config is inert until `nix run .#migrate-rust-cache && nix run .#deploy` runs in a maintenance window (sudo + quiesced builds). Until then `/mnt/rust-cache` is a dangling automount target: shell sessions are protected by the fish guard (CARGO_HOME/SCCACHE_DIR redirect to `/tmp/bc-fallback`), but env-less processes writing CARGO_HOME would fail loudly until migration. Order matters: migrate FIRST, then deploy.
2. **Stale-reference sweep** — I updated every reference I FOUND (code + storage.md), but only grepped code paths + storage.md; a full docs sweep for "frozen spare"/"SSD 2"/"spare SSDs" (e.g. `system-health.nix`'s DAS-link alert text still says "spare SSDs") is queued (§f.4), not done.
3. **Guard coverage parity** — buildcache has `check-buildcache-known-parity.sh`; the new `rustCacheDirs` ↔ `KNOWN_RUSTCACHE_ENTRIES` pair has NO parity guard (hand-kept on both sides, drift fails only at the next manual re-fire). Queued (§f.2), not built.
4. **Fixture tests** — `migrate-rust-cache.sh` is UNEXECUTED (no fixture test; the migrate-hot-db fixture pattern exists and should be copied). `rust-cache-init` has no provisioning fixture (the buildcache one is itself still queued). Queued (§f.1).
5. **Self-harvest of §f** — done AT AUTHORING TIME (5 items → `docs/todo/storage.md` + `TODO_LIST.md` queue one-liners, structure check green); the deliberately-not-harvested remainder is listed below the §f table.

## c) NOT STARTED (explicitly out of this session's scope)

1. The maintenance window: format/mount/move + deploy (owner, sudo).
2. Post-migration verification: `findmnt /mnt/rust-cache`, btrfs `compress` effective ratio (`compsize`), first cargo build hits sccache, Gatus checks green, `rust-cache.prom` present, `das-link-recovery-check.sh` full pass with the new legs.
3. VM test for the module (buildcache has none either; the P15 row "opposing-state assertions … buildcache/pool-smart VM tests" is the natural vehicle — a rust-cache twin can ride it).
4. `docs/services/rust-cache.md` runbook — deliberately NOT created: buildcache (the direct precedent) has none; `docs/agents/storage.md` owns both disks' state. If the owner wants per-service runbooks for infra modules, that's a separate doctrine decision covering buildcache too.
5. Shared sccache S3 backend for the MacBook (the RustFS eval's standing idea) — unrelated, untouched.
6. The `known-parity` pre-commit leg for the new files (the buildcache leg keys on literal filenames; a rust-cache twin would need the same rename-proofing already queued for buildcache's).

## d) TOTALLY FUCKED UP

Nothing catastrophic — tree is green, nothing deployed, nothing irreversible done. Honest misses, worst first:

1. **I created premise drift in the queue and only caught it at report authoring** — `TODO_LIST.md` row "Fixture test for `buildcache-init` dir provisioning" said buildcacheDirs includes `cargo/registry` (now false after my change). The "queue one-liners and library entries must not drift" rule applies to premises too; a reviewer catch class. FIXED at authoring time (both rows corrected, incl. the `af9b3ef2` deploy-proof row), but it should never have shipped in the working tree even briefly.
2. **Formatter run came AFTER "done"** — I declared completion, then ran the repo treefmt and it fixed a whitespace issue in buildcache.nix. The verify-before-finish pass should have included it.
3. **I built the module before confirming the structural direction with the owner** — a sibling module (~500 lines, duplicating the recovery/metrics machinery) vs. parameterizing the existing buildcache module was a real fork with maintenance consequences; I picked the sibling on isolation-risk grounds and noted the duplication, but this superseded a previously user-decided plan and deserved a one-line confirmation before 500 lines landed. (Reversible — refactor is queued as an improvement, not a defect.)
4. **Two sloppy tool calls**: `rg -rln` typo'd into replace-mode TWICE (output garbage, no damage), and `migrate-rust-cache.sh` briefly shipped `local sf df` / `dfc=` name mismatch — caught and fixed immediately, but it shipped in the auto-commit window (ff9c6053/6c32ad94 era).
5. ** Alejandra detour**: I format-checked with raw `nixpkgs#alejandra`, which flags even untouched files (the repo uses the locked treefmt-full-flake formatter) — wasted a roundtrip; should have gone straight to `.#formatter.x86_64-linux`.

## e) WHAT WE SHOULD IMPROVE

1. **Kill the recovery/metrics duplication** — rust-cache.nix duplicates ~200 lines of hardened USB recovery/metrics machinery from buildcache.nix. The clean end-state: extract a shared `lib/usb-cache-fs.nix` helper (mount + init + recovery + metrics parameterized by `{mountPoint, device, fsType, dirs, metricPrefix}`) consumed by both modules. Do it as a dedicated refactor session with the VM/eval gates, not piecemeal.
2. **Ask earlier on direction-reversing work** — a one-question confirm ("spare SSD dedicated to Rust — abandon the merge?") before implementation would have cost 30 seconds. The autonomy bias is right for reversible work, wrong for plan reversals.
3. **Full-repo reference sweep as a standard close-out step** — one `rg` over the whole repo (code + docs) for every renamed/repurposed identifier, not just the files I know about. The "spare SSDs" alert-text staleness is exactly this class.
4. **Never ship a guard without its selftest** — I added `KNOWN_RUSTCACHE_ENTRIES` by hand with no pinning guard; the repo's own doctrine ("no guard without a positive fixture", "hand-edits fail loudly") says the parity script should have landed in the same commit.
5. **Unexecuted migration scripts deserve fixtures at authoring time** — the script will run exactly once, under sudo, in a window; the repo already learned this with migrate-hot-db (fixture shipped before first window). I repeated the gap.
6. **Run the formatter inside the verify pass**, not after the final summary.

## f) NEXT (prioritized; §f.1-§f.5 harvested to `docs/todo/storage.md` + `TODO_LIST.md` at authoring time)

| #  | Task                                                                                                                                                                                                      | Why / class                                                                                  |
| -- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| 1  | Fixture-test `migrate-rust-cache.sh` (PATH stubs: mkfs.btrfs/mount/findmnt/mountpoint/lsblk/rsync; content-gate refusals; already-formatted skip; move/verify/rm; SKIP-when-buildcache-unmounted)         | UNEXECUTED script runs once under sudo (migrate-hot-db fixture pattern) — **HARVESTED §f.1** |
| 2  | Parity guard `rustCacheDirs` ↔ `KNOWN_RUSTCACHE_ENTRIES` (+ selftest incl. positive-asymmetry shape)                                                                                                      | re-fire-9 drift class; hand-kept both sides — **HARVESTED §f.2**                             |
| 3  | Give `rust-cache-gc` its own `highWatermarkPercent` (today alert-threshold 85 == destructive-prune trigger; buildcache separates 85/90)                                                                   | one-number coupling of alert and rm -rf — **HARVESTED §f.3**                                 |
| 4  | Sweep stale "frozen spare / SSD 2 / spare SSDs" references (system-health.nix DAS-link alert text + gotchas-archive/stability/monitor365 docs)                                                            | renamed-role staleness — **HARVESTED §f.4**                                                  |
| 5  | Close the rust-cache-metrics first-scrape race (device-absent early exit skips metrics start; 2-min Gatus phantom-red window)                                                                             | phantom-metric class — **HARVESTED §f.5**                                                    |
| 6  | Run the maintenance window: `nix run .#migrate-rust-cache && nix run .#deploy` (owner, sudo, quiesced builds)                                                                                             | the actual goal                                                                              |
| 7  | Post-migration proof: `findmnt /mnt/rust-cache` (btrfs), `compsize` compression ratio, first `cargo build` in monitor365 hits sccache, both Gatus checks green, `.prom` present                           | assert WHICH disk served the build                                                           |
| 8  | Post-migration buildcache reclaim check: `rust/`, `sccache/`, `cargo/` GONE from `/mnt/buildcache` (df before/after; expect ~50G+ freed), `das-link-recovery-check.sh` full pass                          | the split must actually free the buildcache                                                  |
| 9  | Verify env-less rust path: with the mount up, a fresh shell has `CARGO_HOME` → rust-cache; HM activation heals `~/.cargo/registry` without checkLinkTargets abort                                         | symlink-landing proof                                                                        |
| 10 | Decide: keep buildcache ext4 permanently, or revisit ext4→btrfs (checksums for npm/pnpm) in a later window — the merge rationale (compression+checksums) now lives only on the rust disk                  | owner decision, was folded into the merge                                                    |
| 11 | Fold the old `[blocked:user] e2fsck /dev/sdc1 (buildcache)` row's device naming — sdc letters rotate; the row should name the by-id serial 174444471311                                                   | stale-device-naming trap                                                                     |
| 12 | Extract shared `lib/usb-cache-fs.nix` helper; refactor buildcache.nix + rust-cache.nix onto it (dedup ~200 lines)                                                                                         | §e.1                                                                                         |
| 13 | Consider a `docs/services/rust-cache.md` (and buildcache) runbook IF the owner wants per-service docs for infra modules                                                                                   | doctrine decision, not solo                                                                  |
| 14 | Extend P15's VM-test row to cover rust-cache-metrics opposing states (device-absent `.prom` shape) alongside buildcache/pool-smart                                                                        | rides existing queue item                                                                    |
| 15 | Add rust-cache to the deploy-FOD §11 / pre-deploy vendorHash preview? N/A check — confirm no pre-deploy §-leg is owed for a mount-only module (no ports, no images)                                       | completeness audit                                                                           |
| 16 | After first deploy: confirm `rust-cache-usb-recovery` fires on a real replug event (or at least the deploy.sh path) and recovery sweeps `~/.cargo/registry`                                               | live-verify the copied machinery                                                             |
| 17 | Watch first weekly `rust-cache-gc` run (Sun 05:15): stale-prune + watermark branches, ioTier.maintenance respected                                                                                        | first-run verification class                                                                 |
| 18 | SigNoz: decide whether `rustcache_*` gauges deserve a dashboard tile/rule (buildcache ones have none beyond Gatus)                                                                                        | monitoring parity question                                                                   |
| 19 | Gatus alert text charset check on the two new checks (alert-description rule) at first deploy smoke                                                                                                       | monitoring.md rule                                                                           |
| 20 | Update `docs/planning/*` disk-layout HTML(s) if regenerated — they still show the spare as earmarked-for-merge (stale-artifact rule applies only on regeneration)                                         | stale-planning-artifacts                                                                     |
| 21 | Confirm `system-health.nix` DAS-link alert's checked-mount enumeration doesn't need `/mnt/rust-cache` added (mount-presence leg, not just text)                                                           | §f.4 sibling                                                                                 |
| 22 | When the merge is truly dead, delete or archive `scripts/buildcache-btrfs-convert.sh` (today: header-marked do-not-run; scripts/ dead-code policy says trash after a soak period)                         | dead code hygiene                                                                            |
| 23 | `check-image-updates`/ports audits: confirm nothing registers for the new module (expected: nothing) — one-time sanity, then close                                                                        | belt-and-braces                                                                              |
| 24 | Re-run `nix flake check --all-systems` from the Mac once, to prove the Linux-gated migrate-rust-cache app + module evals cleanly on darwin (flake-check omits darwin by default)                          | the documented darwin blind spot                                                             |
| 25 | After migration, re-baseline `df` dashboards/health-dashboard tiles if buildcache usage drops ~50G (tiles may show a step change worth annotating)                                                        | observability hygiene                                                                        |
| 26 | Queue a one-line AGENTS.md touch ONLY if the rust-cache split proves durable post-window (storage.md is the owner today; AGENTS buildcache routing line says "read docs/agents/storage.md" already)       | avoid premature memory writes                                                                |
| 27 | Extend the buildcache+rust-cache fixture test (TODO row fixed this session) to PATH-stub both inits in one harness                                                                                        | rides harvested item                                                                         |
| 28 | If more Rust projects appear, add them to `services.rust-cache.rustProjects` (drives init dirs + target symlinks) — check for Cargo.toml trees beyond monitor365                                          | config surface                                                                               |
| 29 | Consider whether `go-bin-salvage`/`.Trash-1000`-style KNOWN entries will be needed on /mnt/rust-cache (btrfs has no lost+found? — btrfs DOES create lost+found; already in KNOWN) — verify at first mount | small correctness check                                                                      |
| 30 | Post-window: update the decision doc's Status line from "awaiting maintenance window" to executed, with the commit/profile anchors                                                                        | decision-record hygiene                                                                      |

**Deliberately NOT harvested:** items 6-12, 16-17, 21-30 are either the owner's window/decisions, one-time post-migration verifications that only make sense AFTER the window, or already covered by existing queue rows (14). Harvesting them now would seed stale queue rows that pre-suppose an executed migration — the two source-of-truth rows (the setup row in `docs/todo/storage.md` + the decision doc) already carry them.

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **Window + ordering:** when do you want to run `nix run .#migrate-rust-cache && nix run .#deploy`, and do you accept a few days of cold rust/sccache rebuilds? (The config is inert until then; deploying WITHOUT migrating first leaves CARGO_HOME pointing at a nonexistent mount — shells self-heal via the fish guard, env-less tooling fails loudly.)
2. **CARGO_HOME placement:** the cargo registry (incl. private git deps + `credentials.toml`) now moves to the no-redundancy USB rust disk (same class as go-mod staying on buildcache). Keep it there, or would you rather the registry live on buildcache/go-mod-style and only target/+sccache move?
3. **Scope of Rust projects:** `monitor365` is the only entry carried over from the old buildcache list. Are there other Rust trees you actively build (dms-plugins? forgejo? something in ~/forks|worktrees) that should get `rustProjects` entries + target symlinks?

## Harvest record (authoring-time self-harvest)

- **Harvested now (5):** §f.1-§f.5 → `docs/todo/storage.md` library rows + matching `TODO_LIST.md` queue one-liners (Source pointers to this report). `check-todo-system.sh` structure-clean after.
- **Premise-drift fixes (2):** `TODO_LIST.md` buildcache-init fixture row + `af9b3ef2` deploy-proof row updated for the cargo/registry move (drift I introduced mid-session, caught at authoring).
- **Deliberately not harvested:** see the note under §f (post-window verifications + owner decisions would be stale queue rows today).

## Commit mapping (auto-commit daemon; short revs)

| Commit     | Contents                                                                                                                                                                                                      |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ff9c6053` | rust-cache.nix (new module) + home.nix rewiring                                                                                                                                                               |
| `6c32ad94` | buildcache.nix trim + configuration.nix + snapshots.nix + migrate-rust-cache.sh                                                                                                                               |
| `7b614182` | flake app + das-link-recovery-check.sh + deploy.sh                                                                                                                                                            |
| `0ebb6605` | storage.md + todo/storage.md doc updates                                                                                                                                                                      |
| `cb572682` | stray-unit-audit allowUnits entry                                                                                                                                                                             |
| `b01f5212` | ⚠ NOT THIS SESSION — another session's netbird work rode the daemon commit (netbird status report + TODO_LIST +4 + docs/todo/services.md). Flagged per shared-tree discipline; not verified or touched by me. |
| `695cef4a` | decision doc + buildcache.nix whitespace (treefmt) + btrfs-convert.sh superseded header                                                                                                                       |
| `143cdd4a` | hardware-configuration.nix comment fix                                                                                                                                                                        |

Uncommitted at report time: the §f harvest rows + TODO_LIST premise fixes + this report (daemon will sweep them).

_Arte in Aeternum_
