# Status: Hyprland Removal + Mass vendorHash Fix + Successful Boot Deploy

**Date:** 2026-08-05 22:02  
**Session scope:** Started from "why do we have hyprland-0.56.1?!" → discovered grimblast leftover → removed it → boot-deploy exposed 8 Go vendorHash mismatches → fixed all upstream → deployed successfully.  
**Overall verdict:** DEPLOY SUCCEEDED. hyprland-0.56.1 and all 10 hypr* dependencies purged from system closure (-122 MiB, 3850→3824 paths).

---

## The user's question

> hyprland-0.56.1 <-- why do we have it?!??!

**Answer:** `grimblast` (a Hyprland screenshot wrapper) was still in `platforms/nixos/users/home.nix:229`. It was a leftover from the Hyprland→Niri→DMS migration. Screenshots already work via `grim + slurp + swappy` configured in `niri-wrapped.nix`. The entire Hyprland package set (hyprland, hyprcursor, hyprgraphics, hyprland-qt-support, hyprland-qtutils, hyprlang, hyprpicker, hyprutils, hyprwire) was being pulled in transitively — **~70 MiB** of dead weight.

---

## a) FULLY DONE

| # | Item | Detail |
|---|------|--------|
| 1 | **grimblast removed** | `platforms/nixos/users/home.nix:229` — eliminates hyprland-0.56.1 + all hypr* deps from system closure |
| 2 | **8 upstream vendorHash fixes** | Committed + pushed to 8 repos: emeet-pixyd (2 commits — package.nix + goBrandedSrc param fix), crush-daily, mr-sync, md-go-validator, go-humanize-linter, branching-flow, hierarchical-errors. BuildFlow was already fixed upstream (lockfile was stale). |
| 3 | **SystemNix flake.lock updated** | All 8 inputs updated to new upstream revs. nixpkgs confirmed GitHub `e72e4f299401`. Zero tarball-type nodes. |
| 4 | **hermes-agent follows restored** | My earlier session wrongly removed `inputs.nixpkgs.follows` to fix a phantom eval error. The real cause was a corrupted root nixpkgs rev (0954f7ee from hermes's pinned nixpkgs leaked into root). Reverted. |
| 5 | **nixpkgs node restored** | Root nixpkgs node was rewritten to tarball by `nix flake update` (user's `nix flake update -v` paste showed this clearly). Fixed via Python script to restore GitHub type. |
| 6 | **Pre-commit guard active** | `.githooks/pre-commit` now rejects tarball-type nixpkgs before any commit can land |
| 7 | **Darwin registry override** | `platforms/darwin/nix/settings.nix` mirrors the NixOS `nixpkgs/nixos-unstable` override |
| 8 | **Boot deploy succeeded** | `nh os boot . --keep-going` → 202 built, 0 failed. 3850→3824 paths, -122 MiB. hyprland-0.56.1 confirmed removed in diff output. |
| 9 | **PMA vendorHash from prior session** | The upstream PMA fix (vendorHash `sha256-mWaq...`) was already pushed as `34b62ceb`. Lockfile updated in earlier part of session. |
| 10 | **hierarchical-errors cloned** | Cloned `LarsArtmann/hierarchical-errors` to `~/projects/` to fix vendorHash locally. |

### Deploy diff (key removals)

```
[R.] grimblast          0.1-unstable-2026-06-30, -19.0 KiB
[R.] hyprcursor         0.1.13-lib, -502 KiB
[R.] hyprgraphics       0.5.1, -288 KiB
[R.] hyprland           0.56.1, -67.4 MiB
[R.] hyprland-qt-support 0.1.0, -766 KiB
[R.] hyprland-qtutils   0.1.5, -769 KiB
[R.] hyprlang           0.6.8, -338 KiB
[R.] hyprpicker         0.4.7, -486 KiB
[R.] hyprutils          0.14.0, -562 KiB
[R.] hyprwire           0.3.1, -962 KiB
PATHS: 3850 -> 3824 (+243, -269)
SIZE:  50.6 GiB -> 50.5 GiB
DIFF:  -122 MiB
```

---

## b) PARTIALLY DONE

| Item | Status | What remains |
|------|--------|--------------|
| **Pre-commit guard** | Active in `.githooks/pre-commit` | Only protects manual `git commit`. The auto-commit daemon (PMA) runs `nix flake update` + `git commit` and bypasses this hook (or uses its own). The daemon can still commit a tarball regression. |
| **Registry override (NixOS)** | Deployed as boot profile (not `switch`) | The new boot profile has the registry override, but it's not active until reboot. The currently running system still uses the old registry. |
| **Registry override (Darwin)** | Written in config | Not deployed to macOS. Needs `nix run .#deploy` from the Mac or `darwin-rebuild`. |

---

## c) NOT STARTED

| # | Item |
|---|------|
| 1 | Reboot evo-x2 to activate the new boot profile (registry override takes effect) |
| 2 | Deploy to macOS (Darwin registry override) |
| 3 | Add tarball guard to CI / flake checks (the eval-time `nixpkgsTarballGuard` in `flake.nix:524-534` catches it, but a `nix flake check` step in CI would prevent merge) |
| 4 | Investigate whether the PMA auto-commit daemon can add `--no-use-registries` or `--override-input` to its `nix flake update` command to prevent tarball rewrites at the source |

---

## d) TOTALLY FUCKED UP (mistakes this session)

### 1. Wrong hermes-agent diagnosis → corrupted root nixpkgs rev

**What happened:** When `nix flake check` failed with `path 'ka5bsg1p80h9b4hdamskxc2ldf9mwmks-hermes-python-source' is not valid`, I misdiagnosed it as a hermes-agent/nixpkgs incompatibility and removed `inputs.nixpkgs.follows` from hermes-agent in `flake.nix`.

**What actually happened:** Removing the `follows` caused hermes-agent's own pinned nixpkgs (`0954f7ee2f6b`) to become the **root** `nixpkgs` node in the lockfile (via `original.ref` resolution). This silently downgraded the entire system from Aug 2026 nixpkgs to Jul 29 nixpkgs. The hermes-python-source path error was a **store DB issue** caused by the corrupted nixpkgs rev changing the `cleanSourceWith` filter hash — NOT a real incompatibility.

**Fix:** Reverted the follows removal + restored root nixpkgs to `e72e4f299401` via Python script.

**Lesson:** When `nix flake check` reports a store path as "not valid", first check `nix-store --query --hash <path>` — if it returns a hash, the path IS valid and the error is an evaluation artifact, not a real build problem. I wasted ~15 minutes chasing a phantom hermes-agent issue.

### 2. Edited wrong file in emeet-pixyd

**What happened:** The deploy failed on emeet-pixyd with vendorHash mismatch. I searched for `vendorHash` in `flake.nix` and found it, changed it, committed, pushed. But the actual package definition was in `package.nix:16` (discovered via `nix eval .#emeet-pixyd.meta.position` → `package.nix:41`). The `flake.nix` vendorHash was for a separate check derivation.

**Fix:** Also fixed `package.nix`, pushed again.

**Lesson:** Always check `nix eval .#<pkg>.meta.position` to find the actual file defining a package before editing vendorHashes.

### 3. deadnix hook broke emeet-pixyd build

**What happened:** When pushing the emeet-pixyd fix, the BuildFlow pre-commit hook's deadnix auto-fix removed the `goBrandedSrc` lambda parameter from `package.nix` (flagged as "unused"). But the caller in `flake.nix` still passes `goBrandedSrc`, causing an eval error: `function 'anonymous lambda' called with unexpected argument 'goBrandedSrc'`.

**Fix:** Added `goBrandedSrc` back to the parameter list with `...` to allow extra attrs.

**Lesson:** This matches the AGENTS.md gotcha: "deadnix `--fix` removes lambda params — does NOT add `...` when removing all params." The fix is to add `...` to the pattern.

### 4. Empty commit messages from auto-commit daemon

Two commits (`4b2efeb4`, `ad5401b8`) have empty commit messages. These were from the auto-commit daemon capturing my intermediate work. Not harmful but pollutes git log.

---

## e) WHAT WE SHOULD IMPROVE

### Architecture / Process

1. **The auto-commit daemon (PMA) is the tarball regression vector.** It runs `nix flake update` which rewrites nixpkgs to tarball via the global registry. The registry override in NixOS config only takes effect after deploy. We need to either:
   - Configure the daemon to run `nix flake update --no-use-registries` (if that flag actually works — prior session showed it doesn't)
   - Add a post-update hook in the daemon that reverts nixpkgs to GitHub type
   - Or: set the user-level registry (`~/.config/nix/registry.json`) which would apply to the daemon's user process

2. **vendorHash maintenance is a chronic pain.** Every nixpkgs version jump breaks Go vendorHashes because the Go toolchain version changes, which changes `go mod vendor` output. We have 8+ Go packages. Consider:
   - A script that sets `vendorHash = ""` on all packages, builds, and collects correct hashes
   - Or: `nix hash fix` integration in BuildFlow's `nix-hash-fix` step (currently skipped in pre-commit mode)

3. **Store path validation errors are misleading.** Nix reported `hermes-python-source` as "not valid" when it was registered in the store DB. The error was an evaluation cascade from a corrupted nixpkgs rev. Nix's error messages for these cases are unhelpful.

4. **The `follows` relationship is load-bearing.** Removing `inputs.nixpkgs.follows` from a flake input changes which nixpkgs version the root node resolves to. This is a sharp edge that's easy to get wrong — the lockfile's `original` field determines resolution, and removing follows changes the original.

5. **Pre-commit guard only covers manual commits.** The daemon bypasses it. The eval-time `nixpkgsTarballGuard` in `flake.nix` is the real protection — but it only fires on `nix flake check` / `nix eval` / `nix build`, not on `git commit`.

### Code Quality

6. **`niri-wrapped.nix` screenshot function** uses `grim` directly, not `grimblast`. The `swappy` config is in `home.nix:320`. Both grim and swappy are also installed via `multi-wm.nix:55-56`. There's duplication — the screenshot toolchain is spread across 3 files.

7. **Two empty commit messages** in git history from the daemon. Should configure the daemon to always generate a message.

---

## f) Up to 50 things to do next

### Immediate (this session's loose ends)

1. **Reboot evo-x2** to activate the new boot profile (registry override + hyprland removal)
2. **Verify `hyprland` is gone** from `nix path-info` after reboot
3. **Verify screenshots still work** (grim + slurp + swappy in niri)
4. **Run `nix run .#post-deploy-check`** to verify functional outcomes
5. **Deploy to macOS** — `nix run .#deploy` from the Mac to activate Darwin registry override

### Hyprland cleanup (dead code removal)

6. **Search for remaining hyprland references in active code** (not docs/archive) — `rg -l 'hyprland|hyprpaper|hyprlock|hypridle|hyprpicker|hyprsunset' platforms/ modules/` 
7. **Remove `swww-daemon.service` and `swww-wallpaper`** if they appear in the new closure (the deploy diff showed them as removed `[R.] swww-daemon.service` and `[R.] swww-wallpaper` — verify they're actually gone, not just renamed)
8. **Clean up `docs/status/archive/` hyprland references** — 20+ archived status reports reference hyprland configs that no longer exist
9. **Check if `uwsm` is still needed** — it was in the removal diff (`[R.] uwsm 0.26.6`). If it was only for Hyprland session management, it may be dead code now

### Tarball regression prevention

10. **Investigate user-level registry** (`~/.config/nix/registry.json`) — can we set `nixpkgs/nixos-unstable` there to apply to ALL processes including the daemon?
11. **Add CI check** that runs `nix flake check --no-build` on every PR and push — the `nixpkgsTarballGuard` will catch tarball regressions
12. **Configure PMA daemon** to run `nix flake update` with `--override-input nixpkgs github:NixOS/nixpkgs/nixos-unstable` to prevent the rewrite at the source
13. **Add a systemd timer** that checks flake.lock for tarball-type nixpkgs every hour and alerts on Discord if found
14. **Document the tarball regression** in AGENTS.md gotchas (partially done, needs the registry override solution documented)

### vendorHash automation

15. **Write a vendorHash batch-update script** — `scripts/update-all-vendorhashes.sh` that sets `vendorHash = ""` on all Go packages, builds each, and reports correct hashes
16. **Integrate `nix-hash-fix` into BuildFlow's pre-commit** for Go repos (currently skipped) — would catch vendorHash mismatches before push
17. **Consider `vendorHash = lib.fakeHash`** as a development pattern — forces a rebuild always, never stale
18. **Centralize vendorHash in `vendorHash.nix` files** — BuildFlow already does this, other repos should follow

### Deploy / system health

19. **Run `nix run .#deploy`** (switch, not boot) after reboot to make the new profile active
20. **Check Gatus dashboard** for any services broken by the nixpkgs version jump
21. **Run `nix-collect-garbage --delete-older-than 3d`** after confirming the new profile works — old hyprland paths are still in the store
22. **Verify BTRFS snapshots** ran successfully after the deploy
23. **Check `journalctl -u projects-management-automation`** — the daemon may have logged tarball regression attempts

### Upstream repo maintenance

24. **Fix emeet-pixyd CI** — 4 BuildFlow steps failed on push (biome, vitest, jest, tailwind — all "not found", likely missing in devShell)
25. **Fix mr-sync CI** — 1 BuildFlow step failed
26. **Fix md-go-validator CI** — 4 BuildFlow steps failed  
27. **Fix branching-flow CI** — 1 BuildFlow step failed
28. **Consolidate go-error-family dep version** across all repos — multiple repos updated to `8baa8344` independently

### Code quality / refactoring

29. **Consolidate screenshot toolchain** — grim, slurp, swappy are spread across `home.nix`, `niri-wrapped.nix`, `multi-wm.nix`. Extract to a single `screenshots.nix` module
30. **Remove `nixpkgsTarballGuard` complexity** — now that the registry override exists, the guard could be simplified or removed (it fires on every eval, adding latency)
31. **Add `...` to all package.nix lambda params** to prevent deadnix breakage (the emeet-pixyd incident)
32. **Audit all `inputs.X.nixpkgs.follows = "nixpkgs"` declarations** — verify none are silently overriding the root nixpkgs
33. **Document the hermes-agent `follows` restoration** in AGENTS.md — it's load-bearing and must not be removed

### Documentation

34. **Update AGENTS.md** with grimblast removal + hyprland purge
35. **Update FEATURES.md** if Hyprland was listed as a feature
36. **Write a runbook** for "nixpkgs tarball regression recovery" — the manual Python fix, the registry override, the pre-commit guard
37. **Update docs/gotchas-archive.md** with the hermes-agent follows incident
38. **Archive the prior status report** (`2026-08-05_20-13_nixpkgs-tarball-root-cause-and-pma-vendorhash.md`) — it's now resolved

### Monitoring

39. **Add a Gatus check** for flake.lock nixpkgs type — a simple script that reads flake.lock and reports to Prometheus
40. **Add a Gatus check** for "days since last successful deploy" — if > 3 days, alert
41. **Monitor nix store size** — the hyprland removal saved 122 MiB, but the store is still 50.5 GiB

### Testing

42. **Add a VM test** for the tarball guard — `tests/default.nix` should have a test that verifies `nixpkgsTarballGuard` fires on tarball-type nixpkgs
43. **Add a VM test** for screenshot functionality (grim + slurp + swappy)
44. **Run `nix flake check --all-systems`** to verify Darwin evaluation too

### Future

45. **Consider `nixpkgs` input pinning** — use a specific commit instead of a branch ref to avoid registry resolution entirely
46. **Evaluate Nix 2.35+'s `flake-registry` config** — may offer a process-level registry override that applies to the daemon
47. **Consider Attic cache** for the 8 Go packages — vendorHash rebuilds are expensive and repeat across machines
48. **Audit `platforms/nixos/users/home.nix`** for other Hyprland-era leftovers (hyprpaper, hyprlock, hypridle references)
49. **Check if `waybar` references are fully gone** — AGENTS.md says retired but may have residual packages
50. **Consider migrating from `nh` to `nixos-rebuild`** — `nh` has been flaky with context cancellation

---

## g) Questions I CANNOT answer myself

### Q1: Should I reboot evo-x2 now to activate the new boot profile?

The deploy was `nh os boot` (adds to bootloader, doesn't switch). The registry override and hyprland removal are not active until reboot. But rebooting disrupts running services (Docker containers, Ollama models, SigNoz, etc.). Should I:
- **(a)** Reboot now
- **(b)** Wait for a planned maintenance window
- **(c)** Run `nh os switch .` instead to activate immediately without full reboot (riskier — services restart in-place)

### Q2: Should the PMA auto-commit daemon be modified to prevent tarball rewrites?

The daemon runs `nix flake update` which triggers the registry rewrite. I could modify the daemon's update command in `modules/nixos/services/projects-management-automation.nix`, but that's an upstream PMA behavior — changing it in SystemNix means diverging from upstream defaults. Should the fix go in:
- **(a)** SystemNix's PMA module (override the update command)
- **(b)** Upstream PMA repo (add a `--no-use-registries` or `--override-input` flag option)
- **(c)** A post-update systemd `ExecStartPost` that reverts nixpkgs to GitHub type

### Q3: Is the `nixpkgsTarballGuard` in flake.nix still worth keeping?

The eval-time assertion adds latency to every `nix eval` / `nix flake check`. With the registry override deployed and the pre-commit guard active, is the eval-time guard redundant? Or is defense-in-depth worth the cost?
