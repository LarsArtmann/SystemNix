# Status Report — Module Enable Toggles + CI Setup

**Date:** 2026-04-25
**Commits:** `bcfe724` → `b7e6d34` (5 commits)
**Branch:** `master` (synced with origin)

---

## Completed This Session

### P4-37–40: Enable Toggles for All 16 Service Modules

Every service module now has an explicit `services.<name>.enable` toggle gated with `lib.mkIf`. All are activated in `configuration.nix`.

| Batch | Commit    | Modules                                                 | Option Names                                                                   |
| ----- | --------- | ------------------------------------------------------- | ------------------------------------------------------------------------------ |
| P4-37 | `bcfe724` | sops, caddy, gitea, immich                              | `sops-config`, `caddy`, `gitea`, `immich`                                      |
| P4-38 | `02b8474` | authelia, photomap, homepage, taskchampion              | `authelia-config`, `photomap`, `homepage`, `taskchampion-config`               |
| P4-39 | `eb02fcc` | display-manager, audio, niri-config, security-hardening | `display-manager-config`, `audio-config`, `niri-desktop`, `security-hardening` |
| P4-40 | `8dd8ccc` | monitoring, multi-wm, chromium-policies, steam          | `monitoring-tools`, `multi-wm`, `chromium-policies`, `steam-config`            |

**Key pattern:** Modules wrapping nixpkgs service options (where we also set `enable = true`) use a custom `-config` suffixed option to avoid infinite recursion. Modules for services without nixpkgs option conflicts use the natural name.

### P7-69/70/71: GitHub Actions CI

Three workflow files created in `.github/workflows/`:

| Workflow           | Trigger                 | Purpose                                                                                   |
| ------------------ | ----------------------- | ----------------------------------------------------------------------------------------- |
| `nix-check.yml`    | push/PR to master       | `nix flake check --no-build`                                                              |
| `go-test.yml`      | push/PR (Go paths)      | `go vet` + `go test -race` for emeet-pixyd; `go vet` + `go build` for dnsblockd-processor |
| `flake-update.yml` | Weekly Monday 06:00 UTC | `nix flake update` + auto PR via `peter-evans/create-pull-request`                        |

---

## Verification

- `nix flake check --no-build` passes (all modules evaluate)
- All 5 commits pass pre-commit hooks (gitleaks, deadnix, statix, alejandra, nix-check, flake-lock-validate)
- All changes pushed to origin

---

## MASTER_TODO_PLAN Progress

| Tasks                              | Status      |
| ---------------------------------- | ----------- |
| P4-37 through P4-40 (4 tasks)      | ✅ Complete |
| P7-69, P7-70, P7-71 (3 tasks)      | ✅ Complete |
| **7 tasks completed this session** |             |

---

## Remaining AI-Actionable Tasks (from MASTER_TODO_PLAN)

Next priorities from the plan that can be done without evo-x2 access:

- **P1-8:** Add systemd hardening to `gitea-ensure-repos` service
- **P1-12:** Remove dead `ublock-filters.nix` module
- **P1-13:** Fix `gitea-ensure-repos` missing `Restart` + `StartLimitBurst`
- **P2-14/15:** Add `WatchdogSec` + `Restart=on-failure` to caddy, gitea, authelia, taskchampion, sops
- **P2-16:** Fix dead `let` bindings
- **P2-20:** Add `.editorconfig`
- **P3-25–28:** Fix deadnix unused params (4 batches)
- **P7-72–78:** Eval smoke tests, justfile cleanup, pre-commit modernization

## User Action Required

- **P5-41:** `just switch` on evo-x2 to deploy all changes
- **P1-7:** Move Taskwarrior encryption secret to sops-nix (requires evo-x2)
- **P1-9/10:** Pin Docker image digests (requires evo-x2)
- **P1-11:** Secure VRRP auth_pass with sops-nix (requires evo-x2)
