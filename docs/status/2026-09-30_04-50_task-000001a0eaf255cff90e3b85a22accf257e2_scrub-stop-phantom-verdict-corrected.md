# Task close-out — Guard scrub-stop phantom (000001a0eaf255cff90e3b85a22accf257e2)

**Task:** TODO_LIST "Guard scrub-stop may be a PHANTOM … verify + make the guard cancel scrubs" (Source: docs/status/2026-09-29_01-45 §e.2). Session 2026-09-30 ~04:00-05:00. All findings live/eval-verified; nothing deployed (deploy stays owner-run).

## Verdict — CORRECTED, not as claimed

The churn-stop WAS a phantom, but the claimed mechanism is wrong for this config:

1. **The deployed `btrfs-scrub@` template (nixpkgs) already carries the kernel-side cancel**: `Type=simple` + `ExecStop=btrfs-scrub-maybe-cancel %f` (runs `btrfs scrub cancel`, rc=2 tolerated) — read from `/etc/systemd/system/btrfs-scrub@.service` on system-800. `systemctl stop` on a correctly-named instance kills the CLI waiter AND then runs ExecStop, which cancels the kernel scrub. The "stop only kills the CLI waiter" premise holds only for a bare `btrfs scrub start -B` (or a oneshot unit, where ExecStop is not used — the nixpkgs comment is explicit).
2. **The real bug was unit names**: the guard's `ioChurnUnits` named the STRAY unit files `btrfs-scrub--`/`btrfs-scrub-data`/`btrfs-scrub-mnt-pool` — unit FILES rendered from snapshots.nix's ExecStart override, which systemd never starts (the weekly timers pull the template instances `btrfs-scrub@-`/`@data`/`@mnt-pool`, confirmed via `systemd.targets.timers.wants` + the live service-health listings naming `btrfs-scrub@data.service`). Every trip's scrub stop was a silent no-op — that, not a cancel failure, is why the 2026-09-28 storm scrub read 5.9 TB through ~100 trips.
3. **Sibling bug, same root cause**: the scrubGuard deferral override documented live in AGENTS.md since 2026-08-31 was dead the whole time (same stray attrnames). The weekly scrub that fired into the Sep 26-28 storm ran RAW. (Explains "no completed scrub since Aug 31" in the /data gate-b history too.)

## Landed (all in-tree, daemon-committed)

- `memory-emergency-guard.nix`: ioChurnUnits → the three template instances; churn re-arm now EXCLUDES `btrfs-scrub@*.service` (no-resume doctrine, the freeze-#7 loop) with a disclosure line; a guard-side `btrfs scrub cancel` was REJECTED — the guard unit deliberately lacks CAP_SYS_ADMIN (BTRFS_IOC_SCRUB_CANCEL ioctl), and the template's ExecStop already provides the cancel in the scrub unit's own sandbox.
- `snapshots.nix`: scrubGuard ExecStart override moved onto the template (`"btrfs-scrub@".serviceConfig.ExecStart` with `%f` — systemd expands %f to the mountpoint per systemd.unit(5), keeping the wrapper's argument contract). Stray unit definitions disappear from the config (verified by eval: services list now has only `btrfs-scrub@`).
- `tests/test-memory-emergency-guard.nix`: dummy `btrfs-scrub@` template (Type=simple + ExecStop marker); scenario 8 proves the trip stops the INSTANCE and runs its ExecStop cancel; scenario 8a proves the re-arm restarts the balance unit but leaves the scrub instance dead.
- Docs: AGENTS.md (BTRFS §Scrub correction + Zone-6 churn-stop semantics + freeze-#7 entry), `docs/services/memory-emergency-guard.md` runbook, TODO_LIST + `docs/todo/stability.md` close-outs (3 rows done), 1 new [ready] backlog item (eval-time stray-unit lint).

## Verification

- `nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel.drvPath` green (all eval-time audits over the changed modules).
- `nix flake check --no-build` green; guard script derivation builds (shellcheck) and the built script carries the instance names + case-skip + disclosure line (`bash -n` OK).
- Rendered `btrfs-scrub@.service` verified: guard ExecStart with `%f`, ExecStop cancel preserved, Type=simple.
- VM test (`checks.x86_64-linux.memory-emergency-guard`): deferred to the first quiet-IO window — the session ran mid-storm (io PSI some avg60 42-60%); running a qemu VM test into that is the freeze-7 reader-stacking class. Driver build green.

## Deploy notes (owner-run)

- The changed template unit file will make switch-to-configuration restart the currently-FAILED `btrfs-scrub@-`/`@data` instances — ExecStart (scrubGuard) then re-checks PSI/zram/heavy-readers at start, so a pressured box defers. Expect the chronic-FAIL exit-4 hazard (01-45 §f.12) once at most; the SuccessExitStatus=[1] follow-up (already in another lane) further defuses it.
- After deploy: next trip's churn-stops actually cancel scrubs; post-storm re-arms restore btrbk/balance but NOT scrubs (weekly timers own their resume; gap is Gatus-visible via the never-finished btrfs-health metrics).
