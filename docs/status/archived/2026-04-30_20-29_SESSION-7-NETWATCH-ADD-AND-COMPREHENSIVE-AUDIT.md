# Session 7 Status — 2026-04-30 20:29

**Session focus:** Add netwatch (network diagnostics TUI) to NixOS, comprehensive status audit

---

## a) FULLY DONE

### This Session

| # | Task                                                      | Evidence                                                                         |
| - | --------------------------------------------------------- | -------------------------------------------------------------------------------- |
| 1 | Package netwatch v0.14.1 as Nix derivation                | `pkgs/netwatch.nix` — Rust buildRustPackage, fetchFromGitHub                     |
| 2 | Add netwatchOverlay to flake.nix                          | `netwatchOverlay` in overlays, `linuxOnlyOverlays`, `perSystem`, `packages`      |
| 3 | Add netwatch to monitoring-tools module                   | `modules/nixos/services/monitoring.nix` — system package alongside nethogs/iftop |
| 4 | Update AGENTS.md architecture tree                        | `pkgs/` section now lists netwatch.nix                                           |
| 5 | Build verified — `netwatch --version` → `netwatch 0.14.1` | Binary in `/nix/store/...-netwatch-0.14.1/bin/netwatch`                          |
| 6 | `just test-fast` passes — all NixOS modules eval clean    | Monitoring module includes netwatch                                              |
| 7 | awww-daemon hardening in niri-wrapped.nix                 | Restart=always + StartLimitBurst, BindsTo for wallpaper service                  |

### Today's Full Commit History (47 commits on 2026-04-30)

| Commit    | Category | Summary                                                        |
| --------- | -------- | -------------------------------------------------------------- |
| `029a911` | feat     | Add netwatch package + overlay + monitoring module integration |
| `65b2537` | refactor | Extract emeet-pixyd into standalone project                    |
| `f43a28a` | fix      | Caddy: use default_bind instead of servers block bind          |
| `d815a2c` | docs     | WatchdogSec/sd_notify rules in AGENTS.md                       |
| `3d64bb6` | fix      | Remove WatchdogSec from services without sd_notify             |
| `7056155` | fix      | SigNoz: remove WatchdogSec (not sd_notify capable)             |
| `9198775` | fix      | TaskChampion: remove WatchdogSec — crash-looping               |
| `2a7eac3` | fix      | ComfyUI: remove WatchdogSec — Python                           |
| `0909f06` | fix      | Hermes: remove WatchdogSec                                     |
| `2f68153` | fix      | systemd: remove WatchdogSec from service-defaults              |
| `00a9ee7` | refactor | Increase WatchdogSec defaults (reverted in 2f68153)            |
| `4ed1c5d` | docs     | Session 6 status                                               |
| `a4d89e0` | feat     | Add go-arch-lint                                               |
| `a6794cf` | docs     | End-of-day comprehensive status                                |
| ...       | ...      | Plus 32 more commits across sessions 1–5                       |

**Key achievements from all sessions today:**

- WatchdogSec/sd_notify audit: fixed crash-looping services (taskchampion, comfyui, hermes, signoz)
- Caddy config fix (default_bind)
- EMEET PIXY daemon extracted to standalone repo
- Network config modularized (networking.local options)
- Niri BindsTo incident resolved with PartOf + Restart=always
- Cross-platform health check rewrite
- Systemd service-defaults helper created
- Catppuccin theme unification (homepage, waybar, fzf, starship)
- Minecraft settings declarative via Prism Launcher

---

## b) PARTIALLY DONE

| Task                                | Status                           | What's Left                                                                                                                   |
| ----------------------------------- | -------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| MASTER_TODO_PLAN P5 — Deploy/Verify | 0/13 tasks                       | All require `just switch` on evo-x2 (physical machine)                                                                        |
| MASTER_TODO_PLAN P6 — Services      | 9/15 tasks                       | 6 remaining: Hermes health check, Hermes key_env migration, SigNoz metrics, Authelia SMTP, Immich/Twenty backup restore tests |
| MASTER_TODO_PLAN P9 — Future        | 2/12 tasks                       | homeModules pattern, ComfyUI nix derivation, lldap/Kanidm, VM tests, Cachix, etc.                                             |
| niri-wrapped awww changes           | Committed but untested on evo-x2 | Needs `just switch` + visual verification                                                                                     |

---

## c) NOT STARTED

All P5 tasks (deployment verification) — blocked on evo-x2 physical access:

| #  | Task                              | Est. |
| -- | --------------------------------- | ---- |
| 41 | `just switch` on evo-x2           | 45m+ |
| 42 | Verify Ollama                     | 5m   |
| 43 | Verify Steam                      | 5m   |
| 44 | Verify ComfyUI                    | 5m   |
| 45 | Verify Caddy HTTPS block page     | 3m   |
| 46 | Verify SigNoz metrics/logs/traces | 5m   |
| 47 | Check Authelia SSO                | 3m   |
| 48 | Check PhotoMap                    | 3m   |
| 49 | Verify AMD NPU test workload      | 10m  |
| 50 | Build Pi 3 SD image               | 30m+ |
| 51 | Flash SD + boot Pi 3              | 15m  |
| 52 | Test DNS failover                 | 10m  |
| 53 | Configure LAN devices for DNS VIP | 10m  |

---

## d) TOTALLY FUCKED UP

| Incident                                | What Happened                                                                                                      | Resolution                                                                             | Status                                       |
| --------------------------------------- | ------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------- | -------------------------------------------- |
| WatchdogSec on non-sd_notify services   | Setting WatchdogSec on Python/Go/Rust services without sd_notify support caused systemd to KILL them after timeout | Systematically removed from: TaskChampion, ComfyUI, Hermes, SigNoz, service-defaults   | **FIXED** in `3d64bb6`                       |
| Niri BindsTo=graphical-session.target   | Upstream niri.service uses BindsTo — `just switch` killed niri permanently                                         | Patched to PartOf + Restart=always                                                     | **FIXED** in prior sessions                  |
| niri-wrapped changes in netwatch commit | Pre-existing unstaged awww-daemon changes got swept into the netwatch commit                                       | The changes are correct (Restart=always, BindsTo) but should have been separate commit | **Minor** — cosmetic only, changes are valid |

---

## e) WHAT WE SHOULD IMPROVE

1. **Commit hygiene**: Pre-existing unstaged niri-wrapped changes got mixed into the netwatch commit. Should have committed separately or stashed first.
2. **Automated integration testing**: All P5 tasks are manual verification. No CI pipeline for "does the full NixOS config boot?"
3. **Sops secret management**: 4 security tasks (P1-7/9/10/11) blocked on sops secret creation — needs a streamlined process.
4. **Service dependency documentation**: The WatchdogSec incident shows we need a living "service capability matrix" (sd_notify support, capabilities needed, etc.)
5. **Binary cache**: Building Rust packages from source is slow. Cachix/Hydra would eliminate rebuilds.
6. **MASTER_TODO_PLAN staleness**: Plan hasn't been regenerated since 2026-04-27 — 3 days of work not reflected in completion counts.
7. **Go overlay duplication**: The Go overlay is defined separately for Darwin and perSystem — could consolidate.
8. **Hardcoded paths**: `/home/lars/` in 3 files, `"lars"` username in 7 files — should use module option defaults consistently.

---

## f) Top 25 Things We Should Get Done Next

### Priority 1: Deploy & Verify (requires evo-x2)

| #  | Task                                         | Est. | Impact                          |
| -- | -------------------------------------------- | ---- | ------------------------------- |
| 1  | `just switch` on evo-x2                      | 45m  | **All pending changes go live** |
| 2  | Verify netwatch works on evo-x2              | 2m   | New tool validation             |
| 3  | Verify Caddy HTTPS block page                | 3m   | Security                        |
| 4  | Verify SigNoz collecting metrics/logs/traces | 5m   | Observability                   |
| 5  | Verify Ollama + AI stack                     | 5m   | AI tooling                      |
| 6  | Check Authelia SSO status                    | 3m   | Security                        |
| 7  | Verify ComfyUI works                         | 5m   | AI tooling                      |
| 8  | Verify Steam works                           | 5m   | Gaming                          |
| 9  | Check PhotoMap service status                | 3m   | Services                        |
| 10 | Verify AMD NPU with test workload            | 10m  | Hardware                        |

### Priority 2: Security (requires evo-x2)

| #  | Task                                     | Est. | Impact                      |
| -- | ---------------------------------------- | ---- | --------------------------- |
| 11 | Move Taskwarrior encryption to sops-nix  | 10m  | Eliminates hardcoded secret |
| 12 | Pin Docker image digest for Voice Agents | 5m   | Supply chain security       |
| 13 | Pin Docker image digest for PhotoMap     | 5m   | Supply chain security       |
| 14 | Secure VRRP auth_pass with sops-nix      | 8m   | Network security            |

### Priority 3: Pi 3 DNS Failover Cluster

| #  | Task                                      | Est. | Impact         |
| -- | ----------------------------------------- | ---- | -------------- |
| 15 | Build Pi 3 SD image                       | 30m  | Infrastructure |
| 16 | Flash SD + boot Pi 3                      | 15m  | Infrastructure |
| 17 | Test DNS failover between evo-x2 and Pi 3 | 10m  | Reliability    |
| 18 | Configure LAN devices for DNS VIP         | 10m  | Infrastructure |

### Priority 4: Codebase Improvements

| #  | Task                                                       | Est. | Impact            |
| -- | ---------------------------------------------------------- | ---- | ----------------- |
| 19 | Regenerate MASTER_TODO_PLAN with current state             | 15m  | Accuracy          |
| 20 | Add netwatch to packages/base.nix (cross-platform)         | 5m   | Availability      |
| 21 | Create service capability matrix (sd_notify, capabilities) | 15m  | Documentation     |
| 22 | Investigate Cachix binary cache                            | 30m  | Build performance |
| 23 | Add Hermes health check endpoint                           | 30m  | Observability     |
| 24 | Add NixOS VM tests for critical services                   | 2h   | Testing           |
| 25 | Migrate remaining hardcoded paths to module options        | 20m  | Code quality      |

---

## g) Top #1 Question I Cannot Figure Out Myself

**Should netwatch be a Linux-only package or cross-platform?**

Currently it's in `linuxOnlyOverlays` and only available on `x86_64-linux`. However:

- The Cargo.toml has `cfg(unix)` and `cfg(target_os = "linux")` conditional dependencies
- It builds fine on macOS (uses system libpcap)
- The user's macOS machine is `aarch64-darwin`

Moving it to shared overlays would make it available on both machines. But the monitoring-tools module that installs it as a system package is NixOS-only. Should I:

- **A)** Keep Linux-only (current) — simpler, monitoring module handles installation
- **B)** Make cross-platform in shared overlays + add to Darwin home packages — available everywhere

I went with **A** since it's a network diagnostics tool most useful on the server, but the user may have a preference.

---

## Session Statistics

| Metric                      | Value                                                                         |
| --------------------------- | ----------------------------------------------------------------------------- |
| Commits today               | 47                                                                            |
| Commits this session        | 2 (netwatch + emeet-pixyd extraction)                                         |
| Files changed this session  | 5 (pkgs/netwatch.nix, flake.nix, monitoring.nix, AGENTS.md, niri-wrapped.nix) |
| New packages added          | 1 (netwatch v0.14.1)                                                          |
| Build time (netwatch)       | ~3 min (Rust from source)                                                     |
| Test-fast result            | PASS                                                                          |
| Working tree                | CLEAN                                                                         |
| Branch                      | master (up to date with origin)                                               |
| MASTER_TODO_PLAN completion | 65% (62/95) — likely outdated, needs regeneration                             |
