# Session Status: Build Fix Triple — btrfs SC2004, cqrs-lint vendorHash, KeePassXC symlink collision

**Date:** 2026-08-02 05:47
**Session scope:** Three independent build failures investigated and fixed

---

> **RESOLVED — Resolved. Work captured in CHANGELOG.md.**
> All forward-looking items in this report were completed in subsequent sessions.


## a) FULLY DONE

### 1. btrfs-health.nix SC2004 shellcheck warnings (4 fixes)
**Files:** `platforms/nixos/system/btrfs-health.nix` (lines 296, 333, 364, 372)
**Root cause:** `$` prefix on variables inside `$(())` arithmetic context — shellcheck SC2004.
**Fix:** Removed unnecessary `$` from `$UNALLOC_BYTES`, `$CURRENT_SIZE`, `$FREE_BYTES`, `$MIN_FREE` inside `$(())`.
**Verified:** `nix build` of `btrfs-balance-data` derivation succeeds with no shellcheck output. `nix flake check --no-build` passes.

### 2. cqrs-lint vendorHash mismatch (upstream go-cqrs-lite)
**Files (upstream):** `go-cqrs-lite/flake.nix:362`, `go-cqrs-lite/cmd/cqrs-lint/go.mod`
**Files (SystemNix):** `flake.lock` (go-cqrs-lite input updated)
**Root cause:** Upstream commit `54b69063` refreshed `go.sum` pseudo-versions but:
- Did NOT update the `vendorHash` in `flake.nix` → hash mismatch at build time
- Left `cmd/cqrs-lint/go.mod` with a stale pseudo-version (`go-finding v0.0.0-00010101000000-000000000000`) that `go mod tidy` resolves to `v1.4.1`
**Fix:** Ran `go mod tidy` in `cmd/cqrs-lint/`, updated `vendorHash` to `sha256-jCWga0Vwgc57K/BLPrE6W+V2VPzdpxmaNs/sJWCQg8g=`, committed as `d6be91ca`, pushed to GitHub, updated SystemNix `flake.lock`.
**Verified:** `nix build .#cqrs-lint` succeeds from both go-cqrs-lite and SystemNix. Binary runs (`cqrs-lint version 0.2.2`). `nix flake check --no-build` passes.
**Commit:** `d6be91ca` on go-cqrs-lite master (pushed)

### 3. KeePassXC symlinkJoin collision (keepassxc-with-chromium-manifests)
**File:** `platforms/common/programs/keepassxc.nix`
**Root cause:** nixpkgs `keepassxc` now ships its OWN Chromium native messaging manifest at `$out/etc/chromium/native-messaging-hosts/org.keepassxc.keepassxc_browser.json` (with 3 extension origins). The SystemNix `symlinkJoin` wrapper tried to `ln -s` a custom manifest at the SAME path → "File exists" collision.
**Fix:** Removed the entire `symlinkJoin` wrapper and `chromiumManifest` writeText derivation. `programs.keepassxc.package` now points directly to `pkgs.keepassxc`. The Helium-specific manifest (non-standard config path) is retained.
**Verified:** `nix build` of the keepassxc package succeeds. `nix flake check --no-build` passes.

---

## b) PARTIALLY DONE

### KeePassXC runtime verification
The package builds and `nix flake check` passes, but native messaging has NOT been verified at runtime. The browser extension → keepassxc-proxy → KeePassXC IPC chain is untested. A deploy + browser test is needed to confirm the nixpkgs-shipped manifest works with Chromium/Helium.

### cqrs-lint behavioral verification
Built and `--help`/`--version` work, but no real linting run was performed against a consumer project to verify the `go-finding v1.4.1` resolution doesn't cause behavioral changes.

---

## c) NOT STARTED

N/A — all three reported build failures were addressed.

---

## d) TOTALLY FUCKED UP

Nothing irreversibly damaged. No data loss, no broken state.

---

## e) WHAT WE SHOULD IMPROVE

### Critical self-criticism

1. **Did NOT run the upstream test suite for cqrs-lint** — The `go mod tidy` changed `go-finding` from a pseudo-version to `v1.4.1`. The buildflow pre-commit hook ran (passed with warnings), but the full Go test suite was NOT run. If `go-finding v1.4.1` has breaking API changes vs the pseudo-version, `cqrs-lint` could silently produce wrong results.

2. **Did NOT check for other stale pseudo-versions** — Only `cmd/cqrs-lint/go.mod` was fixed. The go-cqrs-lite repo has 64 Go modules (per buildflow output). Other `cmd/*/go.mod` files may have the same stale pseudo-version problem. The buildflow `gomod-check` tool reported "83 findings remain" including "direct and indirect requires are mixed" across many modules.

3. **Did NOT verify KeePassXC native messaging at runtime** — A build passing is NOT proof the browser extension can communicate with KeePassXC. The nixpkgs manifest has `allowed_origins` with 3 extension IDs (vs our previous 1). This is MORE permissive (good), but the `path` field points to the nix store path of the base `keepassxc` package, which is correct but unverified.

4. **Did NOT check for orphaned references** — After removing `keepassxcWithChromiumManifests` and `chromiumManifest`, I did NOT grep for other references to these names in docs, status reports, or other modules. Old status reports reference them (in `docs/status/archive/`), but those are historical and acceptable.

5. **Did NOT update AGENTS.md** — The KeePassXC wrapper removal is a meaningful architecture change. The AGENTS.md doesn't have a specific KeePassXC gotcha entry, but the pattern (nixpkgs now ships what we manually wrapped) is worth documenting as a general principle: "before adding a wrapper/overlay, check if current nixpkgs already ships it."

6. **Ignored 175 buildflow findings** — The go-cqrs-lite pre-commit hook surfaced 86 critical/high findings (AGENTS.md too long at 1128 lines, GitHub Actions not SHA-pinned, go.mod mixing). These are upstream issues, not SystemNix, but they represent real security/maintenance debt that was acknowledged and ignored.

7. **Did NOT investigate the stale `go-cqrs-lite` flake.lock node** — SystemNix's flake.lock has a `go-cqrs-lite` node at `649bcd5` (flake=false, unreferenced by root) alongside the active `go-cqrs-lite_3` at `54b69063`→`d6be91ca`. This stale entry is harmless but pollutes the lock file. A `nix flake lock --redundant-flakes` or manual cleanup could remove it.

8. **GitHub reported 13 vulnerabilities on go-cqrs-lite** — 7 critical, 2 high, 4 moderate. Not investigated. These are dependency vulnerabilities in the upstream repo.

### Process improvements

9. **Always verify runtime behavior, not just builds** — Three fixes, zero runtime tests. The pattern of "build passes = done" is insufficient for infrastructure changes.

10. **Run `nix flake check` after EVERY change, not just the last one** — I ran it after the final change but not after each individual fix. If the keepassxc change had broken evaluation, I would have caught it earlier.

11. **Document WHY the wrapper existed** — The KeePassXC wrapper was added because nixpkgs didn't ship Chromium manifests. Now it does. The removal comment explains this, but the original implementation report (`docs/status/archive/2026-03-18_21-30_KEEPASSXC-PASSWORD-MANAGER-IMPLEMENTATION.md`) still describes the old approach as current.

---

## f) Up to 50 things we should get done next

### High priority — verify this session's work
1. **Deploy and verify KeePassXC native messaging** — Deploy to evo-x2, open Chromium, verify the KeePassXC browser extension can connect
2. **Run `cqrs-lint` against a real consumer project** — Verify the go-finding v1.4.1 resolution doesn't break linting
3. **Run go-cqrs-lite test suite** — `go test ./cmd/cqrs-lint/...` to verify the go.mod change

### Medium priority — upstream debt noticed during this session
4. **Pin GitHub Actions to SHAs in go-cqrs-lite** — 40+ actions use tag pins (security risk)
5. **Shorten go-cqrs-lite AGENTS.md** — 1128 lines (max should be ~377). Extract to referenced docs
6. **Fix go.mod direct/indirect mixing in go-cqrs-lite** — 83 modules have mixed require blocks (buildflow `gomod-check`)
7. **Audit go-cqrs-lite dependency vulnerabilities** — 13 dependabot alerts (7 critical)
8. **Check all `cmd/*/go.mod` files for stale pseudo-versions** — Same bug class as the cqrs-lint fix
9. **Clean stale flake.lock nodes** — Remove the unreferenced `go-cqrs-lite` (flake=false) node from SystemNix's flake.lock

### SystemNix improvements noticed
10. **Audit all `symlinkJoin` wrappers for nixpkgs convergence** — Same pattern as KeePassXC: check if nixpkgs now ships what we wrap
11. **Audit all `writeShellApplication` scripts for SC2004** — The btrfs fix caught 4, but other scripts may have the same issue
12. **Add SC2004 to pre-commit hook** — Ensure shellcheck warnings are caught before commit, not at build time
13. **Add a "does nixpkgs already ship this?" check** — Before maintaining custom wrappers, verify they're still needed
14. **Run full SystemNix build** — `nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel` to catch any other build failures beyond the three fixed

### From the git diff (pre-existing uncommitted changes, not this session)
15. **Review and commit the `tests/` changes** — `test-helpers.nix`, `test-searxng.nix`, `test-attic.nix` have uncommitted modifications
16. **Review the `secrets/attic.yaml` addition** — New sops secret file staged but not committed
17. **Review `statix.toml` changes** — Configuration modification uncommitted
18. **Review `.github/workflows/nix-check.yml` changes** — CI workflow changes uncommitted
19. **Review `flake.nix` changes** — Uncommitted modifications to the flake
20. **Review all modified service modules** — `_signoz-packages.nix`, `attic.nix`, `disk-monitor.nix`, `manifest.nix`, `minecraft.nix`, `nvme-health-monitor.nix`, `pocket-id.nix`, `qmd-config.nix`, `taskchampion.nix`, `twenty.nix`, `voice-agents.nix` all have uncommitted changes

### General SystemNix maintenance
21. **Run `nix flake check --no-build` on a clean eval cache** — Catch any eval-time issues hidden by stale cache
22. **Audit all `writeText` + `symlinkJoin` patterns** — May be other wrappers made redundant by nixpkgs updates
23. **Check if the Helium manifest path is still correct** — Helium's config dir (`net.imput.helium`) may have changed in newer versions
24. **Verify `keepassxc-proxy` path in the Helium manifest** — Now points to `${keepassxcPkg}/bin/keepassxc-proxy` (the base package, not the wrapper)
25. **Consider adding `programs.keepassxc.nativeMessagingHosts`** — HM may have a built-in option for this now (vs manual `home.file`/`xdg.configFile`)

---

## g) Questions I CANNOT figure out myself

### 1. Should the cqrs-lint go.mod change be considered a breaking change?
The `go-finding` dependency was resolved from a pseudo-version (`v0.0.0-00010101000000-000000000000`) to `v1.4.1`. I cannot determine whether `v1.4.1` is API-compatible with whatever the pseudo-version pointed to at the time `54b69063` was committed. The pseudo-version suggests a local replace directive that was never properly tagged. Should I investigate the git history to find what commit the pseudo-version corresponded to, or is `v1.4.1` the correct tagged release?

### 2. Should I commit the SystemNix changes (keepassxc.nix + btrfs-health.nix + flake.lock)?
There are 26 files with uncommitted changes in SystemNix (from this session and prior sessions). Should I commit just the three files I changed this session, or do you want to handle the full diff separately?

### 3. The pre-existing uncommitted changes (26 files) — are those yours or from a previous agent session?
I see changes to tests, service modules, CI workflow, flake.nix, overlays, and secrets that predate this session. I did NOT touch these and will NOT revert them, but I need to know if they should be included in any commit I make, or if they're work-in-progress from another context.
