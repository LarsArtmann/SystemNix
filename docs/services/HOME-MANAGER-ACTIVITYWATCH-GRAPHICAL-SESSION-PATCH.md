# Upstream Home Manager PR: ActivityWatch Wayland Watcher `graphical-session.target` Deps

## Problem

The Home Manager `services.activitywatch` module generates a systemd **user** service per watcher that is ordered `After = [ "activitywatch.service" ]` and pulled in by `activitywatch.target` (itself `WantedBy = default.target`).

`default.target` is reached at user-session start — **before** any Wayland compositor is running. A Wayland watcher such as `aw-watcher-window-wayland` therefore starts at login with no display to connect to and panics with `Failed to connect to wayland display`. Under the default systemd start-limit (5 starts / 10 s) this rapidly reaches `start-limit-hit` and the watcher stays dead until someone runs `systemctl --user reset-failed`.

## Fix

Add a per-watcher `requiresGraphicalSession` boolean (default `false`, backward compatible). When enabled, the generated service is ordered `After` and bound to the lifetime of (`PartOf`) `graphical-session.target`, so it starts only once the compositor is ready and is stopped together with the session.

| Changed file                         | Change                                                                                        |
| ------------------------------------ | --------------------------------------------------------------------------------------------- |
| `modules/services/activitywatch.nix` | New `requiresGraphicalSession` option on the watcher submodule + conditional `After`/`PartOf` |

Non-graphical watchers (`aw-watcher-afk`, `aw-watcher-utilization`, …) are unaffected — `requiresGraphicalSession` defaults to `false`.

## Files

| File                                                 | Purpose                                                               |
| ---------------------------------------------------- | --------------------------------------------------------------------- |
| `home-manager-activitywatch-graphical-session.patch` | Git patch against `home-manager` `modules/services/activitywatch.nix` |

## Base commit

Pinned Home Manager input at the time of generation:

```
home-manager rev: 079a3b5d1aa6a719920a51316253b7d6dd22738d
```

## Verification (done locally)

The patch was verified by evaluating a full `homeManagerConfiguration` against a patched copy of the Home Manager source:

- `aw-watcher-window-wayland` with `requiresGraphicalSession = true` →
  `Unit.After = [ "activitywatch.service" "graphical-session.target" ]`, `Unit.PartOf = [ "graphical-session.target" ]`
- `aw-watcher-afk` (default) → `Unit.After = [ "activitywatch.service" ]`, `Unit.PartOf = [ ]` (unchanged)

## How to apply / submit

```bash
# In a clone of github:nix-community/home-manager checked out at the rev above:
git checkout 079a3b5d1aa6a719920a51316253b7d6dd22738d
git apply docs/services/home-manager-activitywatch-graphical-session.patch
nix build .#homeConfigurations.<name>.activationPackage   # or the HM test for activitywatch
```

Then open a PR to `nix-community/home-manager` titled e.g. `activitywatch: add requiresGraphicalSession watcher option`. Suggested PR body: the Problem/Fix/Verification sections above.

## SystemNix local status

SystemNix already carries a **local workaround** in `platforms/common/programs/activitywatch.nix` that hard-codes `After`/`PartOf = graphical-session.target` plus `StartLimitBurst = 5; StartLimitIntervalSec = 300` on `aw-watcher-window-wayland`. Once this upstream option is merged and the SystemNix `home-manager` input is bumped, the local override can be replaced with:

```nix
services.activitywatch.watchers.aw-watcher-window-wayland.requiresGraphicalSession = true;
```

(The start-limit hardening is a SystemNix-specific choice and stays local — upstream users have different needs.)
