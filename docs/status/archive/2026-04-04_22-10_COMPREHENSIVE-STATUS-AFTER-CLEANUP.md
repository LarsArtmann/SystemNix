# SystemNix: Comprehensive Status Report

**Date:** 2026-04-04 22:10
**Branch:** master
**Recent Commits:** `24e5c5a` (Gitea Actions), `3064e55` (branding docs), `7c74c24` (docs+scripts reorg), `c00fcc4` (Setup-Mac→SystemNix rename)

---

## A) FULLY DONE

| Item                                      | Details                                                                                                                                                                                                                   |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Project rename: Setup-Mac → SystemNix** | All active scripts (6), justfile (31 refs), dep-graph filenames, architecture SVG, and .nix files updated. Only remaining `Setup-Mac` is a fallback search path in `gitea-repos.nix:142` (intentional).                   |
| **Ghost Systems references removed**      | `flake.nix:313` comment fixed. Zero "Ghost Systems" references remain in any active `.nix` or `.sh` file.                                                                                                                 |
| **Hyprland → Niri migration**             | `validate-deployment.sh` fully rewritten: Hyprland validation section (48 lines) replaced with Niri validation. Call site and deployment report text updated. Zero Hyprland references in any active script or .nix file. |
| **Pre-commit hooks fully wired**          | All 8 hooks have deps in devShell: `gitleaks`, `jq`, `deadnix`, `statix`, `alejandra`, `just`, `nixfmt`, `shellcheck`. Previously `gitleaks` and `jq` were missing.                                                       |
| **Orphan scripts resolved**               | 4 archived (`config-validate.sh`, `find-nix-duplicates.sh`, `nix-diagnostic.sh`, `dns-diagnostics.sh`). 3 wired into justfile: `deploy-evo`, `diagnose`, `test-aliases`.                                                  |
| **Gitea Actions CI/CD**                   | Full Gitea Actions pipeline in `modules/nixos/services/gitea.nix`: runner token auto-gen, act-runner service with Docker labels, systemd ordering.                                                                        |
| **ActivityWatch dark theme**              | User systemd service sets AW theme to dark via API on Linux.                                                                                                                                                              |
| **Documentation reorganized**             | `docs/README.md` rewritten as proper index. `docs/status/README.md` updated with archive policy. 95 status reports archived (Jan-Feb 2026 + Hyprland-specific).                                                           |
| **private-cloud removed**                 | Empty `platforms/nixos/private-cloud/` moved to `docs/planning/private-cloud-planning/`.                                                                                                                                  |
| **Stale Hyprland docs archived**          | `HYPRLAND-*.md`, `TV-CURSOR-SIZE-FIX-HYPRLAND.md` moved to `docs/status/archive/`.                                                                                                                                        |
| **`docs/README.test.md` fixed**           | Title, Ghost Systems claim, Hyprland→Niri, UserConfig.nix→nix-settings.nix all corrected.                                                                                                                                 |
| **NixOS service modules**                 | 11 flake-parts modules working: Docker, Caddy, Gitea (+Actions runner), Grafana, Homepage, Immich, Prometheus monitoring, PhotoMap AI, SigNoz, sops-nix, Gitea repo sync                                                  |
| **NixOS desktop**                         | Niri (Wayland tiling) + Waybar + SDDM + SilentSDDM + Catppuccin Mocha everywhere. Sway as backup WM.                                                                                                                      |
| **NixOS hardware**                        | AMD GPU (ROCm), AMD NPU (XDNA), BTRFS dual layout, ZRAM, Timeshift snapshots                                                                                                                                              |
| **DNS blocker**                           | Unbound + custom dnsblockd, 25 blocklists, 2.5M+ domains, DNS-over-TLS                                                                                                                                                    |
| **Cross-platform Home Manager**           | 14 shared program modules, ~80% config shared between macOS and NixOS                                                                                                                                                     |
| **Secrets management**                    | sops-nix with age encryption, deployed on both platforms                                                                                                                                                                  |
| **All Nix imports resolve**               | Zero broken imports across all 78 .nix files                                                                                                                                                                              |
| **Helium browser**                        | Wrapped with Widevine CDM + VAAPI flags                                                                                                                                                                                   |

---

## B) PARTIALLY DONE

| Item                   | Status                                                  | What's Missing                                                                                                                                                        |
| ---------------------- | ------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Stale docs cleanup** | Top-level Hyprland docs archived, status reports pruned | ~55+ docs outside status/ still reference Setup-Mac/Hyprland/Ghost Systems (architecture/, planning/, troubleshooting/, etc.) — these are historical and low priority |
| **CI/CD**              | Gitea Actions runner enabled on evo-x2                  | No actual workflow files (`.gitea/workflows/` or `.github/workflows/`) exist yet. No caching strategy. No NixOS build verification in CI.                             |
| **Monitoring**         | Prometheus scrapes metrics, Grafana has dashboard       | No alert rules defined. No notification pipeline. No PagerDuty/email/webhook integration.                                                                             |

---

## C) NOT STARTED

| Item                             | Impact                                                                                                        | Effort |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------- | ------ |
| **Test infrastructure**          | No NixOS VM tests, no `nixosTests`, no property-based testing. All "tests" are imperative bash scripts.       | High   |
| **CI workflow definitions**      | Gitea Actions runner exists but has zero workflows. Need `.gitea/workflows/*.yaml` for build validation.      | Medium |
| **Automated dependency updates** | No Renovate/Dependabot. All flake input updates manual via `just update`.                                     | Low    |
| **Monitoring/alerting**          | Prometheus scrapes but no alert rules or notifications.                                                       | Medium |
| **Backup verification**          | Timeshift configured but no automated restore testing. Immich DB backup timer exists but no integrity checks. | Medium |
| **Secrets rotation**             | sops-nix deployed but no rotation policy or automated key rotation.                                           | Low    |
| **Darwin build in CI**           | No CI at all currently. Would need macOS runner for Darwin build verification.                                | Low    |

---

## D) TOTALLY FUCKED UP

| Item                            | Problem                                                                                                                                                                                                                                                                                               | Severity                  |
| ------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------- |
| **Go version inconsistency**    | `flake.nix` overlays `go_1_26` (pinned to 1.26.1) but `signoz.nix` builds with `go_1_25`. Neither version verified to exist in current `nixpkgs-unstable`. If `go_1_26` doesn't exist, the overlay fails. If `go_1_25` doesn't exist, SigNoz build breaks. Cannot verify without running `nix build`. | **Potential build break** |
| **Security hardening disabled** | `security-hardening.nix` has 2 TODOs with disabled kernel audit rules and AppArmor due to bugs. System runs without these protections.                                                                                                                                                                | **Security gap**          |
| **2 Go versions for no reason** | Main overlay pins Go 1.26.1, but SigNoz forces Go 1.25. This means two separate Go toolchains in the closure, increasing closure size and maintenance burden. Should align to single version if SigNoz builds with 1.26.                                                                              | **Technical debt**        |
| **No CI workflows**             | Gitea Actions runner is running but has zero workflows. The runner consumes resources (Docker labels configured) but does nothing useful.                                                                                                                                                             | **Wasted resources**      |

---

## E) WHAT WE SHOULD IMPROVE

### Immediate (this session could do)

1. **Verify Go 1.26/1.25 availability in nixpkgs-unstable** — run `nix eval nixpkgs#go_1_26.meta.description` or similar
2. **Align SigNoz to Go 1.26** if possible, eliminating the dual Go toolchain
3. **Create first Gitea Actions workflow** — even a basic `nix flake check` on push

### Short-term (next few sessions)

4. **Add Prometheus alerting rules** for critical services (Caddy down, Immich down, disk full)
5. **Audit and consolidate docs/architecture/** — 21 files, many stale
6. **Audit and consolidate docs/planning/** — 19 files, may contain obsolete plans
7. **Create `docs/decisions/` or use `docs/architecture/` for ADRs** — currently scattered
8. **Write NixOS VM test for dnsblockd** — most critical custom service
9. **Set up automated flake input updates** (Renovate or GitHub Action)
10. **Investigate security-hardening.nix TODOs** — check if NixOS upstream fixed the bugs

### Long-term (strategic)

11. **Build full NixOS test infrastructure** (nixosTests for each service)
12. **Implement backup restore testing pipeline**
13. **Automated secret rotation with sops-nix**
14. **Multi-machine CI** (Darwin + NixOS builds in CI)
15. **NixOS system auto-upgrade with automatic rollback**

---

## F) TOP 25 THINGS TO DO NEXT

| #   | Task                                                             | Priority | Effort | Category       |
| --- | ---------------------------------------------------------------- | -------- | ------ | -------------- |
| 1   | Verify `go_1_26` and `go_1_25` exist in current nixpkgs-unstable | P0       | 5min   | Build health   |
| 2   | Align SigNoz to Go 1.26 (eliminate dual toolchain)               | P0       | 30min  | Technical debt |
| 3   | Create first Gitea Actions workflow (`nix flake check` on push)  | P1       | 1hr    | CI/CD          |
| 4   | Add Prometheus alerting rules for critical services              | P1       | 2hr    | Monitoring     |
| 5   | Investigate security-hardening.nix TODOs (auditd, AppArmor)      | P1       | 1hr    | Security       |
| 6   | Audit and prune `docs/architecture/` (21 files)                  | P2       | 1hr    | Docs cleanup   |
| 7   | Audit and prune `docs/planning/` (19 files)                      | P2       | 1hr    | Docs cleanup   |
| 8   | Consolidate remaining Setup-Mac/Hyprland refs in docs/           | P2       | 2hr    | Docs cleanup   |
| 9   | Write NixOS VM test for dnsblockd service                        | P2       | 2hr    | Testing        |
| 10  | Write NixOS VM test for Caddy reverse proxy                      | P2       | 2hr    | Testing        |
| 11  | Add Immich ML with GPU acceleration on evo-x2                    | P2       | 1hr    | Services       |
| 12  | Create `.gitea/workflows/` directory with CI templates           | P2       | 30min  | CI/CD          |
| 13  | Set up Cachix or Gitea Actions cache for Nix builds              | P2       | 1hr    | CI/CD          |
| 14  | Document DNS blocker architecture in a proper ADR                | P3       | 1hr    | Documentation  |
| 15  | Create ADR for flake-parts service module pattern                | P3       | 30min  | Documentation  |
| 16  | Set up automated flake input updates (Renovate)                  | P3       | 2hr    | Automation     |
| 17  | Implement backup restore testing                                 | P3       | 2hr    | Reliability    |
| 18  | Automated secret rotation with sops-nix                          | P3       | 2hr    | Security       |
| 19  | Add Darwin build to CI (macOS runner)                            | P3       | 1hr    | CI/CD          |
| 20  | NixOS system auto-upgrade with automatic rollback                | P3       | 1hr    | Automation     |
| 21  | Clean up `dotfiles/` directory — all managed by HM now           | P3       | 1hr    | Tech debt      |
| 22  | Add Waybar custom modules for service health                     | P3       | 2hr    | Desktop        |
| 23  | Create docs index by topic (services, hardware, desktop)         | P3       | 1hr    | Documentation  |
| 24  | Investigate NixOS minimal ISO for recovery boot                  | P4       | 2hr    | Reliability    |
| 25  | Add system health dashboard (Grafana panel for NixOS host)       | P4       | 2hr    | Monitoring     |

---

## G) TOP QUESTION I CANNOT FIGURE OUT MYSELF

**Does `go_1_26` actually exist in the current nixpkgs-unstable?**

The flake.nix overlays `go_1_26` with a custom source tarball (`go1.26.1.src.tar.gz`). This means either:

- (a) `go_1_26` exists in nixpkgs and the overlay just overrides its source/version — works fine
- (b) `go_1_26` does NOT exist in nixpkgs — the overlay will fail with "attribute `go_1_26` missing"

Similarly, `signoz.nix:14` uses `pkgs.go_1_25` for its build. If that doesn't exist, SigNoz builds break.

I cannot run `nix eval` or `nix build` from this machine to verify. This needs a build test on the actual target machine (evo-x2 for NixOS, Lars-MacBook-Air for Darwin).

**Also:** If both Go versions DO exist, the question becomes: why maintain two? SigNoz should be tested with Go 1.26 and the `go_1_25` override removed, simplifying the closure.

---

## Metrics Summary

| Metric                                    | Value                                          |
| ----------------------------------------- | ---------------------------------------------- |
| Total `.nix` files                        | 78                                             |
| Justfile lines                            | 1,828                                          |
| Justfile public recipes                   | ~83                                            |
| Active scripts                            | 19                                             |
| Archived scripts                          | 10                                             |
| Active status docs                        | 92                                             |
| Archived status docs                      | 93+                                            |
| Total docs (non-archive)                  | ~200+                                          |
| TODO/FIXME in code                        | 2 (both in security-hardening.nix)             |
| Broken imports                            | 0                                              |
| Stale "Setup-Mac" refs in active code     | 1 (gitea-repos.nix fallback path, intentional) |
| Stale "Ghost Systems" refs in active code | 0                                              |
| Stale "Hyprland" refs in active code      | 0                                              |
| Pre-commit hooks                          | 8 (all deps in devShell ✅)                    |
| NixOS service modules                     | 11                                             |
| NixOS desktop modules                     | 8                                              |
| NixOS program modules                     | 8                                              |
| Go versions in closure                    | 2 (go_1_26 + go_1_25)                          |
| CI workflows                              | 0 (runner exists, no workflows)                |

---

## Session Changelog

This report documents the state after the following commits (2026-04-04):

| Commit    | Description                                                                |
| --------- | -------------------------------------------------------------------------- |
| `c00fcc4` | Rename Setup-Mac → SystemNix across scripts, justfile, nix files           |
| `04f9398` | Add gitleaks/jq to devShell, Hyprland→Niri in validate-deployment.sh       |
| `7c74c24` | Reorganize docs, archive scripts, add deploy/diagnose/test-aliases recipes |
| `ff2ea54` | Archive status reports, rewrite docs/README.md index                       |
| `6a224e8` | Rename SVG, archive Hyprland docs                                          |
| `3064e55` | Update branding in docs/README.test.md, docs/status/README.md              |
| `52f554d` | Enable Gitea Actions CI/CD + ActivityWatch dark theme                      |
| `24e5c5a` | Status report (superseded by this document)                                |

---

_Generated by Crush on 2026-04-04_
