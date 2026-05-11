# Nix Flake Standardization Plan

**Date:** 2026-05-11
**Status:** Planning
**Scope:** Standardize Nix flakes across all 9 LarsArtmann Go tooling projects

---

## Pareto Breakdown

### The 1% that delivers 51% of the result
Fix the 3 broken builds: BuildFlow (fakeHash), PMA (vendorHash=null), go-auto-upgrade (local path: inputs).

### The 4% that delivers 64% of the result
Create a shared flake-parts template with standard env vars, checks, and sibling-dep handling (the art-dupl vendor swap pattern).

### The 20% that delivers 80% of the result
Apply the template to all 8 projects, add overlay outputs, wire into SystemNix.

---

## Phase 1: Fix Broken Builds (P0 — Critical)

| # | Task | Project | Impact | Effort | Est |
|---|------|---------|--------|--------|-----|
| 1 | Compute real vendorHash for BuildFlow (run nix build, capture hash) | BuildFlow | Critical | 5min |
| 2 | Add CGO_ENABLED=0 to BuildFlow build env | BuildFlow | Critical | 2min |
| 3 | Add preparedSrc for BuildFlow's 5 modules/* replace directives | BuildFlow | Critical | 10min |
| 4 | Verify BuildFlow nix build succeeds end-to-end | BuildFlow | Critical | 5min |
| 5 | Compute real vendorHash for PMA (replace null with actual hash) | PMA | Critical | 5min |
| 6 | Add CGO_ENABLED=0 to PMA build env | PMA | Critical | 2min |
| 7 | Replace strip-replaces hack with proper workspace module resolution in PMA | PMA | Critical | 10min |
| 8 | Verify PMA nix build succeeds end-to-end | PMA | Critical | 5min |
| 9 | Convert go-auto-upgrade path: inputs to SSH URLs (cmdguard, go-finding, go-output) | go-auto-upgrade | Critical | 5min |
| 10 | Verify go-auto-upgrade nix build succeeds | go-auto-upgrade | High | 3min |

**Phase 1 subtotal: 10 tasks, ~52min**

---

## Phase 2: Shared Template (P1 — Very High)

| # | Task | Project | Impact | Effort | Est |
|---|------|---------|--------|--------|-----|
| 11 | Create shared flake template: flake.nix skeleton with flake-parts | Template | Very High | 5min |
| 12 | Create nix/packages/default.nix template with mkGoPackage helper | Template | Very High | 8min |
| 13 | Create nix/checks/default.nix template (build+test+lint+vet+nix-fmt) | Template | Very High | 8min |
| 14 | Create nix/devshells/default.nix template with standard env vars | Template | Very High | 5min |
| 15 | Create nix/apps/default.nix template with standard apps | Template | High | 5min |
| 16 | Create sibling-dep helper function (art-dupl vendor swap pattern) | Template | Very High | 10min |
| 17 | Document template usage in README with copy-paste instructions | Template | High | 8min |

**Standard env vars every devShell must set:**
```nix
CGO_ENABLED = "0";
GOWORK = "off";
GOPRIVATE = "github.com/LarsArtmann";
GOTOOLCHAIN = "local";
```

**Standard checks every project must have:**
- build (buildGoModule)
- test (go test -race ./...)
- lint (golangci-lint run)
- nix-fmt (alejandra or nixfmt --check)

**Standard overlay output:**
```nix
flake.overlays.default = final: prev: {
  <project-name> = final.callPackage ./nix/packages/default.nix {};
};
```

**Phase 2 subtotal: 7 tasks, ~49min**

---

## Phase 3: Apply Template to Each Project (P2 — High)

### library-policy (already flake-parts — DRY cleanup only)

| # | Task | Impact | Effort | Est |
|---|------|--------|--------|-----|
| 18 | DRY up duplicated buildTags/version/src into shared let in nix/packages | Medium | 5min |
| 19 | Deduplicate packages.default and production preBuild/meta | Medium | 5min |
| 20 | Verify nix flake check still passes after DRY refactor | Medium | 5min |

### go-structure-linter (minimal — needs full upgrade)

| # | Task | Impact | Effort | Est |
|---|------|--------|--------|-----|
| 21 | Replace raw genAttrs flake with flake-parts structure, add src filtering | High | 10min |
| 22 | Add shellHook + standard env vars + apps output | High | 5min |
| 23 | Verify nix build + devShell works | High | 5min |

### branching-flow (functional — needs consistency)

| # | Task | Impact | Effort | Est |
|---|------|--------|--------|-----|
| 24 | Convert from flake-utils to flake-parts, fix platform list | High | 10min |
| 25 | Derive version from self.shortRev instead of hardcoded 0.0.1 | Low | 3min |
| 26 | Add formatter output + GOWORK=off env var | Medium | 3min |
| 27 | Verify nix build + devShell | High | 5min |

### golangci-lint-auto-configure (functional — needs consistency)

| # | Task | Impact | Effort | Est |
|---|------|--------|--------|-----|
| 28 | Convert from flake-utils to flake-parts with SSH input for go-finding | High | 10min |
| 29 | Add GOWORK=off + CGO_ENABLED=0 to build + devShell | Medium | 3min |
| 30 | Add proper checks (build+test+lint+nix-fmt) | Medium | 5min |
| 31 | Verify nix build + checks | High | 5min |

### art-dupl (polished — needs consistency)

| # | Task | Impact | Effort | Est |
|---|------|--------|--------|-----|
| 32 | Convert from raw genAttrs to flake-parts | Medium | 10min |
| 33 | Add formatter output + extra checks (lint, nix-fmt) | Medium | 5min |
| 34 | Verify nix build + checks + overlay still works | High | 5min |

### BuildFlow (after Phase 1 fixes — needs restructure)

| # | Task | Impact | Effort | Est |
|---|------|--------|--------|-----|
| 35 | Convert monolithic flake-utils flake to flake-parts modules | High | 10min |
| 36 | Add proper checks (build+test+lint+nix-fmt) | Medium | 5min |
| 37 | Verify nix build + checks after full restructure | High | 5min |

### PMA (after Phase 1 fixes — needs restructure)

| # | Task | Impact | Effort | Est |
|---|------|--------|--------|-----|
| 38 | Convert 441-line flake to flake-parts modules | High | 10min |
| 39 | Extract strip-replaces into proper sibling-dep helper | High | 8min |
| 40 | Verify nix build + checks after full restructure | High | 5min |

### go-auto-upgrade (after Phase 1 fixes — needs restructure)

| # | Task | Impact | Effort | Est |
|---|------|--------|--------|-----|
| 41 | Convert flake-utils to flake-parts with SSH inputs | High | 10min |
| 42 | Verify nix build + checks after restructure | High | 5min |

**Phase 3 subtotal: 25 tasks, ~137min**

---

## Phase 4: Fill the Gap — hierarchical-errors (P3 — High)

| # | Task | Impact | Effort | Est |
|---|------|--------|--------|-----|
| 43 | Create flake.nix with flake-parts (from existing proposal) | High | 10min |
| 44 | Create nix/packages, nix/checks, nix/devshells modules | High | 8min |
| 45 | Handle go-finding + go-filewatcher sibling deps with vendor swap | High | 8min |
| 46 | Add legacyerrors-lint as second package in flake | Medium | 5min |
| 47 | Create .envrc with use flake | Low | 2min |
| 48 | Add nix entries to .gitignore (result, .direnv/) | Low | 2min |
| 49 | Update AGENTS.md with nix commands and devShell instructions | Medium | 5min |
| 50 | Verify nix build + test + lint end-to-end | High | 5min |

**Phase 4 subtotal: 8 tasks, ~45min**

---

## Phase 5: Add Overlay Outputs (P4 — Medium)

| # | Task | Project | Impact | Effort | Est |
|---|------|---------|--------|--------|-----|
| 51 | Add overlays.default output | library-policy | Medium | 3min |
| 52 | Add overlays.default output | BuildFlow | Medium | 3min |
| 53 | Add overlays.default output | PMA | Medium | 3min |
| 54 | Add overlays.default output | hierarchical-errors | Medium | 3min |
| 55 | Add overlays.default output | golangci-lint-auto-configure | Medium | 3min |
| 56 | Add overlays.default output | go-structure-linter | Medium | 3min |
| 57 | Add overlays.default output | branching-flow | Medium | 3min |
| 58 | Add overlays.default output | go-auto-upgrade | Medium | 3min |

**Phase 5 subtotal: 8 tasks, ~24min**

---

## Phase 6: Wire into SystemNix (P5 — Medium)

| # | Task | Impact | Effort | Est |
|---|------|--------|--------|-----|
| 59 | Add BuildFlow flake input to flake.nix | High | 3min |
| 60 | Add BuildFlow overlay to sharedOverlays | High | 2min |
| 61 | Add branching-flow flake input + overlay | Medium | 3min |
| 62 | Add hierarchical-errors flake input + overlay | Medium | 3min |
| 63 | Add go-structure-linter flake input + overlay | Medium | 3min |
| 64 | Add go-auto-upgrade flake input + overlay | Medium | 3min |
| 65 | Add art-dupl flake input + overlay | Medium | 3min |
| 66 | Add desired tools to platforms/common/packages/base.nix | Medium | 5min |
| 67 | Run just test-fast to verify SystemNix evaluates | High | 5min |

**Phase 6 subtotal: 9 tasks, ~30min**

---

## Summary

| Phase | Priority | Tasks | Est Time | What |
|-------|----------|-------|----------|------|
| 1 | P0 Critical | 10 | 52min | Fix 3 broken builds |
| 2 | P1 Very High | 7 | 49min | Create shared flake-parts template |
| 3 | P2 High | 25 | 137min | Apply template to all 8 projects |
| 4 | P3 High | 8 | 45min | Implement hierarchical-errors flake |
| 5 | P4 Medium | 8 | 24min | Add overlay outputs to all projects |
| 6 | P5 Medium | 9 | 30min | Wire into SystemNix |
| **Total** | | **67** | **~337min** | |

---

## Execution Graph (D2)

```d2
phase_1: Fix Broken Builds {
  shape: rectangle
  style.fill: "#ff6b6b"

  buildflow: BuildFlow {
    bf_hash: Compute vendorHash
    bf_cgo: Add CGO_ENABLED=0
    bf_modules: Handle modules/* replaces
    bf_verify: Verify build
    bf_hash -> bf_cgo -> bf_modules -> bf_verify
  }

  pma: PMA {
    pma_hash: Compute vendorHash
    pma_cgo: Add CGO_ENABLED=0
    pma_replaces: Fix workspace resolution
    pma_verify: Verify build
    pma_hash -> pma_cgo -> pma_replaces -> pma_verify
  }

  gou: go-auto-upgrade {
    gou_ssh: Convert path: to SSH URLs
    gou_verify: Verify build
    gou_ssh -> gou_verify
  }
}

phase_2: Shared Template {
  shape: rectangle
  style.fill: "#ffd93d"

  tpl_skeleton: flake.nix skeleton
  tpl_packages: nix/packages template
  tpl_checks: nix/checks template
  tpl_devshell: nix/devshells template
  tpl_apps: nix/apps template
  tpl_sibling: Sibling-dep helper
  tpl_docs: README documentation

  tpl_skeleton -> tpl_packages -> tpl_checks -> tpl_devshell -> tpl_apps -> tpl_sibling -> tpl_docs
}

phase_3: Apply Template {
  shape: rectangle
  style.fill: "#6bcb77"

  lp: library-policy { style.fill: "#a8e6cf"; lp_dry: DRY cleanup; lp_verify: Verify }
  gsl: go-structure-linter { style.fill: "#a8e6cf"; gsl_restructure: Restructure; gsl_shell: Add shell; gsl_verify: Verify }
  bf2: branching-flow { style.fill: "#a8e6cf"; bf2_restructure: Restructure; bf2_version: Fix version; bf2_fmt: Add formatter; bf2_verify: Verify }
  glac: golangci-lint-auto-configure { style.fill: "#a8e6cf"; glac_restructure: Restructure; glac_env: Add env vars; glac_checks: Add checks; glac_verify: Verify }
  ad: art-dupl { style.fill: "#a8e6cf"; ad_restructure: Restructure; ad_checks: Add checks; ad_verify: Verify }
  bf3: BuildFlow { style.fill: "#a8e6cf"; bf3_restructure: Restructure; bf3_checks: Add checks; bf3_verify: Verify }
  pma2: PMA { style.fill: "#a8e6cf"; pma2_restructure: Restructure; pma2_helper: Sibling dep helper; pma2_verify: Verify }
  gou2: go-auto-upgrade { style.fill: "#a8e6cf"; gou2_restructure: Restructure; gou2_verify: Verify }
}

phase_4: hierarchical-errors {
  shape: rectangle
  style.fill: "#4d96ff"

  he_flake: Create flake.nix
  he_modules: Create nix/ modules
  he_deps: Handle sibling deps
  he_legacy: Add legacyerrors-lint
  he_envrc: Create .envrc
  he_gitignore: Update .gitignore
  he_agents: Update AGENTS.md
  he_verify: Verify build
  he_flake -> he_modules -> he_deps -> he_legacy -> he_verify
  he_verify -> he_envrc -> he_gitignore -> he_agents
}

phase_5: Overlay Outputs {
  shape: rectangle
  style.fill: "#9b59b6"

  ov_lp: library-policy overlay
  ov_bf: BuildFlow overlay
  ov_pma: PMA overlay
  ov_he: hierarchical-errors overlay
  ov_glac: golangci-lint-auto-configure overlay
  ov_gsl: go-structure-linter overlay
  ov_bf2: branching-flow overlay
  ov_gou: go-auto-upgrade overlay
}

phase_6: SystemNix Integration {
  shape: rectangle
  style.fill: "#1abc9c"

  sn_bf: Add BuildFlow input+overlay
  sn_bf2: Add branching-flow input+overlay
  sn_he: Add hierarchical-errors input+overlay
  sn_gsl: Add go-structure-linter input+overlay
  sn_gou: Add go-auto-upgrade input+overlay
  sn_ad: Add art-dupl input+overlay
  sn_base: Add to base.nix
  sn_test: Run just test-fast
}

# Dependencies
phase_1 -> phase_2 -> phase_3
phase_2 -> phase_4
phase_3 -> phase_5 -> phase_6
phase_4 -> phase_5
```

---

## Risks

| Risk | Mitigation |
|------|-----------|
| Go 1.26 not in nixpkgs stable | Use `go_1_26` from nixos-unstable (already pinned in SystemNix) |
| vendorHash breaks on go.mod changes | Document `nix run .#update-vendor-hash` workflow |
| Sibling dep vendor swap is subtle | art-dupl already proves the pattern works; template abstracts it |
| 67 tasks across 9 repos | Phase-gated execution; each phase is independently valuable |
| PMA workspace resolution is complex | May need to vendor dependencies instead of proxying |

---

_This plan covers ALL 67 tasks across 9 repos. Execute phase by phase. Each task ≤12min._
