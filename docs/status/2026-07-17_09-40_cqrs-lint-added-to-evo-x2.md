# Status: cqrs-lint added to evo-x2

**Date:** 2026-07-17 09:40
**Session goal:** Add `go-cqrs-lite/cmd/cqrs-lint` as a dev tool on evo-x2
**Outcome:** Functional — binary builds and lands in systemPackages

---

## a) FULLY DONE

| #   | Task                                                                                                                                                                                                                                                          | Verification                                                                    |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| 1   | **Upstream: `packages.cqrs-lint` in go-cqrs-lite flake.nix**                                                                                                                                                                                                  | `nix build .#cqrs-lint` → `cqrs-lint version 0.2.1`                             |
| 2   | **Upstream: `mkPreparedSource` for cqrs-lint** with all 6 LarsArtmann deps (go-finding, cmdguard, go-output, gogenfilter, go-branded-id, samber-do-auditlog) + go-output subModules                                                                           | Source prep derivation builds; no "private modules without local replace" error |
| 3   | **Upstream: `overlays.cqrs-lint`** exported from go-cqrs-lite flake                                                                                                                                                                                           | `nix eval` confirms overlay attr exists                                         |
| 4   | **GOEXPERIMENT=jsonv2 root cause found and fixed** — `buildGoModule` silently drops `GOEXPERIMENT` from `env`; `goexperiment.jsonv2` as a `-tags` flag does NOT work (it's a reserved toolchain prefix). Fixed via `export GOEXPERIMENT=jsonv2` in `preBuild` | Build log shows no "build constraints exclude all Go files" errors              |
| 5   | **vendorHash computed and locked** — `sha256-iYsgtIvIluo0ZSr5trFHWfG2RZ+DYdlxG/IFxHycw0Y=`                                                                                                                                                                    | Second build substitutes from cache                                             |
| 6   | **SystemNix: `go-cqrs-lite` flake input added** with nixpkgs/flake-parts/treefmt-nix/system follows                                                                                                                                                           | `nix flake lock` succeeds; rev `509e23f7` (pushed to origin/master)             |
| 7   | **SystemNix: `cqrs-lint` wired into `lib/lars-packages.nix`** via named package lookup (not flakePkg default — go-cqrs-lite's default is a no-op stub)                                                                                                        | `nix eval` count = 1 in evo-x2 systemPackages                                   |
| 8   | **`nix flake check --no-build` passes** for SystemNix                                                                                                                                                                                                         | All NixOS modules evaluate                                                      |
| 9   | **Binary verified from SystemNix flake** — `nix build .#cqrs-lint` + `./result/bin/cqrs-lint --version` → `0.2.1`                                                                                                                                             | Clean build from committed state                                                |
| 10  | **Upstream committed and pushed** — go-cqrs-lite commit `509e23f7` is on origin/master                                                                                                                                                                        | `git rev-list --count origin/master..HEAD` = 0                                  |
| 11  | **SystemNix changes committed** (by external process) in commit `d873222f`                                                                                                                                                                                    | Working tree clean                                                              |

---

## b) PARTIALLY DONE

| #   | Item                                     | What's done                          | What's missing                                                                                                                                                                                                                                                    |
| --- | ---------------------------------------- | ------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | **AGENTS.md documentation**              | Nothing written                      | Should document: (a) cqrs-lint is wired via lars-packages.nix named-package lookup (not overlay), (b) the GOEXPERIMENT=jsonv2 preBuild gotcha for cqrs-lint builds, (c) go-cqrs-lite is now a flake input (not just a Go module replace target)                   |
| 2   | **`overlays.cqrs-lint` in go-cqrs-lite** | Overlay exported from upstream flake | NOT wired into SystemNix `overlays/linux.nix` — SystemNix reads the package directly via lars-packages.nix. The overlay is available for other consumers but unused here. Not wrong, just asymmetric with how monitor365/dnsblockd are wired (those use overlays) |
| 3   | **Cross-platform verification**          | Builds on x86_64-linux (evo-x2)      | NOT verified on aarch64-darwin (Lars-MacBook-Air). cqrs-lint is pure Go (CGO_ENABLED=0), platforms.unix — should work, but Darwin has `flake = false` go-finding as a tarball fetch which was already in the lock for other tools                                 |

---

## c) NOT STARTED

| #   | Item                         | Why it matters                                                                                                                                                                                  |
| --- | ---------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | **Deploy to evo-x2**         | `nix run .#deploy` not run — cqrs-lint is committed but not yet activated on the live system                                                                                                    |
| 2   | **Post-deploy smoke test**   | `nix run .#post-deploy-check` not run                                                                                                                                                           |
| 3   | **GOPRIVATE pattern update** | `home-base.nix` has `privateGoPattern` with 4 repos. go-cqrs-lite is already in it. But cqrs-lint's go.mod pulls `go-finding` (already in GOPRIVATE) — no change needed, but should be verified |
| 4   | **devShell inclusion**       | cqrs-lint is in systemPackages (available everywhere) but NOT in `devShells.default`. May want it there for explicit dev-tool visibility                                                        |

---

## d) TOTALLY FUCKED UP

| #   | What happened                                                                                                                                                                                                                            | Impact                                                         | Root cause                                                                                                                                                                                                                                                                                                                                                                        |
| --- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | **Destructive first edit on SystemNix flake.nix** — when inserting the go-cqrs-lite input, my `old_string` match was too greedy and deleted the `branching-flow`, `art-dupl`, and `projects-management-automation` input blocks entirely | Would have broken ALL those packages if not caught immediately | I matched on a multi-block span instead of a precise insertion point. Fixed in 2 follow-up edits, but this was careless and dangerous                                                                                                                                                                                                                                             |
| 2   | **GOFLAGS="-mod=mod -tags=goexperiment.jsonv2" initial attempt** — two bugs in one line                                                                                                                                                  | Silent empty binary (build constraints excluded all Go files)  | (a) `-mod=mod` conflicts with `proxyVendor = true` (vendored modules). (b) `goexperiment.jsonv2` is NOT a build tag you pass via `-tags` — it's a reserved prefix the toolchain sets internally from `GOEXPERIMENT`. AND `buildGoModule` silently drops `GOEXPERIMENT` from `env` anyway (documented gotcha in AGENTS.md). Fixed by exporting `GOEXPERIMENT=jsonv2` in `preBuild` |
| 3   | **First build produced empty output silently** — `nix build` exited 0 but `$out/bin/` was empty                                                                                                                                          | Would have shipped a broken package if not caught              | `buildGoModule` doesn't fail on "build constraints exclude all Go files" — it silently produces nothing. This is the exact gotcha documented in AGENTS.md (`buildGoDir swallows "build constraints exclude all Go files"`). I should have added a post-build assertion                                                                                                            |

---

## e) WHAT WE SHOULD IMPROVE

### Process improvements

1. **Always use minimal-precision edits** — My destructive flake.nix edit (deleting 3 input blocks) happened because I matched too much context. Rule: match the SMALLEST unique string, not the largest convenient block. The edit tool is literal — precision is safety.

2. **Read the AGENTS.md gotchas BEFORE writing code, not after hitting errors** — The GOEXPERIMENT-drop and build-constraints-silent-failure are BOTH documented in AGENTS.md. I hit both bugs before re-reading the gotchas table. If I had scanned it first, I'd have written the correct `preBuild` export on the first try.

3. **Add post-build assertions for Go binaries** — `buildGoModule` silently succeeds on empty output. Every `buildGoModule` in this project should have:

   ```nix
   postInstall = ''
     test -x $out/bin/cqrs-lint || { echo "ERROR: binary not found"; exit 1; }
   '';
   ```

4. **The `git restore docs/` decision needs scrutiny** — treefmt reformatted 25 HTML files that were ALREADY reformatted by commit `9aec8bd9`. This means treefmt's output differs from what was committed — a config drift issue. I silently restored them instead of investigating why. This should be a separate task.

### Code improvements

5. **The `overlays.cqrs-lint` in go-cqrs-lite is currently dead code from SystemNix's perspective.** SystemNix reads the package via `lars-packages.nix` (named package lookup), not via overlay. Two options: (a) remove the overlay if no other consumer needs it, or (b) wire it into SystemNix's `overlays/linux.nix` for consistency with other LarsArtmann tools. The lars-packages approach is actually cleaner for dev tools — the overlay would only matter if we wanted `pkgs.cqrs-lint` available in overlays.

6. **The cqrs-lint `version` in go-cqrs-lite uses `self.rev or self.dirtyRev or "dev"`** — correct for upstream. But SystemNix's `lars-packages.nix` pulls whatever version the flake input resolves to, which is the pushed rev. Good.

---

## f) Up to 50 things we should get done next

### Immediate (blocks deploy)

1. **Deploy to evo-x2** — `nix run .#deploy` to activate cqrs-lint on the live system
2. **Run post-deploy smoke test** — `nix run .#post-deploy-check`
3. **Verify `cqrs-lint --version` works in a new shell** on evo-x2 after deploy

### Documentation

4. **Update SystemNix AGENTS.md** — add cqrs-lint to the tool inventory, note the GOEXPERIMENT preBuild gotcha, note go-cqrs-lite is now a flake input
5. **Update go-cqrs-lite AGENTS.md** (if it has one) — document the `packages.cqrs-lint` build, the mkPreparedSource deps map, and the GOEXPERIMENT requirement
6. **Add a comment in lars-packages.nix** explaining why cqrs-lint uses named-package lookup instead of `flakePkg` (go-cqrs-lite's default is a no-op stub)

### Build hardening

7. **Add post-build assertion** to `packages.cqrs-lint` in go-cqrs-lite — `test -x $out/bin/cqrs-lint` to catch silent empty builds
8. **Add post-build assertion to ALL `buildGoModule` derivations** in the LarsArtmann ecosystem — this is a systemic blind spot
9. **Investigate treefmt HTML config drift** — why does `nix fmt` want to reformat 25 HTML files that commit `9aec8bd9` already reformatted?

### Cross-platform

10. **Verify cqrs-lint builds on aarch64-darwin** — `nix build github:LarsArtmann/go-cqrs-lite#cqrs-lint --system aarch64-darwin` (or on the MacBook)
11. **Verify cqrs-lint lands in Lars-MacBook-Air's systemPackages** via `lars-packages.nix` (it should — the filterAttrs drops nulls)

### Consistency

12. **Decide overlay vs lars-packages for cqrs-lint** — either remove the unused upstream overlay or wire it into SystemNix overlays/linux.nix for consistency
13. **Consider adding cqrs-lint to devShells.default** for explicit dev-tool visibility (currently only in systemPackages)
14. **Run cqrs-lint against go-cqrs-lite itself** — dogfood the linter on its own codebase
15. **Run cqrs-lint against SystemNix Go services** (discordsync, crush-daily, etc.) — validate real-world usage

### go-cqrs-lite upstream

16. **Add a CI check for `nix build .#cqrs-lint`** in go-cqrs-lite's GitHub Actions
17. **Tag a release** of go-cqrs-lite so SystemNix can pin to a stable rev instead of `ref=master`
18. **Consider adding `packages.cqrs-gen`** to the flake (same pattern as cqrs-lint — it's another CLI in cmd/)
19. **Consider adding `packages.api-stability`** to the flake (same pattern)

### SystemNix ecosystem

20. **Audit all lars-packages.nix entries** — verify each one's default package is NOT a no-op stub (like go-cqrs-lite's was). If it is, switch to named-package lookup
21. **Add a flake check that asserts larsPackages are non-empty derivations** — catch silent package resolution failures
22. **Document the "named package vs default package" pattern** in AGENTS.md — when to use `flakePkg` vs direct attribute lookup

### Monitoring (N/A for CLI tools, but noting for completeness)

23. ~~Add Gatus health check~~ — N/A, cqrs-lint is a CLI dev tool, not a service

---

## g) Questions I CANNOT figure out myself

### 1. Should cqrs-lint be pinned to a tagged release instead of `ref=master`?

go-cqrs-lite is currently pinned via `github:LarsArtmann/go-cqrs-lite?ref=master`. All other LarsArtmann Go tools in lars-packages.nix also use `ref=master`. But cqrs-lint is at `v0.2.1` (version constant in main.go) and actively evolving (reduced false positives in the last commit). Should I:

- **(a)** Keep `ref=master` (consistent with other tools, auto-tracks changes)
- **(b)** Pin to a tag like `?ref=v0.2.1` (reproducible, but requires manual bumping)

I can't decide this because it's a policy question about the project's stability requirements vs. currency.

### 2. Should the `overlays.cqrs-lint` be wired into SystemNix's `overlays/linux.nix`?

I added an overlay to go-cqrs-lite's flake but SystemNix doesn't use it — cqrs-lint is wired via `lars-packages.nix` named-package lookup instead. The overlay is available but unused. Other LarsArtmann tools (monitor365, dnsblockd, crush-daily) ARE wired via overlays in `overlays/linux.nix`. Should cqrs-lint follow the same pattern for consistency, or is the lars-packages approach preferred for dev-only CLI tools?

### 3. The `git restore docs/` — should I have kept the treefmt output?

treefmt reformatted 25 HTML files that commit `9aec8bd9` already reformatted. I restored them to keep my diff clean. But this hides a real config drift (treefmt producing different output than what was committed). Should I:

- **(a)** Leave them restored (separate issue, separate commit)
- **(b)** Re-apply the formatting and investigate the drift
- **(c)** Add the HTML files to treefmt's exclude list

This is a judgment call about whether formatting consistency or diff cleanliness matters more in this context.
