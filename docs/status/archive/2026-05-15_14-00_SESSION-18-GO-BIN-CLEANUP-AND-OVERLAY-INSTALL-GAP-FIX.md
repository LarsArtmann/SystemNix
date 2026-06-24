# Session 18 — Full Comprehensive Status Report

**Date:** 2026-05-15 14:00 CEST
**Branch:** master (1 commit ahead of origin)
**Nixpkgs:** 26.05.20260423.01fbdee (Yarara)
**Nix:** 2.34.6
**Platform:** evo-x2 (x86_64-linux, AMD Ryzen AI Max+ 395, 128GB)

---

## Disk

| Mount | Size | Used | Avail | Use% |
|-------|------|------|-------|------|
| `/` (root) | 512G | 418G | 78G | 85% |
| `/data` | 1.0T | 819G | 206G | 80% |

---

## a) FULLY DONE ✅

### Session 18 Work: `~/go/bin` Stale Binary Cleanup

**Problem discovered:** 9 Nix overlay-managed tools in `~/go/bin/` were stale `go install` binaries that shadowed the Nix-managed versions. Worse, 6 overlay tools were never added to `home.packages` — they only "worked" because the stale binaries existed.

| Tool | Was in overlay? | Was in packages? | Fix |
|------|:-:|:-:|-----|
| `art-dupl` | ✅ | ❌ | Added to `base.nix` |
| `branching-flow` | ✅ | ❌ | Added to `base.nix` |
| `buildflow` | ✅ | ❌ | Added to `base.nix` |
| `go-auto-upgrade` | ✅ | ❌ | Added to `base.nix` |
| `go-structure-linter` | ❌ | ❌ | Added to `base.nix` |
| `hierarchical-errors` | ✅ | ❌ | Added to `base.nix` |
| `golangci-lint-auto-configure` | ✅ | ✅ | Trashed stale binary |
| `library-policy` | ✅ | ✅ | Trashed stale binary |
| `mr-sync` | ✅ | ✅ | Trashed stale binary |
| `ginkgo` | ❌ | ❌ | Added to `base.nix` (nixpkgs) |
| `goimports` | ❌ | ❌ | Added via `gotools` (nixpkgs) |
| `templ` | N/A | N/A | Trashed redundant symlink |

**Files changed:**
- `platforms/common/packages/base.nix` — Added 8 packages (6 overlay + 2 nixpkgs)
- `platforms/common/home-base.nix` — Updated `~/go/bin` PATH comment with current contents
- `AGENTS.md` — Documented overlay ≠ installed distinction, `~/go/bin` gotcha
- `flake.lock` — Auto-updated (branching-flow, go-structure-linter new revisions)

**Remaining in `~/go/bin/`** (legitimate `go install`-only, no nixpkgs alternative):
- `govalid` (sivchari/govalid — third-party Go validator)
- `projects-management-automation` (LarsArtmann, has flake.nix but not wired as input)

**Verification:** `just test-fast` — all checks passed.

### Previously Completed (Sessions 13–17)

- SigNoz alert rules + dashboards extracted to `signoz-alerts.nix` with `mkRule` helper
- All 35 service modules have header comments
- `mkPackageOverlay` helper adopted by 4 overlays
- Config-derived URLs (no hardcoded ports) in `caddy.nix`
- `harden{}` / `hardenUser{}` adopted by all service modules
- `serviceDefaults{}` / `serviceDefaultsUser{}` adopted system-wide
- Pre-commit hooks fixed (statix pipe operator filter, config-validate cleanup)
- EMEET PIXY module rewritten with HID state querying
- Monitor365 rewritten + enabled
- Minecraft server disabled on evo-x2
- Flake inputs updated (2025-05-15)
- AGENTS.md comprehensive documentation (600+ lines)

---

## b) PARTIALLY DONE 🔧

| Area | Status | Details |
|------|--------|---------|
| `mkPackageOverlay` adoption | **40%** | 4 of ~10 overlays use it; `buildflow`, `go-auto-upgrade`, `go-structure-linter`, `branching-flow`, `art-dupl` still use raw `.overlays.default` |
| `systemdServiceIdentity` adoption | **44%** | ~4 service modules could still adopt the helper |
| `flake.nix` modularization | **20%** | 612 lines, should be split into flake-parts sub-modules |
| NixOS VM tests | **0%** | None exist — no integration testing |
| nix-colors integration | **30%** | Catppuccin Mocha theme applied to most apps; 17+ hardcoded colors remain |
| CI pipeline | **30%** | Only `flake-update` + `nix-check`; no VM tests, no Darwin cross-build |
| Documentation cleanup | **10%** | 350+ files in `docs/`, 250+ in `docs/status/archive/`; no pruning strategy |
| DNS failover cluster | **60%** | Module written, Pi 3 image buildable; hardware not provisioned |

---

## c) NOT STARTED ❌

| # | Item | Priority | Effort |
|---|------|:--------:|:------:|
| 1 | Pi 3 hardware provisioning for DNS failover | High | 2h |
| 2 | NixOS VM test suite | High | 8h |
| 3 | Deploy Dozzle (`logs.home.lan`) | Medium | 1h |
| 4 | `mkDockerService` shared helper | Medium | 3h |
| 5 | Shared Go flake-parts template | Medium | 4h |
| 6 | Per-threshold SigNoz alert routing (critical→Discord) | Medium | 2h |
| 7 | Move dns-failover `authPassword` to sops | Medium | 30m |
| 8 | Consolidate voice-agents Caddy vHost | Medium | 30m |
| 9 | Secret rotation strategy | Low | 4h |
| 10 | AppArmor profiles | Low | 4h |
| 11 | DNS-over-QUIC overlay | Low | 2h |
| 12 | Create `flake.nix` for hierarchical-errors repo | Low | 1h |
| 13 | Benchmark/storage cleanup scripts | Low | 2h |
| 14 | Compute real `vendorHash` for BuildFlow | Medium | 30m |
| 15 | Convert PMA to flake input | Low | 1h |
| 16 | Darwin distributed builds to evo-x2 | Medium | 2h |
| 17 | `projects-management-automation` as flake input | Low | 1h |

---

## d) TOTALLY FUCKED UP 💥

### No Critical Breakages

No services are known-broken at this time. The system is functional.

### Known Issues (Accepted/Low-Impact)

| Issue | Severity | Status |
|-------|:--------:|--------|
| ~130W power ceiling | Info | GMKtec firmware limit, no OS override. `amd_pstate=performance` ensures max within ceiling |
| Darwin disk exhaustion (90-95%) | Medium | 229 GB disk. Consider distributed builds to evo-x2 |
| awww-daemon BrokenPipe | Low | Upstream 0.12.0 bug, mitigated via `Restart=always` |
| watchdogd nixpkgs module broken | Low | Workaround: omit `device` from settings |
| `otel-tui` Darwin excluded | Info | 40+ min build, disk exhaustion. Linux-only via `_module.args` pattern |
| Flake.lock merge conflicts | Low | No lockfile merge strategy |
| PhotoMap AI disabled | Low | Pinned to old SHA256 |
| Multi-WM (Sway) disabled | Low | Possibly bitrotten |
| Auditd disabled | Medium | NixOS 26.05 bug #483085 |
| Broken justfile commands | Low | `benchmark`, `perf`, `context`, `clean-storage` reference non-existent scripts |

---

## e) WHAT WE SHOULD IMPROVE 📈

### Architecture & Code Quality

1. **`flake.nix` is 612 lines** — should be modularized into flake-parts sub-modules per the `overlays/` extraction pattern already used
2. **4 Docker services follow identical patterns** (hermes, openseo, manifest, comfyui) — extract `mkDockerService` helper to lib/
3. **5 overlays still use raw `.overlays.default`** instead of `mkPackageOverlay` — inconsistent
4. **350+ docs files** with no pruning strategy — status archive alone has 250+ files
5. **No NixOS VM tests** — zero integration test coverage for 36 service modules
6. **Broken justfile recipes** — 4 commands reference scripts that don't exist

### Infrastructure

7. **DNS failover cluster** — module written but Pi 3 not provisioned; single point of failure for DNS
8. **No secret rotation** — sops secrets are age-encrypted with SSH host key; no rotation plan
9. **No Darwin cross-build** — CI only checks Linux; Darwin config could silently break
10. **Authelia forward auth** not tested end-to-end programmatically

### Developer Experience

11. **`~/go/bin` is still in PATH** — only for 2 tools now, but the pattern is fragile; could break again if someone runs `go install` for an overlay-managed tool
12. **No `nix develop` integration** — devShell exists but is minimal; could include all Go tooling
13. **Pre-commit hooks are local-only** — not enforced in CI

---

## f) Top #25 Things We Should Get Done Next

| # | Priority | Item | Effort | Impact | Category |
|---|:--------:|------|:------:|:------:|----------|
| 1 | **P0** | **Deploy to evo-x2** (`just switch` + verify services) | 30m | Critical | Deploy |
| 2 | **P1** | Convert remaining 5 overlays to `mkPackageOverlay` | 30m | Medium | Consistency |
| 3 | **P1** | Add NixOS VM test for caddy+authelia (critical path) | 4h | High | Testing |
| 4 | **P1** | Modularize `flake.nix` into flake-parts sub-modules | 4h | High | Architecture |
| 5 | **P1** | Fix broken justfile commands (remove or create scripts) | 30m | Low | DX |
| 6 | **P1** | Deploy Dozzle (`logs.home.lan`) | 1h | Medium | Observability |
| 7 | **P2** | Create `mkDockerService` helper (4 services) | 3h | Medium | DRY |
| 8 | **P2** | Per-threshold SigNoz alert routing | 2h | Medium | Monitoring |
| 9 | **P2** | Move dns-failover `authPassword` to sops | 30m | Medium | Security |
| 10 | **P2** | Adopt `systemdServiceIdentity` in remaining 4 modules | 1h | Low | Consistency |
| 11 | **P2** | Consolidate voice-agents Caddy vHost | 30m | Low | Code quality |
| 12 | **P2** | Add Darwin cross-build check to CI | 2h | High | CI |
| 13 | **P2** | Prune `docs/status/archive/` (250+ files) | 30m | Low | Docs |
| 14 | **P2** | Wire `projects-management-automation` as flake input | 1h | Medium | Completeness |
| 15 | **P3** | Provision Pi 3 for DNS failover cluster | 2h | High | Infrastructure |
| 16 | **P3** | Compute real `vendorHash` for BuildFlow | 30m | Medium | External repos |
| 17 | **P3** | Create shared Go flake-parts template | 4h | Medium | External repos |
| 18 | **P3** | nix-colors full integration (17+ hardcoded colors) | 6h | Low | Theme |
| 19 | **P3** | AppArmor profiles | 4h | Medium | Security |
| 20 | **P3** | Secret rotation strategy | 4h | Medium | Security |
| 21 | **P3** | Add VM tests for all 36 service modules | 16h | High | Testing |
| 22 | **P4** | Darwin distributed builds to evo-x2 | 2h | Medium | DX |
| 23 | **P4** | DNS-over-QUIC overlay | 2h | Low | Feature |
| 24 | **P4** | Create `flake.nix` for hierarchical-errors repo | 1h | Low | External repos |
| 25 | **P4** | Enforce pre-commit hooks in CI | 2h | Medium | CI |

---

## g) Top #1 Question I Cannot Figure Out Myself 🤔

**Should `projects-management-automation` and `govalid` be added as flake inputs, or are they intentionally kept as `go install`-only tools?**

- PMA is a LarsArtmann repo with its own `flake.nix` but not wired into SystemNix
- `govalid` is a third-party tool (`sivchari/govalid`) not in nixpkgs
- Both currently live in `~/go/bin/` via `go install`
- Adding PMA as a flake input would make it declarative and version-pinned
- `govalid` would need a custom derivation in `pkgs/` or as an overlay

This is a user decision — it affects how much tooling is declaratively managed vs. ad-hoc.

---

## Project Statistics

| Metric | Value |
|--------|-------|
| `.nix` files | 110 |
| Service modules | 36 |
| Common program modules | 14 |
| Custom packages | 5 |
| Overlays | 14 (12 shared + 6 Linux, with some overlap) |
| Shared lib helpers | 7 |
| Scripts | 16 |
| Flake inputs | 30+ |
| Docs files | 350+ |
| AGENTS.md lines | 650+ |
| `flake.nix` lines | 612 |

---

## Git State

**Modified files (uncommitted):**
- `flake.lock` — branching-flow + go-structure-linter auto-updated
- `platforms/common/home-base.nix` — updated `~/go/bin` PATH comment
- `platforms/common/packages/base.nix` — added 8 packages (6 overlay + 2 nixpkgs)
- `AGENTS.md` — documented overlay ≠ installed, `~/go/bin` gotcha

**Stashed stale binaries (via `trash`):**
- 11 files removed from `~/go/bin/`: art-dupl, branching-flow, buildflow, go-auto-upgrade, golangci-lint-auto-configure, go-structure-linter, hierarchical-errors, library-policy, mr-sync, ginkgo, goimports, templ
