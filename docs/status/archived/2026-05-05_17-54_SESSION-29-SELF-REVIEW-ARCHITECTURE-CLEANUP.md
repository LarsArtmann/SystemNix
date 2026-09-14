# SystemNix — Comprehensive Status Report

**Date:** 2026-05-05 17:54 CEST
**Session:** 29 — Brutal Self-Review + Architecture Cleanup Sprint
**Branch:** master (`4d03d32`, pushed to origin)
**Build:** `just test-fast` — ALL CHECKS PASSED ✅
**Agent:** GLM-5.1 via Crush

---

## Executive Summary

Session 29 was a READ→UNDERSTAND→RESEARCH→REFLECT→EXECUTE session focused on brutal self-review and architecture cleanup. The session produced **8 atomic commits** addressing the top systemic issues identified across sessions 23–28: the #1 DRY violation (15 hardcoded `"lars"` refs), dead code accumulation (gatus module, nix-visualize input, lib/default.nix facade), missing service hardening, Darwin compatibility bugs, and documentation sprawl (88→3 status docs).

**Overall Health:** 🟢 Build clean, all 30 service modules evaluate, dead code removed, primaryUser module introduced. **Deploy pending** — changes not yet activated on evo-x2.

---

## A) FULLY DONE ✅

### Session 29 — This Session (8 Commits)

| # | Commit    | What                                                                                                                                                                                                                                               | Files Changed                       |
| - | --------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------- |
| 1 | `cf0019a` | **Remove unused params** — `pkgs` from darwin/home.nix, `stdenv` from netwatch.nix, `crush-config` from flake.nix outputs destructuring                                                                                                            | 5                                   |
| 2 | `d1319c8` | **Fix monitor365 harden on user service** — `harden{}` sets system-level directives (ProtectSystem, PrivateTmp, etc.) that are invalid for `systemd.user.services`. Removed harden, kept inline MemoryMax                                          | 1                                   |
| 3 | `a099190` | **Guard taskwarrior systemd.user with isLinux** — `systemd.user` has no effect on Darwin. Wrapped with `lib.mkIf pkgs.stdenv.isLinux`                                                                                                              | 1                                   |
| 4 | `587843c` | **Fix nix-settings sandbox for Darwin** — macOS `sandbox-exec` is deprecated and causes build failures. `sandbox = lib.mkDefault (!pkgs.stdenv.isDarwin)`                                                                                          | 1                                   |
| 5 | `abb7739` | **Shared primaryUser module** — Created `platforms/nixos/system/primary-user.nix` with `options.users.primaryUser` (default: `"lars"`). Replaced 15 hardcoded `"lars"` across 12 service modules and 2 platform files. **#1 DRY violation fixed.** | 13 (1 new + 12 modified)            |
| 6 | `ade530b` | **Harden ai-stack + disk-monitor** — Last two system services missing `harden()`. Ollama: MemoryMax=32G, ProtectHome=false, NoNewPrivileges=false. Disk-monitor: ProtectHome=false, NoNewPrivileges=false                                          | 2                                   |
| 7 | `8cc002b` | **Remove dead code** — gatus.nix (406 lines, never imported), nix-visualize flake input (declared + passed as specialArgs but zero consumers), lib/default.nix facade (zero consumers, all 23 modules import files directly)                       | 3 files deleted, flake.nix modified |
| 8 | `4d03d32` | **Archive 85 status docs** — 87→3 active reports, 330 total in archive/                                                                                                                                                                            | 84 moved                            |

### Session 28 — Previous Session (Already Deployed)

- Fixed gogenfilter→go-filewatcher→file-and-image-renamer dependency chain across 3 upstream repos
- Deployed via `nh os switch` — crash recovery sysctls verified active
- Waybar crash recovery (Restart=always), health checks expanded, Gitea sops token fixed
- Nix GC thresholds fixed (3GB→100GB)

### Evergreen — Verified Complete Across All Sessions

| Category                  | Status | Details                                                                                   |
| ------------------------- | ------ | ----------------------------------------------------------------------------------------- |
| Cross-platform flake      | ✅     | macOS (aarch64-darwin) + NixOS (x86_64-linux), ~80% shared                                |
| flake-parts architecture  | ✅     | 30 service modules imported in flake.nix                                                  |
| Crash recovery stack      | ✅     | 6-layer defense-in-depth (earlyoom, kernel panic, watchdogd, SysRq, pstore, GPU recovery) |
| GPU memory ceiling        | ✅     | GTT/TTM limited to 32GB, ~96GB for CPU workloads                                          |
| DNS blocking              | ✅     | Unbound + dnsblockd, 25 blocklists, 2.5M+ domains                                         |
| Service hardening         | ✅     | `harden()` adopted in 16/18 applicable modules                                            |
| Shared lib/ helpers       | ✅     | `lib/systemd.nix`, `lib/systemd/service-defaults.nix`, `lib/types.nix`, `lib/rocm.nix`    |
| Wallpaper self-healing    | ✅     | awww-daemon + PartOf restart propagation + awww restore                                   |
| EMEET PIXY webcam         | ✅     | Auto-activation, face tracking, privacy mode                                              |
| Hermes AI gateway         | ✅     | System service, sops secrets, 24G MemoryMax                                               |
| Taskwarrior sync          | ✅     | TaskChampion server, zero-setup deterministic client IDs                                  |
| Niri session save/restore | ✅     | 60s timer, workspace-aware, crash recovery                                                |
| Theme                     | ✅     | Catppuccin Mocha everywhere                                                               |
| Pre-commit hooks          | ✅     | gitleaks + deadnix + statix + alejandra + nix flake check                                 |

---

## B) PARTIALLY DONE ⚠️

| # | Item                                | What's Done                                           | What's Missing                                                                                  |
| - | ----------------------------------- | ----------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| 1 | **serviceDefaults adoption**        | 5/30 modules use `serviceDefaults{}`                  | 13 modules manually inline `Restart=` instead of shared helper                                  |
| 2 | **primaryUser adoption**            | 12 service modules + 2 platform files                 | `hermes.nix` still has inline `user`/`group` options (has `lib/types.nix` serviceTypes instead) |
| 3 | **Catppuccin color centralization** | zellij, starship, fzf, tmux use `colorScheme.palette` | waybar (32 hex), rofi (15), swaylock (20), yazi (73) — **140 hardcoded colors total**           |
| 4 | **DNS failover cluster**            | Keepalived VRRP module, shared local-network.nix      | Pi 3 hardware not provisioned                                                                   |
| 5 | **SigNoz observability**            | Full stack deployed, 7 alert rules                    | Not all 10 service metric endpoints verified as scraped                                         |
| 6 | **Voice agents**                    | Module enabled, Whisper Docker + ROCm                 | Not verified post-deploy                                                                        |

---

## C) NOT STARTED 📋

| #  | Item                                                                          | Priority | Effort | Blocker                               |
| -- | ----------------------------------------------------------------------------- | -------- | ------ | ------------------------------------- |
| 1  | **Deploy session 29 changes** (`just switch`)                                 | P0       | 45min  | Needs evo-x2 access                   |
| 2  | **Investigate 3 failing services** (caddy, comfyui, photomap from session 28) | P0       | 30min  | Needs `systemctl`/`journalctl` access |
| 3  | **Verify all services post-deploy**                                           | P1       | 30min  | Post `just switch`                    |
| 4  | **Docker digest pinning** — Voice Agents + PhotoMap                           | P1       | 30min  | None                                  |
| 5  | **Move VRRP auth_pass to sops**                                               | P1       | 30min  | None                                  |
| 6  | **nix-collect-garbage -d**                                                    | P1       | 10min  | None                                  |
| 7  | **docker system prune -af**                                                   | P2       | 5min   | None                                  |
| 8  | **Adopt colorScheme.palette** in 4 desktop modules                            | P2       | 60min  | None                                  |
| 9  | **Split signoz.nix** (746 lines) into sub-modules                             | P2       | 60min  | None                                  |
| 10 | **Create centralized color module**                                           | P2       | 30min  | None                                  |
| 11 | **serviceDefaults migration** (13 modules)                                    | P3       | 60min  | None                                  |
| 12 | **Pi 3 provisioning** for DNS failover                                        | P3       | 2hr+   | Hardware                              |
| 13 | **BTRFS snapshot restore test**                                               | P3       | 15min  | None                                  |
| 14 | **LUKS disk encryption + TPM**                                                | P4       | 60min  | None                                  |
| 15 | **CI/CD pipeline** for `just test`                                            | P4       | 60min  | None                                  |

---

## D) TOTALLY FUCKED UP 💥

### Issues Found and Fixed This Session

| # | What                                      | How Bad                                                             | Root Cause                               | Fixed By                            |
| - | ----------------------------------------- | ------------------------------------------------------------------- | ---------------------------------------- | ----------------------------------- |
| 1 | **15 hardcoded `"lars"` across 12 files** | HIGH — #1 DRY violation, portability blocker                        | No shared user module existed            | `abb7739` — primaryUser module      |
| 2 | **monitor365 harden on user service**     | MEDIUM — system directives silently ignored on user services        | harden() used on `systemd.user.services` | `d1319c8` — removed harden          |
| 3 | **taskwarrior breaks on Darwin**          | HIGH — `systemd.user` in common code with no platform guard         | Missing `isLinux` guard                  | `a099190` — `lib.mkIf isLinux`      |
| 4 | **nix sandbox=true breaks Darwin**        | MEDIUM — macOS sandbox-exec deprecated                              | No platform guard on sandbox setting     | `587843c` — `mkDefault (!isDarwin)` |
| 5 | **gatus.nix — 406 lines dead code**       | MEDIUM — fully implemented but never imported                       | Created as draft, never wired in         | `8cc002b` — deleted                 |
| 6 | **nix-visualize — dead flake input**      | LOW — declared, destructured, passed as specialArgs, zero consumers | Cargo-culted input                       | `8cc002b` — removed                 |
| 7 | **lib/default.nix — dead facade**         | LOW — zero consumers, all 23 modules import files directly          | Created but never adopted                | `8cc002b` — deleted                 |
| 8 | **88 status docs in docs/status/**        | LOW — massive documentation sprawl, nobody reads them               | Every session generated reports          | `4d03d32` — archived 85             |

### Carried Forward (Multi-Session Issues)

| #  | What                                                          | How Bad                                                | Status                                       |
| -- | ------------------------------------------------------------- | ------------------------------------------------------ | -------------------------------------------- |
| 9  | **3 services failing post-deploy** (caddy, comfyui, photomap) | CRITICAL — caddy down = all *.home.lan unreachable     | From session 28A — needs `systemctl` access  |
| 10 | **Waybar was dead 4 days** (May 1–5)                          | SEVERE — fixed in session 26 but deploy delayed        | Fix deployed session 28                      |
| 11 | **Root disk at 84%** (82GB free)                              | HIGH — needs nix GC + docker prune                     | Not done                                     |
| 12 | **81-task execution plan never executed**                     | MEDIUM — written session 26, became another status doc | Replaced by this session's focused execution |
| 13 | **140 hardcoded Catppuccin hex colors**                       | LOW — works fine, just not DRY                         | Not done                                     |

---

## E) WHAT WE SHOULD IMPROVE 📈

### Architecture

1. **Deploy verification as mandatory step** — 8 sessions (23→29) committed fixes without deploying. Rule: every commit that changes systemd services MUST be deployed within the same session.

2. **Centralized Catppuccin color module** — 140 hardcoded hex colors in 4 desktop modules. Create a shared color accessor that maps `colorScheme.palette` to the format each tool needs (CSS variables for waybar, rasi for rofi, etc.).

3. **signoz.nix at 746 lines** — Split into `signoz/packages.nix`, `signoz/alerts.nix`, `signoz/scrapers.nix`. It's the largest module by 2x.

4. **`lib/types.nix` adoption** — Only used by `hermes.nix`. The `systemdServiceIdentity`, `servicePort`, `restartDelay` helpers could eliminate boilerplate across 10+ modules. Either adopt broadly or inline into hermes.

5. **Port registry** — Ports scattered across modules with no conflict detection. Even a simple `lib/port-registry.nix` would prevent future collisions.

### Process

6. **Atomic commits for API changes** — Session 24 broke all `harden {}` calls by changing `lib/systemd.nix` signature without updating callers. API changes + all callers must be ONE commit.

7. **Status doc hygiene** — 88 files accumulated before this session's archival. Going forward: keep ≤5 active, auto-archive after 7 days.

8. **Pre-commit hook message rewriting** — The hook rewrites commit messages, losing detailed explanations. Consider disabling auto-rewrite or accepting the hook's format.

9. **No parallel sessions on same branch** — Sessions 27 and 28A both committed to master simultaneously, causing divergence. Use feature branches or serialize.

### Code Quality

10. **serviceDefaults migration** — 13 modules manually inline `Restart = "always"` instead of using the shared `serviceDefaults{}` helper. Maintenance hazard.

11. **file-and-image-renamer user service** — All other custom services use system-level systemd. Inconsistent.

12. **Inline bash scripts** — gitea.nix (200+ lines), gitea-repos.nix (200+ lines) have massive inline bash. Should use `writeShellApplication`.

---

## F) TOP 25 THINGS TO DO NEXT

### Tier 1: Deploy & Fix What's Broken (P0)

| # | Task                                                                            | Effort | Impact   | Blocked?        |
| - | ------------------------------------------------------------------------------- | ------ | -------- | --------------- |
| 1 | **`just switch` on evo-x2** — deploy session 29 changes                         | 45min  | CRITICAL | Needs evo-x2    |
| 2 | **Investigate caddy failure** — `systemctl status caddy`, `journalctl -u caddy` | 15min  | CRITICAL | Needs systemctl |
| 3 | **Investigate comfyui failure**                                                 | 15min  | HIGH     | Needs systemctl |
| 4 | **Investigate photomap failure**                                                | 15min  | HIGH     | Needs systemctl |
| 5 | **Verify all services post-deploy** — `just health`, `systemctl --failed`       | 10min  | HIGH     | Post deploy     |

### Tier 2: High Impact Cleanup (P1)

| #  | Task                                                                         | Effort | Impact | Blocked? |
| -- | ---------------------------------------------------------------------------- | ------ | ------ | -------- |
| 6  | **nix-collect-garbage -d** — root at 84%                                     | 10min  | HIGH   | No       |
| 7  | **docker system prune -af** — reclaim unused images                          | 5min   | HIGH   | No       |
| 8  | **Docker digest pin** — Voice Agents + PhotoMap use version tags             | 30min  | HIGH   | No       |
| 9  | **Move VRRP auth_pass to sops**                                              | 10min  | MED    | No       |
| 10 | **Update AGENTS.md** — primaryUser module, gatus removal, session 29 changes | 30min  | MED    | No       |

### Tier 3: Architecture Improvements (P2)

| #  | Task                                                      | Effort | Impact | Blocked? |
| -- | --------------------------------------------------------- | ------ | ------ | -------- |
| 11 | **Adopt colorScheme.palette** in waybar.nix (32 colors)   | 20min  | MED    | No       |
| 12 | **Adopt colorScheme.palette** in rofi.nix (15 colors)     | 15min  | MED    | No       |
| 13 | **Adopt colorScheme.palette** in yazi.nix (73 colors)     | 25min  | MED    | No       |
| 14 | **Adopt colorScheme.palette** in swaylock.nix (20 colors) | 10min  | MED    | No       |
| 15 | **Split signoz.nix** into sub-modules                     | 60min  | MED    | No       |
| 16 | **serviceDefaults migration** — consolidate 13 modules    | 60min  | MED    | No       |

### Tier 4: Lower Priority (P3–P4)

| #  | Task                                                   | Effort | Impact | Blocked? |
| -- | ------------------------------------------------------ | ------ | ------ | -------- |
| 17 | **BTRFS snapshot restore test**                        | 15min  | MED    | No       |
| 18 | **Pi 3 provisioning** for DNS failover                 | 2hr+   | HIGH   | Hardware |
| 19 | **file-and-image-renamer → system service**            | 30min  | MED    | No       |
| 20 | **Extract gitea inline bash** to writeShellApplication | 30min  | MED    | No       |
| 21 | **Adopt lib/types.nix broadly** or inline into hermes  | 30min  | LOW    | No       |
| 22 | **CI/CD pipeline** for `just test`                     | 60min  | MED    | GitHub   |
| 23 | **LUKS disk encryption + TPM**                         | 60min  | HIGH   | Planning |
| 24 | **UPS monitoring** (NetworkUPSTools)                   | 30min  | MED    | Hardware |
| 25 | **Centralized firewall port management**               | 30min  | MED    | No       |

---

## G) TOP #1 QUESTION I CANNOT FIGURE OUT MYSELF

**Why are caddy, comfyui, and photomap failing after the session 28 deploy?**

The session 28A `nh os switch` reported:

```
Failed to start caddy.service
Failed to start podman-photomap.service
warning: the following units failed: caddy.service, comfyui.service, podman-photomap.service
```

Caddy is the **reverse proxy** for ALL `*.home.lan` services. If it's down, Immich, Gitea, Homepage, SigNoz, etc. are all unreachable via HTTPS — even if running internally.

I cannot diagnose without:

```bash
systemctl status caddy.service
systemctl status comfyui.service
systemctl status podman-photomap.service
journalctl -u caddy.service --since "1 hour ago" --no-pager -n 50
journalctl -u comfyui.service --since "1 hour ago" --no-pager -n 50
```

**Hypotheses:**

- Caddy: `harden{}` from session 29 now strips `CAP_NET_BIND_SERVICE` — but session 28A had a fix (`48e1884`) restoring capabilities. May be the `AmbientCapabilities` vs `CapabilityBoundingSet` interaction.
- ComfyUI: Python venv issue, GPU access, or ROCm library path
- PhotoMap: Podman container image pull failure or network issue

---

## System Metrics

| Metric                   | Value                                              |
| ------------------------ | -------------------------------------------------- |
| Service modules          | 30 (was 31 — gatus removed)                        |
| Harden adoption          | 16/18 applicable (89%)                             |
| serviceDefaults adoption | 5/30 (17%)                                         |
| Custom packages          | 9                                                  |
| Platforms                | 2 (macOS aarch64-darwin, NixOS x86_64-linux)       |
| Total .nix files         | 89                                                 |
| Service module LOC       | 5,141                                              |
| Status docs              | 3 active, 330 archived                             |
| Working tree             | 1 modified (flake.lock from nix-visualize removal) |
| Failing services         | 3 (caddy, comfyui, photomap)                       |
| Pre-commit hooks         | All passing                                        |
| Last deploy              | Session 28A (session 29 NOT deployed)              |

## Commit History This Session

```
4d03d32 chore(docs): archive 85 status reports (keep 3 most recent)
8cc002b chore(cleanup): remove dead code — gatus module, nix-visualize input, lib/default.nix
ade530b harden(ai-stack, disk-monitor): add harden{} to previously unprotected services
abb7739 feat(nixos): shared primaryUser module — eliminate 15 hardcoded "lars" refs
587843c fix(nix-settings): sandbox=false on Darwin by default
a099190 fix(taskwarrior): guard systemd.user with isLinux
d1319c8 fix(monitor365): remove harden{} from user service
cf0019a chore(cleanup): remove unused imports and fix shellcheck warnings
```

---

_Arte in Aeternum_
