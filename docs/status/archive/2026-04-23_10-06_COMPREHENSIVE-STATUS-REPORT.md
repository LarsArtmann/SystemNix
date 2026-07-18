# SystemNix Comprehensive Status Report

**Date:** 2026-04-23 10:06 CEST
**Branch:** master
**HEAD:** `2579d67` — refactor(chromium-policies): streamline browser configuration
**Working tree:** CLEAN (no uncommitted changes)
**Total Nix files:** 92
**Total Nix lines:** ~11,797

---

## A) FULLY DONE ✅

### Infrastructure & Architecture

- **Cross-platform flake** — single flake managing macOS (aarch64-darwin) + NixOS (x86_64-linux) with ~80% shared config via `platforms/common/`
- **flake-parts modular architecture** — 17 service modules as self-contained flake-parts modules in `modules/nixos/services/`
- **Home Manager** — fully wired on both platforms, importing 15 common program modules
- **sops-nix secrets** — age-encrypted secrets via SSH host key, template-based env delivery for all services that need API keys
- **Overlay system** — 8 overlays (Go 1.26, aw-watcher, dnsblockd, emeet-pixyd, jscpd, openaudible, monitor365, unbound DoQ)

### NixOS Services (17 modules)

| Service                | Module             | Status                         |
| ---------------------- | ------------------ | ------------------------------ |
| Docker                 | `default.nix`      | ✅ Always-on                   |
| Caddy (reverse proxy)  | `caddy.nix`        | ✅ Running, TLS via sops       |
| Gitea (git hosting)    | `gitea.nix`        | ✅ Running, GitHub mirror      |
| Gitea repo sync        | `gitea-repos.nix`  | ✅ Automated sync              |
| Homepage dashboard     | `homepage.nix`     | ✅ Running                     |
| Immich (photos)        | `immich.nix`       | ✅ Running                     |
| Photomap (AI photos)   | `photomap.nix`     | ✅ Running                     |
| SigNoz (observability) | `signoz.nix`       | ✅ Full stack                  |
| Authelia (SSO)         | `authelia.nix`     | ✅ Running                     |
| Twenty CRM             | `twenty.nix`       | ✅ Module ready                |
| TaskChampion           | `taskchampion.nix` | ✅ Sync server                 |
| Hermes (AI gateway)    | `hermes.nix`       | ✅ System service, Discord bot |
| Minecraft              | `minecraft.nix`    | ✅ Parameterized               |
| Monitor365             | `monitor365.nix`   | ✅ Device monitoring           |
| ComfyUI (AI image)     | `comfyui.nix`      | ✅ Module ready                |
| Voice agents (Whisper) | `voice-agents.nix` | ✅ Module ready                |
| Sops (secrets)         | `sops.nix`         | ✅ Secret management           |

### Custom Packages (7)

All packages have proper `meta` with description, license, and homepage:

- `dnsblockd` / `dnsblockd-processor` — DNS block page (Go)
- `emeet-pixyd` — EMEET PIXY webcam daemon (Go)
- `aw-watcher-utilization` — ActivityWatch plugin (Python)
- `modernize` — Go modernize tool
- `jscpd` — Copy/paste detector
- `openaudible` — Audible manager
- `monitor365` — Device monitoring agent

### DNS Stack

- Unbound resolver with DNS-over-TLS (Quad9) + DNS-over-QUIC (DoQ) fallback
- dnsblockd block page server with 25 blocklists (2.5M+ domains)
- Local `.home.lan` DNS records for all services

### Desktop (NixOS)

- Niri Wayland compositor with session save/restore (crash recovery)
- Waybar, Rofi, SDDM (Catppuccin Mocha theme throughout)
- Full AI stack (Ollama, ComfyUI, Whisper)

### Observability

- SigNoz full stack (ClickHouse + OTel Collector + Query Service)
- node_exporter + cAdvisor metrics collection
- Journald log ingestion for all services
- OTLP receiver for instrumented apps

### Developer Experience

- `justfile` with 40+ recipes (switch, test, format, deploy, diagnostics, etc.)
- `nix flake check` with statix + deadnix + treefmt checks
- Dev shell with git, alejandra, statix, deadnix, shellcheck, gitleaks, jq
- `nh` for fast NixOS rebuilds
- Pre-commit hooks configured

### Security

- sops-nix for all secrets (age-encrypted)
- Systemd hardening on most services (hermes.nix is the gold standard)
- Firewall with explicit port allowlisting
- DNS-level ad/malware blocking
- SSH via external flake input (nix-ssh-config)

### Statix Linting

- **0 statix warnings** — fully clean as of this session (fixed twenty.nix repeated keys + hermes.nix inherit pattern)

---

## B) PARTIALLY DONE ⚠️

### Deadnix (33 warnings)

Statix is clean, but **33 deadnix warnings** remain across the codebase:

- **12 service modules** with unused `inputs` parameter
- **10+ files** with unused `config`, `lib`, or `pkgs` parameters
- **3 dead `let` bindings** (`appSecretFile`, `pgPasswordFile` in twenty.nix; `addIPScript` in dns-blocker.nix; `poetry` in aw-watcher-utilization.nix)
- **4 unused lambda arguments** (`final`/`oldAttrs` in darwin overlay, `old` in ai-stack, `subdomain` in caddy, `name` in sops, `type` in flake.nix, `utils` in voice-agents)

### Service Module Consistency

Only **7 of 17** service modules follow the full `options` + `mkIf` toggle pattern:

- ✅ `hermes`, `twenty`, `signoz`, `comfyui`, `minecraft`, `monitor365`, `voice-agents`
- ❌ Always-on (no toggle): `sops`, `caddy`, `gitea`, `immich`, `authelia`, `photomap`, `homepage`, `taskchampion`, `default`, `gitea-repos`

### Systemd Hardening Coverage

- **Full hardening**: hermes (gold standard), minecraft, monitor365, signoz
- **Partial hardening**: twenty, comfyui, voice-agents (missing NoNewPrivileges, WatchdogSec, etc.)
- **No hardening**: gitea-repos (zero hardening directives on `gitea-ensure-repos`)
- **No reliability (Restart/WatchdogSec)**: caddy, gitea (main), authelia, taskchampion, sops, default

### Package Metadata

All 7 packages have `meta.description` + `meta.license`. Missing:

- `emeet-pixyd` — no `homepage` URL
- `openaudible` — `unfree` license (correct) but no source URL

---

## C) NOT STARTED 🔲

1. **`.editorconfig`** — no file exists for consistent editor settings across contributors/tools
2. **Treefmt config** — no `treefmt.toml` in repo; formatter comes from `treefmt-full-flake` input (external)
3. **Nix eval checks** — darwin and NixOS eval smoke tests exist but use `|| true` (always pass)
4. **CI/CD pipeline** — no GitHub Actions or equivalent; all checks are local via `nix flake check`
5. **Automated flake input updates** — no Renovate/Dependabot; manual `just update`
6. **Cross-platform testing** — darwin config can't be tested on Linux and vice versa
7. **Documentation site/README** — `docs/status/README.md` exists but no top-level README for the repo
8. **Module option documentation** — service modules with options lack `description` fields on options
9. **`.sops.yaml` shared config** — sops config appears to be per-file rather than centralized
10. **Backup verification** — Immich and Twenty have backup scripts but no restore testing

---

## D) TOTALLY FUCKED UP 💥

### Security Hardening (Blocker)

- **Audit framework disabled** — `security-hardening.nix:19,26` has two TODOs commenting out `auditd` and audit rules due to NixOS bug. Entire audit subsystem is non-functional.
  - See: https://github.com/NixOS/nixpkgs/issues/483085

### Dead Code in Production Modules

- **`twenty.nix:19-20`** — `appSecretFile` and `pgPasswordFile` are `let`-bound from `config.sops.secrets.*.path` but **never used anywhere**. The sops template approach superseded direct file references, but the dead bindings remain.
- **`dns-blocker.nix:288`** — `addIPScript` is defined as a `let` binding but never referenced. Appears to be leftover from a refactoring.
- **`aw-watcher-utilization.nix:2`** — `poetry` is imported but never used in the derivation.

### Flake Check Reliability

The `deadnix` check in `flake.nix` passes despite 33 warnings because deadnix returns exit 0 for warnings (only fails for errors). This means `nix flake check` gives false confidence.

---

## E) WHAT WE SHOULD IMPROVE 📈

### Code Quality

1. **Fix all 33 deadnix warnings** — prefix unused params with `_`, remove dead `let` bindings
2. **Add `.editorconfig`** — 2-space indent, UTF-8, LF line endings for consistency
3. **Make deadnix check strict** — use `--fail` flag so warnings actually fail CI
4. **Add `with pkgs;` lint rule** — 32 files use `with pkgs;` which statix can warn about
5. **Standardize module pattern** — all 17 service modules should have `options` + `mkIf`
6. **Add option descriptions** — `lib.mkEnableOption "..."` should have meaningful descriptions

### Reliability

7. **Complete systemd hardening** — bring all services up to hermes.nix standard
8. **Add WatchdogSec** to all long-running services
9. **Add Restart=on-failure** to services missing it (caddy, gitea, authelia, taskchampion)
10. **Fix audit framework** — track NixOS issue #483085, re-enable when fixed
11. **Harden gitea-repos** — zero hardening on `gitea-ensure-repos` service

### Architecture

12. **Extract shared service patterns** — create a `lib/systemd-harden.nix` helper to avoid repeating 20 lines of hardening per service
13. **Consolidate overlays** — consider moving overlays to a dedicated `overlays/` directory
14. **Add module option documentation** — use `lib.mkOption { description = "..."; }` consistently
15. **Centralize sops config** — shared `.sops.yaml` for secret paths

### Testing & CI

16. **Fix eval smoke tests** — remove `|| true`, make them actually verify evaluation
17. **Add GitHub Actions** — at minimum `nix flake check` on push
18. **Add Renovate** — automated flake.lock updates with PRs
19. **Test restore procedures** — verify Immich/Twenty backups can actually be restored

### Documentation

20. **Write top-level README** — project overview, quickstart, architecture diagram
21. **Clean up status reports** — 39 status reports in `docs/status/`, many are transient; archive old ones
22. **Document module patterns** — AGENTS.md covers this but a `docs/CONTRIBUTING.md` would help human contributors

---

## F) TOP 25 THINGS TO DO NEXT

| #   | Priority | Task                                                                                | Effort | Impact                                     |
| --- | -------- | ----------------------------------------------------------------------------------- | ------ | ------------------------------------------ |
| 1   | 🔴 HIGH  | Fix 3 dead `let` bindings (twenty.nix, dns-blocker.nix, aw-watcher-utilization.nix) | 10min  | Eliminates dead code in production modules |
| 2   | 🔴 HIGH  | Fix all 33 deadnix unused parameter warnings                                        | 30min  | Clean linting baseline                     |
| 3   | 🔴 HIGH  | Make deadnix check strict (`--fail` flag) in flake.nix                              | 5min   | Prevents future dead code from merging     |
| 4   | 🔴 HIGH  | Add systemd hardening to gitea-repos (currently zero)                               | 15min  | Security: unhardened service               |
| 5   | 🔴 HIGH  | Add WatchdogSec + Restart to services missing them                                  | 30min  | Reliability: crash recovery                |
| 6   | 🟡 MED   | Create `lib/systemd-harden.nix` shared helper                                       | 30min  | DRY: avoid 20 lines × 17 services          |
| 7   | 🟡 MED   | Add `options` + `mkIf` to always-on service modules                                 | 1hr    | Enables per-host toggling                  |
| 8   | 🟡 MED   | Add `.editorconfig`                                                                 | 5min   | Consistency across tools                   |
| 9   | 🟡 MED   | Track/fix NixOS audit bug (security-hardening.nix TODOs)                            | 30min  | Security monitoring gap                    |
| 10  | 🟡 MED   | Write top-level README.md                                                           | 30min  | Onboarding, discoverability                |
| 11  | 🟡 MED   | Fix eval smoke tests (remove `\|\| true`)                                           | 15min  | Test reliability                           |
| 12  | 🟡 MED   | Complete systemd hardening for partial services (twenty, comfyui, voice-agents)     | 30min  | Security consistency                       |
| 13  | 🟡 MED   | Add `homepage` URL to emeet-pixyd meta                                              | 2min   | Package metadata completeness              |
| 14  | 🟢 LOW   | Add GitHub Actions for `nix flake check` on push                                    | 30min  | Continuous quality gate                    |
| 15  | 🟢 LOW   | Add Renovate for automated flake.lock updates                                       | 30min  | Dependency freshness                       |
| 16  | 🟢 LOW   | Consolidate overlays to `overlays/` directory                                       | 1hr    | Code organization                          |
| 17  | 🟢 LOW   | Add option `description` fields to all service modules                              | 30min  | Documentation                              |
| 18  | 🟢 LOW   | Centralize sops config (shared `.sops.yaml`)                                        | 30min  | Config dedup                               |
| 19  | 🟢 LOW   | Archive old status reports (39 in docs/status/)                                     | 5min   | Repo cleanliness                           |
| 20  | 🟢 LOW   | Test Immich backup restore procedure                                                | 1hr    | Disaster recovery confidence               |
| 21  | 🟢 LOW   | Test Twenty backup restore procedure                                                | 1hr    | Disaster recovery confidence               |
| 22  | 🟢 LOW   | Add `docs/CONTRIBUTING.md` with module patterns                                     | 30min  | Contributor onboarding                     |
| 23  | 🟢 LOW   | Replace `with pkgs;` with explicit `pkgs.` prefixes in service modules              | 1hr    | Static analysis friendliness               |
| 24  | 🟢 LOW   | Add pre-commit hook for deadnix + statix                                            | 15min  | Catch issues before commit                 |
| 25  | 🟢 LOW   | Add `nix flake check` timing benchmark to justfile                                  | 10min  | Build performance monitoring               |

---

## G) TOP #1 QUESTION 🤔

**What is the intended deployment topology for services that currently lack `options` + `mkIf` toggles?**

Nine service modules (sops, caddy, gitea, immich, authelia, photomap, homepage, taskchampion, default) are always enabled — they have no `services.<name>.enable` option. This means:

1. Are these **intentionally always-on** for the evo-x2 machine (and will never be deployed elsewhere)?
2. Or should they follow the hermes.nix pattern with proper toggle options, in case you want to:
   - Deploy to a second NixOS machine with a different service subset?
   - Temporarily disable a service for debugging?
   - Test configurations without bringing up the full stack?

This matters because adding `options` + `mkIf` to all modules is either a quick standardization win (if multi-machine is planned) or unnecessary overhead (if evo-x2 is the sole target forever).

---

## Session Activity (2026-04-23)

Today's 32 commits include:

- **feat**: DNS-over-QUIC, ComfyUI module, jscpd package, OOM protections, deploy app
- **fix**: hermes env conflict, scheduled-tasks UID, OOM journald, statix lint (twenty.nix, hermes.nix)
- **refactor**: chromium-policies simplification, deploy script inline, SSH extraction, minecraft parameterization
- **docs**: 8 status reports (this is the 9th)
- **chore**: JetBrains IDEA, OpenAudible URL, monitor365 migration, 30-item improvement initiative completion
