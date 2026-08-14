# Full Status Report: Build Cache SSD Setup — Deployed, One Unit Crash-Looping, Activation Incomplete

**Date:** 2026-08-14 18:29 CEST
**Session:** ~15:30 → 18:29 (~3h)
**System:** evo-x2, NixOS 26.11.20260812.867dcbc (Zokor)
**Session goal:** Wire SSD 1 (SanDisk SDSSDA240G, serial 174444471311) as the build-cache drive ("use nix as much as reasonable", "give the disk a good name"), migrate ~115 GB of caches off the QLC NVMe, monitor it, document it.

---

## Executive Summary

The build cache drive is **live and actively used**: `/mnt/buildcache` (ext4, named `buildcache`) holds 109 GiB / 1.47M verified files, env vars + HM symlinks are deployed (a live `golangci-lint` run was observed reading its cache from the SSD), metrics flow into node_exporter, and both Gatus checks are green.

**But the last deploy's activation is incomplete**: `buildcache-init.service` is crash-looping on a `chown: Operation not permitted` caused by MY `CapabilityBoundingSet` override (dropped `CAP_CHOWN`), which made `nh os switch` report failure (exit 4 class). Unit files ARE updated in `/etc/systemd/system`, but the deploy aborted before smoke checks, so full activation state is unverified. One-line fix pending (add `CAP_CHOWN`, or drop the override entirely — it's no longer needed since the preStart remount guard was removed).

Two earlier iterations were burned on an impossible idea (ext4 refuses `data=writeback` on remount — journal mode is fixed at mount time). The mount currently runs `data=ordered,commit=5` and will pick up `data=writeback,commit=120,lazytime` at the next reboot (a reboot is already pending for oomd thresholds + registry fix).

~75 GiB of migrated cache sources sit in the trash on a disk that is at 90%+ — one `trash-empty` away from the biggest single-space win available right now.

---

## a) FULLY DONE

1. **`services.buildcache` module** (`modules/nixos/services/buildcache.nix`) — options (`enable`, `mountPoint`, `device`, `wholeDiskDevice`, `rustProjects`, `usageThresholdPercent`), ext4 mount via `mkFilesystem` (`noatime,lazytime,data=writeback,commit=120,nofail,x-systemd.automount,x-systemd.device-timeout=10s`), init oneshot, metrics collector + 5-min timer. Auto-discovered as `flake.nixosModules.buildcache` (had to learn the `flake.nixosModules.<name> = { config, ... }: ...` wrapper form — bare NixOS modules fail `nix flake check`).
2. **Migration executed** — `nix run .#migrate-buildcache` (flake app, `scripts/migrate-buildcache.sh`): relabeled ext4 `ssd-ext4` → `buildcache`, mounted with production options, rsynced + verified **1,473,096 files / 109 GiB**: go-build (64 GiB), go-mod, golangci-lint, goimports, `~/.cache/go`, playwright, pip, npm `_cacache`, pnpm store, and `/rust-cache/monitor365` (source kept — partition reclaim is a follow-up). Sources trash-put (not deleted).
3. **Live-cache-tolerant migration** — two real failures fixed in-flight: rsync exit 24 ("files vanished" — go/gopls trimming mid-copy) and a growing source (gopls downloading during copy). Final script: 3-pass rsync convergence loop, superset verification for static dirs, cache-semantics (skip byte-equality) for live dirs.
4. **Env vars + HM symlinks deployed** (`platforms/nixos/users/home.nix`): `GOCACHE`, `GOMODCACHE`, `GOLANGCI_LINT_CACHE`, `PIP_CACHE_DIR`, `PLAYWRIGHT_BROWSERS_PATH`, `npm_config_cache`, `npm_config_store_dir` → `/mnt/buildcache/*`; `~/.cache/goimports` and `~/.cache/go` as `mkOutOfStoreSymlink`. NixOS-only (darwin untouched). **Evidence of function:** a running `golangci-lint` had its cache files open on `/mnt/buildcache` (8,17 device).
5. **Rust target symlinks rewired** (`platforms/nixos/system/snapshots.nix`): `~/projects/monitor365/target → /mnt/buildcache/rust/monitor365`; `services.buildcache.rustProjects = [ "monitor365" ]` is the single source (verified via eval). Old `rustCacheDirs` tmpfiles removed.
6. **Monitoring deployed** — `buildcache-metrics.service` writes `buildcache.prom` (mounted / smart_healthy / usage % / over_threshold / free / total bytes) **always**, even when the drive is absent (anti-stale-green design). Timer active. Verified live: `buildcache_mounted 1`, `buildcache_smart_healthy 1`, usage 57%. SMART via `smartctl -d sat` through the USB bridge.
7. **Gatus checks deployed** (`gatus-config.nix`, guarded by `buildcache.enable`): "Build Cache SSD" (mount+SMART) and "Build Cache Usage" (>85%) with actionable Discord alert text (including the revert path if the drive dies). Both in the endpoint list (eval-verified).
8. **smartd extended** (`configuration.nix`): both SanDisk SSDs via stable `ata-SanDisk_SDSSDA240G_<serial>` by-id paths with `-d sat`, alongside the NVMe. Eval-verified 3 devices.
9. **Docs updated** — AGENTS.md: new "Build Cache SSD" section (device identification, no-TRIM-through-bridge + reformat procedure, failure modes, corruption tolerance, /rust-cache follow-up); CHANGELOG.md [Unreleased] entry; FEATURES.md (System Reliability table row); TODO_LIST.md (2 new items: Docker-on-SSD-2, p9 reclaim; disk-space item now mentions `trash-empty` ~75 GiB).
10. **Pre-deploy check allowlist** — `buildcache_mounted/smart_healthy/usage_over_threshold` added to `KNOWN_NEW_METRICS` in `scripts/pre-deploy-check.sh` (bootstrap pass-through; to be removed after first green post-deploy run shows them in `/metrics` — they ARE live now, so removable).
11. **All eval checks green** — `nix flake check --no-build` passes; targeted evals confirmed mount options, rustProjects merge, smartd devices, gatus endpoint names, HM vars, symlinks, tmpfiles.

## b) PARTIALLY DONE

1. **Deployment of the final config** — 4 deploy attempts: (1) blocked by pre-deploy phantom-metric check (fixed via allowlist); (2) activated BUT `buildcache-init` lacked `wantedBy` → never ran → dirs not stamped; (3) blocked by failed unit (my preStart remount guard failed: automount path not yet mounted + `FS_OPTIONS` column typo); (4) preStart removed, unit file IS in `/etc/systemd/system` (new gen partially applied), but init crash-loops on `chown: Operation not permitted` → `nh os switch` exit 1, deploy.sh aborted before post-deploy smoke checks. **State: mount/metrics/timer/gatus/HM live, init failing, full activation unverified.**
2. **ext4 writeback options** — fstab is correct, but systemd adopted the migration's manual mount; live consumers (golangci-lint) hold the mount busy so the unit cannot cycle; ext4 kernel state is still `data=ordered,commit=5`. Applies at next reboot (already pending for other reasons).
3. **End-to-end build verification** — NOT yet run: no `go build` / `cargo build` in a NEW terminal with the new env vars. golangci-lint using the SSD is strong indirect evidence, but a cold `go build` + `cargo build` is the real test.

## c) NOT STARTED

1. `trash-empty` — ~75 GiB of migrated sources in trash on a 90%+ full QLC NVMe (the single biggest immediate space win).
2. Reboot (activates `data=writeback`; also oomd 60%/30s, registry override, niri outputs — pre-existing TODO).
3. Docker data-root → SSD 2 (btrfs) — TODO'd with full plan, nothing wired.
4. `/rust-cache` p9 partition reclaim (100 GiB) — TODO'd.
5. Removing the `KNOWN_NEW_METRICS` allowlist entries now that the metrics are live.
6. VM test for the buildcache module (none of the SystemNix modules have one for this; pattern exists in `tests/`).

## d) TOTALLY FUCKED UP

1. **`CapabilityBoundingSet = "CAP_SYS_ADMIN"` override on `buildcache-init`** — I overrode harden()'s empty set for the (since-deleted) remount preStart and thereby **dropped `CAP_CHOWN`**: root cannot chown → init crash-looped → **blocked two consecutive `nh os switch` activations** (exit-4 class, the exact pattern documented in AGENTS.md: failed unit blocks switch-to-configuration). The override is pointless now (preStart removed) and must be deleted or extended with `CAP_CHOWN CAP_DAC_OVERRIDE CAP_FOWNER`. Classic case of a workaround outliving its reason.
2. **The remount-guard idea itself** — 2 iterations wasted trying to `mount -o remount,data=writeback`. ext4 journal data mode CANNOT be changed on remount; it is fixed at mount time. I should have known/collapsed this to "umount + mount" (then discovered the busy-holder) or simply "reboot applies fstab" immediately.
3. **Deployed a never-tested unit script twice** — neither the chown failure nor the `FS_OPTIONS` typo nor the wantedBy omission would have survived a 10-second `systemd-run --wait` smoke test of the exact unit script. I verified eval output extensively but runtime not at all — then paid 3 deploy cycles for it.
4. **Left the failed unit to poison subsequent deploys** — after deploy (2) failed I diagnosed via ad-hoc scripts but did not `reset-failed` + re-run init cleanly before the next deploy, so the failed state carried into the next switch.

*(Also observed, not mine, not investigated: `nix-build-cleanup.service` is in failed state — pre-existing or collateral; needs a look.)*

## e) WHAT WE SHOULD IMPROVE (session lessons)

1. **Runtime-test unit scripts before deploy** — `systemd-run --wait --property=... <script>` or at least executing the script body as root in a shell. Eval-green ≠ runs-green. This session: 3 of 4 deploy failures were runtime-only bugs.
2. **A failed unit must be cleared (reset-failed + fix + start) BEFORE the next `nh os switch`** — otherwise every subsequent deploy aborts at activation. Consider adding "no failed units" to `pre-deploy-check.sh` (it currently doesn't check).
3. **Don't override `CapabilityBoundingSet` for one capability you think you need** — enumerate the FULL set the script needs, or drop the override. The empty-set default exists precisely so services fail loudly instead of half-working.
4. **Filesystem options that differ between fstab and an adopted live mount need a mount-unit cycle or reboot** — remount cannot change ext4 journal mode. Design migrations to unmount at the end so systemd owns the mount from the first boot.
5. **Live caches need convergence-style copy** — du/rsync byte-equality checks against a source that gopls is actively rewriting will always fail. Cache semantics: verify superset/static dirs strictly, live dirs loosely.
6. **Bootstrap chicken-and-egg for new metrics** is now a handled pattern (KNOWN_NEW_METRICS) — but the entries must be pruned once live, or they silently mask real phantoms later. Add pruning to the post-deploy checklist.
7. `findmnt` column is `FS-OPTIONS` (hyphen), not `FS_OPTIONS` — cost a round trip; test snippets before embedding in units.

## f) NEXT — up to 50 things, ordered

**Immediate (unblocks everything):**
1. Fix `buildcache-init.service`: delete the `CapabilityBoundingSet` override (or add `CAP_CHOWN CAP_DAC_OVERRIDE CAP_FOWNER`), keep `wantedBy`, `nix flake check`, redeploy.
2. `sudo systemctl reset-failed buildcache-init nix-build-cleanup` before/with that deploy.
3. Verify init succeeds: `.initialized` stamp exists, dirs owned `lars:users`.
4. Re-run `nix run .#deploy` to complete activation + post-deploy smoke checks (8 failures last full run need triage — several were pre-existing: Overview 503, unreachable vHosts).
5. Investigate `nix-build-cleanup.service` failure (not mine, in failed list).

**Reclaim space (disk at 90%+):**
6. `trash-empty` (~75 GiB) after build verification.
7. `nix-collect-garbage --delete-older-than 7d`.
8. Re-check "Root Disk Usage" Gatus alert state after 6+7 (should go green if <85%).

**Verify the actual purpose (builds on the SSD):**
9. NEW terminal: `cd ~/projects/SystemNix && go build ./...` → confirm artifacts land in `/mnt/buildcache/go-build` (du before/after).
10. `cd ~/projects/monitor365 && cargo build` → confirm via `readlink target` + du on `/mnt/buildcache/rust/monitor365`.
11. `pnpm store path` / `npm config get cache` in new shell → confirm env vars win.
12. Watch `buildcache_usage_percent` over a day (was 57% after migration; sanity-check growth).

**Reboot (pending anyway):**
13. Reboot evo-x2 → verify `/proc/fs/ext4/sdb1/options` shows `data=writeback,commit=120` (plus lazytime), automount works from cold boot, oomd 60%/30s active, registry override active.
14. After reboot: confirm mount unit (not adoption) owns `/mnt/buildcache`; `x-systemd.idle-timeout` NOT set here — decide if idle-unmount is wanted (probably NOT for a cache: churning mounts hurt).

**Hardening/cleanup of this feature:**
15. Remove the 3 `buildcache_*` entries from `KNOWN_NEW_METRICS` (metrics are live).
16. Remove `.initialized`-condition edge: if mount wiped, init reruns — good; add a Gatus condition or leave as-is (documented).
17. Add "no failed units" check to `pre-deploy-check.sh`.
18. Consider a `tests/test-buildcache.nix` VM test (mount + init + metrics file emission) following `test-attic.nix`.
19. Update `docs/status/2026-08-14_13-15_ssd-repurposing-options.md` with an "IMPLEMENTED" annotation pointing at the module (docs-health: old status reports should reflect outcome).
20. Add `/mnt/buildcache` mention to `disk-diagnose.sh` inventory script if it lists mounts.

**SSD 2 + follow-ons (from TODO):**
21. Docker data-root → SSD 2: rename mount to `/mnt/docker`, add `fileSystems` entry, migrate `/data/docker`, keep SigNoz/ClickHouse volumes on `/data`.
22. `/rust-cache` p9 reclaim (100 GiB): empty, drop `fileSystems."/rust-cache"`, delete partition, optionally grow adjacent BTRFS.
23. Off-site backup (Priority 0, untouched since 2026-06-25 — biggest real risk on this machine).
24. Foreground BTRFS scrub on `/` (never scrubbed).
25. dnsblockd `ManagedOOMPreference=omit`.

**Pre-existing carryovers visible in this session's outputs:**
26. Overview service 503 (post-deploy smoke FAIL).
27. signoz.home.lan 404 auth-gateway WARN; several vHosts unreachable (dozzle/monitor365/searx/crush/taskchampion SKIP) — likely LAN-vs-external check artifact, verify once.
28. Fish startup 260ms > 200ms threshold WARN.
29. Quickshell 1 error line in last 1h WARN.
30. smartd devices: consider adding the two DAS HDDs (sda/sdd `usb-External_USB3.0_DISK00/04`) if they're permanent — currently unmonitored.

## g) QUESTIONS (cannot determine myself)

1. **Reboot timing:** a reboot is now doubly pending (oomd thresholds + registry + ext4 `data=writeback`). It also interrupts whatever is running (golangci-lint was mid-run on the new cache). When do you want it — now after the init fix, or tonight/idle-time?
2. **`trash-empty` now or after your own build verification?** ~75 GiB on a 90% disk says now; "I want to eyeball a green `go build` first" says wait. Your risk call (trash is on the same nearly-full disk, so it isn't free space yet either way).
3. **SSD 2 (Docker) — proceed to implement now, or park it until the p9/rust-cache reclaim and reboot are done?** Both orderings are defensible; it's a prioritization call.

---

*Sources this session: docs/status/2026-08-14_13-15_ssd-repurposing-options.md (analysis), docs/status/2026-08-14_12-30_ssd-recovery-benchmarking-session.md (benchmarks), live system via /tmp scripts (bc-verify, bc-diag, bc-state).*

---

## h) COMPLETION ADDENDUM (2026-08-14 ~20:00, same day follow-up session)

The blocker, verification, and all three questions were resolved by a follow-up session the same evening ("execute and verify one step at a time; keep going until everything works").

**Resolved:**

- **Blocker fixed** — `buildcache-init` now grants exactly `CAP_CHOWN CAP_FOWNER CAP_DAC_OVERRIDE` (the `CAP_SYS_ADMIN` override replaced `harden {}`'s set and dropped `CAP_CHOWN`). Also added the missing `startLimitBurst/IntervalSec` and a `ConditionPathIsMountPoint` guard (prevents root-fs `mkdir` contamination if the automount is ever dead while the drive is absent). Unit ran clean: `.initialized` stamped, dirs `lars:users`.
- **Question 1 (reboot)** — scheduled for the end of the follow-up session (see below).
- **Question 2 (trash-empty)** — done, with a correction: the "~75 GiB in trash" claim above was WRONG. Most migrated sources were still in place on the NVMe (~34.5G: go-build 22G, golangci-lint 5.1G, go/pkg/mod 4.3G, .npm 3.1G — long-lived pre-env-change processes kept writing them). All removed + all trash emptied (Go's 0555 mod-cache dirs needed `chmod -R u+w`). Root fs 90-93% → **86%** (~18 GiB reclaimed).
- **Question 3 (Docker→SSD 2)** — parked in TODO_LIST (pre-existing item); the follow-up session stayed scoped to making the build-cache setup + everything it touched work.
- **Cold-build verification** — full `go build ./...` green against `/mnt/buildcache` (needs `GOEXPERIMENT=jsonv2` on this toolchain); rust `target` symlink write-probe green; go/goimports/pnpm-store symlinks resolve to the SSD; **pnpm 11 does NOT honor `npm_config_*` env vars or .npmrc for `store-dir`** (found empirically) — store now redirected via `~/.local/share/pnpm/store` HM symlink instead.

**Incidents found and fixed while verifying (not buildcache bugs, but they blocked the deploy/smoke):**

- **PMA discovery-daemon starvation (root cause of the 21h Overview-503 + a blocked switch)** — the daemon goroutine starves in direct reclaim pinned at the 6G `MemoryHigh` ceiling; socket accepts but never answers. Hung 3x in one day (21h, 9 min, 5 min after restarts). Fixes: ceiling retuned `MemoryHigh 6G→12G` / `MemoryMax 8G→16G` (scan working set outgrew the 2026-08-09 ceiling; pre-incident scans ran under a 16G max), `PMA_DISCOVERY_WORKERS=2`, and a new `pma-daemon-watchdog` (5-min liveness probe, restart after 2 fails 30s apart). **Validated:** 16/16 healthy probes over 13 min, memory peaked 6.7G (above old ceiling — diagnosis confirmed), settled ~5.2G, 0 restarts. Upstream root-cause fix + env-quoting fix filed in TODO_LIST.
- **Overview `StartLimitBurst=` systemd warning** — upstream placed `StartLimit*` in `serviceConfig`, and SystemNix's `lib.mkForce null` neutralization renders as an EMPTY key (nixpkgs `attrsToSection` `toString`s null — it is never filtered; deleting a key via null is impossible). Upstream fixed (`LarsArtmann/overview@a9321f0`, committed locally, push+bump pending), SystemNix null-hack deleted.
- **browser-history-agent start-limit-hit during deploy windows** — the 60s server-wait gate aborted during the server's ~5-min projection drain, and `startLimitBurst=2` bricked the agent until manual reset. Gate extended to 7 min (`TimeoutStartSec=9min`); burst deliberately kept at 2 (WDT crash-loop protection).
- Pocket-id 3× SQLITE_BUSY errors (19:22-23, transient under the PMA-flap IO churn window; self-resolved).

**Remaining known state at session end:** Monitor365 smoke failures are the deliberate disable (upstream Rust workspace issue — unchanged); browser-history needs ~5 min after every deploy restart (no persistent checkpoint store — pre-existing TODO); `~/.npm`/`.cache`/`go`/`.cargo` subvolume automounts + p9 partition reclaim parked in TODO_LIST; overview flake input bump pending push of `a9321f0`.

**Reboot:** scheduled at end of session with `shutdown -r` (+cancellable). Activates: `/mnt/buildcache` mount options (`data=writeback,commit=120,lazytime` — the live mount still runs `data=ordered,commit=5` from the migration's manual mount; ext4 journal mode cannot be changed via remount), oomd 60%/30s, registry override. Post-reboot verify: `tr ' ' '\n' < /proc/fs/ext4/sdb1/options | grep -E '^(data|commit)='`, `buildcache_mounted 1` in `:9100/metrics`, `.initialized` still present (init is a no-op), golangci-lint/go builds continue writing to the SSD.
