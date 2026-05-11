# Nix Flake Audit: LarsArtmann Go Tooling Ecosystem

**Date:** 2026-05-11
**Scope:** Nix flake quality audit across 9 Go projects

---

## Project Status

| Project | Has flake.nix | Framework | Maturity |
|---------|:---:|---|---|
| **library-policy** | ✅ | flake-parts + treefmt-nix + git-hooks-nix | Most mature — modular, 7 checks, 10 apps |
| **BuildFlow** | ✅ | flake-utils | Broken — fakeHash, no local module handling |
| **projects-management-automation** | ✅ | flake-utils (441 lines) | Medium — 25 apps, but vendorHash=null, strips replaces |
| **hierarchical-errors** | ❌ | — | Proposal only — `docs/proposals/MIGRATION_TO_NIX_FLAKES_PROPOSAL.md` |
| **golangci-lint-auto-configure** | ✅ | flake-utils | Functional — SSH flake input for go-finding |
| **go-structure-linter** | ✅ | Raw `genAttrs` | Minimal — no apps, no shellHook, unclean src |
| **branching-flow** | ✅ | flake-utils | Functional — templ build, GOPRIVATE set |
| **go-auto-upgrade** | ✅ | flake-utils | Most checks (build/test/lint/nix-fmt) but local path inputs |
| **art-dupl** | ✅ | Raw `genAttrs` | Most polished — overlay, vendor swap, pinned dep |

---

## Framework Inconsistency

Three different approaches are used. No two projects share the same framework choice consistently.

| Framework | Projects | Pros | Cons |
|---|---|---|---|
| **flake-parts** | library-policy | Modular, composable, shared config, perSystem | More complex, requires understanding flake-parts |
| **flake-utils** | BuildFlow, PMA, golangci-lint-auto-configure, branching-flow, go-auto-upgrade | Simple, `eachDefaultSystem` | Flat structure, gets unwieldy past ~100 lines |
| **Raw `genAttrs`** | go-structure-linter, art-dupl | No extra dependency | Verbose system list, no auto-discovery |

**Recommendation:** Standardize on **flake-parts**. library-policy already demonstrates the best pattern — modular files under `nix/`, shared `buildTags`/`version`, treefmt integration, pre-commit hooks. Every other project would benefit from this structure.

---

## Sibling Dependency Handling

Three completely different strategies for injecting local sibling libraries:

### Strategy 1: postPatch go.mod replace (golangci-lint-auto-configure)

```nix
postPatch = ''
  echo 'replace github.com/larsartmann/go-finding => ${goFindingSrc}' >> go.mod
'';
```

- **Pros:** Simple, works in sandbox
- **Cons:** Appends to go.mod (dirty), only handles one dep easily

### Strategy 2: preparedSrc + substituteInPlace (go-auto-upgrade)

```nix
preparedSrc = pkgs.runCommand "prepared-src" {} ''
  cp -r ${src} $out
  chmod -R u+w $out
  mkdir -p $out/_local_deps/{cmdguard,go-finding,go-output}
  cp -r ${cmdguardSrc} $out/_local_deps/cmdguard
  cp -r ${goFindingSrc} $out/_local_deps/go-finding
  cp -r ${goOutputSrc} $out/_local_deps/go-output
  substituteInPlace $out/go.mod --replace "path:/home/..." "path:$out/_local_deps/..."
'';
```

- **Pros:** Handles multiple deps, rewrites all paths
- **Cons:** Uses non-portable `path:` inputs (only works on Lars's machine), complex

### Strategy 3: overrideModAttrs + vendor swap (art-dupl)

```nix
overrideModAttrs (_: {
  preBuild = ''
    # Create dummy module for vendor phase (no SSH needed)
    mkdir -p vendor/gogenfilter
    echo 'module gogenfilter' > vendor/gogenfilter/go.mod
  '';
})
# Then in preBuild of main derivation:
# cp -r ${gogenfilterSrc} vendor/gogenfilter
```

- **Pros:** Most sandbox-friendly, handles private deps correctly
- **Cons:** Two-phase build is subtle, requires understanding of goModules lifecycle

### Strategy 4: Strip replaces (PMA)

```nix
stripReplaceDirectives = ''
  sed -i -E '/^replace\s+.*=>\s+\/(home|tmp|var|usr)\//d' go.mod
'';
```

- **Pros:** Quick fix
- **Cons:** Silently drops replaces instead of resolving them, fragile regex

**Recommendation:** Standardize on **Strategy 3** (art-dupl's approach) for all projects with private sibling deps. It's the most sandbox-friendly and doesn't require local path inputs. For projects with only public deps, Strategy 1 is acceptable.

---

## Cross-Cutting Issues

### Critical

| Issue | Projects | Impact |
|---|---|---|
| **`vendorHash = fakeHash`** | BuildFlow | Build always fails — completely broken |
| **`vendorHash = null`** | PMA | Non-reproducible builds |
| **No flake.nix** | hierarchical-errors | No nix support at all |
| **Local `path:` inputs** | go-auto-upgrade | Only works on one machine |

### High

| Issue | Projects | Impact |
|---|---|---|
| **Strips `replace` directives** | PMA | Silently drops workspace deps |
| **No `src` filtering** | go-structure-linter | Includes `.git` in build source |
| **`go_1_26` doesn't exist in nixpkgs** | BuildFlow, PMA | May fail or silently downgrade |
| **No go-finding integration** | library-policy | Can't produce SARIF output |
| **No CGO_ENABLED=0** | go-structure-linter, golangci-lint-auto-configure | May fail on systems without gcc |

### Medium

| Issue | Projects | Impact |
|---|---|---|
| **Duplicated constants** (buildTags, version, src) | library-policy (nix/) | DRY violation across 4 nix files |
| **No GOWORK=off** | golangci-lint-auto-configure (devShell), go-structure-linter | May break if go.work exists |
| **No GOPRIVATE/GOINSECURE** | All except branching-flow | May fail to fetch private deps in devShell |
| **Hardcoded versions** | go-structure-linter (0.3.0), branching-flow (0.0.1) | Not derived from git |
| **Redundant platform lists** | branching-flow (`unix ++ darwin`) | darwin is subset of unix |
| **`import nixpkgs { inherit system; }`** | golangci-lint-auto-configure, branching-flow | Unnecessary evaluation overhead |

---

## Feature Matrix

| Feature | library-policy | BuildFlow | PMA | hier-errors | golangci-auto | go-struct | branch-flow | go-auto-up | art-dupl |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **Builds with nix** | ✅ | ❌ | ⚠️ | — | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Modular nix files** | ✅ | ❌ | ❌ | — | ❌ | ❌ | ❌ | ❌ | ❌ |
| **treefmt** | ✅ | ❌ | ❌ | — | ❌ | ❌ | ❌ | ❌ | ❌ |
| **pre-commit hooks** | ✅ | ❌ | ❌ | — | ❌ | ❌ | ❌ | ❌ | ❌ |
| **Multiple packages** | ✅ (debug+prod) | ❌ | ❌ | — | ❌ | ❌ | ❌ | ❌ | ❌ |
| **7+ checks** | ✅ | ❌ | 3 | — | 1 | 1 | 1 | 4 | 2 |
| **Apps** | 10 | 0 | 25 | — | 1 | 0 | 2 | 1 | 2 |
| **Overlay output** | ❌ | ❌ | ❌ | — | ❌ | ❌ | ❌ | ❌ | ✅ |
| **Portable (no local paths)** | ✅ | ❌ | ⚠️ | — | ✅ | ✅ | ✅ | ❌ | ✅ |
| **Sibling dep handling** | N/A | ❌ | ⚠️ strip | — | ✅ postPatch | N/A | N/A | ⚠️ local paths | ✅ vendor swap |
| **Dev shell richness** | Full | Full | Full | — | Full | Minimal | Medium | Full | Medium |
| **CGO_ENABLED=0** | ✅ | ❌ | ✅ | — | ❌ | ❌ | ❌ | ❌ | ✅ |

---

## Recommendations

### Immediate (fix broken builds)

1. **BuildFlow**: Replace `fakeHash` with real `vendorHash`, add `CGO_ENABLED=0`, handle `modules/*` replace directives
2. **go-auto-upgrade**: Convert local `path:` inputs to SSH URLs like art-dupl uses
3. **PMA**: Replace `vendorHash = null` with real hash, properly resolve workspace replaces instead of stripping

### Short-term (consistency)

4. **Adopt flake-parts** across all projects following library-policy's modular structure
5. **Extract shared nix patterns** into a shared library or template (Go version, buildTags, src filtering, env vars)
6. **Standardize env vars**: All devShells should set `CGO_ENABLED=0`, `GOWORK=off`, `GOPRIVATE=github.com/LarsArtmann`, `GOTOOLCHAIN=local`
7. **Standardize version derivation**: Use `self.shortRev or "dirty"` consistently

### Medium-term (quality)

8. **hierarchical-errors**: Implement the proposed flake.nix (proposal is thorough)
9. **library-policy**: Integrate go-finding for SARIF output
10. **All projects**: Add `overlay` output (only art-dupl has one) for SystemNix consumption
11. **All projects**: Add proper nix checks (at minimum: build + test + lint + nix-fmt)

---

## SystemNix Integration Status

| Project | SystemNix flake input | Overlay | Global install |
|---|---|---|---|
| library-policy | ✅ `git+ssh://...master` | ✅ `libraryPolicyOverlay` | ✅ `base.nix` |
| golangci-lint-auto-configure | ✅ `git+ssh://...master` (src) | ✅ `sharedOverlays` | ✅ `base.nix` |
| go-finding | ✅ `git+ssh://...master` (src) | Via auto-configure | Indirect |
| cmdguard | ✅ (via go-output-submodules) | Via auto-configure | Indirect |
| go-output | ✅ (via go-output-submodules) | Via auto-configure | Indirect |
| BuildFlow | ❌ | ❌ | ❌ |
| PMA | ❌ | ❌ | ❌ |
| hierarchical-errors | ❌ | ❌ | ❌ |
| branching-flow | ❌ | ❌ | ❌ |
| go-structure-linter | ❌ | ❌ | ❌ |
| go-auto-upgrade | ❌ | ❌ | ❌ |
| art-dupl | ❌ | ❌ | ❌ |

Only library-policy and golangci-lint-auto-configure are wired into SystemNix. The remaining 6 tools are either not yet needed on the NixOS machine or would need new flake inputs + overlays to be added.
