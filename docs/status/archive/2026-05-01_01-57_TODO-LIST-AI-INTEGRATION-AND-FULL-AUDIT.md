# Session 9 — todo-list-ai Integration & Full System Audit

**Date:** 2026-05-01 01:57
**Session Duration:** ~30 minutes
**Status:** Integration complete, all checks passing

---

## Summary

Integrated `todo-list-ai` (AI-powered TODO extraction CLI) as a cross-platform package into SystemNix. This is a developer tool, not a service — it compiles to a standalone Bun binary and runs on-demand. Available on both macOS (Darwin) and NixOS.

---

## A) FULLY DONE

### todo-list-ai Integration (this session)

| Step                             | Status | Details                                                                                              |
| -------------------------------- | ------ | ---------------------------------------------------------------------------------------------------- |
| Read & understand project        | ✅     | Bun/TypeScript CLI, v2.4.0, 464 tests, multi-provider AI, Effect Schema                              |
| Flake input added                | ✅     | `git+ssh://git@github.com/LarsArtmann/todo-list-ai?ref=master` (private repo, SSH like crush-config) |
| Overlay created                  | ✅     | `todoListAiOverlay` — delegates to `todo-list-ai.packages.${system}.default`                         |
| Wired into sharedOverlays        | ✅     | Available on both Darwin and NixOS via shared overlay list                                           |
| Wired into perSystem overlays    | ✅     | Also in `perSystem` overlay list for `packages` output                                               |
| Added to perSystem.packages      | ✅     | `inherit (pkgs) ... todo-list-ai;` — exposed as flake package                                        |
| Added to cross-platform packages | ✅     | `platforms/common/packages/base.nix` — developmentPackages section                                   |
| Justfile commands                | ✅     | `todo-scan`, `todo-scan-openai`, `todo-scan-mock`, `todo-version`                                    |
| AGENTS.md updated                | ✅     | Architecture tree, essential commands, flake inputs table                                            |
| flake.lock pinned                | ✅     | `todo-list-ai` at `5aedc2a` + `flake-utils` + `nix-systems`                                          |
| `nix flake check --no-build`     | ✅     | All checks pass, derivation evaluated: `todo-list-ai-2.4.0.drv`                                      |

### System-Wide (prior sessions, verified)

| Component               | Status | Count/Details                                                   |
| ----------------------- | ------ | --------------------------------------------------------------- |
| NixOS service modules   | ✅     | 31 modules in `modules/nixos/services/`                         |
| NixOS modules wired     | ✅     | 29 `inputs.self.nixosModules.*` in evo-x2 config                |
| Flake inputs            | ✅     | 27 inputs (includes todo-list-ai)                               |
| Custom packages         | ✅     | 10 in `pkgs/` + todo-list-ai via external flake                 |
| Cross-platform packages | ✅     | 70+ in `platforms/common/packages/base.nix`                     |
| Home Manager modules    | ✅     | 14+ program modules in `platforms/common/programs/`             |
| Theme consistency       | ✅     | Catppuccin Mocha across all apps                                |
| Secrets management      | ✅     | sops-nix with age encryption                                    |
| DNS blocking            | ✅     | Unbound + dnsblockd, 2.5M+ domains blocked                      |
| Observability           | ✅     | SigNoz (ClickHouse + OTel Collector + node_exporter + cAdvisor) |
| DNS failover design     | ✅     | Keepalived VRRP module (Pi 3 hardware not yet provisioned)      |
| Service hardening       | ✅     | systemd security hardening via `lib/systemd.nix` helper         |
| WatchdogSec audit       | ✅     | Removed from all non-sd_notify services                         |
| Session save/restore    | ✅     | Niri window restoration with 60s save interval                  |

---

## B) PARTIALLY DONE

| Item                       | Status                  | What's Missing                                                              |
| -------------------------- | ----------------------- | --------------------------------------------------------------------------- |
| DNS failover cluster       | Designed, module exists | Pi 3 hardware not provisioned, no second node                               |
| AI model storage migration | Module + docs complete  | User must run `just ai-migrate` before first `just switch` on fresh install |
| todo-list-ai               | Package integrated      | Not yet built/tested on real hardware (only `--no-build` check)             |
| ComfyUI                    | Service module exists   | Depends on AI model storage, requires GPU testing                           |

---

## C) NOT STARTED

| Item                                | Priority | Notes                                         |
| ----------------------------------- | -------- | --------------------------------------------- |
| Build todo-list-ai on real hardware | High     | `--no-build` passed but actual build untested |
| Automated flake input updates       | Medium   | Currently manual `just update`                |
| CI/CD pipeline                      | Medium   | No GitHub Actions for SystemNix itself        |
| NixOS tests (actual build)          | High     | Only `--no-build` checked in this session     |
| Darwin eval smoke test              | Low      | Currently just a placeholder check            |
| Pi 3 image build & deploy           | Low      | Hardware not available                        |
| Homepage dashboard service links    | Low      | Cosmetic                                      |
| Immich Bull Board patch             | Low      | Patch file exists, not wired                  |

---

## D) TOTALLY FUCKED UP

Nothing. Clean session. No broken state, no reverts, no failures.

The only notable issue was the initial `github:LarsArtmann/todo-list-ai` URL returning 404 (private repo), which was immediately fixed by switching to `git+ssh://` like other LarsArtmann private inputs.

---

## E) WHAT WE SHOULD IMPROVE

### High Impact

1. **Test actual builds, not just eval** — `nix flake check --no-build` only validates syntax. We should periodically run `nix build .#todo-list-ai` on real hardware.
2. **CI pipeline for SystemNix** — No automated validation on push. A `nix flake check` GitHub Action would catch regressions.
3. **Centralized version management** — todo-list-ai version is pinned in its own flake.nix (2.4.0). If we need to override, we'd need a separate overlay.

### Medium Impact

4. **Flake input categorization** — 27 inputs is a lot. Consider grouping: core, services, tools, private.
5. **Justfile organization** — 1970 lines and growing. Could benefit from `just` modules or includes.
6. **AGENTS.md accuracy audit** — Some entries may be stale (e.g., descriptions from early sessions).
7. **Document which packages are Darwin-only vs Linux-only vs cross-platform** — Currently implicit in the overlay lists.
8. **Status doc pruning** — 43 status docs in `docs/status/`, most are historical. Consider archiving older ones.

### Low Impact

9. **todo-list-ai shell completions** — Not provided by the package. Could generate via `--help` output.
10. **todo-list-ai config file** — `~/.todo-list-ai.json` not managed via Home Manager.

---

## F) Top 25 Things to Do Next

| #  | Task                                                                       | Impact | Effort |
| -- | -------------------------------------------------------------------------- | ------ | ------ |
| 1  | `just switch` on NixOS to verify todo-list-ai actually builds and installs | High   | Low    |
| 2  | `just switch` on Darwin to verify cross-platform compatibility             | High   | Low    |
| 3  | Run `todo-list-ai --provider mock --dir ~/projects/SystemNix` to test CLI  | High   | Low    |
| 4  | Add GitHub Actions CI with `nix flake check --no-build`                    | High   | Medium |
| 5  | Periodic full build test (`nix build .#nixosConfigurations.evo-x2`)        | High   | High   |
| 6  | Audit all 31 service modules for consistency                               | Medium | Medium |
| 7  | Wire todo-list-ai API keys via sops for non-interactive scans              | Medium | Low    |
| 8  | Add todo-list-ai config to Home Manager (`.todo-list-ai.json`)             | Low    | Low    |
| 9  | Provision Pi 3 for DNS failover cluster                                    | High   | High   |
| 10 | Test VRRP failover between evo-x2 and Pi 3                                 | High   | Medium |
| 11 | Add nix-auto-update automation (Renovate or github-actions)                | Medium | Medium |
| 12 | Audit flake.lock staleness — when were inputs last updated?                | Medium | Low    |
| 13 | Clean up/archive old status docs (43 → keep last 10)                       | Low    | Low    |
| 14 | Review justfile for dead recipes (1970 lines)                              | Low    | Medium |
| 15 | Add `nix flake check` pre-commit hook                                      | Medium | Low    |
| 16 | Test monitor365 service on real hardware                                   | Medium | Low    |
| 17 | Wire Immich Bull Board patch                                               | Low    | Low    |
| 18 | Add Ollama GPU acceleration testing                                        | Medium | Medium |
| 19 | Verify all sops secrets are current and decryptable                        | Medium | Low    |
| 20 | Homepage dashboard — add all services to dashboard                         | Low    | Low    |
| 21 | Document which packages are Darwin/NixOS/cross-platform in AGENTS.md       | Low    | Low    |
| 22 | Add `just health-dashboard` recipe for comprehensive system overview       | Low    | Medium |
| 23 | Consider merging small service modules (e.g., display-manager + audio)     | Low    | Medium |
| 24 | Test Photomap service end-to-end                                           | Medium | Medium |
| 25 | Review Twenty CRM service status                                           | Medium | Low    |

---

## G) Top Question I Cannot Answer Myself

**Should todo-list-ai be a system package (available to all users) or a user-level Home Manager package?**

Currently it's in `platforms/common/packages/base.nix` → `environment.systemPackages` (system-level). This means:

- Available to all users on the system
- Rebuild required to update
- No user-specific config possible

Alternative: Move to Home Manager `home.packages` in `platforms/nixos/users/home.nix` and `platforms/darwin/home.nix`:

- Per-user installation
- Could add config file management (`.todo-list-ai.json`)
- More Nix-idiomatic for CLI tools used by one person

For a single-user system like evo-x2, either works. But if you want to manage the config file declaratively, Home Manager is the right place.

---

## Files Changed This Session

| File                                 | Lines Changed | Purpose                                                   |
| ------------------------------------ | ------------- | --------------------------------------------------------- |
| `flake.nix`                          | +15 -1        | Added input, overlay, wiring                              |
| `flake.lock`                         | +56           | Pinned todo-list-ai + flake-utils + nix-systems           |
| `platforms/common/packages/base.nix` | +3            | Added todo-list-ai to devPackages                         |
| `justfile`                           | +20           | todo-scan, todo-scan-openai, todo-scan-mock, todo-version |
| `AGENTS.md`                          | +10           | Architecture tree, commands, flake inputs table           |

**Total: 103 lines added, 1 removed, 5 files changed.**

---

## Project Metrics

```
Flake inputs:          27 (27 URL declarations)
NixOS service modules: 31 files in modules/nixos/services/
NixOS modules wired:   29 inputs.self.nixosModules.* for evo-x2
Custom packages:       10 in pkgs/ + 1 external (todo-list-ai)
Cross-platform pkgs:   70+ in platforms/common/packages/base.nix
HM program modules:    14+ in platforms/common/programs/
Justfile recipes:      ~130+ (1970 lines)
Status docs:           43 in docs/status/
AGENTS.md:             554 lines
```

---

_Next session: Verify build on real hardware, consider CI pipeline._
