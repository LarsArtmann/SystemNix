# P1 Execution Status Report

**Date:** 2026-03-31 23:44
**Session:** Continuation of comprehensive P1 task execution
**Scope:** 15 files changed, +51/-467 lines net reduction
**Build Status:** PASSING (`nix flake check --no-build` clean)

---

## A. FULLY DONE (10 items)

| #  | Task                                                                                                 | Files Changed                                                                                                                             |
| -- | ---------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| 1  | **IP consolidation** — all hardcoded `.162`/`.163` references → `.150`                               | `dns-blocker-config.nix`, `ssh.nix`, `deploy-evo-x2-local.sh`, `deploy-evo-x2.sh`, `fix-dnsblockd.sh`, `justfile` (6 files, 13 locations) |
| 2  | **Remove `//nolint:gosec` directives** — 4 unused linter suppressions in dnsblockd-processor         | `pkgs/dnsblockd-processor/main.go`                                                                                                        |
| 3  | **Add error handling** for unchecked `fmt.Fprintf` in dnsblockd "temp allowed" page                  | `platforms/nixos/programs/dnsblockd/main.go`                                                                                              |
| 4  | **Add swayidle + dunst to Niri spawn-at-startup** — 300s lock, 600s suspend, before-sleep lock       | `platforms/nixos/programs/niri-wrapped.nix`                                                                                               |
| 5  | **Extract wallpaperDir variable** — DRY wallpaper path (used in spawn-at-startup + Mod+W bind)       | `platforms/nixos/programs/niri-wrapped.nix`                                                                                               |
| 6  | **Remove wrapper-modules flake input** — dead code, never consumed by any module                     | `flake.nix`, `flake.lock`                                                                                                                 |
| 7  | **Delete orphaned regreet.css** — 235 lines from greetd era, replaced by SilentSDDM                  | `platforms/nixos/desktop/regreet.css` (DELETED)                                                                                           |
| 8  | **Delete dead dns.nix** — Technitium DNS config never imported anywhere                              | `platforms/nixos/private-cloud/dns.nix` (DELETED)                                                                                         |
| 9  | **Delete superseded dns-blocklist.nix** — Nix blocklist processor replaced by Go dnsblockd-processor | `pkgs/dns-blocklist.nix` (DELETED)                                                                                                        |
| 10 | **Add `just reload` recipe** — `niri msg action reload-config` for quick compositor reload           | `justfile`                                                                                                                                |

## B. PARTIALLY DONE (1 item)

| # | Task                    | Status                                                            | Remaining                                                        |
| - | ----------------------- | ----------------------------------------------------------------- | ---------------------------------------------------------------- |
| 1 | **display-manager.nix** | Rewritten with valid syntax, SilentSDDM + defaultSession = "niri" | Works but should be tested on-target with `nixos-rebuild switch` |

## C. NOT STARTED (P2/P3 items deferred)

| # | Task                                                                        | Priority | Effort |
| - | --------------------------------------------------------------------------- | -------- | ------ |
| 1 | Configure sops-nix age key via SSH host key on evo-x2                       | P2       | 15 min |
| 2 | Wire dnsblockd-processor into systemd timer for automated blocklist updates | P2       | 20 min |
| 3 | Add NixOS test for dnsblockd HTTP block page                                | P2       | 30 min |
| 4 | Centralize IP config into a single module (no hardcoded IPs anywhere)       | P2       | 25 min |
| 5 | Add niri keybinding for display brightness on laptops                       | P3       | 10 min |
| 6 | Configure automatic garbage collection schedule                             | P3       | 10 min |
| 7 | Add immich backup verification to justfile                                  | P3       | 15 min |

## D. TOTALLY FUCKED UP (and fixed this session)

| # | What Broke                                                     | Root Cause                                                                                        | Fix Applied                                                                                                  |
| - | -------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| 1 | **`nix flake check` failed** after wrapper-modules URL removal | URL removed from inputs but still in outputs function params + flake.lock                         | Removed from outputs params (line 106), ran `nix flake lock` to regenerate                                   |
| 2 | **display-manager.nix had broken Nix syntax**                  | Previous session rewrite produced mismatched braces (extra `};` on line 11)                       | Rewrote with correct structure: `services.xserver` + `displayManager.defaultSession` + `programs.silentSDDM` |
| 3 | **`wallpaperDir` undefined** in niri-wrapped.nix               | Variable placed inside `programs.niri.settings` block (Niri setting) instead of Nix `let` binding | Moved to `let wallpaperDir = ...; in` at function level                                                      |
| 4 | **`just reload` recipe never added**                           | Previous edit failed (old_string mismatch) but was marked complete                                | Appended correctly to end of justfile                                                                        |

## E. WHAT WE SHOULD IMPROVE

1. **Never mark edits as complete without verifying the tool response** — the previous session marked 4 items complete that actually failed
2. **Test after every change** — `nix flake check --no-build` should be run after each logical edit, not batched
3. **Don't "fix" things that aren't broken** — the display-manager.nix was fine before the previous session tried to "improve" it and broke the syntax
4. **Use `let` bindings for shared variables** — the wallpaperDir issue would have been caught by a build check
5. **Remove dead code aggressively** — 3 files deleted (394 lines) with zero functional impact

## F. Top 25 Next Actions (Prioritized)

### P0 — Critical (deploy-blocking)

_None currently — build passes clean._

### P1 — High (this week)

| # | Task                                                                                       | Effort | Impact                                     |
| - | ------------------------------------------------------------------------------------------ | ------ | ------------------------------------------ |
| 1 | Deploy to evo-x2 with `nixos-rebuild switch` and verify display-manager + swayidle + dunst | 10 min | Confirms all changes work on real hardware |
| 2 | Verify dnsblockd responds on `.150` with correct block page                                | 5 min  | Confirms IP migration worked               |
| 3 | Test wallpaper randomizer via Mod+W and at startup                                         | 5 min  | Confirms wallpaperDir + swww work          |

### P2 — Medium (this sprint)

| #  | Task                                                                         | Effort | Impact                             |
| -- | ---------------------------------------------------------------------------- | ------ | ---------------------------------- |
| 4  | Centralize all hardcoded IPs into a single `networking.nix`-derived variable | 25 min | Single source of truth for IPs     |
| 5  | Wire dnsblockd-processor into systemd timer                                  | 20 min | Automated blocklist updates        |
| 6  | Add sops-nix age key derivation from SSH host key                            | 15 min | Proper secret management on evo-x2 |
| 7  | Add NixOS test for dnsblockd HTTP responses                                  | 30 min | Regression protection              |
| 8  | Configure firewall rules (nftables) for dnsblockd ports                      | 20 min | Network security                   |
| 9  | Add zfs scrub timer for evo-x2 storage                                       | 10 min | Data integrity                     |
| 10 | Configure resolved forward zones for `.lan`                                  | 15 min | Local DNS resolution               |
| 11 | Add `just deploy-evo-x2` recipe wrapping deploy script                       | 10 min | DX improvement                     |
| 12 | Migrate remaining hardcoded paths to Nix variables                           | 15 min | Maintainability                    |

### P3 — Low (backlog)

| #  | Task                                                  | Effort | Impact                |
| -- | ----------------------------------------------------- | ------ | --------------------- |
| 13 | Add automatic GC schedule to NixOS config             | 10 min | Disk management       |
| 14 | Add immich backup verification to justfile            | 15 min | Backup reliability    |
| 15 | Configure niri brightness keybinds for laptops        | 10 min | Mobile usability      |
| 16 | Add homepage dashboard service entries                | 15 min | Ops visibility        |
| 17 | Set up Caddy reverse proxy for internal services      | 30 min | Service access        |
| 18 | Add Grafana dashboards for system metrics             | 20 min | Monitoring            |
| 19 | Configure Netdata alerts for disk/CPU/memory          | 15 min | Proactive monitoring  |
| 20 | Add Photomap service configuration                    | 20 min | Photo geolocation     |
| 21 | Write ADR for SilentSDDM vs greetd decision           | 10 min | Documentation         |
| 22 | Consolidate 21 status reports into single roadmap doc | 20 min | Documentation hygiene |
| 23 | Add pre-commit hook for Nix syntax validation         | 10 min | CI quality            |
| 24 | Create nixos-rebuild dry-run CI check                 | 15 min | Build safety          |
| 25 | Document evo-x2 hardware profile in README            | 10 min | Onboarding            |

## G. Top #1 Question

**What is the intended lifecycle for `dnsblockd` blocklist updates?**

The Go `dnsblockd-processor` builds the blocklist at build time into the Nix store, meaning updates require a full `nixos-rebuild switch`. Should we:

- **(A)** Keep it declarative — blocklist only updates on rebuild (current approach)
- **(B)** Add a systemd timer that re-runs the processor and reloads dnsblockd at runtime
- **(C)** Fetch the blocklist at dnsblockd startup from a local/remote source

This determines whether we need the systemd timer (P2 item #5) or if the current build-time approach is intentional.

---

## Files Changed Summary

```
15 files changed, 51 insertions(+), 467 deletions(-)

Modified (9):
  flake.nix                                     (-4)  removed wrapper-modules input + comment
  flake.lock                                    (-37) regenerated without wrapper-modules
  justfile                                      (+7)  reload recipe + IP updates
  pkgs/dnsblockd-processor/main.go              (-4)  removed unused nolint directives
  platforms/common/programs/ssh.nix             (-1)  evo-x2 IP → .150
  platforms/nixos/desktop/display-manager.nix   (+3)  SilentSDDM + defaultSession
  platforms/nixos/programs/dnsblockd/main.go    (+5)  error handling for fmt.Fprintf
  platforms/nixos/programs/niri-wrapped.nix     (+10) swayidle, dunst, wallpaperDir
  platforms/nixos/system/dns-blocker-config.nix (-8)  IP → .150, removed 360.cn domains
  scripts/deploy-evo-x2-local.sh               (-2)  IP → .150
  scripts/deploy-evo-x2.sh                     (-2)  IP → .150
  scripts/fix-dnsblockd.sh                     (-2)  IP → .150

Deleted (3):
  pkgs/dns-blocklist.nix                        (-70) superseded by Go processor
  platforms/nixos/desktop/regreet.css           (-235) orphaned greetd theme
  platforms/nixos/private-cloud/dns.nix         (-89) dead Technitium config
```
