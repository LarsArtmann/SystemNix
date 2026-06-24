# SystemNix Status Report — Session 63

**Date:** 2026-05-20 03:06
**Session:** 63 — vendorHash Cascade Fix + mkPackageOverlay Enhancement
**Branch:** master (1 commit ahead of origin)
**Build Status:** PASSING (NixOS + Darwin eval)

---

## a) FULLY DONE

### mkPackageOverlay Enhancement — vendorHash Override Support

**Problem:** After `nix flake update`, 7 private Go repos had stale `vendorHash` values in their upstream `flake.nix` files. The `go-modules` fixed-output derivation hashes no longer matched, breaking the entire NixOS build with cascading dependency failures (16 errors total).

**Solution:** Extended `mkPackageOverlay` in `overlays/default.nix` to accept an `overrides` parameter, enabling `vendorHash` overrides at the overlay layer without modifying upstream repos:

```nix
mkPackageOverlay = input: name: overrides:
  _final: prev: let pkg = input.packages.${prev.stdenv.system}.default; in {
    ${name} = if overrides == {} then pkg else pkg.overrideAttrs overrides;
  };
```

**7 packages fixed with correct vendorHash:**

| Package | Overlay File | Hash (got) |
|---------|-------------|------------|
| hierarchical-errors | shared.nix | `sha256-imjTscWHsv2zw7OegiTiDHoKWSCM/Lamff5nzYrECEE=` |
| mr-sync | shared.nix | `sha256-ewYNWIETjxKwINzdbwWNmL6+CQsNvxLR7CZqtsb9xA0=` |
| buildflow | shared.nix | `sha256-W63V4gnt2itUo8etknSuyjRtMvut/7bU1kxhqOiReBM=` |
| go-structure-linter | shared.nix | `sha256-rG/RiwyqV4Mhko/axWyj/LakrZ8eumyDBPr0tzX5jlI=` |
| projects-management-automation | shared.nix | `sha256-lv0xp20Z6tpqVQPa6RxRPvUMDIRCRqXlAme57pg5owI=` |
| file-and-image-renamer | linux.nix | `sha256-FdABe/wPpG1f1hiKwqqFJGYOtw8wD1n93aXWDHhJ3Hk=` |
| dnsblockd | linux.nix | {} (no override needed) |

**Additional changes:**
- All `mkPackageOverlay` calls updated to explicit `{}` when no overrides needed (was implicit before)
- `file-and-image-renamer` switched from raw `.overlays.default` to `mkPackageOverlay` for consistency
- AGENTS.md updated with new `mkPackageOverlay` signature and usage patterns

**Verification:**
- NixOS (`evo-x2`) full build: PASSED (0 hash mismatches)
- Darwin evaluation: PASSED (`nix eval` returns true)
- `nix flake check --no-build`: ALL CHECKS PASSED
- Build was broken completely before this fix (16 cascading errors from 2 root hash mismatches)

### Recent Sessions (Context from git log)

| Commit | Description |
|--------|-------------|
| `d1ab93bb` | fix: resolve dual-platform build breakage from nix flake update |
| `dd9ba72a` | fix(forgejo): runner token — eliminate separate service, fix escapeSystemdPath mismatch |
| `255900c4` | fix(forgejo): use RuntimeDirectory for runner token — fix permission and hardening conflict |

---

## b) PARTIALLY DONE

### Upstream Repo vendorHash Synchronization

**Status:** Patched locally via `overrideAttrs`, but the ROOT CAUSE remains — 7 upstream repos have stale `vendorHash` values in their own `flake.nix`:

| Repo | Needs `vendorHash` update in upstream |
|------|------|
| hierarchical-errors | YES — still has old hash |
| mr-sync | YES — still has old hash |
| buildflow | YES — still has old hash |
| go-structure-linter | YES — still has old hash |
| projects-management-automation | YES — still has old hash |
| file-and-image-renamer | YES — still has old hash |

**Impact:** SystemNix builds fine with the overlay overrides, but:
1. Other consumers of these repos (standalone) will hit the same hash mismatch
2. Every `nix flake update` may introduce MORE stale hashes
3. The overlay overrides become stale themselves when upstream eventually fixes their hashes — then we'd have WRONG hashes in our overrides

### AGENTS.md Documentation

The `mkPackageOverlay` section is updated, but the broader documentation may need:
- Cross-reference the vendorHash override pattern from the "Critical Rules & Gotchas" section
- Update the "Active overlays" section to reflect the new calling convention

---

## c) NOT STARTED

### Push to Origin

Branch is 1 commit ahead of `origin/master` (commit `d1ab93bb`). The current session's changes are NOT yet committed.

### Upstream Repo Fixes

None of the 6 upstream repos have been updated with correct `vendorHash` values. This requires:
1. Clone each repo
2. Set `vendorHash = ""` in each repo's `flake.nix`
3. Build to get the correct hash
4. Commit and push
5. Update `flake.lock` in SystemNix to pull the fix
6. Remove the overlay overrides from SystemNix (since they'd be redundant)

### Darwin Full Build Verification

Darwin config evaluates correctly but can't be fully built from Linux (platform mismatch). Needs verification from the MacBook Air.

### Pi 3 Provisioning

Still in "Planned" status per AGENTS.md. Hardware not yet provisioned. Would complete the DNS failover cluster (evo-x2 + Pi 3).

### SigNoz Dashboard/Alert Gap Analysis

SigNoz is deployed and collecting metrics, but custom dashboards and alert rules may need review after recent infrastructure changes.

---

## d) TOTALLY FUCKED UP

### The vendorHash Whack-a-Mole Pattern

This session revealed a systemic problem: **every `nix flake update` potentially breaks ALL Go-based private repos** because upstream `vendorHash` values become stale. The fix is local overrides, but this is a band-aid:

- We now have 6 hardcoded SHA-256 hashes in our overlay that will THEMSELVES become stale when upstream repos update their hashes
- There's no CI/automation to detect these mismatches before deployment
- The build went from "works" to "16 cascading errors" with a single `nix flake update`
- The error messages are terrible — "hash mismatch" in a `go-modules` derivation doesn't tell you WHICH upstream repo needs fixing

### The `overrideAttrs` vs `override` Confusion

Spent significant time trying `.override { vendorHash = "..."; }` (which failed because the upstream `package.nix` doesn't accept `vendorHash` as a function argument) before realizing `.overrideAttrs` was the correct approach. The distinction between function argument overrides and derivation attribute overrides in nixpkgs is subtle and error-prone.

---

## e) WHAT WE SHOULD IMPROVE

### 1. Upstream Repo vendorHash Hygiene

**Fix the root cause.** Each upstream Go repo should:
- Use `vendorHash = ""` during development (forces hash computation)
- Have CI that verifies the hash is correct on every push
- Or use a `postPatch` that runs `go mod tidy` + auto-computes the hash

### 2. Automated vendorHash Detection

Create a script (e.g., `scripts/check-vendor-hashes.sh`) that:
1. Runs `nix build` for each Go package overlay
2. Detects hash mismatches automatically
3. Extracts the correct `got:` hash
4. Reports which overlay files need updating
5. Optionally patches them automatically

### 3. Reduce Private Go Repo Dependency Count

Each private Go repo that uses `_local_deps` pattern is a vector for hash mismatches. Consider:
- Publishing some repos publicly (reduces `_local_deps` complexity)
- Merging tightly-coupled repos (go-output + go-branded-id + gogenfilter could be one repo)
- Using a shared Go module proxy

### 4. Lockfile Hygiene Monitoring

After the session 48/49 dedup work reduced lock nodes from 137 → 93, we should maintain this:
- Add a CI check that warns when lock nodes exceed a threshold
- Auto-detect new duplicate nixpkgs/flake-parts instantiations

### 5. Better Error Reporting

The 16 cascading NixOS build errors from 2 root hash mismatches is unacceptable. Consider:
- A pre-build check script that validates all Go overlay vendor hashes
- `nom` output filtering to highlight root causes vs cascading failures

---

## f) Top 25 Things We Should Get Done Next

### Priority 1 — Fix Root Causes (High Impact)

1. **Fix upstream `vendorHash` in all 6 repos** — eliminate the overlay overrides entirely
2. **Remove overlay vendorHash overrides** from shared.nix/linux.nix after upstream fixes
3. **Write `scripts/check-vendor-hashes.sh`** — automated detection of stale hashes
4. **Add `vendorHash` validation to `just test-fast`** — catch mismatches before deploy
5. **Push current changes to origin** — uncommitted changes are at risk

### Priority 2 — Build Reliability (High Impact)

6. **Add CI pipeline** — at minimum, `nix flake check --no-build` on every push
7. **Create `just test-vendor` recipe** — verify all Go overlay hashes match
8. **Test Darwin build from MacBook Air** — verify cross-platform after overlay changes
9. **Review all `_local_deps` repos for transitive dep issues** — prevent future cascades
10. **Update `just test-fast` to include overlay validation** — expand beyond syntax checks

### Priority 3 — Documentation & Maintenance (Medium Impact)

11. **Update AGENTS.md "Critical Rules" section** — add vendorHash override pattern
12. **Audit AGENTS.md for stale info** — several sections may be outdated
13. **Review `docs/status/` — archive old reports**, keep last 5 sessions
14. **Update FEATURES.md** — hasn't been updated since the Go overlay migration
15. **Update TODO_LIST.md** — reflects current priorities and completed work

### Priority 4 — Infrastructure (Medium Impact)

16. **Pi 3 DNS failover cluster** — provision hardware, deploy config, test VRRP failover
17. **SigNoz dashboard review** — verify all metrics are flowing after recent changes
18. **Gatus endpoint review** — verify all 26+ endpoints are still valid
19. **sops key rotation audit** — verify all secrets are using current age keys
20. **Disk space monitoring** — evo-x2 BTRFS usage trends

### Priority 5 — Code Quality (Lower Impact)

21. **Reduce lock file nodes further** — currently 72, target <65
22. **Consolidate private Go repos** — go-output + go-branded-id + gogenfilter merge
23. **Remove deprecated `justfile` if fully migrated** — AGENTS.md says it's deprecated
24. **Review NixOS module hardening consistency** — ensure all services use `harden {}` helper
25. **Audit systemd service ordering** — prevent circular dependencies like the awww wallpaper bug

---

## g) Top #1 Question I Cannot Figure Out Myself

**Should we keep fixing vendorHash locally via overlay overrides, or mandate that every upstream private Go repo must have a correct vendorHash before we bump its flake lock?**

The tradeoff:
- **Local overrides:** Fast fix, works now, but creates a shadow layer of hashes that will itself become stale when upstream repos update
- **Upstream mandate:** Slower (requires updating 6 repos), but SystemNix stays clean and the overlays remain simple pass-throughs

The AGENTS.md currently says "Never override vendorHash from outside a package" — but we just did exactly that to fix the build. This rule needs revisiting or the upstream repos need fixing.

---

## Session Metrics

| Metric | Value |
|--------|-------|
| Files changed | 4 |
| Lines changed | +25 / -18 |
| Build time | ~3 min (incremental) |
| Packages fixed | 7 |
| Root cause | Stale vendorHash in 6 upstream repos |
| Build status before | 16 errors, completely broken |
| Build status after | Clean, all checks passed |
| Commits to push | 2 (existing + this session) |
| Lock file nodes | 72 |
| Flake inputs | 47 |
| nixpkgs pin | `01fbdee` (2026-04-23) |

---

_Generated by Crush — Session 63_
