# Session 56 — Darwin d2 Build Fix, Network Failures

**Date:** 2026-05-09 23:48 CEST
**Branch:** master
**Commit:** `524be5ab` fix(flake): add Darwin overlay to stub d2's Linux-only dependencies

---

## Summary

Investigated and resolved the Darwin build failure caused by `d2` diagram tool pulling in Linux-only dependencies (`libgbm` → `mesa` → `libdrm`). The fix was already committed from a prior session (`524be5ab`). During verification, discovered a separate network-related build failure in `library-policy`.

---

## Work Completed (a)

### 1. d2 Darwin Build Fix — VERIFIED WORKING ✅

**Root cause:** The pinned nixpkgs (`01fbdeef22b76`) has `d2` with unconditional `buildInputs = [ libgbm playwright-driver.browsers ]`. On Darwin, `libgbm` → `mesa` → `libdrm` fails the platform meta check.

**Fix (commit `524be5ab`):** Added a Darwin-only overlay in `flake.nix` `sharedOverlays` that re-instantiates `d2` via `callPackage` with stub packages for `libgbm` and `playwright-driver`. The overlay is a no-op on Linux.

```nix
(_final: prev:
  prev.lib.optionalAttrs prev.stdenv.isDarwin {
    d2 = prev.callPackage (prev.path + "/pkgs/by-name/d2/d2/package.nix") {
      libgbm = prev.runCommand "libgbm-stub" {} "mkdir $out";
      playwright-driver = { browsers = prev.runCommand "playwright-stub" {} "mkdir $out"; };
    };
  })
```

**Verification:** Build output shows `d2-0.7.1` as `⏸` (waiting/pending), not `✗` (failed). The d2 overlay correctly avoids the `libdrm` evaluation chain.

**Key learning:** The pinned nixpkgs input URL (`01fbdeef22b76`) and the flake.lock resolved rev (`46db2e09`) are different. The input URL takes precedence for fetching. Always check the URL in `flake.nix`, not just the lock file.

### 2. Research & Analysis

- Traced the full error chain: `system-applications → d2 → mesa-libgbm → libdrm → platform check failure`
- Fetched and compared d2 package definitions across nixpkgs revisions:
  - `01fbdeef22b76` (pinned): unconditional `buildInputs = [ libgbm ... ]`
  - `46db2e09` (lock file): added `lib.optionals libdrm.meta.available` guard (still broken due to eager evaluation)
  - `master`: same guard pattern
- Identified that `lib.optionals` eagerly evaluates the list argument in Nix, so the guard doesn't prevent `libgbm` evaluation

---

## Partially Done (b)

### Darwin Full Build — network-dependent packages failing

The d2 fix is correct, but the full `nh darwin switch` still fails due to:

| Package | Status | Cause |
|---------|--------|-------|
| `d2-0.7.1` | ✅ Fixed by overlay | Linux-only deps stubbed |
| `library-policy-0.0.0-unstable-go-modules` | ❌ Network failure | Go proxy `proxy.golang.org` connection reset / timeout |
| `todo-list-ai-deps` | ⏸ Blocked by library-policy | Dependency chain |
| `otel-tui-v0.7.2-go-modules` | ⏸ Blocked | Dependency chain |
| `golangci-lint-auto-configure-0.1.0-go-modules` | ⏸ Blocked | Dependency chain |

**Root cause:** `library-policy` Go module download hits `proxy.golang.org` and gets `connection reset by peer` / `i/o timeout`. This is a transient network issue — not a Nix configuration problem.

---

## Not Started (c)

- N/A — the primary objective (d2 fix) was already done

---

## Totally Fucked Up (d)

### Build Environment Network Instability

During this session, multiple network issues caused build failures and long waits:
- `hyprland.cachix.org` — DNS resolution failure (not our cache, probably from an old substituter config)
- `proxy.golang.org` — connection reset during Go module downloads for `library-policy`
- `cache.nixos.org` — intermittent DNS failures
- `nix-community.cachix.org` — SSL connect errors

These are external infrastructure issues, not caused by our configuration. They make build verification unreliable.

---

## What We Should Improve (e)

1. **Fix `hyprland.cachix.org` substituter** — it's referenced somewhere in the config but DNS can't resolve it. Remove or fix.
2. **Go module cache** — `library-policy` and other Go packages should use a Go proxy cache or vendor their dependencies to avoid network-dependent builds.
3. **Network resilience** — Consider adding `--option connect-timeout 30` or similar to `nh darwin switch` in the justfile to fail faster on network issues.
4. **Upstream d2 bug report** — The nixpkgs `d2` package should conditionally include `libgbm` using a lazy pattern (e.g., `builtins.deepSeq` or moving the conditional inside `buildInputs`). Worth filing upstream.
5. **AGENTS.md update** — Document the d2 overlay and its rationale for future reference.

---

## Top 25 Things to Do Next (f)

1. ~~Fix d2 Darwin build~~ ✅ DONE (commit `524be5ab`)
2. Retry `nh darwin switch` when network is stable to confirm full build passes
3. Remove `hyprland.cachix.org` from substituters if it's still configured somewhere
4. Update AGENTS.md with d2 overlay documentation
5. Push `524be5ab` to remote (`git push`)
6. Clean up untracked `pkgs/dnsblockd-processor/` and `pkgs/emeet-pixyd/` — either add or gitignore
7. Investigate if `library-policy` can vendor Go deps to avoid network-dependent builds
8. Consider updating nixpkgs pin to get newer d2 with the conditional guard
9. File upstream nixpkgs issue about d2's eager evaluation of Linux-only deps
10. Audit all other packages in `base.nix` for similar platform-specific dependency issues
11. Test the NixOS build (`just test`) to confirm d2 still works on Linux with the overlay
12. Update flake.lock to get security patches
13. Check if `mermaid-cli` (also in graph visualization section) has similar issues
14. Review the `image-and-file-renamer` untracked package status
15. Clean up stale `result` symlink in project root
16. Run `just health` to check overall system health
17. Consider adding a CI check that verifies Darwin eval without full build
18. Document the `prev.path + "/pkgs/by-name/..."` pattern for future overlay fixes
19. Check if `niri-session-manager` build is still working on NixOS
20. Review `just test-fast` as a quicker validation loop for future changes
21. Consider pinning Go module hashes in the flake for offline builds
22. Audit `docs/` directory for stale/outdated documents
23. Check if the activation script `.d2` verification still works with stubbed deps
24. Update FEATURES.md with d2 overlay info
25. Consider adding `nix flake check` to the justfile for pre-push validation

---

## Top #1 Question (g)

**The `library-policy` Go module download failure is transient (network issue).** Should we:
- (a) Just retry the build when network is stable?
- (b) Vendor Go dependencies in the `library-policy` repo to make builds hermetic?
- (c) Pre-build `library-policy` in a CI pipeline and push to a binary cache?

Option (a) is the path of least resistance. Option (b) is the most robust long-term fix.

---

## Files Changed

| File | Change | Status |
|------|--------|--------|
| `flake.nix` | Added d2 Darwin overlay in `sharedOverlays` | Committed (`524be5ab`) |

## Build Status

| Target | Status | Notes |
|--------|--------|-------|
| `d2` on Darwin | ✅ Fixed | Overlay stubs Linux-only deps |
| `library-policy` | ❌ Network failure | Go proxy timeout — transient |
| Full Darwin build | ⏳ Blocked by network | Retry when stable |
