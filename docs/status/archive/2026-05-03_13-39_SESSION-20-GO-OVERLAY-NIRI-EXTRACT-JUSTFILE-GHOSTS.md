# SystemNix Comprehensive Status Report

**Date:** 2026-05-03 13:39
**Session:** 20
**Platform:** Linux (evo-x2, x86_64) — primary work machine
**Branch:** master @ `8f111e5`
**NixOS State Version:** 25.11
**Working Tree:** Clean (all changes committed, even with origin/master)

---

## A) FULLY DONE — Completed This Session

### Task 1: Remove Darwin Go Overlay ✅

**Commit:** `68e508a`
**Files:** `platforms/darwin/default.nix`

- Removed the Go 1.26.1 pin overlay and golangci-lint override from `platforms/darwin/default.nix`
- nixpkgs `go_1_26` is already 1.26.1 — the overlay was forcing from-source rebuilds invalidating binary cache for 1094 derivations
- Added explanatory comment matching the approach in `flake.nix:214`
- Darwin config evaluates correctly (`nix eval .#darwinConfigurations.Lars-MacBook-Air` passes)

### Task 2: Extract niri-session-restore to Standalone Script ✅

**Commits:** `ec18885`, `68e508a`
**Files:** `scripts/niri-session-save.sh` (new), `scripts/niri-session-restore.sh` (new), `platforms/nixos/programs/niri-wrapped.nix`

- Extracted ~300 lines of inline Nix shell scripts to `scripts/` directory
- `niri-session-save.sh` — 94 lines, reads niri state + kitty /proc tree
- `niri-session-restore.sh` — 192 lines, JSON validation, workspace recreation, window spawning
- Used `builtins.readFile` + `builtins.replaceStrings` for template variable injection (`@maxSessionAgeDays@`, `@fallbackCommands@`)
- Both scripts now use `writeShellApplication` (gets shellcheck + proper PATH wrapping)
- Extracted `fallbackCommands` helper into a `let` binding for clarity
- Flake check passes, statix passes, deadnix passes

### Task 3: Clean Up Justfile Ghost Recipes ✅

**Commits:** `b21cd24`, `0889cad`
**Files:** `justfile`, `scripts/niri-session-restore.sh`

**Removed ghost recipes (140 lines deleted, 21 added):**

| Recipe                                          | Reason                                               |
| ----------------------------------------------- | ---------------------------------------------------- |
| `netdata-start/stop`                            | `netdata` not in Nix packages                        |
| `ntopng-start/stop`                             | `ntopng` not in Nix packages                         |
| `monitor-all/stop/status/restart`               | Orchestration of removed monitoring tools            |
| `claude-config/config-safe/backup/restore/test` | `better-claude` not in Nix packages                  |
| `perf-full-analysis`                            | References non-existent `benchmark`/`perf`/`context` |
| `automation-setup`                              | References non-existent `perf setup`/`context setup` |
| `doc-update-readme`                             | Fragile hardcoded line numbers                       |
| `doc-update-go-what-you-get`                    | Fragile perl one-liner with hardcoded line number    |

**Fixed:**

- `d2-verify`: Added platform guard (uses Darwin-only `duti`)
- `help` recipe: Removed references to deleted sections (Performance & Benchmarking, Claude AI, health-dashboard), added Node.js/TypeScript tools section, fixed `clean-storage` → `clean-quick`

**Additional cleanup:**

- Removed unused `focused_app` variable from niri-session-restore.sh

---

## B) PARTIALLY DONE

None — all 3 assigned tasks were completed fully.

---

## C) NOT STARTED

These are from the broader project backlog (not assigned this session):

1. **Pi 3 DNS failover cluster hardware provisioning** — module exists (`dns-failover.nix`) but Pi 3 not yet provisioned
2. **Twenty CRM** — module imported but service not yet configured/enabled
3. **Photomap** — module imported but service status unknown
4. **SigNoz build-from-source performance** — Go 1.25 build takes significant time; no cached alternative

---

## D) TOTALLY FUCKED UP

Nothing is broken. All checks pass:

- `just test-fast` (nix flake check --no-build) — ✅
- `statix` check — ✅
- `deadnix` check — ✅
- Darwin config evaluation — ✅
- Justfile parsing (`just --list`) — ✅

---

## E) WHAT WE SHOULD IMPROVE

1. **Justfile is still 1777 lines** — Even after removing ghost recipes, it's massive. Consider splitting into category-specific files (e.g., `justfile.dns`, `justfile.go`, `justfile.services`) or migrating more tasks to Nix apps.

2. **Too many status reports (70+ files)** — The `docs/status/` directory is overflowing. Should archive older reports more aggressively.

3. **Niri scripts use `builtins.replaceStrings` templating** — Works but fragile. If someone adds `@` in the script, it could break. Consider using `substituteAll` or a proper Nix function that passes arguments as environment variables.

4. **No CI/CD** — All validation is manual (`just test-fast`). Should add GitHub Actions for nix flake check on push.

5. **Darwin overlays not in perSystem** — The Darwin config uses `sharedOverlays` directly in the darwinSystem modules, while perSystem has its own overlay list. This is intentional per AGENTS.md but creates a maintenance burden.

6. **Session restore script is Linux-only** — The scripts use `/proc` for process tree walking. No Darwin equivalent exists.

---

## F) Top 25 Things We Should Get Done Next

### High Priority (Architecture & Performance)

| # | Task                                                                 | Impact | Effort |
| - | -------------------------------------------------------------------- | ------ | ------ |
| 1 | **Add GitHub Actions CI** for `nix flake check` on push/PR           | High   | 2hr    |
| 2 | **Split justfile** into category files or migrate to Nix apps        | Medium | 4hr    |
| 3 | **Provision Pi 3** for DNS failover cluster                          | High   | 4hr    |
| 4 | **Add `niri-session-restore` tests** — at least a dry-run validation | Medium | 2hr    |
| 5 | **Archive old status reports** — move 60+ files to archive/          | Low    | 15min  |

### Medium Priority (Code Quality)

| #  | Task                                                                                                                | Impact | Effort |
| -- | ------------------------------------------------------------------------------------------------------------------- | ------ | ------ |
| 6  | **Consolidate overlay definitions** — perSystem and darwinSystem share the same overlays, reduce duplication        | Medium | 1hr    |
| 7  | **Add shellcheck** to all scripts in `scripts/` directory via pre-commit                                            | Medium | 30min  |
| 8  | **Migrate remaining justfile patterns to Nix apps** — `deploy`, `validate`, `dns-diagnostics` pattern shows the way | Medium | 2hr    |
| 9  | **Add module-level assertions** for critical services (immich postgres, caddy certs, etc.)                          | Medium | 2hr    |
| 10 | **Create a `lib/` helper for systemd service generation** — reduce boilerplate across 30 service modules            | Medium | 3hr    |
| 11 | **Twenty CRM configuration** — module imported but not configured                                                   | Medium | 4hr    |
| 12 | **Photomap service activation** — verify it works                                                                   | Low    | 1hr    |
| 13 | **SigNoz cached build** — investigate if binary cache is available                                                  | High   | 2hr    |
| 14 | **DNS blocklist automated hash updates** — currently manual `just update` + hash editing                            | Medium | 3hr    |
| 15 | **Add `home-manager` shared test** — verify both platforms build same program set                                   | Medium | 1hr    |

### Lower Priority (Polish & DX)

| #  | Task                                                                                   | Impact | Effort |
| -- | -------------------------------------------------------------------------------------- | ------ | ------ |
| 16 | **Niri session restore: add Darwin equivalent** using `launchctl` + `osascript`        | Low    | 4hr    |
| 17 | **Unify theme application** — some apps still have hardcoded Catppuccin values         | Low    | 2hr    |
| 18 | **Add `nixos-generators` for VM images** — test config changes in VMs before deploying | Medium | 3hr    |
| 19 | **Create a service dependency graph** — visualize which services depend on which       | Low    | 1hr    |
| 20 | **Migrate emeet-pixyd config to module options** — currently hardcoded in nix module   | Low    | 2hr    |
| 21 | **Add `programs.niri-session` to AGENTS.md** — document the new config options         | Low    | 30min  |
| 22 | **Investigate `nix-fast-build`** for parallel remote builds                            | Medium | 2hr    |
| 23 | **Create a flake output for Raspberry Pi SD image builds**                             | Low    | 1hr    |
| 24 | **Add sops secret rotation strategy** — document how to rotate age keys                | Low    | 1hr    |
| 25 | **Clean up `flake.nix` input list** — 30+ inputs, consider grouping or reducing        | Low    | 2hr    |

---

## G) Top #1 Question I Cannot Figure Out Myself

**Should the justfile be split into multiple files, or should recipes be migrated to Nix apps?**

The justfile is at 1777 lines with 149 recipes. Two approaches exist:

1. **Split justfile** into `justfile.dns`, `justfile.go`, etc. (just supports `import`)
2. **Migrate to Nix apps** — the `deploy`, `validate`, `dns-diagnostics` apps in `flake.nix` show the pattern

The tradeoff: justfile is more discoverable (`just --list`) and supports dynamic platform detection. Nix apps are more reproducible and don't require `just` to be installed. But Nix apps can't do interactive commands easily.

I cannot determine the user's preference without asking — both approaches have merit and the decision affects the project's DX architecture.

---

## Session Stats

| Metric                     | Value                |
| -------------------------- | -------------------- |
| Commits this session       | 5 (68e508a..8f111e5) |
| Files changed              | 9                    |
| Lines added                | +716                 |
| Lines removed              | -476                 |
| Net change                 | +240                 |
| Nix files in project       | 101                  |
| Service modules            | 30                   |
| Justfile recipes remaining | 149                  |
| All checks passing         | ✅                   |
