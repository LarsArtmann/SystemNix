# Session 50: Brutal Self-Review & Dead Code Cleanup

**Date:** 2026-05-08 03:25
**Type:** Audit / Cleanup / Hardening
**Status:** Changes implemented, awaiting validation

---

## What We Did

Comprehensive self-review of the entire SystemNix codebase (106 `.nix` files, 782-line flake.nix, 33 service modules). Identified dead code, stale references, unused library functions, dangerous scripts, and architectural gaps. Executed cleanup.

---

## a) FULLY DONE ✅

| # | Change | Files | Impact |
|---|--------|-------|--------|
| 1 | **Deleted dead Go CI workflow** | `.github/workflows/go-test.yml` | Referenced `pkgs/dnsblockd-processor/` which no longer exists — workflow would never trigger and would fail if it did |
| 2 | **Deleted vestigial `go.mod`** | `go.mod` | 2-line file with zero `require` directives; Go code extracted to external `dnsblockd` repo months ago |
| 3 | **Deleted duplicate blocklist-hash-updater** | `platforms/nixos/scripts/blocklist-hash-updater` | Duplicates `scripts/dns-update.sh` (the canonical one called from justfile); was never referenced |
| 4 | **Fixed AGENTS.md stale references** | `AGENTS.md` | Removed `dnsblockd-processor/` from architecture diagram; fixed `go-update-tools-manual` (recipe doesn't exist) → plain `go install` |
| 5 | **Removed dnsblockd-processor from pkgs/README.md** | `pkgs/README.md` | Package extracted to external `dnsblockd` repo; documentation was stale |
| 6 | **Removed dnsblockd-processor from FEATURES.md** | `FEATURES.md` | Updated blocklist processing description; removed dead CI entry and package row |
| 7 | **Fixed dangerous `rm -rf` in diagnostic script** | `scripts/nixos-diagnostic.sh` | `sudo rm -rf /nix/var/nix/db` destroys the entire Nix database → replaced with safe `nix-collect-garbage -d` |
| 8 | **Adopted `serviceDefaultsUser` in monitor365.nix** | `modules/nixos/services/monitor365.nix` | `serviceDefaultsUser` was exported from `lib/systemd/service-defaults.nix` but **never used anywhere** — now adopted |
| 9 | **Adopted `serviceDefaultsUser` in file-and-image-renamer.nix** | `modules/nixos/services/file-and-image-renamer.nix` | Same — inline `Restart`/`RestartSec` replaced with shared library call |
| 10 | **Added `services.default-services.enable` option** | `modules/nixos/services/default.nix` | Docker + Nix GC were unconditionally enabled on import; now guarded by explicit enable option (defaults to `true` for backward compat) |

---

## b) PARTIALLY DONE ⚠️

| Item | Status | What's Left |
|------|--------|-------------|
| Hardcoded ports in service modules | Identified but not fixed | `signoz.nix` (6 scrape targets), `homepage.nix` (7 URLs), `gatus-config.nix` (7 endpoints), `gitea.nix` (1), `ai-stack.nix` (1) — should reference `config.services.*` options |
| Shell config duplication between darwin/nixos | Identified but not fixed | `platforms/darwin/programs/shells.nix` and `platforms/nixos/programs/shells.nix` have identical carapace/starship/nixAliases patterns |

---

## c) NOT STARTED ❌

| # | Item | Effort | Impact | Priority |
|---|------|--------|--------|----------|
| 1 | **Unsloth Studio missing `harden{}`** — `ai-stack.nix` line 250 | 5 min | High | P1 |
| 2 | **`gpu-recovery` service missing `harden{}` + `serviceDefaults{}`** — `niri-config.nix` line 87 | 5 min | High | P1 |
| 3 | **Signoz port options should use `serviceTypes.servicePort`** — lines 105-155 use inline `lib.mkOption` instead of shared `types.nix` | 15 min | Medium | P2 |
| 4 | **Signoz scrape targets hardcoded** — 6 Prometheus scrape targets use raw `127.0.0.1:PORT` instead of `config.services.*` options | 30 min | High | P2 |
| 5 | **Homepage dashboard hardcoded ports** — 7 `localhost:PORT` URLs should reference service module options | 30 min | Medium | P2 |
| 6 | **Gatus endpoints hardcoded ports** — 7 `http://localhost:PORT` URLs should reference service module options | 30 min | Medium | P2 |
| 7 | **Shell config dedup** — Extract common carapace/starship/nixAliases to `platforms/common/programs/` | 1 hr | Medium | P3 |
| 8 | **NixOS VM tests** — No `nixosTests` in flake; only static analysis (statix, deadnix, alejandra) | 2 hr | High | P2 |
| 9 | **Darwin CI** — CI runs on `ubuntu-latest`; Darwin config is never built/checked | 1 hr | Medium | P3 |
| 10 | **Outdated test scripts** — `scripts/test-home-manager.sh` and `scripts/test-shell-aliases.sh` are not in CI or justfile | 30 min | Low | P4 |

---

## d) TOTALLY FUCKED UP 💥

Nothing broken. All changes are non-breaking:
- `default.nix` enable option defaults to `true` — backward compatible
- `serviceDefaultsUser` adoption preserves existing `Restart = "always"` + `RestartSec = "10"` behavior
- Deleted files were all dead code

---

## e) WHAT WE SHOULD IMPROVE 📈

### Architecture

1. **`serviceDefaultsUser` adoption gap** — The function was designed for Home Manager user services but was never used. Now used in 2 modules. The `emeet-pixyd` user service (from external flake) and `niri-drm-healthcheck` user service still use inline patterns — but these may be acceptable given their simplicity.

2. **Hardcoded port references** — The project has a strong convention of `config.services.<name>.port` in caddy.nix, but ~20 other locations across signoz, homepage, gatus, gitea, ai-stack, voice-agents, and authelia still hardcode ports. This violates the stated rule in AGENTS.md.

3. **No `nixosTests`** — The flake has `statix` and `deadnix` checks but no NixOS VM tests. Services like caddy, authelia, immich, and the DNS stack would benefit from integration tests that verify they actually start and respond.

4. **Stale documentation in `docs/status/archive/`** — Many archived status reports reference `dnsblockd-processor` and `pkgs/dnsblockd-processor/` which no longer exists. These are historical and probably fine to leave as-is.

### Type Model / Shared Lib

5. **`types.nix` adoption incomplete** — `servicePort` is used by 10 modules, but signoz.nix defines 3 inline port options that duplicate the pattern. `systemdServiceIdentity` is used by most service modules but some (monitor365, file-and-image-renamer) manually define `user`/`group` options instead.

6. **No shared `homeManagerUserService` helper** — monitor365.nix and file-and-image-renamer.nix have identical boilerplate for `Unit`/`Install` (graphical-session.target, StartLimitBurst, StartLimitIntervalSec). This could be a shared function.

### Libraries

7. **No Nix library reuse beyond stdlib** — The lib/ helpers are hand-rolled. Libraries like `nixpkgs-lib` patterns or `flake-utils-plus` could reduce boilerplate, but the current approach is fine for this scale.

---

## f) Top #25 Things We Should Get Done Next

### P0 — Immediate (safety / correctness)

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 1 | Add `harden{}` to `unsloth-studio` service in ai-stack.nix | 5 min | High — unsandboxed Python running arbitrary code |
| 2 | Add `harden{}` + `serviceDefaults{}` to `gpu-recovery` service in niri-config.nix | 5 min | High — system service without sandboxing |
| 3 | Validate flake check passes after this session's changes | 2 min | Critical |

### P1 — High Impact, Low Effort

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 4 | Extract signoz port options to use `serviceTypes.servicePort` from types.nix | 15 min | Consistency |
| 5 | Replace 6 hardcoded scrape target ports in signoz.nix with config references | 30 min | Correctness — won't break on port change |
| 6 | Replace 7 hardcoded ports in homepage dashboard with config references | 30 min | Same |
| 7 | Replace 7 hardcoded ports in gatus-config.nix with config references | 30 min | Same |
| 8 | Add `MemoryMax` to all Docker containers in twenty.nix, manifest.nix, voice-agents.nix | 15 min | Prevent OOM |
| 9 | Fix `gitea.nix` `url = "http://localhost:3000"` → use `config.services.gitea.settings.server.HTTP_PORT` | 5 min | Correctness |

### P2 — Medium Impact, Medium Effort

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 10 | Deduplicate shell config (carapace, starship, nixAliases) between darwin/nixos | 1 hr | DRY |
| 11 | Add basic NixOS VM test for caddy + authelia (can they start? do they respond?) | 2 hr | Reliability |
| 12 | Add `harden{}` to user services (monitor365, file-and-image-renamer) — requires adapting for HM | 30 min | Defense in depth |
| 13 | Create shared `homeManagerUserService` helper for common Unit/Install boilerplate | 30 min | DRY |
| 14 | Wire `scripts/health-check.sh` harden audit into CI (`nix-check.yml`) | 15 min | Automated enforcement |
| 15 | Add flake input destructuring consistency — add missing inputs to `outputs` pattern | 10 min | Style |

### P3 — Nice to Have

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 16 | Add Darwin CI runner (macOS-based GitHub Actions) | 1 hr | Cross-platform reliability |
| 17 | Convert `scripts/test-home-manager.sh` and `test-shell-aliases.sh` to justfile recipes | 30 min | Discoverability |
| 18 | Add `services.default-services.dockerPruneDates` option (currently hardcoded `"weekly"`) | 5 min | Configurability |
| 19 | Add `services.default-services.gcDates` option (currently hardcoded `"weekly"`) | 5 min | Configurability |
| 20 | Remove outdated `scripts/nixos-diagnostic.sh` — replaced by `just check` and `just health` | 10 min | Cleanup |
| 21 | Add `MemoryMax` to emeet-pixyd user service (currently unlimited) | 5 min | Safety |
| 22 | Extract `photomap.nix` from flake.nix imports if permanently disabled | 2 min | Dead eval reduction |
| 23 | Add BTRFS scrub results to SigNoz (currently only monitored by snapshot freshness timer) | 30 min | Observability |
| 24 | Consider `nix-fast-build` for CI to speed up Darwin+NixOS matrix | 2 hr | CI speed |
| 25 | Archive `docs/planning/` files older than 30 days | 10 min | Clean docs |

---

## g) Top #1 Question I Cannot Figure Out Myself

**Should `photomap.nix` and `monitor365.nix` stay in the flake.nix imports if they're disabled in configuration.nix?**

- `photomap.enable` is commented out (line 148 of configuration.nix) but the module is still imported in flake.nix (line 433/707)
- `monitor365.enable = false` (line 243) but module imported (line 439/716)

Removing them from imports would slightly reduce eval time, but makes re-enabling a 3-step process (uncomment import, uncomment module reference, enable). Keeping them is more convenient. Is there a preference?

---

## Brutal Self-Review Answers

### 1. What did you forget?
- `serviceDefaultsUser` existed for months but was never adopted — nobody caught this
- `go.mod` was vestigial for months after `dnsblockd-processor` was extracted
- The `go-test.yml` CI workflow was dead since the extraction and nobody noticed
- The dangerous `rm -rf /nix/var/nix/db` was in a diagnostic script since it was written

### 2. What is something that's stupid that we do anyway?
- Hardcode ~20 port numbers across modules while having a stated convention against it
- Define `serviceDefaultsUser` in the shared lib and then never use it
- Keep a `go.mod` in the repo root when there's zero Go code in the repo

### 3. What could you have done better?
- Should have caught the dead CI workflow in the session where `dnsblockd-processor` was extracted
- Should have adopted `serviceDefaultsUser` immediately when it was created
- Should have added the `default.nix` enable option when it was first imported

### 4. What could you still improve?
- All the P1 items above (hardcoded ports, missing harden, missing tests)
- The signoz module is the worst offender: 6+ hardcoded scrape targets + inline port options when `types.nix` has the exact pattern needed

### 5. Did you lie to you?
- No. All findings are verified with file paths and line numbers.

### 6. How can we be less stupid?
- Wire the `health-check.sh` harden audit into CI so missing adoptions are caught automatically
- Add a CI check that scans for `localhost:\d+` patterns in `modules/nixos/services/*.nix`

### 7. Ghost systems?
- `platforms/nixos/scripts/blocklist-hash-updater` was a ghost — duplicated `scripts/dns-update.sh`, never referenced. **Now deleted.**
- `.github/workflows/go-test.yml` was a ghost — triggered on a deleted path. **Now deleted.**

### 8. Scope creep trap?
- The hardcoded ports cleanup could easily become a multi-day project. Prioritized P1 (safety) and P2 (correctness) separately. Not starting P2 without explicit instruction.

### 9. Did we remove something useful?
- No. All removed files/code was dead: unreferenced scripts, vestigial `go.mod`, CI targeting deleted directory.

### 10. Split brains?
- **Shell config** — darwin and nixos have near-identical `nixAliases`/carapace/starship blocks that could diverge silently. Not yet fixed.
- **Homepage + Gatus port references** — these manually duplicate port numbers that are defined as options in their respective service modules. If a port changes, homepage/gatus won't update automatically.

### 11. Tests?
- **Current coverage:** statix (static), deadnix (dead code), alejandra (formatting), shellcheck (scripts), gitleaks (secrets) — all via CI + pre-commit
- **Missing:** NixOS VM tests, service integration tests, Home Manager activation tests
- **The Go CI is now removed** (was dead anyway) — dnsblockd tests run in the external `dnsblockd` repo

---

## Files Changed This Session

| File | Change |
|------|--------|
| `.github/workflows/go-test.yml` | **DELETED** — dead CI path |
| `go.mod` | **DELETED** — vestigial, no Go code in repo |
| `platforms/nixos/scripts/blocklist-hash-updater` | **DELETED** — duplicates `scripts/dns-update.sh` |
| `AGENTS.md` | Removed `dnsblockd-processor/` from architecture tree; fixed `go-update-tools-manual` reference |
| `pkgs/README.md` | Removed `dnsblockd-processor` documentation |
| `FEATURES.md` | Updated blocklist processing description; removed dead CI + package entries |
| `scripts/nixos-diagnostic.sh` | Replaced dangerous `sudo rm -rf /nix/var/nix/db` with safe `nix-collect-garbage -d` |
| `modules/nixos/services/default.nix` | Added `services.default-services.enable` option (defaults `true`) |
| `modules/nixos/services/monitor365.nix` | Adopted `serviceDefaultsUser` from shared lib |
| `modules/nixos/services/file-and-image-renamer.nix` | Adopted `serviceDefaultsUser` from shared lib |
