# Session 26 — Branching-Flow Build Fix + onFailure Bugfix

**Date:** 2026-05-17 04:00
**Session:** 26
**Trigger:** `just switch` failing with 13 errors — branching-flow vendorHash stale

---

## A. FULLY DONE

1. **Branching-flow vendorHash fixed** (2 iterations)
   - Root cause: `go-output` dependency changes made the cached vendor hash stale
   - `go-error-family` was made public (unblocked `go mod download` in Nix sandbox)
   - Fixed vendorHash in `branching-flow/flake.nix`: `sha256-Iini...` → `sha256-QbLD...` → `sha256-EP95...`
   - Pushed 2 commits to `LarsArtmann/branching-flow` (revs `1475e06`, `20192b4`)
   - Updated SystemNix `flake.lock` to track new branching-flow revision

2. **disk-monitor.nix missing `onFailure` import** — fixed
   - `modules/nixos/services/disk-monitor.nix:11` — added `onFailure` to the lib import
   - Same pattern as the pre-existing `authelia.nix` fix from session 25

3. **minecraft.nix unused import cleanup** — removed unused `onFailure` from import

4. **AGENTS.md documentation updated**
   - `go-output go-branded-id transitive dep` gotcha expanded with:
     - Correct diagnosis: vendorHash stale after go-output dependency changes
     - Fix procedure: set `vendorHash = ""`, build, grep for `got:` hash
     - Reference to `file-and-image-renamer` as the most robust pattern

5. **Verified `nix build .#branching-flow` succeeds** with latest flake.lock

---

## B. PARTIALLY DONE

1. **Full `just switch` not yet verified** — only `nix build .#branching-flow` tested
   - The build may still have other failures (Rust crates, npm deps, etc.)
   - Need to run full `just switch` to confirm end-to-end

---

## C. NOT STARTED

1. **Full `just switch` deployment** — blocked on verification
2. **Audit all other Go repos for stale vendorHash** — go-structure-linter, buildflow, etc. may have the same issue
3. **Adopt file-and-image-renamer's robust postPatch pattern** in branching-flow and other Go repos
4. **Clean up stale docs/status files** (40+ files, should archive old ones)

---

## D. TOTALLY FUCKED UP (Honest Assessment)

1. **First diagnosis was wrong** — I said "make go-error-family public" would fix it. The real issue was a stale `vendorHash`. Making it public was necessary but not sufficient.

2. **Second diagnosis was also wrong** — I said `go.sum` was missing `go-branded-id`. The actual `go.sum` already had it. The error was a stale `vendorHash` in `flake.nix`.

3. **Didn't check the file-and-image-renamer pattern early enough** — It had the exact same problem already solved. I should have found this in step 1 of my research.

4. **Didn't realize `nix flake lock --update-input` updates transitive inputs** — The first flake.lock update pulled new `go-finding` and `go-output` too, which invalidated the vendorHash I had just fixed. Had to do it twice.

5. **AGENTS.md edit silently failed the first time** — The file was modified externally between my read and edit. I didn't verify the edit took effect until much later.

---

## E. WHAT WE SHOULD IMPROVE

1. **Add a `just update-vendor-hash <repo>` command** — Automate the vendorHash update dance: set to `""`, build, extract `got:` hash, write back
2. **Adopt file-and-image-renamer's postPatch pattern** across ALL Go repos — Inject `go-branded-id` into go.mod/go.sum if missing, preventing this entire class of failure
3. **Pre-commit hook in Go repos** — Validate vendorHash by building with `""` and checking if it matches current value
4. **CI for private Go repos** — `nix build .#default` in CI catches stale vendorHash before merge
5. **Archive old status reports** — 40+ files in `docs/status/`, should move to `archive/` monthly

---

## F. Top 25 Things To Do Next (Sorted by Impact/Effort)

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 1 | Run `just switch` to verify full deployment | Critical | Low | Fix |
| 2 | Adopt file-and-image-renamer postPatch pattern in branching-flow | High | Low | Prevention |
| 3 | Check go-structure-linter vendorHash isn't stale | High | Low | Fix |
| 4 | Check buildflow vendorHash isn't stale | High | Low | Fix |
| 5 | Add `just update-vendor-hash` command to SystemNix | Medium | Medium | Tooling |
| 6 | Audit all Go overlay repos for stale vendorHash | Medium | Low | Fix |
| 7 | Adopt postPatch pattern in all Go repos | High | Medium | Prevention |
| 8 | Archive old docs/status/ files | Low | Low | Cleanup |
| 9 | Fix branching-flow pre-commit nix-fmt error | Low | Low | Fix |
| 10 | Add `go-branded-id` injection to branching-flow's prepared-source postPatch | High | Low | Prevention |
| 11 | Run `just validate-scripts` to verify all shell scripts | Low | Low | Quality |
| 12 | Run `just format` to ensure all .nix files formatted | Low | Low | Quality |
| 13 | Check hermes vendorHash isn't stale after npm dep changes | Medium | Low | Fix |
| 14 | Verify monitor365 build (Rust crates downloading) | Medium | Low | Fix |
| 15 | Run `just test-fast` to validate Nix syntax | Medium | Low | Quality |
| 16 | Add CI pipeline for private Go repos (GitHub Actions) | High | High | Prevention |
| 17 | Create a shared Go repo template with correct Nix patterns | Medium | Medium | Prevention |
| 18 | Document the vendorHash update procedure in justfile help text | Medium | Low | Docs |
| 19 | Consider using `govendor` or similar tool for reproducible Go deps | Medium | High | Prevention |
| 20 | Add `nix flake check` to pre-commit hooks | Medium | Low | Quality |
| 21 | Review all overlay repos for consistent Nix patterns | Medium | Medium | Quality |
| 22 | Add health checks for all overlay packages in CI | Medium | Medium | Quality |
| 23 | Consider consolidating `_local_deps` pattern into a Nix lib helper | Low | Medium | Refactor |
| 24 | Update AGENTS.md with lessons from this session | Low | Low | Docs |
| 25 | Review flake.lock diff for unexpected input changes | Low | Low | Quality |

---

## G. Top #1 Question I Cannot Figure Out Myself

**Why did the first `nix flake lock --update-input branching-flow` NOT update the rev?**

The first time I ran `nix flake lock --update-input branching-flow`, it reported updating from `d12c22e` to `1475e06`, but `git diff flake.lock` showed NO changes and `python3` confirmed the rev was still `d12c22e`. The second time I ran the exact same command, it worked correctly. I suspect the first run updated the lock file in memory but didn't write to disk (perhaps due to a concurrent `direnv` reload or file system race), but I cannot confirm this.
