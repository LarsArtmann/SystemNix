# SystemNix Flake Reliability Improvements

**Created:** 2026-05-27 | **Context:** Session 98 — `todo-list-ai` hash mismatch cascaded into full NixOS build failure during `just switch`

---

## Tier 1: Prevent the failure we just hit

### 1. Pre-switch hash validation

**Problem:** `just switch` runs `nh os switch` directly with no pre-check. A single stale `todoListAiFixedHash` in `overlays/shared.nix` cascaded into a full NixOS build failure (~3 min wasted).

**Fix:** Add a hash-check gate to `just switch` before the `nh os switch` / `darwin-rebuild` step. If any package has a stale hash, abort *before* the build starts. Reuse existing `just hash-check`.

**Impact:** Prevents the most common class of build failure (stale vendorHash / npmDepsHash).

---

### 2. Replace manual FOD hash in `todo-list-ai` overlay

**Problem:** `overlays/shared.nix` manually manages a fixed-output derivation for bun `node_modules` with a hardcoded `todoListAiFixedHash` (line 44). Every upstream `bun install` dependency change silently breaks SystemNix.

**Fix:** Two options:
- **A (preferred):** Have the upstream `todo-list-ai` repo's own flake handle bun deps internally. SystemNix uses `mkPackageOverlay` like all other packages — hash managed upstream, not here.
- **B (quick):** Keep the current pattern but add `todo-list-ai` to `just hash-check` (it may already be there) and ensure the error message is clear.

**Current state:** `todo-list-ai` is already in the `hash-check` package list in the justfile.

---

### 3. Remove hardcoded `vendorHash` overrides from `linux.nix`

**Problem:** `overlays/linux.nix` passes `vendorHash` overrides to `mkPackageOverlay` for `dnsblockd` and `file-and-image-renamer`. The vendor hash is managed *in SystemNix* rather than *in the upstream repo's flake*. Any upstream Go dep change silently breaks.

**Fix:** Remove the `vendorHash` overrides from `linux.nix`. Ensure upstream repos manage their own hashes in their own `flake.nix`. This is already documented as an anti-pattern in AGENTS.md for `file-and-image-renamer`.

**Affected packages:**
- `dnsblockd` — `vendorHash = "sha256-FFcULtnmNhIJr392vRYGqZ+lvW300HWvzQoEJZj8pWw="`
- `file-and-image-renamer` — `vendorHash = "sha256-of+ynTDQ5ahN+6vJFM9mrNNE3je4bCnLaF3O2j0Zo88="`

---

## Tier 2: CI / pre-merge guards

### 4. Add CI — zero pre-merge protection exists

**Problem:** No `.github/workflows`, no `.pre-commit-config.yaml`, no CI at all. Any push to master triggers nothing. `just test-fast` / `just hash-check` / `just test-upstream-builds` exist but rely on manual execution.

**Fix:** Add:
- `.pre-commit-config.yaml` with `nix flake check --no-build` (runs `just test-fast` equivalent)
- GitHub Actions workflow that runs `just test-fast` + `just hash-check` on PRs/pushes
- Note: Private Go repos (`git+ssh://`) won't be buildable in GitHub Actions without SSH keys. CI should at minimum run syntax checks + Nix linting (statix, deadnix).

---

### 5. Add intermediate `just test-hashes` command

**Problem:** `just test-fast` only checks syntax — not buildability. `just test` does a full build but is slow. The gap between them is where hash mismatches live.

**Fix:** Add `just test-hashes` that only verifies overlay package hashes (what `hash-check` does). Fast enough for pre-commit, catches the most common failure mode. Could be used as a pre-switch gate.

---

## Tier 3: Structural hardening

### 6. Auto-discover service modules

**Problem:** `serviceModules` list in `flake.nix` (35 entries) must be manually kept in sync with actual file paths and module names. Adding a `.nix` file but forgetting to add it to the list means it silently doesn't load.

**Fix:** Auto-discover service modules from the filesystem. Each module file declares its own name internally (via `flake.nix` module option), and the flake globs `modules/nixos/services/*.nix` and imports them all. Eliminates the manual sync point.

**Risk:** Requires careful handling to avoid importing files that aren't service modules (e.g., a `default.nix` that's already a directory index).

---

### 7. Port registry collision detection

**Problem:** `lib/ports.nix` has no collision detection. If two services get the same port, nothing catches it until runtime.

**Fix:** Add an assertion:

```nix
assert lib.assertMsg
  (lib.length (lib.unique (lib.attrValues ports)) == lib.length (lib.attrValues ports))
  "Port collision detected in lib/ports.nix";
```

**Impact:** Catches a class of bugs that are otherwise only visible at runtime when two services fight for the same port.

---

### 8. Darwin overlay isolation

**Problem:** `shared.nix` imports all overlays including ones that pull in Linux-only packages. Currently handled by `lib.optionals (lib.hasSuffix "-linux" system)` in `perSystem`, but the `d2DarwinOverlay` pattern (stub out missing deps) is fragile.

**Fix:** Low priority — current approach works. Could be improved by having `mkPackageOverlay` accept a `platforms` parameter and auto-skip on non-matching systems.

---

## Priority Matrix

| # | Improvement | Effort | Impact | Priority |
|---|-------------|--------|--------|----------|
| 1 | Hash-check gate on `just switch` | Low | High | P0 |
| 2 | Move todo-list-ai FOD upstream | Medium | High | P0 |
| 5 | `just test-hashes` command | Low | Medium | P1 |
| 7 | Port collision assertion | Low | Medium | P1 |
| 3 | Remove linux.nix vendorHash overrides | Medium | Medium | P1 |
| 4 | Pre-commit + CI | Medium | High | P2 |
| 6 | Auto-discover service modules | Medium | Medium | P2 |
| 8 | Darwin overlay isolation | Low | Low | P3 |
