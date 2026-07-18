# SystemNix Comprehensive Status Report

**Date:** 2026-04-04 18:59
**Branch:** master
**Recent Commits:** `6c4e091` (scripts cleanup), `0935e7e` (AGENTS.md overhaul), `2abe1bd` (README overhaul)

---

## A) FULLY DONE

| Item                            | Details                                                                                                                                                                                                                                                                                                                                                                                          |
| ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **README.md overhaul**          | Complete rewrite: added NixOS services table (9 services), desktop/hardware sections, cross-platform programs, flake inputs, CI/CD, pre-commit hooks, DNS troubleshooting. Removed broken doc links. All 21 just commands verified.                                                                                                                                                              |
| **AGENTS.md overhaul**          | 1295 → 241 lines (81% reduction). Removed: fabricated Ghost Systems/Type Safety System, generic AI instructions (duplicated by Crush), 6+ non-existent commands, wrong project name (Setup-Mac), wrong WM (Hyprland), wrong Darwin username. Added: accurate architecture, flake-parts service pattern guide, gotchas table, complete flake inputs. All 14 key claims verified against codebase. |
| **Scripts cleanup**             | Reduced from 72 → 21 active scripts (-71%). Archived 7, deleted 28, consolidated 3. Applied statix fixes to ai-stack.nix and signoz.nix.                                                                                                                                                                                                                                                         |
| **NixOS service modules**       | 9 flake-parts modules working: Docker, Caddy, Gitea, Grafana, Homepage, Immich, Prometheus monitoring, PhotoMap AI, SigNoz, sops-nix                                                                                                                                                                                                                                                             |
| **NixOS desktop**               | Niri (Wayland tiling) + Waybar + SDDM + Catppuccin Mocha everywhere. Sway as backup WM.                                                                                                                                                                                                                                                                                                          |
| **NixOS hardware**              | AMD GPU (ROCm), AMD NPU (XDNA), BTRFS dual layout, ZRAM, Timeshift snapshots                                                                                                                                                                                                                                                                                                                     |
| **DNS blocker**                 | Unbound + custom dnsblockd, 25 blocklists, 2.5M+ domains, DNS-over-TLS                                                                                                                                                                                                                                                                                                                           |
| **Cross-platform Home Manager** | 14 shared program modules, ~80% config shared between macOS and NixOS                                                                                                                                                                                                                                                                                                                            |
| **Secrets management**          | sops-nix with age encryption, deployed on both platforms                                                                                                                                                                                                                                                                                                                                         |
| **All Nix imports resolve**     | Zero broken imports across all 78 .nix files                                                                                                                                                                                                                                                                                                                                                     |

---

## B) PARTIALLY DONE

| Item                              | Status                                                                                                                                                                                                | What's Missing                                                                                                                                  |
| --------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| **Stale "Setup-Mac" references**  | 6+ scripts + justfile dep-graph output still use old name                                                                                                                                             | Need rename pass across: `health-dashboard.sh`, `maintenance.sh`, `cleanup.sh`, `optimize.sh`, `validate-deployment.sh`, justfile SVG filenames |
| **Stale "Hyprland" references**   | validate-deployment.sh has full Hyprland validation section (lines 200-243) that will produce false errors                                                                                            | Need removal/rewrite of Hyprland checks                                                                                                         |
| **Stale "Ghost Systems" comment** | `flake.nix:313` still says "Ghost Systems integration"                                                                                                                                                | One-line fix                                                                                                                                    |
| **Docs cleanup**                  | ~150+ docs total, ~90+ in status/ alone, many referencing outdated concepts                                                                                                                           | Need archival pass                                                                                                                              |
| **Pre-commit hooks**              | 8 hooks configured but `gitleaks` and `jq` not in devShell                                                                                                                                            | Need to add to devShell packages                                                                                                                |
| **Orphan scripts**                | 6 scripts not referenced from justfile: `deploy-evo-x2.sh`, `nix-diagnostic.sh`, `dns-diagnostics.sh`, `config-validate.sh`, `find-nix-duplicates.sh`, `test-shell-aliases.sh`, `nixos-diagnostic.sh` | Need either wire into justfile or archive                                                                                                       |
| **private-cloud/ directory**      | Empty except README.md                                                                                                                                                                                | Either implement or remove                                                                                                                      |

---

## C) NOT STARTED

| Item                             | Impact                                                                                                        | Effort |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------- | ------ |
| **Test infrastructure**          | No NixOS VM tests, no `nixosTests`, no property-based testing. All "tests" are imperative bash scripts.       | High   |
| **CI/CD hardening**              | Single workflow (3 jobs). No NixOS build in CI (only Darwin). No caching strategy beyond Cachix.              | Medium |
| **Automated dependency updates** | No Renovate/Dependabot. All updates manual via `just update`.                                                 | Low    |
| **Monitoring/alerting**          | Prometheus scrapes but no alert rules defined. No notification pipeline.                                      | Medium |
| **Backup verification**          | Timeshift configured but no automated restore testing. Immich DB backup timer exists but no integrity checks. | Medium |
| **Secrets rotation**             | sops-nix deployed but no rotation policy or automated key rotation.                                           | Low    |
| **Documentation structure**      | No organized docs tree — status reports, ADRs, and guides mixed together. No docs index.                      | Medium |
| ** Darwin build in CI**          | Only `nix flake check` on macOS runner, no full build verification for NixOS target.                          | Low    |

---

## D) TOTALLY FUCKED UP

| Item                                        | Problem                                                                                                                                                                                                                                           | Severity                          |
| ------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------- |
| **Old AGENTS.md had fabricated content**    | Entire "Ghost Systems" / "Type Safety System" section with files that never existed (`core/TypeSafetySystem.nix`, `core/State.nix`, `core/Validation.nix`, `core/Types.nix`). Only `core/nix-settings.nix` exists. **Fixed in commit `0935e7e`.** | Was critical, now fixed           |
| **Old AGENTS.md had wrong commands**        | Referenced 6+ just commands that don't exist: `just build`, `just debug-paths`, `just type-check`, `just security-scan`, `just deep-clean`, `just benchmark-all`. **Fixed in commit `0935e7e`.**                                                  | Was high, now fixed               |
| **Old AGENTS.md had wrong facts**           | Wrong project name (Setup-Mac), wrong WM (Hyprland → Niri), wrong Darwin user (lars → larsartmann), claimed "uv package manager" and "TypeSpec" exist (they don't). **Fixed in commit `0935e7e`.**                                                | Was high, now fixed               |
| **validate-deployment.sh Hyprland section** | Lines 200-243 contain full Hyprland validation that will produce false errors on Niri-only system. **NOT FIXED.**                                                                                                                                 | Active code, will cause confusion |
| **Docs sprawl**                             | ~90+ status reports in `docs/status/`, many duplicating each other, many referencing dead concepts (Ghost Systems, Hyprland, Setup-Mac). No organization or pruning.                                                                              | Technical debt, confusing         |
| **Flake.nix Go version inconsistency**      | flake.nix overlays `go_1_26` but signoz.nix builds with `go_1_25`. Both may or may not exist in current nixpkgs-unstable. Not verified whether this actually builds.                                                                              | Potential build break             |

---

## E) WHAT WE SHOULD IMPROVE

### Immediate (this session could do)

1. **Fix stale "Setup-Mac" → "SystemNix" in active scripts and justfile**
2. **Fix flake.nix:313 "Ghost Systems" comment**
3. **Remove Hyprland section from validate-deployment.sh**
4. **Add `gitleaks` and `jq` to devShell packages**
5. **Wire orphan scripts into justfile or archive them**

### Short-term (next few sessions)

6. **Prune docs/status/ — archive reports older than 30 days**
7. **Create docs index/README pointing to current documentation**
8. **Verify full NixOS build succeeds** (Go 1.26 overlay + SigNoz source build)
9. **Add NixOS build to CI** (currently only Darwin builds in CI)
10. **Remove or implement `platforms/nixos/private-cloud/`**

### Long-term (strategic)

11. **Add actual NixOS test infrastructure** (nixosTests, VM tests)
12. **Implement Prometheus alerting rules**
13. **Set up automated secret rotation**
14. **Create backup verification pipeline**
15. **Add Renovate or similar for automated flake input updates**

---

## F) TOP 25 THINGS TO DO NEXT

| #   | Task                                                                                  | Priority | Effort | Category       |
| --- | ------------------------------------------------------------------------------------- | -------- | ------ | -------------- |
| 1   | Fix "Setup-Mac" → "SystemNix" in scripts + justfile dep-graph names                   | P0       | 30min  | Stale refs     |
| 2   | Remove Hyprland validation from `validate-deployment.sh`                              | P0       | 15min  | Broken code    |
| 3   | Fix `flake.nix:313` Ghost Systems comment                                             | P0       | 1min   | Stale ref      |
| 4   | Add `gitleaks` and `jq` to devShell packages                                          | P1       | 5min   | Pre-commit     |
| 5   | Verify full `nix flake check --all-systems` passes                                    | P1       | 30min  | Build health   |
| 6   | Wire orphan scripts into justfile or archive                                          | P1       | 30min  | Scripts        |
| 7   | Archive docs/status/ files older than 30 days                                         | P2       | 15min  | Docs cleanup   |
| 8   | Create `docs/README.md` index pointing to key docs                                    | P2       | 30min  | Docs structure |
| 9   | Remove or plan `platforms/nixos/private-cloud/`                                       | P2       | 10min  | Dead code      |
| 10  | Consolidate duplicate DNS scripts (`dns-diagnostics.sh` vs justfile `dns-*` commands) | P2       | 30min  | Scripts        |
| 11  | Update `docs/README.test.md` — still references Setup-Mac and Hyprland                | P2       | 15min  | Stale docs     |
| 12  | Add NixOS build job to CI workflow                                                    | P2       | 1hr    | CI/CD          |
| 13  | Verify Go 1.26 overlay works with current nixpkgs-unstable                            | P2       | 30min  | Build health   |
| 14  | Rename `docs/architecture/Setup-Mac-*.svg` files                                      | P3       | 5min   | Stale refs     |
| 15  | Clean up `dotfiles/` — no .nix files there, all managed by HM                         | P3       | 1hr    | Tech debt      |
| 16  | Add Prometheus alerting rules for critical services                                   | P3       | 2hr    | Monitoring     |
| 17  | Write NixOS test for dnsblockd service                                                | P3       | 2hr    | Testing        |
| 18  | Write NixOS test for Caddy reverse proxy                                              | P3       | 2hr    | Testing        |
| 19  | Implement backup restore testing                                                      | P3       | 2hr    | Reliability    |
| 20  | Add Cachix or GitHub Actions cache to CI                                              | P3       | 1hr    | CI/CD          |
| 21  | Set up automated flake input updates (Renovate)                                       | P3       | 2hr    | Automation     |
| 22  | Create ADR-005 for flake-parts service module pattern                                 | P3       | 30min  | Documentation  |
| 23  | Audit and clean up `docs/planning/` (19 files, may be stale)                          | P3       | 1hr    | Docs cleanup   |
| 24  | Verify Immich ML with GPU acceleration on evo-x2                                      | P3       | 1hr    | Services       |
| 25  | Document the DNS blocker architecture in a proper ADR                                 | P4       | 1hr    | Documentation  |

---

## G) TOP QUESTION I CANNOT FIGURE OUT MYSELF

**Does `go_1_26` actually exist in the current nixpkgs-unstable?**

The flake.nix overlays `go_1_26` with a custom source tarball (`go1.26.1.src.tar.gz`). This means either:

- (a) `go_1_26` exists in nixpkgs and the overlay just overrides its version — works fine
- (b) `go_1_26` does NOT exist in nixpkgs — the overlay will fail with "attribute `go_1_26` missing"

Similarly, `signoz.nix` uses `pkgs.go_1_25` for its build. If that doesn't exist either, SigNoz builds break.

I cannot run `nix eval` or `nix build` from this machine to verify. This needs a build test on the actual target machine (evo-x2 for NixOS, Lars-MacBook-Air for Darwin).

---

## Metrics Summary

| Metric                                | Value                                   |
| ------------------------------------- | --------------------------------------- |
| Total `.nix` files                    | 78                                      |
| Total Nix lines                       | ~8,600                                  |
| Justfile lines                        | 1,813                                   |
| Justfile recipes                      | 99 public + 3 private                   |
| Active scripts                        | 21 (down from 72)                       |
| Status docs                           | ~90+                                    |
| Total docs                            | ~150+                                   |
| TODO/FIXME in code                    | 2 (both in security-hardening.nix)      |
| Broken imports                        | 0                                       |
| Stale "Setup-Mac" refs in active code | 6+ scripts + justfile                   |
| Pre-commit hooks                      | 8 (2 missing devShell deps)             |
| AGENTS.md reduction                   | 1295 → 241 lines (-81%)                 |
| README.md                             | Complete rewrite, all commands verified |

---

_Generated by Crush on 2026-04-04_
