# Session 73 — Overlay Extraction Refactor + Upstream Overlay Fix

**Date:** 2026-05-11 19:23
**Scope:** Overlay extraction into separate files, upstream golangci-lint-auto-configure overlay fix
**System:** evo-x2 (NixOS) — 80% root disk, 80% /data disk

---

## Executive Summary

Two significant changes: (1) All overlays extracted from `flake.nix` into a separate `overlays/` directory with clean `shared.nix` / `linux.nix` / `default.nix` structure, reducing `flake.nix` by 172 lines. (2) golangci-lint-auto-configure upstream flake fixed — `overlays.default` moved outside `eachDefaultSystem` so it resolves correctly (committed locally, needs push).

---

## a) FULLY DONE ✅

### Overlay Extraction (overlays/ directory)

| File | Contents |
|------|----------|
| `overlays/default.nix` | Entry point — imports shared.nix/linux.nix, defines disableTests/pythonTest, exposes `sharedOverlays`/`linuxOnlyOverlays` |
| `overlays/shared.nix` | 13 shared overlays (aw-watcher, todo-list-ai, jscpd, library-policy, buildflow, go-auto-upgrade, go-structure-linter, branching-flow, art-dupl, golangci-lint-auto-configure, mr-sync, hierarchical-errors, d2-darwin) |
| `overlays/linux.nix` | 6 Linux-only overlays (openaudible, dnsblockd, emeet-pixyd, monitor365, netwatch, file-and-image-renamer) |

**Impact:** `flake.nix` reduced from ~843 lines to ~671 lines (-172). Overlay definitions no longer inline in the main file.

### Upstream Fix (golangci-lint-auto-configure)

- Moved `overlays.default` outside `flake-utils.lib.eachDefaultSystem` using `// { overlays.default = ...; }` merge pattern
- Committed locally as `71db4bf` — needs push to GitHub before SystemNix can use `golangci-lint-auto-configure.overlays.default` directly

### Path Fixes

- `overlays/shared.nix` and `overlays/linux.nix` — `callPackage ./pkgs/...` → `callPackage ../pkgs/...` (relative path resolution from `overlays/` subdirectory)
- Added `nur` back to flake.nix outputs destructuring (used in specialArgs and module lists)

### Verification

- `just test-fast` passes on both `x86_64-linux` and `aarch64-darwin`
- All 23 packages evaluate correctly
- All 35 nixosModules evaluate correctly

---

## b) PARTIALLY DONE

### golangci-lint-auto-configure Bridge Overlay

The upstream fix is committed locally but not pushed. SystemNix still uses a bridge overlay (`golangciLintAutoConfigureOverlay`) that references `packages.${system}.default`. Once pushed and `just update` run, this can be replaced with `golangci-lint-auto-configure.overlays.default`.

### todo-list-ai Hash Patching

Unchanged — SystemNix patches upstream's stale bun hash.

---

## c) NOT STARTED

All items from session 72 wishlist remain. No new items added.

---

## d) TOTALLY FUCKED UP

**Nothing fucked up.** The overlay extraction had two issues that were caught and fixed:

1. `nur` removed from outputs destructuring but still used in specialArgs → added back
2. `callPackage ./pkgs/` paths resolved relative to `overlays/` instead of project root → fixed to `../pkgs/`

Both caught by `just test-fast` before commit.

---

## e) WHAT WE SHOULD IMPROVE

1. **Push golangci-lint-auto-configure fix** — the only remaining bridge overlay
2. **Push all upstream fixes** — file-and-image-renamer, monitor365, mr-sync, golangci-lint-auto-configure all have local-only commits
3. **Disk at 80%/80%** — `just clean` is overdue
4. **Consider extracting `overlays/default.nix` pattern** — the `sharedOverlays = [nur.overlays.default] ++ (import ./shared.nix inputs)` pattern is clean and could be documented as a convention

---

## f) Top #25 Next Steps

Same as session 72 — no new items. Priorities remain: push upstream fixes, `just clean`, CI workflows.

---

## g) Top #1 Question

**Should the `overlays/` extraction pattern be documented in AGENTS.md as the canonical way to organize overlays?**

The current pattern is:
- `overlays/default.nix` — imports + composes
- `overlays/shared.nix` — returns a list of overlays
- `overlays/linux.nix` — returns a list of overlays

This is clean but not documented. If it becomes the standard, AGENTS.md should explain it so future sessions don't re-inline overlays into flake.nix.

---

## System Health

| Metric | Value | Status |
|--------|-------|--------|
| Root disk (`/`) | 80% used (100 GB free) | ⚠️ Clean needed |
| Data disk (`/data`) | 80% used (206 GB free) | ⚠️ Watch |
| Go/Rust projects wired | 14/14 | ✅ |
| Go local packages in pkgs/ | 0 | ✅ Zero |
| Overlays in separate files | 3 (default, shared, linux) | ✅ Clean |
| SystemNix `test-fast` | Passes (both platforms) | ✅ |
| Uncommitted changes | 0 (after this commit) | ✅ |

---

_Arte in Aeternum_
