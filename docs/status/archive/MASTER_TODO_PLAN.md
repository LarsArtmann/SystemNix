# MASTER TODO PLAN — SystemNix

**Regenerated:** 2026-04-27
**Source:** Comprehensive code audit of all 96 original tasks
**Previous version:** 2026-04-26 (96 tasks, ~63% complete)

---

## Status Summary

| Category         | Total     | Done   | Remaining | % Complete |
| ---------------- | --------- | ------ | --------- | ---------- |
| P0 CRITICAL      | 6         | 6      | 0         | 100%       |
| P1 SECURITY      | 7         | 3      | 4         | 43%        |
| P2 RELIABILITY   | 11        | 11     | 0         | 100%       |
| P3 CODE QUALITY  | 9         | 9      | 0         | 100%       |
| P4 ARCHITECTURE  | 7         | 7      | 0         | 100%       |
| P5 DEPLOY/VERIFY | 13        | 0      | 13        | 0%         |
| P6 SERVICES      | 15        | 9      | 6         | 60%        |
| P7 TOOLING/CI    | 10        | 10     | 0         | 100%       |
| P8 DOCS          | 5         | 5      | 0         | 100%       |
| P9 FUTURE        | 12        | 2      | 10        | 17%        |
|                  | **TOTAL** | **95** | **62**    | **33**     | **65%** |

---

## COMPLETED TASKS (verified against code)

### P0 — CRITICAL (6/6 DONE)

| #   | Task                                    | Evidence                                           |
| --- | --------------------------------------- | -------------------------------------------------- |
| 1   | ✅ Push all commits to origin           | `git log origin/master..HEAD` = empty              |
| 2   | ✅ Clear stale stashes                  | `git stash list` = empty                           |
| 3   | ✅ Delete remote copilot/fix-* branches | `git branch -r \| grep copilot` = empty            |
| 4   | ✅ Archive redundant status docs        | 40 docs in `archive/`, 5 retained + new audit docs |
| 5   | ✅ Rewrite status README.md             | 6 lines, lean                                      |
| 6   | ✅ Fix "29 modules" → "27" in docs      | No matches in 04-24 files                          |

### P1 — SECURITY (3/7 DONE)

| #   | Task                                            | Status               | Evidence                                                                                                   |
| --- | ----------------------------------------------- | -------------------- | ---------------------------------------------------------------------------------------------------------- |
| 7   | Move Taskwarrior encryption to sops             | ⬜ BLOCKED on evo-x2 | Hardcoded `sha256("taskchampion-sync-encryption-systemnix")` in taskwarrior.nix:38                         |
| 8   | ✅ Add systemd hardening to gitea-ensure-repos  | `bcfe724`            | PrivateTmp, NoNewPrivileges, ProtectHome, ProtectSystem, MemoryMax                                         |
| 9   | Pin Docker digest for Voice Agents              | ⬜ BLOCKED on evo-x2 | Version-tagged (`beecave/insanely-fast-whisper-rocm:1.0.0`) but not digest-pinned (voice-agents.nix:24-25) |
| 10  | Pin Docker digest for PhotoMap                  | ⬜ BLOCKED on evo-x2 | Version-tagged (`lstein/photomapai:1.0.0`) but not digest-pinned (photomap.nix:35-36)                      |
| 11  | Secure VRRP auth_pass with sops                 | ⬜ BLOCKED on evo-x2 | Plaintext in dns-failover.nix                                                                              |
| 12  | ✅ Remove dead ublock-filters.nix               | File deleted         | No longer exists                                                                                           |
| 13  | ✅ Add Restart + StartLimitBurst to gitea-repos | `bcfe724`            | Restart=on-failure, startLimitBurst=3                                                                      |

### P2 — RELIABILITY (11/11 DONE)

| #   | Task                                                    | Evidence                                                     |
| --- | ------------------------------------------------------- | ------------------------------------------------------------ |
| 14  | ✅ WatchdogSec for caddy, gitea, authelia, taskchampion | All have WatchdogSec=30                                      |
| 15  | ✅ Restart=on-failure for all services                  | All long-running services have Restart                       |
| 16  | ✅ Fix dead let bindings                                | Twenty.nix, dns-blocker, aw-watcher-utilization all clean    |
| 17  | ✅ Fix core.pager vs pager.diff conflict                | No core.pager set — only pager.diff = "bat"                  |
| 18  | ✅ Fix fonts.packages darwin compatibility              | `lib.mkIf pkgs.stdenv.isLinux` guard in packages/fonts.nix:6 |
| 19  | ✅ Enable services.udisks2                              | `udisks2.enable = true` in configuration.nix:144             |
| 20  | ✅ Add .editorconfig                                    | Exists at root: 2-space indent, UTF-8, LF, Go tabs           |
| 21  | ✅ Make deadnix strict with --fail                      | `deadnix --fail --no-lambda-pattern-names` in flake.nix:354  |
| 22  | ✅ Fix pre-commit statix hook                           | Configured in .pre-commit-config.yaml:38-44                  |
| 23  | ✅ Add date + commit hash to debug-map.md               | Present in header                                            |
| 24  | ✅ Add meta.homepage to emeet-pixyd                     | pkgs/emeet-pixyd.nix:22                                      |

### P3 — CODE QUALITY (9/9 DONE)

| #     | Task                                       | Evidence                                                                                                  |
| ----- | ------------------------------------------ | --------------------------------------------------------------------------------------------------------- |
| 25-28 | ✅ Fix deadnix unused params (all batches) | All 12 service modules fixed: `{inputs, ...}:` → `{...}:`                                                 |
| 29    | ✅ Remove duplicate git ignores            | All entries unique in git.nix                                                                             |
| 30    | ✅ Fix GPG program cross-platform          | `if pkgs.stdenv.isDarwin` conditional in git.nix:53-59                                                    |
| 31    | ✅ Fix bash.nix history config             | HISTCONTROL, HISTSIZE, HISTFILESIZE, shelloptions all present                                             |
| 32    | ✅ Fix Fish $GOPATH init timing            | `fish_add_path --prepend --global $GOPATH/bin` with guard; `fish_maximum_history_size` is a real variable |
| 33    | ✅ Clean unfree allowlist                  | No castlabs-electron or cursor in list; signal-desktop-bin stays (installed)                              |

### P4 — ARCHITECTURE (7/7 DONE)

| #   | Task                                                                                | Evidence                                                                                                        |
| --- | ----------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| 34  | ✅ Create lib/systemd.nix shared helper                                             | lib/systemd.nix — harden function                                                                               |
| 35  | ✅ Wire preferences.nix to theming                                                  | theme.nix already consumed in home.nix (GTK, cursor, Qt, fonts); preferences.nix is declarative options version |
| 36  | ✅ Convert niri session restore to module options                                   | sessionSaveInterval, maxSessionAgeDays, fallbackApps as options in niri-wrapped.nix:308-361                     |
| 37  | ✅ Enable toggles batch 1 (sops, caddy, gitea, immich)                              | `bcfe724`                                                                                                       |
| 38  | ✅ Enable toggles batch 2 (authelia, photomap, homepage, taskchampion)              | `02b8474`                                                                                                       |
| 39  | ✅ Enable toggles batch 3 (display-manager, audio, niri-config, security-hardening) | `eb02fcc`                                                                                                       |
| 40  | ✅ Enable toggles batch 4 (monitoring, multi-wm, chromium-policies, steam)          | `8dd8ccc`                                                                                                       |

### P7 — TOOLING & CI (10/10 DONE)

| #   | Task                                      | Evidence                                                                                                       |
| --- | ----------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| 69  | ✅ GitHub Actions: nix flake check        | `.github/workflows/nix-check.yml`                                                                              |
| 70  | ✅ GitHub Actions: Go test                | `.github/workflows/go-test.yml`                                                                                |
| 71  | ✅ GitHub Actions: flake.lock auto-update | `.github/workflows/flake-update.yml`                                                                           |
| 72  | ✅ Fix eval smoke tests                   | No `                                                                                                           |     | true` — simple echo-to-out commands |
| 73  | ✅ Consolidate duplicate justfile recipes | No duplicates found                                                                                            |
| 74  | ✅ Replace nixpkgs-fmt with alejandra     | Already using alejandra in .pre-commit-config.yaml                                                             |
| 75  | ✅ Trim system monitors to 2              | Only btop + bottom in base.nix                                                                                 |
| 76  | ✅ Fix LC_ALL/LANG redundancy             | Removed LC_ALL — LANG = "en_US.UTF-8" is sufficient; LC_CTYPE still set in fish.nix:17 for macOS compatibility |
| 77  | ✅ Set allowUnsupportedSystem = false     | nix-settings.nix:75                                                                                            |
| 78  | ✅ Taskwarrior backup timer               | systemd timer in taskwarrior.nix:163-174, OnCalendar = "daily"                                                 |

### P6 — SERVICES (9/15 DONE)

| #     | Task                                 | Evidence                                                        |
| ----- | ------------------------------------ | --------------------------------------------------------------- |
| 54    | ✅ Twenty CRM backup rotation        | `find ... -mtime +30 -delete` in twenty.nix:168                 |
| 55    | ✅ Twenty CRM container name         | Docker Compose `name: twenty` is standard — not hardcoded       |
| 56    | ComfyUI hardcoded paths              | ⬜ ACCEPTABLE — module option defaults designed for override    |
| 57    | ✅ ComfyUI WatchdogSec + MemoryMax   | `WatchdogSec = "60"` + `MemoryMax = "8G"` in comfyui.nix:98-103 |
| 58    | ComfyUI dedicated user               | ⬜ ACCEPTABLE — runs as lars for GPU render/video group access  |
| 59    | ✅ Voice agents Whisper health check | Not applicable — pipecatPort removed                            |
| 60    | ✅ Voice agents unused pipecatPort   | Not present — already clean                                     |
| 61    | ✅ Voice agents PIDFile              | Not present — already clean                                     |
| 62    | Hermes health check                  | ⬜ PENDING — needs health endpoint in Hermes                    |
| 63    | Hermes key_env migration             | ⬜ PENDING — mergeEnvScript redundant but low risk              |
| 64    | ✅ SigNoz duplicate rules            | Idempotent delete-before-create in signoz.nix:287-298           |
| 65    | SigNoz missing metrics               | ⬜ BLOCKED — needs evo-x2 to verify metric endpoints            |
| 66    | Authelia SMTP notifications          | ⬜ BLOCKED — needs SMTP credentials                             |
| 67-68 | Immich/Twenty backup restore tests   | ⬜ BLOCKED — needs evo-x2                                       |

---

## REMAINING TASKS

### P1 — SECURITY (blocked on evo-x2 access)

| #   | Task                                           | Category | Est. | Blocker                                                             |
| --- | ---------------------------------------------- | -------- | ---- | ------------------------------------------------------------------- |
| 7   | Move Taskwarrior encryption secret to sops-nix | SECURITY | 10m  | Needs evo-x2 for sops secret creation                               |
| 9   | Pin Docker image digest for Voice Agents       | SECURITY | 5m   | Version-tagged not `latest`, but needs evo-x2 to pull SHA256 digest |
| 10  | Pin Docker image digest for PhotoMap           | SECURITY | 5m   | Version-tagged not `latest`, but needs evo-x2 to pull SHA256 digest |
| 11  | Secure VRRP auth_pass with sops-nix            | SECURITY | 8m   | Needs evo-x2 for sops secret                                        |

### P5 — DEPLOYMENT & VERIFICATION (all require evo-x2)

| #   | Task                                                 | Category | Est. |
| --- | ---------------------------------------------------- | -------- | ---- |
| 41  | `just switch` — deploy all pending changes to evo-x2 | DEPLOY   | 45m+ |
| 42  | Verify Ollama works after rebuild                    | VERIFY   | 5m   |
| 43  | Verify Steam works after rebuild                     | VERIFY   | 5m   |
| 44  | Verify ComfyUI works after rebuild                   | VERIFY   | 5m   |
| 45  | Verify Caddy HTTPS block page                        | VERIFY   | 3m   |
| 46  | Verify SigNoz collecting metrics/logs/traces         | VERIFY   | 5m   |
| 47  | Check Authelia SSO status                            | VERIFY   | 3m   |
| 48  | Check PhotoMap service status                        | VERIFY   | 3m   |
| 49  | Verify AMD NPU with test workload                    | VERIFY   | 10m  |
| 50  | Build Pi 3 SD image                                  | DEPLOY   | 30m+ |
| 51  | Flash SD + boot Pi 3                                 | DEPLOY   | 15m  |
| 52  | Test DNS failover                                    | VERIFY   | 10m  |
| 53  | Configure LAN devices for DNS VIP                    | DEPLOY   | 10m  |

### P6 — SERVICES IMPROVEMENT

| #   | Task                                           | Category      | Est.                                                |
| --- | ---------------------------------------------- | ------------- | --------------------------------------------------- |
| 54  | ~~Twenty CRM: add backup rotation/cleanup~~    | DONE          | `find -mtime +30` in twenty.nix                     |
| 55  | ~~Twenty CRM: fix hardcoded container name~~   | DONE          | Docker Compose standard naming                      |
| 56  | ComfyUI: replace hardcoded paths               | LOW PRIORITY  | Module option defaults are designed for override    |
| 57  | ~~ComfyUI: add WatchdogSec + MemoryMax~~       | DONE          | WatchdogSec=60, MemoryMax=8G                        |
| 58  | ComfyUI: run as dedicated system user          | ACCEPTABLE    | Needs lars for GPU group access                     |
| 62  | Hermes: add health check endpoint              | OBSERVABILITY | Needs Hermes health endpoint                        |
| 63  | Hermes: migrate remaining providers to key_env | CLEANUP       | mergeEnvScript is redundant, low risk               |
| 64  | ~~SigNoz: fix duplicate rules on reboot~~      | DONE          | Idempotent delete-before-create in provision script |
| 65  | SigNoz: add missing metrics for 10 services    | OBSERVABILITY | Blocked on evo-x2 metric endpoint verification      |
| 66  | Authelia: add SMTP notifications               | UX            | Blocked on SMTP credentials                         |
| 67  | Immich backup restore test                     | RELIABILITY   | Blocked on evo-x2                                   |
| 68  | Twenty CRM backup restore test                 | RELIABILITY   | Blocked on evo-x2                                   |

### P8 — DOCUMENTATION (5/5 DONE)

| #   | Task                                         | Evidence                                                   |
| --- | -------------------------------------------- | ---------------------------------------------------------- |
| 79  | ✅ Write/update top-level README.md          | Updated with all 13 services, DNS failover, new commands   |
| 80  | ✅ Document DNS cluster in AGENTS.md         | DNS Failover Cluster section added                         |
| 81  | ✅ Write ADR for niri session restore design | `docs/architecture/adr-005-niri-session-restore.md`        |
| 82  | ✅ Add module option description fields      | 86 description fields across 8 service files with mkOption |
| 83  | ✅ Create docs/CONTRIBUTING.md               | Full contributing guide with patterns, hooks, architecture |

### P9 — FUTURE / RESEARCH (2/10 investigated, tasks 84+86-96)

| #   | Task                                              | Category | Status       | Notes                                                                                                                             |
| --- | ------------------------------------------------- | -------- | ------------ | --------------------------------------------------------------------------------------------------------------------------------- |
| 85  | Investigate just test intermittent race           | RESEARCH | ⯎ DOCUMENTED | `--all-systems` evaluates x86_64-linux on aarch64-darwin — known Nix cross-system limitation, not a code bug                      |
| 86  | Create homeModules pattern for HM via flake-parts | ARCH     | ⯎            |                                                                                                                                   |
| 87  | Package ComfyUI as proper Nix derivation          | ARCH     | ⯎            |                                                                                                                                   |
| 88  | Investigate lldap/Kanidm for unified auth         | ARCH     | ⯎            |                                                                                                                                   |
| 89  | Migrate Pi 3 from linux-rpi to nixos-hardware     | ARCH     | ⯎            |                                                                                                                                   |
| 90  | Migrate SSH config to HM programs.ssh.matchBlocks | ARCH     | ⯎ DOCUMENTED | nix-ssh-config flake provides SSH keys + server config + client hosts — migrating only client hosts would still require the flake |
| 91  | Add NixOS VM tests for critical services          | TESTING  | ⯎            |                                                                                                                                   |
| 92  | Investigate binary cache (Cachix)                 | PERF     | ⯎            |                                                                                                                                   |
| 93  | Add Waybar module for session restore stats       | FEATURE  | ⯎            |                                                                                                                                   |
| 94  | Add real-time save via niri event-stream          | FEATURE  | ⯎            |                                                                                                                                   |
| 95  | Add integration tests for session restore         | TESTING  | ⯎            |                                                                                                                                   |
| 96  | File nixpkgs issue for hipblaslt Tensile          | UPSTREAM | ⯎            |                                                                                                                                   |

---

## PROACTIVE CLEANUP (beyond original plan)

Completed during code quality audit (commit `f4364c2`):

- Removed 8 dead platform files (628 lines) superseded by flake-parts modules
- Fixed `{…}:` → `_:` anti-pattern in darwin/environment.nix
- Fixed `with lib;` anti-pattern in emeet-pixy.nix (signoz.nix:64 still uses `with lib;` — meta block, low risk)
- Fixed `pkgs.lib.mkForce` → `lib.mkForce` inconsistency in ai-stack.nix
- Cleaned up commented-out dead imports in configuration.nix

Known remaining low-priority issues:

- `HSA_OVERRIDE_GFX_VERSION = "11.5.1"` duplicated in 3 files (hardware-specific constant, minimal DRY benefit from extraction)
- Hardcoded `/home/lars/` paths in 3 files (acceptable as module option defaults)
- Hardcoded `"lars"` username in 7 files (acceptable as module option defaults or `primaryUser` locals)

---

## NEXT ACTIONS

**AI-actionable (remaining):**

1. P6-62: Hermes health check (needs Hermes code change — external dependency)
2. P6-63: Hermes mergeEnvScript cleanup (low risk but needs evo-x2 testing)

**User-actionable (requires evo-x2 or decisions):**

1. P1-7/9/10/11: Sops secrets, Docker digests, VRRP auth
2. P5-41: `just switch` on evo-x2
3. P5-42-49: Verify services after deploy
4. P5-50-53: Pi 3 build and DNS failover
5. P6-65: Verify metric endpoints on evo-x2
6. P6-66: Provide SMTP credentials for Authelia
