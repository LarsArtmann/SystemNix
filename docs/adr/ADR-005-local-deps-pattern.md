# ADR-005: `_local_deps` Pattern for Private Go Repo Overlays

**Status:** Accepted
**Date:** 2026-05-18
**Deciders:** Lars Artmann
**Related:** ADR-003 (flake-parts service modules), go-structure-linter, branching-flow, mr-sync, projects-management-automation

---

## Context

All private Go repos in the `LarsArtmann` GitHub org are consumed as flake inputs in `SystemNix` via overlays. The Nix sandbox has no network access and no SSH keys, so `go mod download` cannot fetch private dependencies during `buildGoModule`'s vendor hash computation.

## Problem

When a Go repo depends on other private Go repos (e.g., `go-structure-linter` → `go-output` → `go-branded-id`), the standard nixpkgs `buildGoModule` pattern fails because:

1. `go mod tidy` needs network to resolve transitive deps (fails in sandbox)
2. `GOPROXY=off` + `GONOSUMCHECK=*` still can't fetch private URLs
3. `go mod vendor` fails because replaced deps aren't available
4. `buildGoModule` creates a vendor derivation that tries to download everything

## Decision

Use the **`_local_deps` pattern**: fetch private deps as flake inputs (`flake = false`), copy them into `_local_deps/` in a `preparedSrc` derivation, and append `replace` directives to `go.mod` so all private deps resolve locally.

## Pattern

### 1. Flake input definitions

```nix
inputs = {
  go-output = {
    url = "git+ssh://git@github.com/LarsArtmann/go-output?ref=master";
    flake = false;
  };
  go-branded-id = {
    url = "git+ssh://git@github.com/LarsArtmann/go-branded-id?ref=master";
    flake = false;
  };
};
```

### 2. preparedSrc derivation

```nix
preparedSrc = pkgs.stdenv.mkDerivation {
  pname = "my-app-prepared-source";
  version = "dev";
  src = srcFiltered; # builtins.path excluding flake.nix

  dontBuild = true;
  nativeBuildInputs = [ goPkg ];

  postPatch = ''
    mkdir -p _local_deps
    cp -r ${go-output} _local_deps/go-output
    cp -r ${go-branded-id} _local_deps/go-branded-id
    chmod -R u+w _local_deps

    # Add replace directives
    echo "" >> go.mod
    echo 'replace (' >> go.mod
    echo '  github.com/larsartmann/go-output => ./_local_deps/go-output' >> go.mod
    echo '  github.com/larsartmann/go-branded-id => ./_local_deps/go-branded-id' >> go.mod
    echo ')' >> go.mod
  '';

  installPhase = ''mkdir $out; cp -r . $out/'';
};
```

### 3. buildGoModule usage

```nix
buildGoModule {
  src = preparedSrc;
  vendorHash = "sha256-..."; # Set empty, build, extract got: hash
  overrideModAttrs = old: {
    preBuild = ''go mod tidy'';
  };
}
```

## Why `overrideModAttrs` with `go mod tidy`?

The go-modules derivation (vendor hash computation) has network access but the main build does not (sets `GOPROXY=off`). When we synthetically modify `go.mod` with `replace` directives, the vendor derivation's go-modules phase needs to reconcile:

- `go.mod` now has `replace` directives pointing to `_local_deps/`
- But the go-modules derivation copies the source BEFORE `postPatch` runs
- So it sees the ORIGINAL `go.mod` without `replace` directives
- `go mod tidy` in `overrideModAttrs` resolves this by tidying the original go.mod

Wait — actually the go-modules derivation DOES see the `postPatch`'d source because it derives from `modBuildPhase` which copies `src`. Let me verify...

Actually, `buildGoModule`'s `mod` phase uses a separate `proxyVendor` path. The key insight from Session 35 is: `overrideModAttrs` with `go mod tidy` is sometimes necessary when the preparedSrc changes cause `go.mod` to be inconsistent with `go.sum`. But for simple replace-only preparedSrc, it may not be needed.

We should prefer NOT using `overrideModAttrs` when possible (simpler), and only add it when builds fail with "go mod tidy needed".

## Transitive go.sum Merging

When a replaced dep has its own transitive deps, ALL of them must be in the consumer's `go.sum`. Example:

```
my-app → go-output (replaced)
go-output → go-branded-id (root package import)
my-app must have: go-branded-id in go.sum
```

**Fix:** After adding `replace` directives, run `go mod tidy` locally (outside Nix) and commit the updated `go.mod`/`go.sum`. The consumer's `go.sum` must include ALL transitive deps from ALL replaced packages.

## Go Sub-Module Tags

Go sub-modules (e.g., `go-output/testhelpers`) need published tags for `go mod tidy` to resolve them via GOPROXY. If a sub-module only exists via `replace` in its parent repo, downstream consumers can't fetch it.

**Fix:** Publish tags with the module path prefix:

```bash
git tag testhelpers/v0.0.0
git push origin testhelpers/v0.0.0
```

## Dependency Chain Visualization

```
Projects Management Automation (9 deps)
├── cmdguard
├── go-output (→ go-branded-id)
├── go-branded-id
├── go-composable-business-types
├── go-commit
├── go-filewatcher
├── project-discovery-sdk (→ go-composable-business-types)
├── project-meta (→ go-composable-business-types)
└── gogenfilter

go-structure-linter (4 deps)
├── go-output (→ go-branded-id)
├── go-branded-id
├── gogenfilter
└── go-composable-business-types

branching-flow (2 deps)
├── go-output (→ go-branded-id)
└── go-branded-id

mr-sync (3 deps)
├── go-output (→ go-branded-id)
├── go-branded-id
└── go-commit
```

## Consequences

### Positive

- ✅ Private Go repos build in Nix sandbox without SSH or network hacks
- ✅ No `GOPATH` pollution, no `go install` binaries
- ✅ All deps pinned via flake.lock (reproducible)
- ✅ Works with nixpkgs `buildGoModule` (no custom builder needed)

### Negative

- ⚠️ Changing a core dep (go-output) cascades to ALL consumers
- ⚠️ Cross-repo coordination required for breaking changes
- ⚠️ `vendorHash` becomes stale when upstream deps change
- ⚠️ Go sub-module tags must be published manually
- ⚠️ Transitive go.sum entries must be manually verified

## Completed: mkPreparedSource Helper

The pattern has been extracted into the shared [`go-nix-helpers`](https://github.com/LarsArtmann/go-nix-helpers) repo, consumed as a `flake = false` input by all Go repos. This eliminates copy-paste drift across 7+ repos. See `AGENTS.md: _local_deps` section for current usage.

## References

- Session 35: 6 upstream build failures fixed using this pattern
- Session 36: PMA build fixed (programminglanguage deleted upstream, SDK updated)
- AGENTS.md: `_local_deps` section
