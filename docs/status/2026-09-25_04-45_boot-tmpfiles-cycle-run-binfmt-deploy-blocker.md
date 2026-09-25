# Boot-time tmpfiles cycle → /run/binfmt missing → ALL builds/deploys wedged (2026-09-25 night session)

**Session scope:** user pasted a failing `nh os switch . -v --show-activation-logs --keep-going` (02:43) with
`error: getting attributes of path "/run/binfmt": No such file or directory`. Goal: root-cause, fix, deploy.

---

## Root cause (proven, not theorized)

1. **Symptom layer:** the error is NOT module eval — it is **build-sandbox setup** (`--show-trace` shows
   `while setting up the build environment`). evo-x2 runs `boot.binfmt.emulatedSystems = [ "aarch64-linux" ]`
   (boot.nix:143) with a non-fixBinary interpreter, so nixpkgs' binfmt.nix adds `/run/binfmt` to
   `nix.settings.extra-sandbox-paths` (live in `/etc/nix/nix.conf`). The nix-daemon stat()s + bind-mounts
   every extra-sandbox-path into each build sandbox → **one missing dir kills EVERY sandboxed build on the
   box**, including pure-x86 builds that never touch emulation.
2. **Failure layer:** `/run/binfmt` (plus `/run/systemnix/sev1`, `/run/lock/*`, `/run/lvm`,
   `/run/emeet-pixyd`) was **never created this boot**: the main tmpfiles pass did not run.
3. **Cause layer:** tonight's 22:34 boot was the **FIRST boot since hot-user-caches deployed**
   (system-797, Sep 22 15:36 — no reboot between deploy and boot; boot -1 ran Sep 20 04:16 → Sep 24 22:29,
   predating the module). At boot, the fstab automount (`home-lars-.cache-nix.automount`) +
   `hot-user-caches-nix-bootstrap` (before=/wantedBy on the automount) +
   `systemd-tmpfiles-setup.service` (upstream `After=local-fs.target`) close an ordering cycle, and
   systemd's cycle breaker **DELETED the tmpfiles start job** (journal 22:35:09 + 22:35:10:
   "Job systemd-tmpfiles-setup.service/start deleted to break ordering cycle").
4. **The 2026-09-20 fix was insufficient:** `DefaultDependencies=false` on the bootstrap (deployed,
   verified in the live unit file) cures only the *activation*-time cycle; the *boot*-time cycle survives
   through the automount's own edges.

### Evidence chain
- `journalctl -b 0 -u systemd-tmpfiles-setup` — the 22:34:56 "Starting/Finished" is the **initrd**
  instance (detection trap); real-root instance: only the two cycle/job-deletion messages.
- `/run/systemd/units/` has `invocation:` entries ONLY for `-dev`/`-dev-early` tmpfiles passes.
- sev1-bridge failed 226/NAMESPACE (`/run/systemnix/sev1` missing) on its FIRST run 22:35:55 —
  **2901 failures since**; zero such failures in boot -1.
- Kernel binfmt registration exists (22:35) — non-fixBinary registrations store the interpreter path as a
  string; does NOT prove the dir/symlink existed.
- Deployed generation unchanged: system-797 (Sep 22) ran healthy through boot -1; only the boot event is new.
- Secondary blocker discovered: `nix flake check` / toplevel build force an **IFD** (crane
  `vendorCargoDeps` reads `Cargo.lock` from the storage-collector prepared-source output, GC'd by the
  00:00 nightly gc) → even eval-realizing paths need the sandbox.

## Fixes landed in-repo (committed via daemon as af87ce31 + later batch)

| Layer | File | Change |
| --- | --- | --- |
| Root cause | `modules/nixos/services/hot-user-caches.nix` | bootstrap now `wantedBy`/`before` the on-demand **`.mount`** (`home-lars-.cache-nix.mount`) instead of the `.automount` — removes all our edges from the boot transaction; subvol is created just before the first real mount (the only moment it is needed). Eval-verified. |
| Belt (per-switch) | `scripts/deploy.sh` | post-switch heal `sudo systemd-tmpfiles --create --remove --exclude-prefix=/dev` (NO `--boot`: boot-only `D! /tmp` must stay boot-only or every deploy wipes /tmp). |
| Regression pin | `tests/test-hot-user-caches.nix` (NEW) + `tests/default.nix` | VM test asserts `systemd-tmpfiles-setup.service` active + a probe tmpfiles rule APPLIED after boot (only an actual boot catches transaction cycles), then automount→bootstrap→subvol→mount flow + writes landing on the hot disk. Drv evals green. |
| Docs | `AGENTS.md` | the 2026-09-20 gotcha extended with the boot-cycle mechanism, detection traps, fix rules, manual-heal command. |
| Belt (per-boot, parallel session) | `platforms/nixos/system/boot.nix` (d827f478, NOT mine) | `binfmt-sandbox-dir` oneshot mkdirs `/run/binfmt` at multi-user.target, gated to binfmt-enabled hosts, no ordering edges. Complementary, no conflict. |

## CURRENT BLOCKER (unchanged for ~50 min)

`/run/binfmt` still absent (04:43). Recreating it needs **one root command**; this session's sandbox
denies `sudo`/`systemctl` (hard "command is not allowed"), `trusted-users = root` makes nix client
overrides ignored (verified), and I will not route around the permission gating. Self-serve attempts
(NIX_CONFIG, `--option`, a buildless heal deploy from an outPath-identical worktree at b186133e) all
failed on the same sandbox setup — legitimately expected in hindsight.

**Required (user):** `sudo systemd-tmpfiles --create --remove --exclude-prefix=/dev`
(or `sudo systemctl start systemd-tmpfiles-setup.service`). Asked via the question tool at ~04:20;
user answered "yes" but the heal has NOT landed (no journal entries, dirs still missing, 04:43).

## Report card (self-assessment)

### a) FULLY DONE
- Root cause identified with a complete, timestamped evidence chain (incident class: boot-transaction
  ordering cycle deleting a boot-critical unit's start job).
- Module fix implemented + eval-verified (`wantedBy = [ "home-lars-.cache-nix.mount" ]`).
- deploy.sh per-switch heal added.
- VM regression test written, registered, eval-green (drv `xw073cqyg…`).
- AGENTS.md gotcha updated with mechanism + traps + heal runbook.
- False leads closed with evidence (storage-collector module innocent; no `/run` deleter — dirs were
  never created; tmp-cleanup innocent; nixpkgs binfmt.nix innocent).

### b) PARTIALLY DONE
- Verification: eval-level done; **VM test not RUN** (needs sandbox), red-run control (revert wiring →
  expect test failure) not performed.
- `nix flake check --no-build` not run (blocked by the IFD realization needing sandbox).
- Deploy not executed (blocked).

### c) NOT STARTED
- The actual deploy of the fix (and the pending Sep-24 18:22 flake.lock bump era behind it — the deploy
  will be a heavy first build; expect duration and pressure-gate interactions).
- Post-deploy verification (anchor check, sandbox probe without overrides, sev1-bridge green).
- Red-run control of the VM test.
- Reboot validation (the true end-to-end proof of the cycle fix; VM test is the proxy meanwhile).

### d) TOTALLY FUCKED UP (honest)
- **The heal stall:** user answered "yes" at ~04:20; I polled passively for 20+ minutes without a crisp
  re-prompt. The critical path sat idle.
- ~10 min on the storage-collector/red-herring trail before running `--show-trace` — the "setting up the
  build environment" line was visible in the user's original paste; the trace should have been step 1.
- Two worktree heal-deploy attempts that were foreseeable to fail (ANY nix realization needs the
  sandbox; the first dry-run's empty plan was an eval-cache mirage, not a build plan).
- Question-tool call rejected once on the 600-char description limit (minor).

### e) WHAT TO IMPROVE
- When a build error's trace says "setting up the build environment", diagnose the SANDBOX first
  (extra-sandbox-paths in /etc/nix/nix.conf), the config second.
- When the resolution path requires a user action, confirm EXECUTION (journal/dir probe), not intent —
  re-prompt within minutes, not tens of minutes.
- Boot-transaction cycles are invisible to eval; every module that adds ordering edges near
  local-fs/sysinit should ship with a boots-the-VM regression test in the same change.

### f) NEXT (roughly ordered)
1. User runs the heal command (or grants this session sudo) — everything unblocks.
2. Verify: `/run/binfmt` + `/run/systemnix/sev1` exist; sev1-bridge green within 10s tick; sandbox probe
   build succeeds.
3. Run `tests/test-hot-user-caches.nix` (green with fix).
4. Red-run control: flip the module wiring back to the automount, rebuild the test, expect the tmpfiles
   assertion to fail, restore (proves the tripwire catches the original bug).
5. `nix flake check --no-build` (full eval incl. the new test + parallel session's boot.nix unit).
6. Review + co-verify the parallel session's `binfmt-sandbox-dir` unit (it will ride the same deploy).
7. Deploy `nix run .#deploy` (pressure gate aware; rc=12 → retry when calm; rc=14 → re-run after fixing
   failed units).
8. Post-deploy: anchor check (`readlink` profile vs current-system), sandbox probe, sev1-bridge green.
9. Cross-reference the parallel session's "boot-regression" doc (commit c3b0aad6) — likely this same
   22:34 boot; link the reports.
10. Consider `boot.binfmt.preferStaticEmulators = true` as a follow-up (drops /run/binfmt from
    extra-sandbox-paths entirely; needs reboot to activate the F-flag registration).
11. Check why `notify-failure@sev1-bridge` did(n't) page Discord 2900× (alert fatigue / channel health).
12. Verify `systemctl is-enabled hot-user-caches-nix-bootstrap` still satisfies deploy.sh's provisioner
    gate after the wantedBy change (mount-wantedBy vs automount-wantedBy).
13. First post-fix REBOOT: confirm tmpfiles-setup active + all /run dirs present (the real proof).
14. The io-psi-forensics bundle from 22:37 (`/var/tmp/io-psi-forensics-20260924T203744Z`, guard Zone 6
    trip during boot IO storm) is unanalyzed — boot was stormy; unrelated to the cycle but worth a look.
15. `pre-reboot-check` before that reboot (house rule).

### g) QUESTIONS I CANNOT ANSWER MYSELF
1. Did the heal command actually run (or fail)? I see no journal trace and the dirs are still missing —
   if it errored, paste the output.
2. Is `sudo` denial in this session intentional? AGENTS documents agents using sudo routinely (sops
   one-liners, systemctl restarts); this session's profile blocks it. Enable it and I finish fully
   autonomously.
3. Should `boot.binfmt.preferStaticEmulators = true` ride this deploy or a separate follow-up? It
   changes the binfmt registration flavor (F-flag static qemu) and only takes effect after a reboot —
   owner call on blast radius vs. this deploy staying minimal.
