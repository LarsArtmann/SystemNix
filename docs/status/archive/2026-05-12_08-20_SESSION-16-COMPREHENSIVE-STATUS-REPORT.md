# SystemNix — Comprehensive Status Report

**Date:** 2026-05-12 08:20
**Session:** 16 (continuation of sessions 13-15 sprint)
**Branch:** `master` (1 commit ahead of origin — unpushed status report)
**Flake:** `nix flake check --no-build` → **all checks passed** ✅
**Pre-commit:** All 9 hooks pass (alejandra, deadnix, statix, shellcheck, etc.) ✅

---

## a) FULLY DONE

### Sprint Sessions 13–15 (15 commits, all pushed to origin)

| # | Commit | What | Impact |
|---|--------|------|--------|
| 1 | `287d2975` | Documented otel-tui Linux-only pattern, Darwin disk exhaustion gotcha, `_module.args` in AGENTS.md | Knowledge capture |
| 2 | `94bbcdb0` | Removed broken `config-validate.sh` references from pre-commit config | Fixed dead hook references |
| 3 | `b0780bd0` | Fixed alejandra formatting in niri-config.nix, disabled dead sublime-sync LaunchAgent | Dead code removal |
| 4 | `a4bb3b94` | `[linux]` tag on `dns-update`, extracted `evo_x2_ip` variable, simplified `gpu-python`, migrated dns-blocker to shared `harden{}` + `serviceDefaults{}` | DRY + platform correctness |
| 5 | `29f9164b` | Migrated awww-daemon, swayidle, cliphist to `sd.hardenUser{}` + `sd.serviceDefaultsUser{}` in niri-wrapped.nix | User-service hardening adoption |
| 6 | `fa0efa75` | Extracted 10× hardcoded `localhost:3000` to config-derived `giteaUrl`; fixed statix to loop files individually | Eliminated hardcoded ports |
| 7 | `4785469d` | Added `mkPackageOverlay` helper, replaced 4 identical overlay definitions | -24 lines, DRY factory |
| 8 | `9e1f229a` | Added single-line header comments to all 35 service modules | Documentation |
| 9 | `33327c7b` | **ROOT CAUSE FIX**: statix hook `grep -q . && exit 1` was failing on clean files (grep returns 1 on no match → became bash exit code). Replaced with result variable pattern | Fixed pre-commit since inception |
| 10 | `df0473cb` | Extracted alert rules into `signoz-alerts.nix` with `mkRule` helper (939 → 599 lines, **-36%**) | Major file size reduction |
| 11 | `bfd0541d` | Documented mkPackageOverlay, config-derived URLs, signoz split, statix gotchas in AGENTS.md | Knowledge capture |
| 12 | `6c20d63e` | Full status report for the sprint | Documentation |
| 13 | `42be95d2` | Updated emeet-pixyd flake lock (camera detection fix, Type=notify, OOM protection) | Dependency update |
| 14 | `2c081cb6` | Documented dual-WAN ECMP+MPTCP architecture in AGENTS.md | Knowledge capture |
| 15 | `a8f41dfd` | Replaced MPTCP polling with NM dispatcher events for dual-WAN | Architecture improvement |

### Prior Sprint Sessions 9–12

| # | What | Impact |
|---|------|--------|
| 1 | Disk exhaustion diagnosis and fix | System stability |
| 2 | otel-tui made Linux-only (saves 40+ min per macOS build) | Build time |
| 3 | Dual-WAN bugfixes, NM dispatcher refactor | Network reliability |
| 4 | EMEET PIXY camera offline root cause analysis & fix | Hardware support |
| 5 | Removed harmful route reset commands from internet-diagnostic | Network safety |

### Overall Repository Health

| Metric | Value | Status |
|--------|-------|--------|
| Nix files | 110 | ✅ |
| Tracked files | 938 | ✅ |
| Service modules | 36 | ✅ |
| Flake evaluation | Pass | ✅ |
| Pre-commit hooks (9) | All pass | ✅ |
| TODO/FIXME in Nix files | 1 (package name, not actual TODO) | ✅ |
| Shellcheck warnings | 3 (unused vars in test scripts, not errors) | ✅ |
| AGENTS.md documentation | 912 lines | ✅ |
| Justfile recipes | 78 | ✅ |

---

## b) PARTIALLY DONE

### Shared lib adoption — IN PROGRESS (good coverage, not 100%)

| Pattern | Adopted | Remaining | Coverage |
|---------|---------|-----------|----------|
| `harden{}` | 28/29 services that manage systemd | 0 (signoz-alerts.nix has no systemd — false positive) | **100%** |
| `serviceDefaults{}` | 34/35 service modules | 1 (security-hardening.nix — intentionally bare) | **97%** |
| `hardenUser{}` | 3 user-service modules | 0 | **100%** |
| `serviceDefaultsUser{}` | 3 user-service modules | 0 | **100%** |
| `serviceTypes.systemdServiceIdentity` | 7 services | **9 still define user/group manually** | **44%** |
| `mkPackageOverlay` | 4 overlays | ~8 more could use it | **33%** |
| Config-derived ports in caddy | All service references | 0 hardcoded service ports | **100%** |

### 9 services still defining user/group manually (candidates for `systemdServiceIdentity` migration):

1. `ai-models.nix` — tmpfiles only, no systemd service
2. `disk-monitor.nix` — defines `lars`/`users`
3. `file-and-image-renamer.nix` — user service
4. `gitea-repos.nix` — uses `gitea` user from gitea module
5. `monitor365.nix` — already uses `hardenUser`
6. `niri-config.nix` — mixed system/user services
7. `security-hardening.nix` — sysctl, no services
8. `signoz.nix` — defines `signoz`/`signoz` custom user
9. `sops.nix` — secret decryption, no user definitions

**Reality**: Only ~4 of these are genuine candidates (disk-monitor, file-and-image-renamer, monitor365, signoz). The rest either don't define users or use users from other modules.

---

## c) NOT STARTED

| # | Item | Estimated Effort | Estimated Impact |
|---|------|-----------------|------------------|
| 1 | **`mkDockerService` helper** — manifest.nix, twenty.nix, openseo.nix all share ~50 lines of identical docker-compose systemd boilerplate | Medium (2h) | High (DRY, -100 lines) |
| 2 | **Consolidate `giteaPort`/`giteaUrl` into gitea module** — currently duplicated as local `let` bindings in gitea.nix and gitea-repos.nix | Low (30min) | Medium (single source of truth) |
| 3 | **Extract OTel collector config from signoz.nix** — lines 844-935 are ~90 lines of scrape pipeline config | Medium (1h) | Medium (readability) |
| 4 | **Eliminate flake.nix double-registration** — 46 references, 68 lines of duplication. Modules registered in both `imports` AND `inputs.self.nixosModules` | High (3h) | High (DRY, correctness) |
| 5 | **Modularize flake.nix** — 612 lines, should be split into `flake/` directory | High (4h) | High (maintainability) |
| 6 | **Add pre-commit hooks to CI** — GitHub Action to run `pre-commit run --all-files` | Low (1h) | High (catch regressions) |
| 7 | **Migrate emeet-pixyd scrape port to config-derived** — signoz.nix hardcodes `127.0.0.1:8090` | Low (15min) | Low (consistency) |
| 8 | **Add `unitDefaults` helper** — `onFailure` directive is in `[Unit]`, not `[Service]`, so can't go in `serviceDefaults`. Would need separate helper | Medium (1h) | Medium (22 files use `onFailure`) |
| 9 | **Consolidate flake inputs** — several inputs could potentially follow nixpkgs that don't currently | Low (30min) | Low (cache hits) |
| 10 | **Shellcheck warning cleanup** — 3 unused var warnings in test scripts | Low (15min) | Low (clean lint) |

---

## d) TOTALLY FUCKED UP

**Nothing is totally fucked up.** The codebase is in excellent shape:

- ✅ Flake evaluates cleanly
- ✅ All 9 pre-commit hooks pass
- ✅ Zero actual TODOs in Nix files
- ✅ All service ports config-derived in caddy
- ✅ 100% hardening adoption on system services
- ✅ 100% hardening adoption on user services
- ✅ Zero hardcoded secrets

### Closest to "fucked up" (resolved):

| Issue | Status | Resolution |
|-------|--------|------------|
| **statix pre-commit hook was broken since creation** | ✅ Fixed (session 14) | Root cause: `grep -q . && exit 1` returns 1 when no output. Fixed with result variable pattern. Every commit since the hook was added had a false-positive statix failure that was ignored. |
| **Darwin disk exhaustion from Nix builds** | ✅ Documented | Workaround: `just clean` before builds. Root cause: `/nix/store` on APFS fills up fast. |
| **awww-daemon BrokenPipe crash loop** | ✅ Mitigated | Upstream bug in awww 0.12.0. `Restart=always` + `PartOf` propagation handles it. |
| **Ollama dual-runner GPU OOM** | ✅ Fixed | `OLLAMA_MAX_LOADED_MODELS=1` + `OLLAMA_GPU_OVERHEAD=8GiB` + per-runner fraction 0.45. |

---

## e) WHAT WE SHOULD IMPROVE

### Architecture

1. **`flake.nix` is 612 lines** — the single biggest maintainability risk. It handles imports, overlays, perSystem packages, NixOS configs for 2 machines, Darwin config, and home-manager wiring all in one file. Should be modularized into `flake/` directory.

2. **Double-registration anti-pattern** — modules appear in both `imports` (for flake-parts) AND `inputs.self.nixosModules` (for consumption). This is 46 references and ~68 lines of pure duplication. The fix requires understanding whether flake-parts can export modules without explicit `nixosModules` declarations.

3. **Docker-compose boilerplate** — manifest.nix, twenty.nix, openseo.nix all copy-paste ~50 lines of systemd service wrapping around `docker compose`. A `mkDockerService` helper in `lib/` would eliminate this.

### Code Quality

4. **`systemdServiceIdentity` adoption at 44%** — 9 services still define user/group manually instead of using the shared type helper. Low individual effort, high consistency payoff.

5. **`mkPackageOverlay` adoption at 33%** — 4 overlays converted, ~8 more could benefit. The pattern is proven and safe.

6. **No CI pipeline** — all quality gates (pre-commit, flake check, formatting) run locally only. One bad force-push could break the NixOS machine.

### Documentation

7. **AGENTS.md at 912 lines** — comprehensive but approaching "too long to scan". Could benefit from extracting reference tables to separate files.

### Testing

8. **No automated integration tests** — `just test-fast` and `just test` do build validation, but there's no "apply to VM and verify services start" testing. NixOS VM tests would catch issues before deployment.

---

## f) Top #25 Things We Should Get Done Next

Sorted by **impact × effort** (high impact, low effort first):

| # | Item | Effort | Impact | Category |
|---|------|--------|--------|----------|
| 1 | Add GitHub Actions CI (pre-commit + flake check) | 1h | 🔴 Critical | Quality |
| 2 | Fix 3 shellcheck warnings in test scripts | 15min | Low | Quality |
| 3 | Migrate emeet-pixyd scrape port to config-derived in signoz.nix | 15min | Low | Consistency |
| 4 | Consolidate giteaPort/giteaUrl into gitea module (export option) | 30min | Medium | DRY |
| 5 | Migrate 4 remaining services to `systemdServiceIdentity` | 1h | Medium | Consistency |
| 6 | Extract `mkDockerService` helper in lib/ | 2h | 🔴 High | DRY |
| 7 | Convert 8 more overlays to `mkPackageOverlay` | 1h | Medium | DRY |
| 8 | Add `unitDefaults` helper for `onFailure` pattern | 1h | Medium | DRY |
| 9 | Extract OTel collector config to signoz-collector.nix | 1h | Medium | Readability |
| 10 | Add `just test-vm` recipe for NixOS VM test | 3h | 🔴 High | Testing |
| 11 | Eliminate flake.nix double-registration | 3h | 🔴 High | Architecture |
| 12 | Modularize flake.nix into flake/ directory | 4h | 🔴 High | Architecture |
| 13 | Add NixOS VM integration tests for critical services | 4h | High | Testing |
| 14 | Create `flake/imports.nix` — centralized import list | 1h | Medium | Architecture |
| 15 | Extract shared DNS config to common module (unbound settings) | 2h | Medium | DRY |
| 16 | Add `just validate` — comprehensive pre-push check (lint + test + format) | 30min | Medium | DX |
| 17 | Document overlay dependency graph in AGENTS.md | 30min | Low | Documentation |
| 18 | Add `just diff` — show nixos-rebuild dry-run diff | 15min | Low | DX |
| 19 | Migrate rpi3-dns to use `dns-blocker-config.nix` shared module | 2h | Medium | DRY |
| 20 | Add health-check endpoints to services that lack them | 3h | Medium | Observability |
| 21 | Create dependency graph visualization for services | 2h | Low | Documentation |
| 22 | Add deployment rollback safety net (auto-rollback on boot failure) | 3h | High | Reliability |
| 23 | Consolidate home-manager program modules into feature groups | 2h | Medium | Architecture |
| 24 | Add secrets rotation automation (sops + age key lifecycle) | 4h | Medium | Security |
| 25 | Split AGENTS.md into focused sections (architecture.md, services.md, gotchas.md) | 2h | Medium | Documentation |

---

## g) Top #1 Question I Cannot Figure Out Myself

**Should `flake.nix` double-registration be eliminated?**

The current pattern registers every service module twice:
1. In `imports` (flake-parts consumption — makes options available within the flake)
2. In `inputs.self.nixosModules.<name>` (exported module — consumed by `nixosConfiguration`)

This is ~46 references and ~68 lines of duplication. However, I'm not certain whether flake-parts provides an automatic way to re-export `imports` as `nixosModules` without the explicit declaration. Attempting to remove the double-registration without understanding the flake-parts module system could break the entire build.

**The specific question:** Does `flake-parts` automatically export modules added to `imports` as `nixosModules`, or is the explicit `inputs.self.nixosModules.<name>` declaration required for consumption in `nixosConfiguration`?

This matters because:
- If auto-exported → we can delete 68 lines and eliminate the duplication
- If not auto-exported → the pattern is necessary and should just be documented as a flake-parts requirement
- Getting it wrong → breaks all 36 service modules on both machines

---

## Summary Metrics

| Area | Score | Trend |
|------|-------|-------|
| Code quality | 9/10 | ↑ (statix fix, hardening adoption, DRY improvements) |
| Documentation | 9/10 | ↑ (AGENTS.md comprehensive, module headers, gotchas) |
| Test coverage | 5/10 | → (build validation only, no VM/integration tests) |
| CI/CD | 2/10 | → (no CI pipeline — all quality gates are local) |
| Architecture | 7/10 | → (flake.nix bloat is the main drag) |
| Observability | 9/10 | → (SigNoz + Gatus + node_exporter + health metrics) |
| Security | 9/10 | → (full hardening, sops secrets, DNS blocking) |
| DRY adherence | 8/10 | ↑ (mkPackageOverlay, mkRule, config-derived ports) |

**Overall: 7.25/10 — strong codebase, main gaps are CI and testing infrastructure.**
