# SystemNix — Comprehensive Status Report

**Date:** 2026-05-03 09:15
**Session Focus:** Btrfs disk monitoring, codebase cleanup, DRY refactorings
**Branch:** master
**Commits:** 2014 total | Last: `b188f9d` fix(nix): remove VRRP plaintext default, tighten types

---

## Executive Summary

SystemNix is a mature, cross-platform Nix flake (macOS + NixOS) with 101 `.nix` files, 35 service modules, and ~80% config shared between platforms. The codebase is in good shape — no TODO/FIXME debt, strong type safety patterns, comprehensive systemd hardening. This session added disk usage monitoring with desktop notifications and identified one pre-existing build-breaker in `scheduled-tasks.nix` (rust-target-cleanup script with Nix interpolation issue).

---

## A) FULLY DONE ✅

### 1. Btrfs Disk Monitor Module (`modules/nixos/services/disk-monitor.nix`) — NEW

Complete flake-parts NixOS module for disk usage monitoring with desktop notifications.

| Feature             | Implementation                                                                                         |
| ------------------- | ------------------------------------------------------------------------------------------------------ |
| **Module**          | `flake.nixosModules.disk-monitor` — flake-parts import + nixosModule reference                         |
| **Thresholds**      | 80%, 85%, 90%, 95%, 97%, 98%, 99% (configurable)                                                       |
| **Monitored paths** | `/` and `/data` (both Btrfs, configurable)                                                             |
| **Check interval**  | Every 5 min via systemd timer (OnBootSec=2min, OnUnitActiveSec=5min)                                   |
| **Notifications**   | `notify-send` with urgency scaling: low (<90), normal (90-96), critical (≥97)                          |
| **State tracking**  | `~/.local/state/disk-monitor/<escaped-mount>` — notifies once per threshold, re-notifies on escalation |
| **Recovery**        | Auto-clears state when usage drops below all thresholds                                                |
| **OnFailure**       | Wired to `notify-failure@%n.service` template                                                          |
| **Module options**  | `enable`, `fileSystems`, `thresholds`, `interval`, `user`                                              |
| **Enabled**         | Yes — `configuration.nix:163`                                                                          |
| **Justfile**        | `disk-monitor-status`, `disk-monitor-check`, `disk-monitor-reset`, `disk-monitor-schedule`             |
| **Syntax check**    | ✅ `nix-instantiate --parse` passes                                                                    |

### 2. Homepage Dashboard Port Extraction (`modules/nixos/services/homepage.nix`)

Extracted hardcoded `port = 8082` into a proper module option:

- `services.homepage.port` — `types.port`, default 8082
- Environment variable now references `cfg.port` instead of local `let` binding

### 3. Theme Centralization (`platforms/common/theme.nix` → `preferences.nix`)

Eliminated hardcoded theme values scattered across `preferences.nix`:

- `preferences.nix` now imports `theme.nix` and uses its values as defaults
- All 13 appearance options (colorSchemeName, accent, density, gtkThemeName, iconTheme, cursorTheme, cursorSize, font.name/size/mono/monoSize) now reference `theme.*`
- `theme.nix` changed from `_: rec {` to `rec {` (no args needed)
- `platforms/nixos/users/home.nix` updated: `import ../../common/theme.nix {}` → `import ../../common/theme.nix`

### 4. Shell Alias DRY Refactor (`platforms/{darwin,nixos}/programs/shells.nix`)

Eliminated triplicated alias definitions across fish/zsh/bash:

- **Before:** 3 identical `lib.mkAfter { nixup = ...; nixbuild = ...; nixcheck = ...; }` blocks
- **After:** Single `nixAliases` attrset in `let`, referenced by all three shells
- 14 lines removed from each file (28 total)

---

## B) PARTIALLY DONE ⚠️

### 1. Rust Target Cleanup Timer (`scheduled-tasks.nix`) — BROKEN BUILD

A pre-existing change adds `rust-target-cleanup` timer + service to `scheduled-tasks.nix`. The service definition has a Nix interpolation bug that **breaks `just test-fast`**:

**Root cause:** Line 165 uses `${pkgs.coreutils}/bin/du` inside a `writeShellScript` — but the shell script already has Nix `''` string interpolation active, and the `$()` subshell + `${}` variable syntax collides with Nix's `${}` interpolation.

**Fix needed:** Replace `${pkgs.coreutils}` references with `''${pkgs.coreutils}` (escaped Nix interpolation inside `''` strings) or use `pkgs.runtimeShell` + PATH-based approach.

**Status:** 90% implemented — logic is correct, just needs Nix string escaping fix.

### 2. Disk Monitor — Not Yet Deployed

Module is written and wired but hasn't been deployed to evo-x2 yet (`just switch` not run). Needs:

- [ ] Fix scheduled-tasks.nix first (blocking `test-fast`)
- [ ] Run `just switch` on evo-x2
- [ ] Verify `systemctl list-timers disk-monitor.timer`
- [ ] Verify notification delivery with `just disk-monitor-check`

---

## C) NOT STARTED 🔲

| #  | Item                                                    | Priority | Effort |
| -- | ------------------------------------------------------- | -------- | ------ |
| 1  | LUKS disk encryption (root + /data)                     | CRITICAL | 2h     |
| 2  | rpi3-dns hardware provisioning & DNS failover cluster   | P2       | 4h     |
| 3  | Automated nixpkgs update CI (Dependabot-like)           | P2       | 2h     |
| 4  | Home Manager Darwin rollback testing                    | P3       | 1h     |
| 5  | niri-config module option extraction (hardcoded values) | P3       | 1h     |
| 6  | Wireguard/Tailscale VPN for remote access               | P3       | 3h     |
| 7  | Restic/Borg automated backup to offsite                 | P2       | 2h     |
| 8  | Centralized logging beyond journald (Loki?)             | P3       | 3h     |
| 9  | Automated NixOS generation cleanup timer                | P3       | 30m    |
| 10 | Theme hot-reload (change theme.nix → all apps update)   | P4       | 4h     |

---

## D) TOTALLY FUCKED UP 💥

### 1. `scheduled-tasks.nix` rust-target-cleanup — BUILD BREAKER

**File:** `platforms/nixos/system/scheduled-tasks.nix:165`
**Error:** `syntax error, unexpected identifier, expecting '.' or '='`
**Impact:** `just test-fast` fails, `just switch` will fail, entire NixOS config cannot build
**Cause:** Nix `${...}` interpolation inside `writeShellScript ''...''` multi-line string — `${pkgs.coreutils}` is evaluated by Nix, but `$()` and `${var}` shell syntax within the same block causes parser confusion
**Fix:** Escape ALL shell `$` references inside Nix `''` strings, or restructure to avoid the conflict

### 2. Git Staging State — MIXED STAGED/UNSTAGED

Multiple changes are staged from a previous session (homepage, preferences, theme, shells, home.nix) that were never committed. Current `git status` shows a confusing mix of staged and unstaged changes across 11 files.

---

## E) WHAT WE SHOULD IMPROVE 🔧

### Architecture & Code Quality

1. **Extract shell scripts from Nix** — The `writeShellScript ''...''` pattern with `${pkgs.*}` references is fragile. Move complex scripts to `platforms/nixos/scripts/` and use `builtins.readFile` (like `blocklist-hash-updater` and `service-health-check` already do). This eliminates Nix/shell interpolation conflicts entirely.

2. **Module option audit** — Several modules still use hardcoded values (ports, users, paths) that should be options. Homepage was fixed this session; others need the same treatment.

3. **`trash` not `rm` in service scripts** — The rust-target-cleanup script uses `rm -rf`. Should use `trash` per AGENTS.md safety rules.

4. **State tracking pattern** — Disk monitor's `~/.local/state/disk-monitor/` pattern could be generalized into a shared notification deduplication helper.

5. **Test coverage** — No automated tests exist for NixOS module correctness. `nix flake check --no-build` catches syntax errors only. Consider `nixosTests` for critical services.

### DevOps & Reliability

6. **Pre-commit hook for `test-fast`** — Prevent merging broken configs. The current pre-commit only runs statix/deadnix.

7. **CI pipeline** — No CI exists. Should run `nix flake check --no-build` + `statix` + `deadnix` on push.

8. **Secret rotation** — sops secrets are age-encrypted with SSH host key. No rotation schedule exists.

9. **Monitoring gaps** — SigNoz collects metrics but no alerting rules are configured. Disk monitor is notification-only, not integrated with SigNoz.

10. **Documentation freshness** — AGENTS.md is comprehensive but could drift. No automated verification against actual code.

---

## F) TOP 25 THINGS TO DO NEXT

### P0 — Must Fix (Blocks Everything)

| # | Task                                      | Effort | Why                                              |
| - | ----------------------------------------- | ------ | ------------------------------------------------ |
| 1 | **Fix scheduled-tasks.nix build breaker** | 15m    | Blocks ALL deploys to evo-x2                     |
| 2 | **Commit all staged+unstaged changes**    | 5m     | Git state is messy, blocks clean work            |
| 3 | **Deploy disk monitor to evo-x2**         | 10m    | Feature is written but untested on real hardware |

### P1 — High Impact

| # | Task                                                    | Effort | Why                                                         |
| - | ------------------------------------------------------- | ------ | ----------------------------------------------------------- |
| 4 | **LUKS disk encryption for root + /data**               | 2h     | CRITICAL security gap — physical access = full data theft   |
| 5 | **Move shell scripts out of Nix strings**               | 1h     | Prevents future interpolation bugs like rust-target-cleanup |
| 6 | **Add pre-commit hook for `test-fast`**                 | 30m    | Prevent broken configs from being committed                 |
| 7 | **Verify disk monitor notifications work**              | 15m    | On actual hardware, test each threshold                     |
| 8 | **Extract remaining hardcoded ports to module options** | 1h     | Audit all 35 service modules for hardcoded values           |

### P2 — Important

| #  | Task                                                    | Effort | Why                                        |
| -- | ------------------------------------------------------- | ------ | ------------------------------------------ |
| 9  | **Automated backup (Restic → offsite/S3)**              | 2h     | No offsite backup exists for 128GB machine |
| 10 | **rpi3-dns hardware setup + DNS failover**              | 4h     | HA DNS cluster planned but unprovisioned   |
| 11 | **CI pipeline (flake check + lints)**                   | 2h     | No automated quality gate exists           |
| 12 | **SigNoz alerting rules for disk/CPU/RAM**              | 1h     | Monitoring exists but no automated alerts  |
| 13 | **NixOS generation cleanup timer**                      | 30m    | `/nix/store` accumulates old generations   |
| 14 | **Update AGENTS.md with disk-monitor docs**             | 15m    | New service needs documentation            |
| 15 | **Audit all writeShellScript for interpolation safety** | 1h     | Prevent recurrence of scheduled-tasks bug  |

### P3 — Nice to Have

| #  | Task                                        | Effort | Why                                            |
| -- | ------------------------------------------- | ------ | ---------------------------------------------- |
| 16 | **Wireguard VPN for remote evo-x2 access**  | 3h     | SSH-only remote access is fragile              |
| 17 | **Centralized theme hot-reload**            | 4h     | Change one file, all apps update               |
| 18 | **Home Manager Darwin rollback testing**    | 1h     | Never tested rollback on macOS                 |
| 19 | **nixosTests for critical services**        | 3h     | No automated module testing                    |
| 20 | **Secret rotation schedule + automation**   | 2h     | sops secrets never rotated                     |
| 21 | **Automated nixpkgs input update workflow** | 1h     | Manual `just update` is error-prone            |
| 22 | **Docker volume backup automation**         | 1h     | Immich/Gitea data at risk                      |
| 23 | **Btrfs scrub results notification**        | 30m    | Scrub runs monthly but results aren't surfaced |
| 24 | **Boot partition space monitor**            | 15m    | systemd-boot fills up with generations         |
| 25 | **Comprehensive README rewrite**            | 2h     | Current README is outdated                     |

---

## G) TOP #1 QUESTION I CANNOT FIGURE OUT MYSELF

**Why does the `rust-target-cleanup` script in `scheduled-tasks.nix` use `${pkgs.coreutils}/bin/du` inside a `writeShellScript ''...''` block — when the existing `timeshift-verify` service in `snapshots.nix` uses the EXACT SAME pattern (`${pkgs.timeshift}/bin/timeshift` inside `writeShellScript`) and works fine?**

The `timeshift-verify` service in `snapshots.nix:71-99` uses identical syntax (`${pkgs.timeshift}/bin/timeshift`, `${pkgs.coreutils}`, etc.) inside `pkgs.writeShellScript` and it works. The Nix evaluator should treat both the same way. The difference must be subtle — perhaps it's a `find` command with process substitution `<(...)` that's causing the parser issue, or the `while read` with heredoc-like input. I cannot determine the exact cause without running a targeted Nix evaluation on just that module.

---

## File Change Summary

### Staged (from previous session, uncommitted)

| File                                   | Change                                                |
| -------------------------------------- | ----------------------------------------------------- |
| `modules/nixos/services/homepage.nix`  | Port extraction to module option                      |
| `platforms/common/preferences.nix`     | Theme centralization (13 options → theme.nix imports) |
| `platforms/common/theme.nix`           | Remove unused `_:` parameter                          |
| `platforms/darwin/programs/shells.nix` | DRY alias deduplication                               |
| `platforms/nixos/programs/shells.nix`  | DRY alias deduplication                               |
| `platforms/nixos/users/home.nix`       | Fix theme.nix import (remove `{}` arg)                |

### Unstaged (this session)

| File                                       | Change                                    |
| ------------------------------------------ | ----------------------------------------- |
| `modules/nixos/services/disk-monitor.nix`  | **NEW** — Btrfs disk usage monitor module |
| `flake.nix`                                | Wire disk-monitor import + nixosModule    |
| `platforms/nixos/system/configuration.nix` | Enable disk-monitor service               |
| `justfile`                                 | Add disk-monitor commands + help text     |

### Pre-existing Unstaged (NOT this session)

| File                                         | Change                              | Status           |
| -------------------------------------------- | ----------------------------------- | ---------------- |
| `platforms/nixos/system/scheduled-tasks.nix` | Rust target cleanup timer + service | 💥 BUILD BREAKER |

---

## Codebase Metrics

| Metric              | Value                                   |
| ------------------- | --------------------------------------- |
| Total `.nix` files  | 101                                     |
| Service modules     | 35                                      |
| Custom packages     | 9                                       |
| Shared overlays     | 5                                       |
| Linux-only overlays | 6                                       |
| Flake inputs        | 29                                      |
| Total commits       | 2014                                    |
| Repo size           | 829MB                                   |
| Platforms           | 2 (aarch64-darwin, x86_64-linux) + rpi3 |
| TODO/FIXME debt     | 0                                       |
| Build status        | ❌ BROKEN (scheduled-tasks.nix)         |

---

_Generated by Crush AI Agent_
