# md-go-validator FOD Purity Break — Root Cause & Workaround

**Date:** 2026-07-28 18:16
**Session type:** Build break diagnosis + fix attempt
**Trigger:** User reported `nh os switch . -v` failing with 20 errors, all cascading from a single fixed-output derivation (FOD) purity violation.

---

## What Broke

```
error: fixed-output derivations must not reference store paths:
  '/nix/store/...-md-go-validator-f1e5584-go-modules.drv'
  references 1 distinct paths, e.g. '/nix/store/...-go-1.26.5'
```

This single FOD failure cascaded into 19 dependent derivations failing:
`unit-polkit.service`, `unit-dbus-broker.service`, `system-units`,
`user-units`, `etc`, `activate`, `system-path`, `man-paths`,
`system_fish-completions`, `dbus-1`, `X-Restart-Triggers-*`,
`unit-mandb.service`, `unit-accounts-daemon.service`, and finally
`nixos-system-evo-x2-26.11.20260726.624af66`. **The entire deploy was
blocked.**

---

## Root Cause (Definitively Diagnosed)

**`go-branded-id` v0.5.0 ships a prebuilt ELF binary committed inside the
Go module zip.**

The published module at `github.com/larsartmann/go-branded-id@v0.5.0`
contains a file named `namer` at the module root which is a **3.3 MB
statically-linked x86-64 ELF executable** (the `cmd/namer` binary,
pre-built):

```
$ file .../go-branded-id@v0.5.0/namer
ELF 64-bit LSB executable, x86-64, ... with debug_info, not stripped
```

That binary's DWARF `debug_info` section embeds the **absolute Nix store
path of the Go compiler** that built it (`/nix/store/...-go-1.26.5`).

When `buildGoModule` runs `go mod download` / `go mod vendor` for
`md-go-validator`, the module cache (and resulting vendor directory)
includes this binary verbatim. The `go-modules` FOD captures the entire
module cache as its output → the FOD output references the Go compiler
store path → **Nix refuses to build the FOD** (FOD outputs must not
reference any store path).

### Why it surfaced now

`md-go-validator` was added to `lib/lars-packages.nix` recently and is in
`environment.systemPackages` via `base.nix`. Every `nh os switch` for
evo-x2 (and the Darwin host) now evaluates this FOD. The break is
deterministic — it fails 100% of the time, not a flake.

### The binary is not needed at build time

`md-go-validator` imports `go-branded-id` as a **library** (the `pkg/`
Go packages). The `namer` binary at the module root is a committed
convenience artifact for `cmd/namer` — it is never compiled against or
invoked during `md-go-validator`'s build. It is pure dead weight that
corrupts the FOD.

---

## a) FULLY DONE

1. **Root-caused the break** to a single file (`namer`) in a single
   transitive dependency (`go-branded-id@v0.5.0`). Confirmed by:
   - Reproducing with a bare `nix build github:LarsArtmann/md-go-validator/<rev>#default`
   - `--keep-failed` + `grep -rl` of the Go store path inside the build dir
   - `zipinfo` on the module cache zip showing `namer` as a 3.3 MB entry
   - `file` confirming it is an ELF executable with `debug_info`
2. **Read upstream `package.nix` and `flake.nix`** for md-go-validator to
   understand the existing `postPatch` (which injects a `replace` for
   `go-finding` from a Nix store path — a *second* FOD-purity hazard).
3. **Identified a second, independent FOD-purity hazard**: md-go-validator's
   upstream `postPatch` writes
   `replace github.com/larsartmann/go-finding => ${go-finding-src}` into
   `go.mod`, where `${go-finding-src}` is an absolute `/nix/store/...`
   path. `go mod vendor` then records this absolute path in
   `vendor/modules.txt` → the FOD references the source store path.
   Confirmed by grepping the kept build dir:
   `vendor/modules.txt` contained
   `=> /nix/store/rw9dplhr5p8k3sllsn33r3iilw8kk091-source`.
4. **Designed a `stripPrebuiltGoBinaries` helper** in
   `lib/lars-packages.nix` that:
   - Switches to vendor mode (`proxyVendor = false`)
   - Replaces the absolute go-finding replace with a relative one
     (`./deps/go-finding`) by copying the source into the tree
   - Strips the `namer` binary from the vendor dir post-`go mod vendor`
5. **Iterated the vendorHash** through multiple attempts and landed on a
   candidate hash `sha256-X0b5+DXMDNW05HONHZUKw96PDrkCaHbkiMKk4mWqwg8=`
   that the FOD accepted (no hash-mismatch error).

---

## b) PARTIALLY DONE

1. **The fix is written but NOT VERIFIED end-to-end.** I computed a
   vendorHash that the `go-modules` FOD accepted, but I was interrupted
   before running a final `nix build .#md-go-validator` to confirm the
   *main* derivation (the binary) builds and the vendoring is consistent.
   The candidate hash needs a confirming build.
2. **`lib/lars-packages.nix` is modified** with the workaround but the
   change is uncommitted and unverified by `nix flake check` or a real
   deploy.

---

## c) NOT STARTED

1. **Final build verification** of `.#md-go-validator` with the candidate
   hash.
2. **`nix flake check --no-build`** after the change.
3. **A real `nix run .#deploy`** to confirm evo-x2 switches.
4. **AGENTS.md gotcha entry** documenting this entire class of bug
   (prebuilt binaries in Go modules break FOD purity).
5. **Auditing other `lars-packages.nix` entries** that depend on
   `go-branded-id` — `branching-flow` (and transitively others) also pull
   `go-branded-id` and may hit the same FOD purity break. Not checked.
6. **Upstream fix**: open an issue/PR on `go-branded-id` to remove the
   committed `namer` binary from the repo (or add it to `.gitattributes`
   as export-ignore, or move it out of the module root). This is the
   *real* fix; the SystemNix workaround is a band-aid.
7. **TODO_LIST.md entry** for tracking the upstream fix.
8. **Pre-commit / CI guard** that detects committed ELF binaries in
   LarsArtmann Go module roots.

---

## d) TOTALLY FUCKED UP (Honest Self-Critique)

1. **I burned multiple build cycles before reading the upstream
   `package.nix` carefully.** My first attempt (`proxyVendor = true` +
   `zip -d` to edit the module cache zip) was doomed: editing a module
   zip changes its checksum, which `go mod download` verifies against
   `go.sum` → "checksum mismatch / SECURITY ERROR". I should have
   foreseen that Go's module checksum verification makes in-place zip
   editing a non-starter. **Wasted one full build cycle.**
2. **My second attempt forgot about the `go-finding` replace.** I
   switched to `proxyVendor = false` and stripped the binary from the
   vendor dir, but left upstream's `postPatch` injecting the absolute
   Nix store path replace. Result: the FOD still referenced the source
   store path (`/nix/store/...-source`) via `vendor/modules.txt`. I
   should have read the upstream `postPatch` *before* designing the fix,
   not after the second failure. **Wasted a second build cycle.**
3. **My third attempt broke go-finding entirely.** I set
   `go-finding-src = null` to drop the replace, but go-finding is a
   **private repo** — `go mod vendor` then tried to `git ls-remote` it
   from GitHub and failed with "could not read Username" (no credentials
   in the sandbox). I should have remembered the AGENTS.md note that
   LarsArtmann private repos need the flake-input source, not network
   fetch. **Wasted a third build cycle.**
4. **The final workaround is complex and fragile.** Copying
   `go-finding-src` into `./deps/go-finding` and rewriting the replace
   to a relative path works, but it duplicates source into the build
   tree and depends on `find ... -exec chmod +w` to make the
   read-only Nix store copy writable. This is clever but brittle. A
   cleaner fix would live upstream (drop the binary; keep the replace
   as-is).
5. **I did not verify the final build.** I have a candidate hash but
   zero confirmation the binary actually links. The user interrupted me
   before I could run the confirming `nix build`. **The fix is
   unverified.**
6. **I did not check blast radius.** `branching-flow` and possibly other
   `lars-packages.nix` entries transitively depend on `go-branded-id`.
   If they hit the same FOD break, they need the same workaround. I
   only touched `md-go-validator`.
7. **I did not update AGENTS.md.** This is exactly the kind of
   non-obvious, hard-won gotcha that belongs in the Non-Obvious Gotchas
   table. I deferred it "until done" — which risks losing the context.

---

## e) WHAT WE SHOULD IMPROVE

1. **Read ALL upstream packaging code before designing a workaround.**
   I read `package.nix` but skimmed the `postPatch`. The `postPatch`
   contained a second FOD-purity hazard (the absolute-path replace)
   that I only discovered after a failed build. Rule: when a FOD purity
   break involves `buildGoModule`, read *both* the package expression
   AND every hook that mutates `go.mod`/`go.sum`.
2. **Verify the fix builds before iterating the hash.** I cycled the
   vendorHash three times against broken configs. Each cycle is a full
   FOD build. I should have dry-run validated the `postPatch` logic in
   a shell first (`nix develop`, manually run the patch + `go mod
   vendor`, confirm no store paths in `vendor/modules.txt`).
3. **Centralize the go-branded-id workaround.** If multiple
   lars-packages depend on go-branded-id, the
   `stripPrebuiltGoBinaries` helper should be applied to all of them,
   not just md-go-validator. Better: a shared `mkLarsGoTool` builder
   that auto-strips known-bad module artifacts.
4. **Push the fix upstream.** The committed `namer` binary in
   go-branded-id is a defect. It should be removed from the repo (or
   `.gitattributes` export-ignored). One upstream PR eliminates the
   need for every downstream workaround.
5. **Add a CI check** that scans LarsArtmann Go module roots for ELF
   files and fails. This class of bug is silent until someone vendors
   the module.
6. **Document in AGENTS.md** the general rule: *Go modules must not
   contain prebuilt binaries — they embed absolute builder paths that
   break FOD purity.*
7. **Don't defer AGENTS.md updates.** The memory-maintenance protocol
   in the global AGENTS.md says "update at the moment of discovery."
   I discovered this gotcha 30 minutes ago and haven't written it down.

---

## f) Next Steps (up to 50)

### Immediate (block deploy)
1. Run `nix build .#md-go-validator` to confirm the candidate vendorHash
   `sha256-X0b5+DXMDNW05HONHZUKw96PDrkCaHbkiMKk4mWqwg8=` produces a
   working binary.
2. If it fails, re-iterate the hash with `lib.fakeHash`.
3. Run `nix flake check --no-build` to confirm no eval breakage.
4. Run `nix run .#deploy` (or `nh os switch .`) to confirm evo-x2
   switches cleanly.
5. Run `nix run .#post-deploy-check` to confirm services are functional.

### Hardening
6. Audit `branching-flow` for the same go-branded-id FOD break.
7. Audit every other `lars-packages.nix` entry that transitively
   depends on go-branded-id.
8. Apply `stripPrebuiltGoBinaries` (or a generalized helper) to any
   other affected package.
9. Verify the Darwin host (`Lars-MacBook-Air`) also builds —
   `lars-packages.nix` is shared.

### Upstream (real fix)
10. Open issue on `go-branded-id`: "Remove committed `namer` binary —
    breaks downstream FOD purity."
11. Open PR on `go-branded-id` removing `namer` from the repo + adding
    it to `.gitattributes` as `export-ignore` (or moving it to a
    `dist/` dir excluded from the module).
12. Tag a new go-branded-id release (v0.5.1) without the binary.
13. Update md-go-validator's go.mod to v0.5.1.
14. Remove the SystemNix `stripPrebuiltGoBinaries` workaround once
    upstream ships.

### Documentation
15. Add AGENTS.md Non-Obvious Gotcha: "Prebuilt binaries in Go modules
    break FOD purity."
16. Add AGENTS.md entry for the go-finding absolute-path replace hazard.
17. Add TODO_LIST.md entry tracking the upstream go-branded-id fix.
18. Update this status report with the verified build result.

### CI / Automation
19. Add a flake check that scans vendored Go modules for ELF files.
20. Add a pre-commit hook on LarsArtmann Go repos rejecting committed
    ELF binaries in module roots.
21. Consider a `mkLarsGoTool` shared builder that centralizes
    FOD-purity hardening.

### Process
22. Adopt the rule: "Read all upstream packaging hooks before designing
    a buildGoModule workaround."
23. Adopt the rule: "Verify the fix builds before iterating vendorHash."
24. Adopt the rule: "Update AGENTS.md at moment of discovery, not
    end-of-session."

### Lower priority
25. Check whether `proxyVendor = true` could be revived with a
    `modPostBuild` that strips the binary from the module cache *and*
    rewrites `go.sum` — probably not worth it, vendor mode is simpler.
26. Investigate whether `deleteVendor` + a hand-maintained vendor dir
    would be cleaner than the `cp -r` into `./deps/`.
27. Consider whether the `find ... -exec chmod +w` step is robust
    against nested read-only dirs (it is, but worth a comment).
28. Check if `go-finding-src` is also a private repo needing the same
    relative-replace treatment in other consumers.
29. Audit whether any *other* LarsArtmann Go module ships committed
    binaries (run `find ~/.cache/go-build` / module cache for ELF
    files across all lars-packages inputs).
30. Add a comment in `stripPrebuiltGoBinaries` linking to the upstream
    issue once filed.
31. Consider gating the workaround behind a version check so it
    auto-disables once go-branded-id > v0.5.0.
32. Verify the workaround does not break `nix fmt` / treefmt.
33. Verify the workaround does not break statix/deadnix checks.
34. Run the full `checks` attrset after the fix.
35. Confirm the workaround's `postPatch` does not clobber md-go-validator's
    own `postPatch` (it currently *replaces* `old.postPatch` rather than
    appending — verify upstream has none, or append).
36. If upstream md-go-validator has its own `postPatch`, merge via
    `(old.postPatch or "") + ...`.
37. Same audit for `modPostBuild` — currently I replace; should append.
38. Add a regression test: `nix build .#md-go-validator` in CI.
39. Pin go-branded-id in flake.lock to a known-good rev once upstream
    fixes, to prevent silent regressions.
40. Document the `go-finding-src` flake input (it's only in flake.lock,
    not flake.nix — surprising).
41. Check whether `inputs.md-go-validator.inputs.go-finding-src` is the
    right way to reference it (it worked, but is it stable?).
42. Consider exposing `go-finding-src` as a top-level SystemNix input
    for clarity.
43. Add a `nix run .#doctor`-style check that validates all
    lars-packages build.
44. Review whether the `namer` binary is even supposed to be in the
    module (maybe it's a release artifact committed by mistake).
45. Check go-branded-id's `.gitignore` — `namer` should be ignored.
46. File a companion issue on md-go-validator to pin go-branded-id
    once fixed.
47. Consider a `vendorHash = lib.fakeHash` CI mode that fails fast on
    drift.
48. Add the candidate hash to a comment explaining how it was derived.
49. Clean up the orphaned build dirs in `/nix/var/nix/builds/` from
    the `--keep-failed` runs (they're 100+ MB each).
50. Write a one-line summary in CHANGELOG.md once verified.

---

## g) Questions I CANNOT Answer Myself

1. **Should I push the fix upstream to `go-branded-id` now (open
   issue + PR to remove the `namer` binary), or wait until the
   SystemNix workaround is verified and deployed?** I cannot push to
   LarsArtmann repos without your confirmation, and I don't know if the
   `namer` binary is intentionally committed (e.g. as a release
   artifact) or a mistake.

2. **Is `branching-flow` (and any other lars-package transitively
   depending on `go-branded-id`) currently broken by the same FOD
   purity issue, or does it vendor differently?** I can audit this
   myself with more build cycles, but you may already know which
   packages are affected — saving me from re-deriving it.

3. **Should the `stripPrebuiltGoBinaries` workaround live in
   SystemNix's `lib/lars-packages.nix` (current location), or would
   you prefer it upstreamed into md-go-validator's `package.nix`
   directly** (so every consumer benefits, not just SystemNix)? This
   is an architecture/placement decision I shouldn't make unilaterally.

---

## Files Changed This Session

| File | Change | Verified? |
|------|--------|-----------|
| `lib/lars-packages.nix` | Added `stripPrebuiltGoBinaries` helper; applied to `md-go-validator` with candidate vendorHash | ❌ NOT verified — build not confirmed |

No other files modified. No commits made. AGENTS.md NOT updated (deferred — should have been immediate per memory protocol).

---

## TL;DR

`go-branded-id@v0.5.0` ships a prebuilt ELF binary in its Go module zip;
the binary's debug_info references the Go compiler store path, breaking
the `md-go-validator` `go-modules` FOD and cascading into a full deploy
block. I wrote a `stripPrebuiltGoBinaries` workaround in
`lib/lars-packages.nix` that switches to vendor mode, rewrites the
go-finding replace to a relative path, and strips the binary. **The
candidate vendorHash is computed but the final build is UNVERIFIED.**
The real fix is upstream: remove the committed binary.
