# COMPREHENSIVE EXECUTION PLAN — SystemNix

**Created:** 2026-05-05 01:00
**Scope:** ALL known TODOs, bugs, improvements across 104 .nix files
**Methodology:** Pareto — sort by (impact × customer-value) / effort, split into ≤12min tasks
**Status:** 81 tasks across 12 categories, ready for execution

---

## Scoring

| Axis      | Scale | Meaning                                        |
| --------- | ----- | ---------------------------------------------- |
| Impact    | 1-5   | 5 = system broken without it, 1 = nice-to-have |
| CustVal   | 1-5   | 5 = user sees immediately, 1 = invisible       |
| Effort    | min   | Estimated minutes (≤12 per task)               |
| **Score** |       | `(Impact × CustVal) / Effort × 10`             |

---

## ALL TASKS — Sorted by Score (Highest First)

| #  | Category | Task                                                                                                                                   | Impact | CustVal | Effort | Score | Prereq        |
| -- | -------- | -------------------------------------------------------------------------------------------------------------------------------------- | ------ | ------- | ------ | ----- | ------------- |
| 1  | BUG      | Fix taskwarrior.nix Darwin breakage — wrap `systemd.user` in `lib.mkIf pkgs.stdenv.isLinux`                                            | 5      | 5       | 5      | 50    | —             |
| 2  | BUG      | Remove duplicate Caddy firewall ports (80/443 already in networking.nix)                                                               | 4      | 3       | 5      | 24    | —             |
| 3  | DRY      | Create `modules/nixos/system/primary-user.nix` with `options.users.primaryUser`                                                        | 5      | 3       | 12     | 13    | —             |
| 4  | DRY      | Replace hardcoded `"lars"` in ai-models, disk-monitor, file-and-image-renamer, monitor365, minecraft (5 files with `default = "lars"`) | 5      | 2       | 8      | 13    | #3            |
| 5  | DRY      | Replace hardcoded `"lars"` in gitea, comfyui, ai-stack, scheduled-tasks (4 files with `primaryUser = "lars"`)                          | 5      | 2       | 8      | 13    | #3            |
| 6  | DRY      | Replace hardcoded `"lars"` in sops.nix (2× `owner = "lars"`), configuration.nix (`allowUsers`), ssh-config.nix (2× `user = "lars"`)    | 5      | 2       | 8      | 13    | #3            |
| 7  | BUG      | Add WatchdogSec=30 to Caddy (Type=notify service, no watchdog set)                                                                     | 4      | 4       | 2      | 40    | —             |
| 8  | RELIAB   | Add MemoryMax to Caddy systemd service (no memory limit, can OOM system)                                                               | 4      | 4       | 2      | 40    | —             |
| 9  | RELIAB   | Add MemoryMax to authelia (no memory limit on auth gateway)                                                                            | 4      | 4       | 2      | 40    | —             |
| 10 | RELIAB   | Add MemoryMax to gitea (no memory limit on git hosting)                                                                                | 4      | 3       | 2      | 30    | —             |
| 11 | RELIAB   | Add MemoryMax to homepage (no memory limit on dashboard)                                                                               | 3      | 3       | 2      | 23    | —             |
| 12 | RELIAB   | Add MemoryMax to taskchampion (no memory limit on sync server)                                                                         | 3      | 3       | 2      | 23    | —             |
| 13 | RELIAB   | Add MemoryMax to voice-agents (no memory limit)                                                                                        | 3      | 3       | 2      | 23    | —             |
| 14 | RELIAB   | Add MemoryMax to sops-nix related services                                                                                             | 3      | 2       | 2      | 15    | —             |
| 15 | BUG      | Fix starship.nix — disable 6 unused modules (git_commit, git_state, package, shell, time, username)                                    | 2      | 4       | 3      | 27    | —             |
| 16 | DRY      | Extract shared DNS subdomain list from dns-blocker-config.nix + rpi3/default.nix into shared module                                    | 4      | 2       | 8      | 10    | —             |
| 17 | BUG      | Justfile: remove dead recipes (tmux-setup, go-setup, duplicate dep-graph)                                                              | 2      | 3       | 5      | 12    | —             |
| 18 | BUG      | Justfile: fix `update-nix` — guard with platform detection (fails on NixOS)                                                            | 3      | 3       | 3      | 30    | —             |
| 19 | MAINT    | Archive old status reports — move 75+ files from docs/status/ to docs/status/archive/                                                  | 2      | 2       | 10     | 4     | —             |
| 20 | HARDEN   | Add harden{} to gitea service                                                                                                          | 3      | 1       | 5      | 6     | —             |
| 21 | HARDEN   | Add harden{} to immich service                                                                                                         | 3      | 1       | 5      | 6     | —             |
| 22 | HARDEN   | Add harden{} to signoz services (multiple systemd units)                                                                               | 3      | 1       | 10     | 3     | —             |
| 23 | HARDEN   | Add harden{} to minecraft service                                                                                                      | 3      | 1       | 5      | 6     | —             |
| 24 | HARDEN   | Add harden{} to comfyui service                                                                                                        | 3      | 1       | 5      | 6     | —             |
| 25 | HARDEN   | Add harden{} to twenty service                                                                                                         | 3      | 1       | 5      | 6     | —             |
| 26 | HARDEN   | Add harden{} to voice-agents service                                                                                                   | 3      | 1       | 5      | 6     | —             |
| 27 | HARDEN   | Add harden{} to sops service                                                                                                           | 3      | 1       | 5      | 6     | —             |
| 28 | HARDEN   | Add harden{} to ai-stack ollama service                                                                                                | 3      | 1       | 5      | 6     | —             |
| 29 | HARDEN   | Add harden{} to hermes service (already has import, wire serviceConfig)                                                                | 3      | 1       | 5      | 6     | —             |
| 30 | THEME    | Adopt colorScheme.palette in yazi.nix (60+ hardcoded hex colors)                                                                       | 2      | 4       | 12     | 7     | —             |
| 31 | THEME    | Adopt colorScheme.palette in waybar.nix (30+ hardcoded hex colors)                                                                     | 2      | 4       | 12     | 7     | —             |
| 32 | THEME    | Adopt colorScheme.palette in rofi.nix (15 hardcoded hex colors)                                                                        | 2      | 3       | 10     | 6     | —             |
| 33 | THEME    | Adopt colorScheme.palette in wlogout.nix (35 hardcoded hex colors)                                                                     | 2      | 3       | 12     | 5     | —             |
| 34 | THEME    | Adopt colorScheme.palette in homepage.nix (12 CSS custom properties)                                                                   | 2      | 2       | 8      | 5     | —             |
| 35 | THEME    | Fix fzf.nix remaining hardcoded color (#a6adc8)                                                                                        | 2      | 2       | 2      | 20    | —             |
| 36 | SPLIT    | Split signoz.nix (746 lines) into signoz/clickhouse.nix, signoz/query-service.nix, signoz/otel-collector.nix                           | 2      | 2       | 12     | 3     | —             |
| 37 | SPLIT    | Split signoz.nix — extract scrapers into signoz/scrapers.nix                                                                           | 2      | 2       | 10     | 4     | #36           |
| 38 | SPLIT    | Split signoz.nix — update flake.nix imports                                                                                            | 2      | 2       | 3      | 13    | #36           |
| 39 | FEATURE  | Enable Gatus — import in flake.nix + enable in configuration.nix                                                                       | 4      | 4       | 5      | 32    | —             |
| 40 | FEATURE  | Personalize Gatus ntfy topic (currently default)                                                                                       | 2      | 3       | 3      | 20    | #39           |
| 41 | FEATURE  | Add Gatus health checks for all services (caddy, gitea, immich, etc.)                                                                  | 3      | 4       | 12     | 10    | #39           |
| 42 | MAINT    | Update FEATURES.md (stale: says Ollama keep-alive 24h, now 1h)                                                                         | 3      | 2       | 5      | 12    | —             |
| 43 | MAINT    | Update AGENTS.md — add primaryUser module, unsloth disabled, harden adoption status                                                    | 3      | 2       | 8      | 8     | #3            |
| 44 | MAINT    | Update AGENTS.md — document Gatus if enabled                                                                                           | 2      | 2       | 5      | 8     | #39           |
| 45 | MAINT    | Update justfile help recipe (missing 30+ recipes)                                                                                      | 2      | 2       | 10     | 4     | —             |
| 46 | MAINT    | Fix justfile backup/restore — remove dotfiles references (managed by HM now)                                                           | 2      | 2       | 5      | 8     | —             |
| 47 | DRY      | Centralize firewall ports — create networking.firewall module or move all to networking.nix                                            | 3      | 2       | 10     | 6     | —             |
| 48 | DRY      | Adopt lib/types.nix helpers (servicePort, restartDelay) in service modules                                                             | 2      | 1       | 12     | 2     | —             |
| 49 | DRY      | Refactor modules to import from lib/default.nix central entry instead of direct paths                                                  | 2      | 1       | 12     | 2     | —             |
| 50 | RELIAB   | Add serviceDefaults{} to gitea                                                                                                         | 2      | 2       | 3      | 13    | —             |
| 51 | RELIAB   | Add serviceDefaults{} to immich                                                                                                        | 2      | 2       | 3      | 13    | —             |
| 52 | RELIAB   | Add serviceDefaults{} to signoz                                                                                                        | 2      | 2       | 5      | 8     | —             |
| 53 | RELIAB   | Add serviceDefaults{} to minecraft                                                                                                     | 2      | 2       | 3      | 13    | —             |
| 54 | RELIAB   | Add serviceDefaults{} to comfyui                                                                                                       | 2      | 2       | 3      | 13    | —             |
| 55 | RELIAB   | Add serviceDefaults{} to twenty                                                                                                        | 2      | 2       | 3      | 13    | —             |
| 56 | RELIAB   | Add serviceDefaults{} to voice-agents                                                                                                  | 2      | 2       | 3      | 13    | —             |
| 57 | RELIAB   | Add coredumpctl vacuum weekly timer                                                                                                    | 3      | 2       | 10     | 6     | —             |
| 58 | BUG      | Simplify lib/systemd.nix — remove mkDefault if not needed (question pending)                                                           | 3      | 2       | 8      | 8     | user decision |
| 59 | SAFETY   | Add ReadWritePaths to hardened services that need write access                                                                         | 3      | 1       | 12     | 3     | #20-29        |
| 60 | QUALITY  | Add NixOS test harness (nixosTests) for critical services                                                                              | 3      | 3       | 12     | 8     | —             |
| 61 | MAINT    | Audit all tmpfiles.rules for consistency (some use primaryUser, some hardcode)                                                         | 2      | 2       | 8      | 5     | #3            |
| 62 | THEME    | Create centralized Catppuccin Mocha color module (avoid per-file palette references)                                                   | 2      | 3       | 12     | 5     | —             |
| 63 | DEPLOY   | Run `just switch` on evo-x2 to deploy all changes                                                                                      | 5      | 5       | 12     | 21    | all above     |
| 64 | VERIFY   | Verify pstore works (`ls /sys/fs/pstore/`)                                                                                             | 3      | 3       | 1      | 90    | #63           |
| 65 | VERIFY   | Verify GPU shows ~32GB in btop/nvtop                                                                                                   | 3      | 3       | 1      | 90    | #63           |
| 66 | VERIFY   | Verify all services healthy after deploy (`just health`)                                                                               | 4      | 4       | 5      | 32    | #63           |
| 67 | VERIFY   | Test Ollama inference                                                                                                                  | 3      | 3       | 10     | 9     | #63           |
| 68 | VERIFY   | Test BTRFS snapshot restore                                                                                                            | 3      | 2       | 12     | 5     | —             |
| 69 | MAINT    | Docker overlay cleanup — prune images/containers                                                                                       | 2      | 2       | 10     | 4     | —             |
| 70 | FUTURE   | Update ancient flake inputs (nix-colors, base16-schemes)                                                                               | 2      | 2       | 10     | 4     | —             |
| 71 | FUTURE   | Provision Pi 3 for DNS failover cluster                                                                                                | 4      | 3       | 60     | 2     | hardware      |
| 72 | FUTURE   | Add kdump for kernel crash diagnostics                                                                                                 | 3      | 2       | 12     | 5     | —             |
| 73 | FUTURE   | Add UPS shutdown integration                                                                                                           | 3      | 2       | 12     | 5     | hardware      |
| 74 | FUTURE   | Add LUKS + TPM disk encryption                                                                                                         | 3      | 2       | 12     | 5     | —             |
| 75 | FUTURE   | Add NIC bonding for network redundancy                                                                                                 | 2      | 2       | 12     | 3     | hardware      |
| 76 | FUTURE   | Set up CI/CD pipeline for flake checks                                                                                                 | 3      | 2       | 12     | 5     | —             |
| 77 | FUTURE   | SSH CA for certificate-based auth                                                                                                      | 3      | 2       | 12     | 5     | —             |
| 78 | MAINT    | Write docs/TODO_LIST.md from this plan                                                                                                 | 2      | 2       | 8      | 5     | —             |
| 79 | MAINT    | Remove unsloth references from AGENTS.md architecture section                                                                          | 2      | 2       | 3      | 13    | —             |
| 80 | BUG      | Fix monitor365 MemoryMax merge order (disabled service has wrong merge)                                                                | 2      | 2       | 2      | 20    | —             |
| 81 | QUALITY  | Add health check endpoints to custom services (photomap, voice-agents, comfyui)                                                        | 2      | 3       | 12     | 5     | —             |

---

## EXECUTION WAVES (Grouped by Dependency + Score)

### Wave 1 — Critical Bugs (No Deps, High Score)

**Est: ~30min | Tasks: #1, #2, #7, #8, #9, #15, #18, #80**

| #  | Task                                   | Time |
| -- | -------------------------------------- | ---- |
| 1  | Fix taskwarrior.nix Darwin guard       | 5min |
| 2  | Remove duplicate Caddy firewall ports  | 5min |
| 7  | Add WatchdogSec=30 to Caddy            | 2min |
| 8  | Add MemoryMax to Caddy                 | 2min |
| 9  | Add MemoryMax to authelia              | 2min |
| 80 | Fix monitor365 MemoryMax merge order   | 2min |
| 15 | Fix starship unused modules            | 3min |
| 18 | Fix justfile update-nix platform guard | 3min |

### Wave 2 — Memory Limits (No Deps, High Reliability)

**Est: ~20min | Tasks: #10, #11, #12, #13, #14**

| #  | Task                           | Time |
| -- | ------------------------------ | ---- |
| 10 | Add MemoryMax to gitea         | 2min |
| 11 | Add MemoryMax to homepage      | 2min |
| 12 | Add MemoryMax to taskchampion  | 2min |
| 13 | Add MemoryMax to voice-agents  | 2min |
| 14 | Add MemoryMax to sops services | 2min |

### Wave 3 — primaryUser DRY (Sequential Chain)

**Est: ~35min | Tasks: #3 → #4 → #5 → #6**

| # | Task                                                | Time  |
| - | --------------------------------------------------- | ----- |
| 3 | Create primary-user.nix module                      | 12min |
| 4 | Replace hardcoded lars (5 files with defaults)      | 8min  |
| 5 | Replace hardcoded lars (4 files with primaryUser)   | 8min  |
| 6 | Replace hardcoded lars (sops, config, ssh — 5 refs) | 8min  |

### Wave 4 — Harden Adoption

**Est: ~50min | Tasks: #20-29**

| #  | Task                                    | Time  |
| -- | --------------------------------------- | ----- |
| 20 | Add harden{} to gitea                   | 5min  |
| 21 | Add harden{} to immich                  | 5min  |
| 22 | Add harden{} to signoz (multiple units) | 10min |
| 23 | Add harden{} to minecraft               | 5min  |
| 24 | Add harden{} to comfyui                 | 5min  |
| 25 | Add harden{} to twenty                  | 5min  |
| 26 | Add harden{} to voice-agents            | 5min  |
| 27 | Add harden{} to sops                    | 5min  |
| 28 | Add harden{} to ai-stack ollama         | 5min  |

### Wave 5 — serviceDefaults Adoption

**Est: ~25min | Tasks: #50-56**

| #  | Task                                  | Time |
| -- | ------------------------------------- | ---- |
| 50 | Add serviceDefaults{} to gitea        | 3min |
| 51 | Add serviceDefaults{} to immich       | 3min |
| 52 | Add serviceDefaults{} to signoz       | 5min |
| 53 | Add serviceDefaults{} to minecraft    | 3min |
| 54 | Add serviceDefaults{} to comfyui      | 3min |
| 55 | Add serviceDefaults{} to twenty       | 3min |
| 56 | Add serviceDefaults{} to voice-agents | 3min |

### Wave 6 — Features & DRY

**Est: ~30min | Tasks: #39, #16, #35, #40, #47**

| #  | Task                              | Time  |
| -- | --------------------------------- | ----- |
| 39 | Enable Gatus (import + config)    | 5min  |
| 40 | Personalize Gatus ntfy topic      | 3min  |
| 16 | Extract shared DNS subdomain list | 8min  |
| 35 | Fix fzf.nix hardcoded color       | 2min  |
| 47 | Centralize firewall ports         | 10min |

### Wave 7 — Theme Adoption

**Est: ~60min | Tasks: #30, #31, #32, #33, #34, #62**

| #  | Task                              | Time  |
| -- | --------------------------------- | ----- |
| 62 | Create centralized color module   | 12min |
| 30 | Adopt colorScheme in yazi.nix     | 12min |
| 31 | Adopt colorScheme in waybar.nix   | 12min |
| 32 | Adopt colorScheme in rofi.nix     | 10min |
| 33 | Adopt colorScheme in wlogout.nix  | 12min |
| 34 | Adopt colorScheme in homepage.nix | 8min  |

### Wave 8 — Signoz Split

**Est: ~25min | Tasks: #36, #37, #38**

| #  | Task                          | Time  |
| -- | ----------------------------- | ----- |
| 36 | Split signoz into sub-modules | 12min |
| 37 | Extract scrapers              | 10min |
| 38 | Update flake.nix imports      | 3min  |

### Wave 9 — Maintenance & Cleanup

**Est: ~60min | Tasks: #17, #19, #42, #43, #44, #45, #46, #61, #69, #78, #79**

| #  | Task                                          | Time  |
| -- | --------------------------------------------- | ----- |
| 79 | Remove unsloth from AGENTS.md                 | 3min  |
| 42 | Update FEATURES.md                            | 5min  |
| 43 | Update AGENTS.md (primaryUser, harden status) | 8min  |
| 44 | Update AGENTS.md (Gatus)                      | 5min  |
| 17 | Remove dead justfile recipes                  | 5min  |
| 45 | Update justfile help recipe                   | 10min |
| 46 | Fix justfile backup/restore dotfiles refs     | 5min  |
| 61 | Audit tmpfiles.rules consistency              | 8min  |
| 69 | Docker overlay cleanup                        | 10min |
| 19 | Archive old status reports                    | 10min |
| 78 | Write docs/TODO_LIST.md                       | 8min  |

### Wave 10 — Deploy & Verify

**Est: ~35min | Tasks: #63, #64, #65, #66, #67, #68**

| #  | Task                        | Time  |
| -- | --------------------------- | ----- |
| 63 | `just switch` on evo-x2     | 12min |
| 64 | Verify pstore               | 1min  |
| 65 | Verify GPU memory           | 1min  |
| 66 | Verify all services healthy | 5min  |
| 67 | Test Ollama inference       | 10min |
| 68 | Test BTRFS snapshot restore | 12min |

### Wave 11 — Quality & Advanced

**Est: ~60min | Tasks: #41, #57, #58, #59, #60, #70, #81**

| #  | Task                                          | Time  |
| -- | --------------------------------------------- | ----- |
| 41 | Add Gatus health checks for all services      | 12min |
| 57 | Add coredumpctl vacuum timer                  | 10min |
| 58 | Simplify lib/systemd.nix (if user approves)   | 8min  |
| 59 | Add ReadWritePaths to hardened services       | 12min |
| 60 | Add NixOS test harness                        | 12min |
| 70 | Update ancient flake inputs                   | 10min |
| 81 | Add health check endpoints to custom services | 12min |

### Wave 12 — Future (External Dependencies)

**Est: varies | Tasks: #71-77**

| #  | Task              | Time  | Dependency |
| -- | ----------------- | ----- | ---------- |
| 72 | Add kdump         | 12min | —          |
| 74 | Add LUKS + TPM    | 12min | —          |
| 76 | CI/CD pipeline    | 12min | GitHub     |
| 77 | SSH CA            | 12min | —          |
| 71 | Pi 3 DNS failover | 60min | Hardware   |
| 73 | UPS integration   | 12min | Hardware   |
| 75 | NIC bonding       | 12min | Hardware   |

---

## SUMMARY STATISTICS

| Metric                  | Value                                                                         |
| ----------------------- | ----------------------------------------------------------------------------- |
| Total tasks             | 81                                                                            |
| Total estimated time    | ~8.5 hours                                                                    |
| Waves                   | 12                                                                            |
| Critical bugs (Wave 1)  | 8 tasks, 30min                                                                |
| DRY (Wave 3)            | 4 tasks, 35min                                                                |
| Hardening (Waves 4+5)   | 16 tasks, 75min                                                               |
| Theme (Wave 7)          | 6 tasks, 60min                                                                |
| Deploy+Verify (Wave 10) | 6 tasks, 35min                                                                |
| External deps (Wave 12) | 7 tasks, varies                                                               |
| Files to modify         | ~45 unique files                                                              |
| New files to create     | ~5 (primary-user.nix, color module, signoz split, TODO_LIST.md, gatus config) |

---

## WHAT WE SHOULD IMPROVE (Meta)

1. **Atomic commits** — API changes to shared libs must be ONE commit with all callers
2. **Post-batch validation** — Always run `nix flake check` after the LAST change, not between
3. **No mkDefault question** — Decide if mkDefault is needed in harden{} or if plain values + `//` suffice
4. **Test Darwin builds** — We can't verify macOS changes locally; need CI or remote build
5. **Pre-commit hook message rewriting** — Creates confusion; consider disabling auto-rewrite
6. **Status report hygiene** — 327 files across status/ and archive/; auto-archive after 7 days
7. **Feature flags** — Every new service should have `enable = false` by default

---

_Arte in Aeternum_
