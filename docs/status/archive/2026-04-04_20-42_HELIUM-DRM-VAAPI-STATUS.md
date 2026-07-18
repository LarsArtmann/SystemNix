# SystemNix Comprehensive Status Report

**Date:** 2026-04-04 20:42
**Branch:** master
**Head:** `58aaf4e` feat(packages): wrap Helium browser with Widevine CDM and VAAPI flags
**Ahead of origin:** 2 commits

---

## Session Work: Helium Browser DRM + Hardware Video Acceleration

### What Was Requested

Enable HBO Max 4K playback in Helium (degoogle-chromium browser) on NixOS.

### What Was Done

**Two files changed, build passing (`just test-fast` green):**

| File                                       | Change                                                                                                                |
| ------------------------------------------ | --------------------------------------------------------------------------------------------------------------------- |
| `platforms/common/packages/base.nix:29-53` | New `heliumWrapped` derivation — symlinks Widevine CDM into Helium's `opt/` directory + wraps binary with VAAPI flags |
| `platforms/nixos/hardware/amd-gpu.nix:52`  | Added `libva-utils` for `vainfo` diagnostics                                                                          |

**Widevine CDM integration** (`base.nix:29-53`):

- `symlinkJoin` wraps the Helium package from the flake input
- Copies `$out/opt` from original package (writable)
- Symlinks `${pkgs.widevine-cdm}/share/google/chrome/WidevineCdm` into `$out/opt/helium/WidevineCdm`
- Wraps `$out/bin/helium` with `makeWrapper` for VAAPI flags
- Falls back to unwrapped Helium on macOS (no Linux VAAPI needed)

**VAAPI flags added:**

- `--enable-features=VaapiVideoDecoder,VaapiVideoEncoder,AcceleratedVideoDecoder,AcceleratedVideoEncoder`
- `--ignore-gpu-blocklist`
- `--enable-zero-copy`

### Important Caveat: 4K on Linux

Widevine on Linux provides **Security Level L3** (software-only). This caps streaming at **720p-1080p**, not 4K. True 4K requires **Level L1** (hardware TEE) only on certified devices (smart TVs, Apple TV, Chromecast, etc.). HBO Max will work with DRM — just not at 4K resolution. This is a platform limitation, not a configuration issue.

### Verification Steps (after `just switch`)

1. `chrome://components` in Helium — WidevineCdm should be listed
2. Visit `https://drm.info/` — Widevine should show enabled
3. `vainfo` in terminal — should list VA-API profiles
4. `chrome://gpu` — "Video Decode" should show "Hardware accelerated"

---

## A) FULLY DONE

| Area                       | Details                                                                                         |
| -------------------------- | ----------------------------------------------------------------------------------------------- |
| Helium Widevine DRM        | `symlinkJoin` wrapper with `widevine-cdm` — passes `nix flake check --no-build`                 |
| Helium VAAPI flags         | `VaapiVideoDecoder`, `AcceleratedVideoDecoder`, `--ignore-gpu-blocklist`, `--enable-zero-copy`  |
| `libva-utils` added        | `vainfo` command available on NixOS for diagnostics                                             |
| AGENTS.md overhaul         | Reduced from 1295→241 lines (-81%), all facts verified                                          |
| README.md overhaul         | 81 lines, comprehensive project documentation                                                   |
| Scripts cleanup            | 72→25 scripts, 6 archived, dead code removed                                                    |
| 9 NixOS service modules    | Caddy, Docker, Gitea, Grafana, Homepage, Immich, Monitoring, SigNoz, Photomap — all flake-parts |
| Desktop stack              | Niri + Waybar + SDDM (SilentSDDM with Catppuccin) — fully working                               |
| AMD GPU/NPU hardware       | ROCm, VA-API, Vulkan, XDNA NPU driver, high-perf DPM udev rules                                 |
| DNS blocker                | Unbound + dnsblockd, 25 blocklists, 2.5M+ domains, `.lan` records                               |
| Cross-platform HM          | 14 shared program modules via `common/home-base.nix`                                            |
| Secrets management         | sops-nix with age (SSH host key), CertAuthority/Service certs                                   |
| KeePassXC integration      | Browser native messaging for both Chromium and Helium paths                                     |
| DNS blocklist expansion    | 2.5M+ domains across 25 curated blocklists                                                      |
| SigNoz observability       | Built from source (Go 1.25), OTEL collector, schema migrator                                    |
| SSH config extraction      | External `nix-ssh-config` flake, both platforms synced                                          |
| Crush config integration   | External `crush-config` flake input deployed via HM                                             |
| Chrome enterprise policies | Extension management, security policies on NixOS                                                |
| Build validation           | `just test-fast` passes clean — zero broken imports across 78 .nix files                        |

## B) PARTIALLY DONE

| Area                       | Status                               | What Remains              |
| -------------------------- | ------------------------------------ | ------------------------- |
| Stale Setup-Mac references | Identified 6+ in scripts             | Not yet cleaned up        |
| `validate-deployment.sh`   | Has Hyprland validation section      | Still causes false errors |
| Ghost Systems comment      | `flake.nix:313` has stale reference  | Not removed               |
| Docs sprawl                | 179 status reports in `docs/status/` | No cleanup/index          |
| Pre-commit hook devShell   | Missing `gitleaks`, `jq` in devShell | Partial tooling gap       |
| Orphan scripts             | 6 scripts not wired into justfile    | `archive/`, `lib/` dirs   |
| Darwin VAAPI flags         | Only on Brave (chromium.nix)         | Not on macOS Chrome       |
| Helium extension mgmt      | Manual install only (issue #116)     | No declarative module     |

## C) NOT STARTED

| Area                         | Priority | Notes                                        |
| ---------------------------- | -------- | -------------------------------------------- |
| NixOS VM tests               | P2       | No `nixosTests` defined anywhere             |
| CI/CD for NixOS              | P1       | Only builds Darwin, not NixOS                |
| Automated dependency updates | P2       | No Renovate/Dependabot for flake inputs      |
| Prometheus alert rules       | P3       | Grafana dashboards exist, no alerting rules  |
| Backup restore testing       | P2       | Timeshift configured, never tested restore   |
| Secrets rotation policy      | P3       | sops-nix works, no rotation schedule         |
| Docs index page              | P3       | 179 reports with no navigation               |
| BTRFS snapshot automation    | P2       | Timeshift configured, no HM-managed schedule |
| Home Manager tests           | P3       | No test harness for program modules          |
| Automated health checks      | P2       | Scripts exist but no cron/systemd timer      |

## D) TOTALLY FUCKED UP

| Issue                                     | Severity       | Status                                                                                                                                                                         |
| ----------------------------------------- | -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| AGENTS.md fabrication history             | Critical (was) | Fixed — but the fabricated Ghost Systems, Type Safety System, and Hyprland sections caused real damage. AI agents created references to non-existent files and wrong commands. |
| `validate-deployment.sh` Hyprland section | Medium         | Still active — validates Hyprland config that doesn't exist, causes false deployment failures                                                                                  |
| 179 stale status reports                  | Low            | Massive docs debt — most reports from Jan-Mar 2026 are outdated and contradictory                                                                                              |
| Go 1.26 overlay uncertainty               | Medium         | `flake.nix` uses `prev.go_1_26` which may not exist in current nixpkgs-unstable. SigNoz needs Go 1.25. Potential build breakage on next `just update`.                         |
| Darwin Chromium Brave-only                | Low            | `chromium.nix` only configures Brave on macOS, Google Chrome is installed separately with no policy management                                                                 |

## E) WHAT WE SHOULD IMPROVE

### Immediate (This Session Could Do)

1. **Clean up `validate-deployment.sh`** — remove Hyprland section
2. **Remove Ghost Systems comment** at `flake.nix:313`
3. **Archive stale status reports** — move pre-2026-04-01 to `docs/status/archive/`
4. **Verify Go overlay** — check if `go_1_26` attr exists in current nixpkgs

### Short-Term (Next Few Sessions)

5. **Add CI for NixOS** — GitHub Actions building `nixosConfigurations.evo-x2`
6. **Create docs index** — README.md in `docs/status/` with table of contents
7. **Wire orphan scripts** — connect 6 disconnected scripts to justfile
8. **Add `widevine-cdm` to chromium policies** — ensure DRM works in system Chrome too
9. **Test Helium DRM on live system** — `just switch` and verify with drm.info

### Long-Term (Strategic)

10. **NixOS VM test framework** — at least smoke tests for services
11. **Automated flake input updates** — weekly Renovate PR
12. **Secrets rotation** — sops key rotation schedule
13. **Backup restore testing** — documented procedure
14. **Consolidate browser config** — single browser module for all Chromium-based

## F) TOP 25 THINGS TO DO NEXT

| #   | Priority | Effort | Item                                                                 |
| --- | -------- | ------ | -------------------------------------------------------------------- |
| 1   | P0       | S      | `just switch` and verify Helium DRM works at drm.info                |
| 2   | P0       | S      | Remove Hyprland validation from `validate-deployment.sh`             |
| 3   | P0       | S      | Remove stale "Ghost Systems" comment at `flake.nix:313`              |
| 4   | P0       | S      | Verify Go overlay: does `go_1_26` exist in current nixpkgs-unstable? |
| 5   | P1       | M      | Archive 170+ stale status reports to `docs/status/archive/`          |
| 6   | P1       | S      | Create `docs/status/README.md` index with links                      |
| 7   | P1       | M      | Add CI pipeline for NixOS build (GitHub Actions)                     |
| 8   | P1       | S      | Wire 6 orphan scripts into justfile or archive                       |
| 9   | P1       | M      | Fix pre-commit devShell: add `gitleaks`, `jq`                        |
| 10  | P1       | S      | Clean up stale Setup-Mac references in scripts                       |
| 11  | P2       | M      | Add `widevine-cdm` support for system Chrome too                     |
| 12  | P2       | M      | Add NixOS VM smoke tests for service modules                         |
| 13  | P2       | S      | Add Prometheus alerting rules for monitoring stack                   |
| 14  | P2       | M      | Test BTRFS/Timeshift backup restore procedure                        |
| 15  | P2       | S      | Add `libva-utils` to Darwin config for consistency                   |
| 16  | P2       | M      | Consolidate browser config into single module                        |
| 13  | P2       | L      | Automated flake input updates (Renovate/Dependabot)                  |
| 18  | P2       | M      | Add systemd timer for `health-check.sh`                              |
| 19  | P2       | M      | Add sops secrets rotation documentation                              |
| 20  | P3       | S      | Add Home Manager test harness                                        |
| 21  | P3       | M      | Create ADR for Widevine L3 limitation                                |
| 22  | P3       | S      | Document Helium DRM setup in AGENTS.md                               |
| 23  | P3       | M      | Unify Darwin/NixOS Chromium policy management                        |
| 24  | P3       | L      | Investigate Helium declarative extension support                     |
| 25  | P3       | M      | Add `chrome://gpu` / `vainfo` verification to justfile               |

## G) TOP #1 QUESTION I CANNOT FIGURE OUT MYSELF

**Does the `heliumWrapped` `symlinkJoin` actually work at runtime?**

The `nix flake check --no-build` passes (syntax is valid), but I cannot verify:

1. Whether `$out/opt/helium/` is the correct path for the Widevine CDM symlink — Helium may look for it elsewhere (e.g., in a versioned subdirectory, or relative to the binary, or via a Chromium component update path)
2. Whether `wrapProgram` correctly intercepts the Helium binary given the complex symlink structure from the original flake's `mkDerivation` (the original package uses `makeWrapper` itself with `--add-flags`)
3. Whether `makeWrapper` creates a proper script or if Helium's binary launch chain bypasses it

The only way to know: `just switch` on evo-x2 and test. The `symlinkJoin` + `wrapProgram` pattern is standard Nix but Helium's pre-built binary packaging from `vikingnope/helium-browser-nix-flake` may have quirks.

---

## Metrics

| Metric                    | Value                    |
| ------------------------- | ------------------------ |
| `.nix` files              | 78                       |
| Just recipes              | 134                      |
| Scripts                   | 25 (6 in archive/lib)    |
| Status reports            | 179 (!)                  |
| Flake inputs              | 18                       |
| NixOS service modules     | 9                        |
| Shared HM program modules | 14                       |
| Commits ahead of origin   | 2                        |
| Build status              | `just test-fast` PASSING |
| Broken imports            | 0                        |
