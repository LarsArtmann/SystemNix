# Status Report — Session 126: vendorHash Cascade Fix (nixpkgs 26.11 buildGoModule Migration)

**Date:** 2026-06-09 20:14 CEST
**Host:** evo-x2 (NixOS x86_64-linux, master)
**Branch:** master @ `c88319c8` (uncommitted: `overlays/shared.nix`)
**Scope:** Fix `buildflow-8df0d54-go-modules` hash mismatch → discovered systemic `follows` + `vendorHash` cascade across all Go packages

---

## Executive Summary

A single `buildflow` vendorHash mismatch revealed a systemic issue: SystemNix uses `inputs.foo.follows = "bar"` to pin shared Go dependency versions (cmdguard, go-finding, go-output, go-branded-id) across all Go project flakes. When upstream projects commit vendorHashes computed with their own (older) dep versions, the `follows` overrides change the transitive dep tree, causing vendorHash mismatches and inconsistent vendoring in SystemNix's build.

**Result:** All 12 Go packages now build cleanly. The fix required a new `mkTidyOverride` helper in `overlays/shared.nix` that runs `go mod tidy` in BOTH the go-modules FOD derivation and the main build derivation via `proxyVendor = true` + `passthru.overrideModAttrs`. Three packages needed this treatment; the rest needed simple vendorHash updates.

---

## A) FULLY DONE

### Go Package vendorHash Fixes (Primary Task)

| # | Package | Upstream Fix | SystemNix Overlay Fix | Verified |
|---|---------|-------------|----------------------|----------|
| 1 | **BuildFlow** | vendorHash updated (`fcf95dc`) | `{}` (no override) | ✅ Builds |
| 2 | **go-auto-upgrade** | vendorHash updated (`04a06b6`) | `{vendorHash = "sha256-RwGN...";}` | ✅ Builds |
| 3 | **projects-management-automation** | vendorHash updated (`9d4db17`) | `{}` | ✅ Builds |
| 4 | **library-policy** | vendorHash updated (`56648f1`) | `mkTidyOverride` — inconsistent vendoring | ✅ Builds |
| 5 | **golangci-lint-auto-configure** | vendorHash updated (`07e80a4`) | Custom override: `proxyVendor + templ generate + go mod tidy` | ✅ Builds |
| 6 | **mr-sync** | vendorHash updated (`e743803`) | `mkTidyOverride` — inconsistent vendoring | ✅ Builds |
| 7 | **hierarchical-errors** | No upstream change needed | `{vendorHash = "sha256-TSXI...";}` | ✅ Builds |
| 8 | **go-structure-linter** | No upstream change needed | `{vendorHash = "sha256-jLc2...";}` | ✅ Builds |
| 9 | **art-dupl** | No upstream change needed | `{vendorHash = "sha256-p8ml...";}` | ✅ Builds |
| 10 | **branching-flow** | No override needed | `{}` | ✅ Builds |
| 11 | **project-meta** | No override needed | `{}` | ✅ Builds |
| 12 | **todo-list-ai** | No override needed | `{}` | ✅ Builds |

### Infrastructure Created

| Artifact | Location | Purpose |
|----------|----------|---------|
| `mkTidyOverride` | `overlays/shared.nix:22-31` | Reusable helper for packages needing `proxyVendor + go mod tidy` in both derivations |
| Custom override for `golangci-lint-auto-configure` | `overlays/shared.nix:72-88` | Preserves original `templ generate` preBuild + appends `go mod tidy` |

### Validation

| Check | Result |
|-------|--------|
| `just test-fast` | ✅ All checks passed |
| Individual Go package builds (all 12) | ✅ All build successfully |
| Full NixOS toplevel build | ⚠️ Pre-existing `monitor365` Rust/WASM failure (unrelated) |
| All upstream repos pushed | ✅ 6 repos committed + pushed |

---

## B) PARTIALLY DONE

### monitor365 (Pre-existing, Unrelated)

- **Status:** `monitor365-ui` Trunk/WASM build fails: "error getting the canonical path to the build target HTML file"
- **Impact:** Blocks full `nixosConfigurations.evo-x2.config.system.build.toplevel`
- **Workaround:** Individual Go packages and all other services build fine
- **Not part of this session's scope** — tracked separately

### Upstream Repos with Dirty Working Trees

Several upstream repos have uncommitted `go.mod`/`go.sum`/`flake.lock` changes from local testing:

| Repo | Uncommitted Files | Risk |
|------|-------------------|------|
| library-policy | `flake.lock`, `go.mod`, `go.sum` | Low — Nix handles this |
| golangci-lint-auto-configure | `flake.lock`, `go.mod`, `go.sum` | Low |
| mr-sync | `flake.lock`, `go.mod`, `go.sum` | Low |
| art-dupl | `flake.lock`, `go.mod`, `go.sum` | Low |
| projects-management-automation | `go.mod`, `go.sum`, `go.work.sum`, `pkg/coreutils/go.mod`, `pkg/coreutils/go.sum` | Low |

These represent the local dep changes that `go mod tidy` produced. They should be committed upstream when those repos are next worked on.

---

## C) NOT STARTED

1. **Deploy the fix** — `just switch` to apply the new overlay to evo-x2
2. **Clean up upstream dirty working trees** — commit go.mod/go.sum changes in affected repos
3. **Update AGENTS.md** — document the `mkTidyOverride` pattern and `follows` vendorHash cascade gotcha
4. **Resolve monitor365 build failure** — Trunk WASM target path issue
5. **Run `just switch` on Darwin** — verify cross-platform eval still works

---

## D) TOTALLY FUCKED UP

### The `follows` + vendorHash Architecture Problem

This is the **deepest issue** and it's not fully resolved — it's *mitigated*:

**Root cause:** SystemNix uses `inputs.X.follows = "Y"` to ensure all Go projects use the same shared dep versions. This means:
- Project X's own `go.mod` says `go-finding v0.5.0`
- SystemNix's `follows` overrides it to `go-finding v0.6.0`
- The vendorHash in Project X's `flake.nix` was computed with v0.5.0
- SystemNix needs a DIFFERENT vendorHash for v0.6.0

**Why this keeps recurring:** Every time a shared dep (cmdguard, go-finding, go-output, go-branded-id) is updated, ALL consuming packages potentially need new vendorHashes. This is a whack-a-mole problem.

**Current mitigation:** `overlays/shared.nix` holds per-package vendorHash overrides. When the cascade hits, fix each one.

**What would actually fix this:** Options not yet explored:
1. **Derive vendorHash from `go.sum`** — compute it dynamically instead of hardcoding
2. **Use `fetchGoModules` with `goSum` file** — newer nixpkgs pattern
3. **Pin shared deps in each project's go.mod** — instead of using `follows` for deps
4. **Remove `follows` for Go deps** — let each project manage its own versions

### golangci-lint-auto-configure Override Fragility

The custom override for `golangci-lint-auto-configure` is fragile:
- Hardcodes `templ@v0.3.1020` version — will break when upstream updates templ
- Duplicates the original preBuild logic in `overrideModAttrs`
- If upstream changes `preBuild`, the overlay won't automatically adapt

---

## E) WHAT WE SHOULD IMPROVE

1. **Document `follows` vendorHash cascade in AGENTS.md** — This hit us again and will keep hitting us. Every AI session needs to know about this pattern.
2. **Create a `just fix-vendor-hashes` recipe** — Automate: `vendorHash=""`, build each Go package, extract `got:` hash, update overlay. This is pure mechanical work that we've now done manually 3+ times.
3. **Upstream go.mod/go.sum cleanup** — The 5 repos with dirty working trees should have their go.mod/go.sum changes committed so their own CI works with SystemNix's dep versions.
4. **Centralize vendorHash management** — Consider a single attrset mapping package names to vendorHashes, making batch updates trivial.
5. **Explore `fetchGoModules` or `go.sum`-based hashing** — Investigate whether nixpkgs 26.11 has a pattern that doesn't require hardcoded vendorHashes.
6. **Fix monitor365 build** — 40 service modules but this one doesn't build. Blocks full NixOS toplevel verification.

---

## F) Top 25 Things We Should Get Done Next

| # | Task | Impact | Effort | Priority |
|---|------|--------|--------|----------|
| 1 | **Deploy this fix** — `just switch` on evo-x2 | HIGH | 5min | P0 |
| 2 | **Commit + push SystemNix overlay changes** | HIGH | 1min | P0 |
| 3 | **Fix monitor365 Rust/WASM build** | HIGH | MED | P0 |
| 4 | **Update AGENTS.md** with `follows` vendorHash cascade docs + `mkTidyOverride` pattern | MED | 10min | P1 |
| 5 | **Create `just fix-vendor-hashes` automation recipe** | MED | 30min | P1 |
| 6 | **Commit dirty go.mod/go.sum in library-policy** | LOW | 2min | P2 |
| 7 | **Commit dirty go.mod/go.sum in golangci-lint-auto-configure** | LOW | 2min | P2 |
| 8 | **Commit dirty go.mod/go.sum in mr-sync** | LOW | 2min | P2 |
| 9 | **Commit dirty go.mod/go.sum in art-dupl** | LOW | 2min | P2 |
| 10 | **Commit dirty go.mod/go.sum in projects-management-automation** | LOW | 2min | P2 |
| 11 | **Verify Darwin eval still passes** after overlay changes | MED | 5min | P1 |
| 12 | **Investigate `fetchGoModules` or `go.sum`-based vendor hashing** | HIGH | 2hr | P1 |
| 13 | **SigNoz 0.127.1 deployment verification** — service health checks | MED | 10min | P1 |
| 14 | **Hermes agent v2026.6.5 deployment verification** — service health checks | MED | 10min | P1 |
| 15 | **Stale status report cleanup** — 140+ files in `docs/status/`, archive old ones | LOW | 15min | P3 |
| 16 | **Run `golangci-lint-auto-configure` on all Go repos** — ensure lint configs are current | MED | 20min | P2 |
| 17 | **Investigate `art-dupl` vendorHash — should it use `mkTidyOverride`?** | LOW | 10min | P3 |
| 18 | **BTRFS snapshot verification** — `just snapshot-verify` on evo-x2 | MED | 5min | P2 |
| 19 | **Stale LSP cleanup timer verification** — check it's running | LOW | 2min | P3 |
| 20 | **Disk usage check on evo-x2** — ensure /nix/store isn't growing unchecked | LOW | 2min | P3 |
| 21 | **Archive `docs/status/` pre-May-24 reports** — move old ones to `archive/` | LOW | 5min | P3 |
| 22 | **Centralize vendorHash overrides** into a single attrset for batch updates | MED | 20min | P2 |
| 23 | **Run `nix flake check` on Darwin** — verify cross-platform compatibility | MED | 10min | P2 |
| 24 | **Review SigNoz alert rules** — ensure critical paths are monitored | MED | 30min | P2 |
| 25 | **Clean up `overlays/default.nix`** — both `isFunction` branches do the same thing | LOW | 5min | P3 |

---

## G) Top #1 Question I Cannot Figure Out Myself

**Is the `follows` pattern for Go dependency overrides actually the right architecture?**

Every time a shared dep (cmdguard, go-finding, go-output, go-branded-id) gets a new version, the cascade breaks ALL consuming packages. We've now fixed this exact class of bug in sessions 63, 68, 94, 97, 107, 119, 125, and now 126. The `mkTidyOverride` helper reduces the pain but doesn't eliminate it.

The fundamental tension:
- `follows` ensures version consistency across the ecosystem (GOOD)
- `follows` creates vendorHash mismatches because each project's hash was computed with different versions (BAD)
- `follows` can change the Go module graph enough to cause "inconsistent vendoring" requiring `go mod tidy` (UGLY)

Should we:
- **(A)** Keep `follows` but automate vendorHash updates (mechanical fix)?
- **(B)** Remove `follows` for Go deps and let each project manage its own versions (semantic versioning trust)?
- **(C)** Investigate nixpkgs `fetchGoModules` or a `go.sum`-based approach that eliminates hardcoded hashes?
- **(D)** Something else entirely?

This is a strategic decision that affects the entire LarsArtmann Go ecosystem. I can implement any option but cannot decide which tradeoff is right.

---

## Technical Details: New `mkTidyOverride` Helper

```nix
# overlays/shared.nix — reusable pattern for packages needing go mod tidy
mkTidyOverride = vendorHash: old: {
  inherit vendorHash;
  proxyVendor = true;
  preBuild = tidyGoBuild;
  passthru =
    (old.passthru or {})
    // {
      overrideModAttrs = _: {preBuild = tidyGoBuild;};
    };
};
```

**How it works:**
1. `proxyVendor = true` — changes go-modules output from vendor-style to proxy cache format, enabling `go mod tidy` to resolve modules during build
2. `preBuild` in main derivation runs `go mod tidy` before compilation
3. `passthru.overrideModAttrs` propagates `preBuild` to the go-modules FOD derivation (both phases need tidy because `go mod tidy` changes what modules are needed)
4. `vendorHash` is computed with the tidy-adjusted module graph

**Why `passthru.overrideModAttrs` and not plain `overrideModAttrs`:** `buildGoModule` stores `overrideModAttrs` in `passthru`. When `overrideAttrs` is called with a plain attrset, `passthru` gets overwritten, losing the original `overrideModAttrs`. By setting it in `passthru` explicitly, we preserve it through the override chain.

---

## Session Timeline

| Time | Event |
|------|-------|
| ~12:00 | Session 125 ends — nixpkgs 26.11 buildGoModule migration complete |
| ~17:00 | SigNoz 0.117→0.127 + Hermes v2026.6.5 upgrades committed |
| ~19:00 | **This session starts** — BuildFlow `go-modules` hash mismatch detected |
| ~19:10 | Identified systemic `follows` + vendorHash cascade pattern |
| ~19:20 | BuildFlow, go-auto-upgrade, projects-management-automation fixed upstream + pushed |
| ~19:30 | library-policy, golangci-lint-auto-configure fixed upstream + pushed |
| ~19:40 | mr-sync fixed upstream + pushed |
| ~19:50 | SystemNix `overlays/shared.nix` — go-structure-linter, go-auto-upgrade vendorHash updated |
| ~20:00 | Created `mkTidyOverride` helper for mr-sync, library-policy |
| ~20:05 | Discovered golangci-lint-auto-configure needs `templ generate` before `go mod tidy` |
| ~20:10 | golangci-lint-auto-configure custom override with `templ generate + go mod tidy` |
| ~20:12 | **All 12 Go packages verified building** — session complete |
