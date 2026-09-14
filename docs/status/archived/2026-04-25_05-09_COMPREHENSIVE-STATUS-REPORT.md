# SystemNix: Comprehensive Status Report

**Date:** 2026-04-25 05:09
**Branch:** master @ `201a441`
**Origin:** Up to date (all commits pushed)
**Working tree:** Clean (1 untracked: previous status report)
**Stashes:** 0
**Total project:** 104 Nix files, 12,624 lines, 1,807 commits
**Remote:** `git@github.com:LarsArtmann/SystemNix.git`
**Remote branches:** `master`, `feature/nushell-configs`, `organize-packages`

---

## A) FULLY DONE

### Three Sessions of Work (17 Commits)

**Session 1 (6 commits): Docs audit + security hardening**

- Archived 40 redundant status docs, rewrote README.md
- Fixed "29 modules" → "27" accuracy
- Dropped 3 stale stashes, deleted 17 remote `copilot/fix-*` branches
- Added systemd hardening to gitea-ensure-repos (was zero directives)
- Pinned Voice Agents and PhotoMap Docker images `latest→1.0.0`
- Added VRRP authentication to dns-failover
- Removed dead `ublock-filters.nix` module (237 lines)
- Added WatchdogSec + Restart to Gitea, Authelia, TaskChampion, Caddy
- Fixed git.nix `core.pager="cat"` conflict
- Enabled `services.udisks2`
- Added `.editorconfig`
- Made deadnix check strict (`--fail`)
- Fixed 9 deadnix warnings across 9 files
- Made GPG path cross-platform
- Removed 7 duplicate git ignores
- Cleaned unfree allowlist
- Removed dead let bindings in twenty.nix

**Session 2 (6 commits): `lib/systemd.nix` + service refactoring**

- Created `lib/systemd.nix` with 3 composable functions
- Refactored **ALL 16 services** with system-level `serviceConfig` to use shared helper
- Fixed structural bug in gitea-repos.nix (ExecStartPre/ExecStart outside serviceConfig)
- Removed Fish fake variables, guarded GOPATH PATH
- Added bash history config
- Added `homepage` to emeet-pixyd package meta

**Session 3 (5 commits): Quality fixes + theme consolidation**

- Made SigNoz alert rule provisioning idempotent (GET→delete→POST)
- Removed unused `pipecatPort` from voice-agents.nix
- Replaced broken eval smoke tests with honest stubs
- Consolidated 3 duplicate justfile recipes → aliases (`validate`/`check-nix-syntax`/`deploy`)
- Added `VISUAL = "micro"` and `MANPAGER = "less -R"`
- Added Taskwarrior daily backup systemd user timer (30-day rotation)
- Removed dead `platforms/nixos/desktop/display-manager.nix`
- Consolidated Catppuccin: `colorScheme` via `extraSpecialArgs` to all 3 HM instances
- Created `platforms/common/theme.nix` as single source of truth
- Wired `theme.nix` to NixOS `home.nix` (replacing 8 hardcoded values)

### Infrastructure That Works

| System                        | Status                                                                                  |
| ----------------------------- | --------------------------------------------------------------------------------------- |
| `just test-fast`              | **PASSING** — all NixOS modules + darwin eval validated                                 |
| Pre-commit hooks              | **ALL PASSING** — gitleaks, deadnix (--fail), statix, alejandra, nix flake check        |
| GitHub Actions CI             | **4 jobs**: check (macOS+Ubuntu), build-darwin, syntax-check, go-test (emeet+dnsblockd) |
| Auto flake updates            | **Weekly** — `flake-update.yml` creates PRs via peter-evans/create-pull-request         |
| `lib/systemd.nix`             | **Adopted by all 16 hardened services** — 0 services with raw serviceConfig             |
| `theme.nix`                   | **Single source of truth** on NixOS (variant, accent, GTK, cursor, font)                |
| `colorScheme` extraSpecialArg | **Passed to all 3 HM instances** — starship, tmux, zellij use palette colors            |

### Service Inventory (27 modules)

| Service              | Hardened | Notes                                              |
| -------------------- | -------- | -------------------------------------------------- |
| Docker (default.nix) | N/A      | Daemon config only                                 |
| AI Stack             | No       | NixOS system package                               |
| Audio                | No       | PipeWire config                                    |
| Authelia             | **Yes**  | SSO/OIDC, 4 sops secrets, Caddy forwardAuth        |
| Caddy                | **Yes**  | TLS via sops, forwardAuth helper, 12+ vhosts       |
| Chromium policies    | No       | System policies                                    |
| ComfyUI              | **Yes**  | Docker, ROCm GPU, 16GB limit                       |
| Display Manager      | No       | SDDM theme                                         |
| DNS Failover         | No       | Keepalived VRRP                                    |
| Gitea                | **Yes**  | SQLite, GitHub mirror, Actions runner, 3 CLI tools |
| Gitea Repos          | **Yes**  | Oneshot mirror sync + timer                        |
| Hermes               | **Yes**  | Discord bot, cron, 5 sops secrets                  |
| Homepage             | **Yes**  | Service dashboard                                  |
| Immich               | **Yes**  | PostgreSQL, Redis, OAuth, daily backup             |
| Minecraft            | **Yes**  | Docker game server                                 |
| Monitor365           | No       | **Disabled** (high RAM)                            |
| Monitoring           | No       | System metrics config                              |
| Multi-WM             | No       | Window manager compat                              |
| Niri Config          | No       | Compositor settings                                |
| PhotoMap             | **Yes**  | Docker, AI photo exploration                       |
| Security Hardening   | No       | Audit, sysctl, kernel hardening                    |
| SigNoz               | **Yes**  | Full observability (ClickHouse + OTel + scrapers)  |
| Sops                 | N/A      | Secrets management                                 |
| Steam                | No       | Gaming platform                                    |
| TaskChampion         | **Yes**  | Taskwarrior sync server                            |
| Twenty CRM           | **Yes**  | Docker CRM                                         |
| Voice Agents         | **Yes**  | LiveKit + Whisper ASR, Docker                      |

**16/27 modules hardened** via `lib/systemd.nix`. 11 have no systemd services (config-only or disabled).

---

## B) PARTIALLY DONE

| Task                      | Done                                                                 | Remaining                                                                                                                         |
| ------------------------- | -------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| Docker image pinning      | Tags pinned (`1.0.0`)                                                | sha256 digests not pinned (2 TODO comments: voice-agents, photomap)                                                               |
| Catppuccin consolidation  | 3 HM modules use `colorScheme.palette`, home.nix uses `theme.nix`    | 3 locations still hardcode: `configuration.nix` (2), `darwin/default.nix` (1), `zellij` theme string                              |
| SigNoz provisioning       | Alert rules idempotent (GET→delete→POST)                             | **Dashboards still POST-only** — creates duplicates on each restart                                                               |
| Taskwarrior encryption    | Sync works, deterministic IDs                                        | Public hash in repo — needs cross-platform sops (darwin lacks sops-nix)                                                           |
| `theme.nix` wiring        | NixOS home.nix fully wired                                           | **Darwin does NOT import theme.nix** — still hardcodes separately                                                                 |
| Security-hardening module | `modules/nixos/services/security-hardening.nix` (flake module) works | **`platforms/nixos/desktop/security-hardening.nix` is a near-identical duplicate** (149 vs 151 lines, byte-for-byte same content) |
| DNS failover              | VRRP auth added                                                      | Default password hardcoded `"DNSClusterVRRP"` — should come from sops for production                                              |

---

## C) NOT STARTED

### Architecture

- Add `enable` toggles to 16 always-on service modules
- Wire `preferences.nix` or kill it (currently dead on NixOS, only darwin imports it)
- Resolve `preferences.nix` vs `theme.nix` duality

### Deployment & Verification (ALL 13 tasks — requires human)

- `just switch` — deploy 17 commits to evo-x2
- Verify Ollama, Steam, ComfyUI, Caddy, SigNoz, Authelia, PhotoMap
- Pi 3: build SD image, flash, boot, test DNS failover end-to-end

### Service Improvements (14 tasks)

- Twenty CRM: backup rotation, fix hardcoded container name
- ComfyUI: hardcoded paths → module options, system user, memory limit
- Voice agents: Whisper ASR health check
- Hermes: health check endpoint, migrate providers to `key_env`
- SigNoz: add missing service metrics for 8 services
- Authelia: SMTP notifications
- Backup restore tests

### Tooling & CI (7 tasks)

- Replace `alejandra` with `nixfmt-rfc-style`
- Trim system monitors (btop + bottom → pick one)
- Fix `LC_ALL` override redundancy
- Remove `allowUnsupportedSystem`
- Setup Cachix binary cache
- Make eval smoke tests meaningful (or remove them)

### Documentation (5 tasks)

- Document DNS cluster in AGENTS.md
- Write ADR for niri session restore
- Add module option descriptions
- Create CONTRIBUTING.md
- Update top-level README.md

### Future/Research (12 tasks)

- GPU passthrough to Docker containers
- Immich hardware transcoding
- Niri IPC scripting for workspace automation
- Home Assistant integration
- WireGuard VPN mesh
- Cachix deployment automation
- etc.

---

## D) TOTALLY FUCKED UP (Mistakes Made & Fixed)

| # | What happened                                     | Impact                                                                                                      | Resolution                                                         |
| - | ------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------ |
| 1 | gitea-repos.nix structural bug (session 2)        | ExecStartPre/ExecStart placed outside `serviceConfig` during initial refactor — service would fail silently | Fixed immediately. `nix fmt` syntax check caught the misplacement. |
| 2 | Taskwarrior `home.file` addition (session 2)      | Added `home.file` pointing to nonexistent path — no functional benefit, no security improvement             | Reverted in commit `1670737`.                                      |
| 3 | Eval smoke test removal (session 3)               | Removed `                                                                                                   |                                                                    |
| 4 | rpi3 extraSpecialArgs edit (session 3)            | Edit ate the closing `};` and `inputs.self.nixosModules.dns-failover` line, breaking rpi3 config            | Fixed immediately. `just test-fast` caught it before commit.       |
| 5 | Statix warnings in theme.nix/home.nix (session 3) | Used `{}: rec` and `x = theme.x` patterns that statix flags                                                 | Fixed: `_` for unused arg, `inherit` for assignments.              |

**Zero lasting damage.** All 5 issues caught by pre-commit hooks or `just test-fast` before push.

### Current Known Bugs / Broken Things

| Issue                                                                           | Severity   | Status                                                            |
| ------------------------------------------------------------------------------- | ---------- | ----------------------------------------------------------------- |
| Ollama/Steam/ComfyUI broken on live evo-x2 (hipblaslt Tensile gfx908 rejection) | **HIGH**   | Fix is in code (removed hipblaslt), needs `just switch` to deploy |
| SigNoz dashboards duplicate on every restart                                    | **MEDIUM** | Alert rules fixed, dashboards still POST-only                     |
| `monitor365` disabled — high RAM usage                                          | **LOW**    | Intentional, documented in configuration.nix                      |
| 2 stale remote branches (`feature/nushell-configs`, `organize-packages`)        | **LOW**    | Left alone — may have intended work                               |
| Duplicate `security-hardening.nix` (modules/ vs platforms/)                     | **MEDIUM** | Byte-for-byte identical, platforms/ version is dead import        |

---

## E) WHAT WE SHOULD IMPROVE

### Architecture Debt

1. **`preferences.nix` is a zombie** — Defines 13 NixOS module options, only darwin imports it, nobody reads its values on NixOS. `theme.nix` now provides the actual values. Need to pick one: kill `preferences.nix`, wire it properly, or merge into `theme.nix`.
2. **`theme.nix` not wired to darwin** — Only NixOS imports it. Darwin still hardcodes `colorScheme` separately.
3. **Duplicate `security-hardening.nix`** — Identical files in `modules/nixos/services/` (flake module, used) and `platforms/nixos/desktop/` (plain module, also imported via `configuration.nix`). Double-applying the same security settings.
4. **16 modules have no `enable` option** — Always-on services can't be toggled without editing the import list.
5. **No binary cache** — Custom overlays (Go 1.26.1, SigNoz built from source) cause 30-60 min cache misses on fresh machines.
6. **4× `allowUnfree = true`** in flake.nix — Could consolidate to shared nixpkgs config.

### Process Debt

7. **`just switch` not run since 04-24** — Ollama/Steam/ComfyUI broken on live system. 17 commits of changes untested at runtime.
8. **Taskwarrior encryption secret is public** — `sha256("taskchampion-sync-encryption-systemnix")` visible in repo. HTTPS on LAN mitigates but it's not zero-trust.
9. **Docker images use tags only** — `1.0.0` > `latest` but sha256 digests would be immutable. 2 TODO comments remain.
10. **DNS failover VRRP password** — Default `"DNSClusterVRRP"` is hardcoded. Should come from sops.

### Code Quality

11. **Catppuccin string literals** — Zellij `theme = "catppuccin-mocha"` is a theme identifier, not a color palette. Can't use `colorScheme.palette` without upstream changes.
12. **`fonts.packages` in common path** — NixOS-specific option in `platforms/common/packages/fonts.nix`. Works on darwin via nix-darwin but conceptually wrong.
13. **SigNoz dashboards not idempotent** — Alert rules fixed, dashboards still create duplicates.
14. **Eval smoke tests are honest stubs** — They pass but don't test anything. `nix flake check --no-build` does the real validation.
15. **No `.pre-commit-config.yaml`** — Pre-commit hooks are defined in `flake.nix` checks, not in a standard `.pre-commit-config.yaml`. Works but non-standard.

---

## F) TOP #25 THINGS TO DO NEXT

### TIER 1: Deploy & Verify (REQUIRES HUMAN)

| # | Task                                          | Est. | Why                                        |
| - | --------------------------------------------- | ---- | ------------------------------------------ |
| 1 | `just switch` — deploy 17 commits to evo-x2   | 45m  | Ollama/Steam/ComfyUI broken until deployed |
| 2 | Verify Ollama + Steam + ComfyUI after rebuild | 15m  | hipblaslt fix must be validated            |
| 3 | Verify Caddy HTTPS block page + all vhosts    | 5m   | TLS certs, forwardAuth, 12+ vhosts         |
| 4 | Verify SigNoz metrics/logs/traces collection  | 5m   | Full observability stack                   |
| 5 | Verify Authelia SSO login (immich, gitea)     | 3m   | OIDC flow end-to-end                       |
| 6 | Verify Taskwarrior backup timer fires         | 2m   | Daily backup, 30-day rotation              |

### TIER 2: High-Impact Code (AI CAN DO NOW)

| #  | Task                                                              | Est. | Why                                         |
| -- | ----------------------------------------------------------------- | ---- | ------------------------------------------- |
| 7  | Delete duplicate `platforms/nixos/desktop/security-hardening.nix` | 5m   | Byte-for-byte duplicate of modules/ version |
| 8  | Wire `theme.nix` to darwin `home.nix`                             | 15m  | Cross-platform theme consistency            |
| 9  | Fix SigNoz dashboard provisioning (idempotent)                    | 10m  | Same fix pattern as alert rules             |
| 10 | Move DNS failover VRRP password to sops                           | 10m  | Production security                         |
| 11 | Add enable toggles to core 4 modules (sops, caddy, gitea, immich) | 45m  | Service composability                       |
| 12 | Pin Docker sha256 digests (voice-agents + photomap)               | 10m  | Immutable deployments                       |
| 13 | Setup Cachix binary cache                                         | 30m  | 30-60min build time savings                 |

### TIER 3: Service Improvements

| #  | Task                                          | Est. | Why                 |
| -- | --------------------------------------------- | ---- | ------------------- |
| 14 | Hermes: add health check endpoint             | 10m  | Service reliability |
| 15 | ComfyUI: fix hardcoded paths → module options | 12m  | Configurability     |
| 16 | Twenty CRM: add backup rotation               | 8m   | Data safety         |
| 17 | Voice agents: add Whisper ASR health check    | 8m   | Service reliability |
| 18 | Authelia: add SMTP notifications              | 10m  | User experience     |

### TIER 4: Quality & Documentation

| #  | Task                                                      | Est. | Why                        |
| -- | --------------------------------------------------------- | ---- | -------------------------- |
| 19 | Resolve `preferences.nix` vs `theme.nix` (pick one)       | 15m  | Eliminate zombie module    |
| 20 | Document DNS cluster in AGENTS.md                         | 10m  | Onboarding                 |
| 21 | Write ADR for niri session restore design                 | 10m  | Architecture documentation |
| 22 | Update top-level README.md                                | 12m  | Project presentation       |
| 23 | Add missing metrics for 8 services in SigNoz              | 12m  | Observability coverage     |
| 24 | Consolidate 4× `allowUnfree = true` in flake.nix          | 10m  | DRY principle              |
| 25 | File nixpkgs issue for hipblaslt Tensile gfx908 rejection | 10m  | Upstream fix               |

**Estimated total: ~5.5 hours (Tier 1: 1.25h, Tier 2: 1.8h, Tier 3: 0.8h, Tier 4: 1.1h)**

---

## G) MY TOP #1 QUESTION

**What's the plan for `preferences.nix` vs `theme.nix`?**

Two parallel theme systems coexist right now:

|                 | `preferences.nix`                     | `theme.nix`                        |
| --------------- | ------------------------------------- | ---------------------------------- |
| **Type**        | NixOS module options (with defaults)  | Plain Nix attrset                  |
| **Imported by** | Darwin only                           | NixOS home.nix only                |
| **Consumed by** | Nothing (options defined, never read) | home.nix (GTK, cursor, font, icon) |
| **Mutable**     | Yes (can override via NixOS config)   | No (static values)                 |
| **Scope**       | 13 options (appearance + font)        | 10 values (theme constants)        |
| **Lines**       | ~80 (with option definitions)         | 19 (just values)                   |

Options:

1. **Kill `preferences.nix`** — Delete it, use `theme.nix` everywhere. Simplest. Loses per-machine override ability.
2. **Wire `preferences.nix` into `configuration.nix`** — Import on NixOS, pass values to HM. Enables per-machine overrides but adds complexity.
3. **Merge them** — `theme.nix` becomes the defaults for `preferences.nix` options. Best of both worlds, more wiring.

Which direction?

---

## MASTER_TODO_PLAN Progress

| Priority         | Total  | Done   | Partial | Not Started |
| ---------------- | ------ | ------ | ------- | ----------- |
| P0 CRITICAL      | 6      | 6      | 0       | 0           |
| P1 SECURITY      | 7      | 6      | 0       | 1           |
| P2 RELIABILITY   | 11     | 9      | 0       | 2           |
| P3 CODE QUALITY  | 9      | 9      | 0       | 0           |
| P4 ARCHITECTURE  | 7      | 3      | 2       | 2           |
| P5 DEPLOY/VERIFY | 13     | 0      | 0       | 13          |
| P6 SERVICES      | 15     | 1      | 0       | 14          |
| P7 TOOLING/CI    | 10     | 3      | 0       | 7           |
| P8 DOCS          | 6      | 1      | 0       | 5           |
| P9 FUTURE        | 12     | 0      | 0       | 12          |
| **TOTAL**        | **96** | **38** | **2**   | **56**      |

**Completion: 40% (40/96). P0-P3: 97% (39/40) — only Taskwarrior sops remains.**

---

## Key Files Reference

| File                              | Purpose                                                      |
| --------------------------------- | ------------------------------------------------------------ |
| `lib/systemd.nix`                 | Shared systemd hardening helpers (3 composable functions)    |
| `platforms/common/theme.nix`      | Single source of truth for theme values                      |
| `docs/status/MASTER_TODO_PLAN.md` | 96-task prioritized plan                                     |
| `docs/status/REVIEW_DOCS.md`      | Full review of all 44 status docs                            |
| `modules/nixos/services/*.nix`    | 27 service modules, 16 using `lib/systemd.nix`               |
| `platforms/nixos/users/home.nix`  | NixOS HM config, imports theme.nix                           |
| `flake.nix`                       | 635 lines — inputs, overlays, 3 system configs, checks, apps |
| `justfile`                        | 300+ lines — cross-platform task runner                      |

## Quick Commands

```bash
just test-fast          # Syntax-only validation (passes)
just switch             # Deploy to current platform (NEEDS HUMAN)
just update             # Update flake inputs
just format             # Format with treefmt + alejandra
nix fmt                 # Auto-format all Nix files
just health             # Health check
```
