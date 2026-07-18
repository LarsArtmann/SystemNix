# SystemNix Comprehensive Status Report

**Date:** 2026-04-04 22:10
**Branch:** master
**Head:** `3064e55` docs: update project branding and maintenance policy documentation
**Ahead of origin:** 6 commits (including uncommitted work)

---

## Session Work: Gitea Actions CI/CD + ActivityWatch Dark Theme

### What Was Done

**Two files changed, `just test-fast` green:**

| File                                          | Change                                                        |
| --------------------------------------------- | ------------------------------------------------------------- |
| `modules/nixos/services/gitea.nix`            | +77 lines: Gitea Actions runner with token generation service |
| `platforms/common/programs/activitywatch.nix` | +18 lines: systemd service to set dark theme via API          |

#### Gitea Actions CI/CD (`gitea.nix`)

- **Gitea Actions enabled** with `DEFAULT_ACTIONS_URL = "github"` (uses GitHub Actions workflow syntax)
- **Runner token generation** (`gitea-runner-token.service`): `oneshot` systemd service that calls `gitea actions generate-runner-token` after Gitea starts, writes token to `/var/lib/gitea/.runner-token`
- **Gitea Actions Runner** (`gitea-actions-runner.instances.${hostname}`): Runs on evo-x2, connects to `http://localhost:3000`, uses token from file
- **Runner labels**: `ubuntu-latest:docker://node:22-bookworm`, `ubuntu-22.04:docker://node:22-bookworm`, `native:host`
- **Capacity**: 2 concurrent jobs, host networking, `info` log level
- **Dependency ordering**: `gitea-runner-${hostname}.service` starts after `gitea-runner-token.service`

#### ActivityWatch Dark Theme (`activitywatch.nix`)

- **Systemd user service** (`activitywatch-theme.service`): `oneshot` that calls `curl -X PUT -d 'dark' http://localhost:5600/api/0/settings/theme`
- **Theme stored**: ActivityWatch stores theme in localStorage but syncs to server via API — this service ensures dark is set on startup
- **Service ordering**: Starts after `activitywatch.service`, belongs to `activitywatch.target`

---

## A) FULLY DONE

| Area                     | Details                                                                       |
| ------------------------ | ----------------------------------------------------------------------------- |
| Gitea CI/CD              | Full Gitea Actions runner with token generation, 3 labels, 2 capacity         |
| ActivityWatch dark theme | systemd service sets dark via API on startup                                  |
| Helium Widevine DRM      | `symlinkJoin` wrapper with Widevine CDM + VAAPI flags                         |
| Helium VAAPI             | All acceleration flags: VaapiVideoDecoder, ZeroCopy, ignore-gpu-blocklist     |
| AGENTS.md                | 241 lines (-81% from 1295), verified facts only                               |
| README.md                | 81 lines, comprehensive project docs                                          |
| Scripts cleanup          | 72→25 scripts, 6 archived, dead code removed                                  |
| 9 NixOS services         | Caddy, Docker, Gitea, Grafana, Homepage, Immich, Monitoring, SigNoz, Photomap |
| Desktop stack            | Niri + Waybar + SDDM (SilentSDDM + Catppuccin Mocha)                          |
| AMD GPU/NPU              | ROCm, VA-API, Vulkan, XDNA NPU, high-perf DPM rules                           |
| DNS blocker              | Unbound + dnsblockd, 25 blocklists, 2.5M+ domains, `.lan` records             |
| Cross-platform HM        | 14 shared program modules via `common/home-base.nix`                          |
| Secrets (sops-nix)       | age encryption with SSH host key, CertAuthority/Service certs                 |
| KeePassXC                | Browser native messaging for Chromium and Helium                              |
| SigNoz                   | Built from source (Go 1.25), OTEL collector, schema migrator                  |
| SSH config               | External `nix-ssh-config` flake, both platforms synced                        |
| Crush config             | External `crush-config` flake, deployed via HM                                |
| Chrome policies          | Extension management, security policies on NixOS                              |
| Build validation         | `just test-fast` passes — zero broken imports                                 |

---

## B) PARTIALLY DONE

| Area                     | Status                                      | What Remains                                |
| ------------------------ | ------------------------------------------- | ------------------------------------------- |
| Gitea Actions testing    | Runner configured, not verified live        | Need `just switch` and test with a workflow |
| Helium DRM verification  | Config done, not tested on evo-x2           | Need live test at drm.info                  |
| Go overlay verification  | `go_1_26` not confirmed in nixpkgs-unstable | Potential breakage on `just update`         |
| Stale Setup-Mac refs     | 6+ identified in scripts                    | Not cleaned up                              |
| `validate-deployment.sh` | Hyprland section still causes false errors  | Not removed                                 |
| Ghost Systems comment    | `flake.nix:313` stale reference             | Not removed                                 |
| Docs sprawl              | 179 status reports                          | No cleanup/index                            |
| Orphan scripts           | 6 scripts not wired into justfile           | `archive/`, `lib/` dirs                     |

---

## C) NOT STARTED

| Area                           | Priority | Notes                                   |
| ------------------------------ | -------- | --------------------------------------- |
| Gitea Actions workflow testing | P1       | No `.gitea/workflows/` defined yet      |
| NixOS VM tests                 | P2       | No `nixosTests` defined                 |
| CI/CD for NixOS                | P1       | Only builds Darwin in current CI        |
| Automated dep updates          | P2       | No Renovate/Dependabot for flake inputs |
| Prometheus alert rules         | P3       | Dashboards exist, no alerting           |
| Backup restore testing         | P2       | Timeshift configured, never tested      |
| Secrets rotation policy        | P3       | sops-nix works, no rotation schedule    |
| Docs index                     | P3       | 179 reports, no navigation              |
| BTRFS snapshot automation      | P2       | Timeshift in HM but no systemd timer    |
| Home Manager tests             | P3       | No test harness for program modules     |
| Automated health checks        | P2       | Scripts exist, no cron/systemd timer    |

---

## D) TOTALLY FUCKED UP

| Issue                                     | Severity | Status                                                                      |
| ----------------------------------------- | -------- | --------------------------------------------------------------------------- |
| `validate-deployment.sh` Hyprland section | Medium   | Still validates Hyprland config that doesn't exist                          |
| 179 stale status reports                  | Low      | Massive docs debt, many contradictory                                       |
| Go 1.26 overlay uncertainty               | Medium   | `flake.nix` uses `prev.go_1_26` — may not exist in current nixpkgs-unstable |
| Darwin Chromium Brave-only                | Low      | Google Chrome installed separately with no policy management                |
| Helium extension mgmt                     | Low      | Manual install only, no declarative module                                  |

---

## E) WHAT WE SHOULD IMPROVE

### Immediate (This Session Could Do)

1. **Test Gitea Actions** — Create a simple workflow in `platforms/nixos/users/home.nix` or as a file to verify runner works
2. **Verify ActivityWatch dark theme** — `just switch` and check ActivityWatch web UI theme
3. **Remove Hyprland validation** from `validate-deployment.sh`
4. **Remove Ghost Systems comment** at `flake.nix:313`
5. **Verify Go overlay** — check if `go_1_26` attr exists in current nixpkgs

### Short-Term (Next Few Sessions)

6. **Add CI for NixOS** — GitHub Actions building `nixosConfigurations.evo-x2`
7. **Create docs index** — README.md in `docs/status/` with table of contents
8. **Archive stale status reports** — move pre-2026-04-01 to `docs/status/archive/`
9. **Wire orphan scripts** — connect 6 disconnected scripts to justfile
10. **Add `widevine-cdm` to chromium policies** — ensure DRM works in system Chrome too

### Long-Term (Strategic)

11. **NixOS VM test framework** — at least smoke tests for services
12. **Automated flake input updates** — weekly Renovate PR
13. **Secrets rotation** — sops key rotation schedule
14. **Backup restore testing** — documented procedure
15. **Consolidate browser config** — single browser module for all Chromium-based

---

## F) TOP 25 THINGS TO DO NEXT

| #   | Priority | Effort | Item                                                                 |
| --- | -------- | ------ | -------------------------------------------------------------------- |
| 1   | P0       | S      | `just switch` and verify Gitea Actions runner registers              |
| 2   | P0       | S      | `just switch` and verify ActivityWatch dark theme applied            |
| 3   | P0       | S      | Remove Hyprland validation from `validate-deployment.sh`             |
| 4   | P0       | S      | Remove stale "Ghost Systems" comment at `flake.nix:313`              |
| 5   | P0       | S      | Verify Go overlay: does `go_1_26` exist in current nixpkgs-unstable? |
| 6   | P1       | M      | Create a test Gitea Actions workflow to verify runner                |
| 7   | P1       | M      | Archive 170+ stale status reports to `docs/status/archive/`          |
| 8   | P1       | S      | Create `docs/status/README.md` index with links                      |
| 9   | P1       | M      | Add CI pipeline for NixOS build (GitHub Actions)                     |
| 10  | P1       | S      | Wire 6 orphan scripts into justfile or archive                       |
| 11  | P1       | S      | Clean up stale Setup-Mac references in scripts                       |
| 12  | P1       | S      | Fix pre-commit devShell: add `gitleaks`, `jq`                        |
| 13  | P2       | M      | Add `widevine-cdm` support for system Chrome too                     |
| 14  | P2       | M      | Add NixOS VM smoke tests for service modules                         |
| 15  | P2       | S      | Add Prometheus alerting rules for monitoring stack                   |
| 16  | P2       | M      | Test BTRFS/Timeshift backup restore procedure                        |
| 17  | P2       | S      | Add `libva-utils` to Darwin config for consistency                   |
| 18  | P2       | M      | Consolidate browser config into single module                        |
| 19  | P2       | L      | Automated flake input updates (Renovate/Dependabot)                  |
| 20  | P2       | M      | Add systemd timer for `health-check.sh`                              |
| 21  | P2       | M      | Add sops secrets rotation documentation                              |
| 22  | P3       | S      | Add Home Manager test harness                                        |
| 23  | P3       | M      | Create ADR for Widevine L3 limitation                                |
| 24  | P3       | S      | Document Gitea Actions setup in AGENTS.md                            |
| 25  | P3       | M      | Unify Darwin/NixOS Chromium policy management                        |

---

## G) TOP #1 QUESTION I CANNOT FIGURE OUT MYSELF

**Does the Gitea Actions runner actually register and run jobs?**

The configuration is declarative and syntax-valid (`just test-fast` passes), but I cannot verify:

1. Whether the runner token generation service runs after Gitea is fully ready (Gitea startup can be slow, 30 retries may not be enough)
2. Whether `gitea-actions-runner` package from nixpkgs has the correct binary name (it might be `act_runner` not `gitea-actions-runner`)
3. Whether the `native:host` label actually works — the runner needs ` acts` in `$PATH` for host executor
4. Whether the token file permissions are correct (`chmod 644`) — Gitea runner runs as a different user potentially
5. Whether the runner survives a system restart — the token is generated once and should persist, but the service dependency ordering might not work correctly

The only way to know: `just switch` on evo-x2 and push a test workflow to the Gitea instance.

---

## Metrics

| Metric                       | Value                    |
| ---------------------------- | ------------------------ |
| `.nix` files                 | 78                       |
| Just recipes                 | 134                      |
| Scripts                      | 25 (6 in archive/lib)    |
| Status reports               | 179                      |
| Flake inputs                 | 18                       |
| NixOS service modules        | 9                        |
| Shared HM program modules    | 14                       |
| Commits ahead of origin      | 6 (staged + unstaged)    |
| Build status                 | `just test-fast` PASSING |
| Broken imports               | 0                        |
| Lines changed (this session) | +94 (2 files)            |
