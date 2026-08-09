# Status Report: Build Failure Diagnosis & Brutal Self-Review

**Date:** 2026-08-04 10:18 CEST
**Scope:** This session only — diagnosis of the `nix run .#deploy` build failure (38 errors) on evo-x2.
**Mode:** Research-only (user requested diagnosis, no fixes applied).
**Format note:** User requested `.md`; `status-report` skill canonical format is HTML — explicit user override honored.

---


## Executive Summary

The deploy is **completely broken**. 38 build errors cascade from **5 root failures**. No eval-time
errors observed (build reached build phase), so the config is syntactically valid — the failures are
all in Go module vendoring / fixed-output derivations. Three distinct root causes were identified.
**Nothing was fixed** (research-only mandate), so the system remains undeployable.

| Root Cause | Severity | Blocks Deploy? | Whose Fault |
|---|---|---|---|
| nixpkgs tarball lock regression (7-month-stale nixpkgs) | **CRITICAL** | Yes (enabler) | SystemNix / nix registry |
| vendorHash drift on 4 Go packages | **HIGH** | Yes | Structural (`follows` + FOD) |
| crush-daily transitive deps (`go-idempotency`/`go-retry`) | **HIGH** | Yes | Upstream go-cqrs-lite |

---

## a) FULLY DONE

### Root-cause diagnosis of the build failure cascade
- **Parsed the 38-error build log** and traced the dependency graph: all 38 errors cascade from 5
  root FOD/go-modules failures (`crush-daily`, `buildflow`, `projects-management-automation`,
  `mr-sync`, `file-and-image-renamer`). The dbus/polkit/mandb/system-path/user-units/etc. failures
  are all transitive dependents of `system-path`.
- **Identified the nixpkgs tarball regression.** `flake.lock` records
  `original.type = "tarball"` for nixpkgs despite `flake.nix` declaring `github:NixOS/nixpkgs/nixos-unstable`.
  The nix global registry (`global flake:nixpkgs → channels.nixos.org tarball`) rewrites the URL.
  Locked nixpkgs is **Jan 8, 2026** — ~7 months stale. This is the documented "FIXED 2026-08-03"
  gotcha regressed.
- **Identified the crush-daily transitive-dependency break.** go-cqrs-lite's `idempotency/` and
  `retry/` submodule `go.mod`s declare:
  ```
  require github.com/larsartmann/go-idempotency v0.0.0-00010101000000-000000000000
  replace github.com/larsartmann/go-idempotency => ../../go-idempotency
  ```
  The zero pseudo-version + local `replace` only resolves inside the go-cqrs-lite dev monorepo.
  When crush-daily consumes these as **dependencies**, Go ignores the consumer's `replace` → tries
  to fetch the nonexistent revision → "unknown revision 000000000000" → build dies.
- **Verified both `go-idempotency` and `go-retry` are now published.**
  - `go-idempotency`: tags `v0.1.0`, `v0.1.1` exist locally.
  - `go-retry`: tag `v0.1.0` exists locally.
  This means the upstream fix is a version bump + dropping the local replaces, not creating new repos.
- **Identified vendorHash drift on 4 packages** (buildflow, PMA, mr-sync, file-and-image-renamer)
  — all fixed-output derivation hash mismatches.

### Flake wiring & topology understanding
- Confirmed crush-daily is consumed via **overlay** (`overlays/linux.nix` → `crush-daily.overlays.default`),
  not `mkLarsPackages`. It's Linux-only in `perSystem.packages`.
- Confirmed the `flake = false` Go library tarballs are NOT `follows`-overridden (correctly, per the
  flake.nix comment), but the **full** Go tool flakes (buildflow, PMA, etc.) DO have `nixpkgs.follows`,
  which is the chronic vendorHash-fragility vector.
- Mapped the go-cqrs-lite node proliferation: 5 distinct lock nodes (`go-cqrs-lite`, `-src`, `_2`,
  `_3`, `_4`) — the crush-daily path uses the `flake = false` `go-cqrs-lite` node pinned at `addb8d5e`.

---

## b) PARTIALLY DONE

### nixpkgs staleness quantification
- Found the lock date (**Jan 8, 2026**) and confirmed the tarball type regression.
- **Did NOT** compute how many nixpkgs commits/patches are behind, nor identify specific security
  advisories (CVEs) in the gap. Stated "security patches missing" without enumeration.

### vendorHash mismatch detail
- Captured the **exact `got:` hash for buildflow** only (`sha256-BilC13zQIP92hlP6dgLHlA6PyethVOtpHmlkBUwouts=`).
- For PMA, mr-sync, file-and-image-renamer: only know they failed with "hash mismatch" — did **not**
  retrieve their specific `got:` hashes (full logs weren't pulled via `nix log`).

### go-cqrs-lite master-state verification
- Read the **local clone** (`/home/lars/projects/go-cqrs-lite`) which shows the OLD local replaces.
- **Did NOT** verify whether go-cqrs-lite **master** (on GitHub) has already bumped to the published
  `v0.1.x` tags. The local clone may be stale. This is a critical gap — if master is already fixed,
  SystemNix only needs a flake input bump, not an upstream PR.

---

## c) NOT STARTED

- **Any actual fix.** No edits made (research-only mandate — correct for this turn).
- **`nix flake check --no-build`** — did not run it myself; relied entirely on the user's pasted log.
  Unknown whether eval-time errors exist beyond the build failures.
- **Individual package builds** (`nix build .#crush-daily .#buildflow …`) to isolate failures.
- **Cross-system impact analysis** — the paste is evo-x2 only. Darwin (`Lars-MacBook-Air`) and rpi3
  (DNS) impact not assessed. crush-daily is Linux-only, so darwin is likely unaffected, but the
  nixpkgs tarball regression affects **all** systems sharing that lock node.
- **Verifying reproducibility** — did not run `nix build .#crush-daily` to confirm the diagnosis
  end-to-end.
- **Latent-failure discovery** — the build exited after 5 failures. There could be more failures
  hidden behind these (build stops at first batch). Claimed "5 fixes clear all 38" from the shown
  dependency graph but did not exhaustively verify no other packages would fail.
- **The `mkPreparedSource` interaction** — SystemNix's `mkPreparedSource` claims to "strip local
  replaces." If it strips the `replace` in the submodule go.mods, the symptom would be "unknown
  revision" (which matches!). Did not determine whether mkPreparedSource is even in the crush-daily
  build path, or whether these submodule-level replaces survive/are-stripped.

---

## d) TOTALLY FUCKED UP

### I conflated two independent causes and presented speculation as fact
- I wrote that the stale nixpkgs (Issue 1) is **"a major contributor"** to the vendorHash drift
  (Issue 2). **I have ZERO evidence for this.** vendorHash mismatches are caused by upstream Go
  module content changes; the Go toolchain version from nixpkgs is rarely the driver. I should have
  labeled this a **hypothesis**, not a conclusion. This violates the "Admit uncertainty" principle.

### I asserted a "regression" without proving the timeline
- I called the tarball issue "the documented FIXED 2026-08-03 bug regressed" without checking
  `git log`/`git blame` on `flake.lock` to confirm the fix was ever applied to the committed file
  and then reverted, vs. the lock simply being regenerated by a `nix flake update` that re-resolved
  through the registry. A regression requires proof of prior-then-reverted state.

### I generalized from one hash to four
- Only saw buildflow's `got:` hash in the paste. I reported all four packages as "hash mismatch"
  uniformly and attributed them to one structural cause. The other three could have distinct root
  causes (e.g., a transitive dep version bump in just one repo).

### I didn't verify the "Go ignores consumer replace" mechanism in THIS build
- The claim "replace directives only apply in the main module" is generally true, but I did not
  confirm this is the exact mechanism here vs. an mkPreparedSource stripping artifact. The
  `unknown revision 000000000000` error is consistent with BOTH explanations.

### I claimed "fixing 5 clears all 38" without full verification
- This was inferred from the visible dependency graph, not exhaustively proven. There may be
  additional latent failures not surfaced because the build aborts early.

---

## e) WHAT WE SHOULD IMPROVE

1. **Stop presenting hypotheses as conclusions.** Every claim about *why* should be tagged
   "confirmed" (with evidence) or "hypothesis" (with what would confirm it). I violated this twice
   (nixpkgs→vendorHash link; "regression" label).
2. **Run my own verification commands** even on "research-only" turns. `nix flake check --no-build`
   and `nix log <drv>` are read-only and would have hardened every claim. Relying solely on a pasted
   log is lazy.
3. **Check upstream master before declaring an upstream bug.** The local clone may be behind master.
   For go-cqrs-lite, I should have `git -C /home/lars/projects/go-cqrs-lite fetch && git log origin/master`
   before asserting the break is present upstream.
4. **Quantify before alarming.** "7 months stale" should come with a commit/CVE count, not just a
   calendar delta.
5. **Distinguish structural fragility from acute breakage.** The `nixpkgs.follows`-into-Go-flakes
   pattern is a *chronic* structural issue; the tarball regression is *acute*. Conflating them muddies
   the remediation plan. Separate "unblock now" from "harden the structure."
6. **Always give a remediation ORDER**, not just a list of causes. For diagnostics, the user needs to
   know what to do first (cheapest, highest-leverage fix).
7. **Verify the mkPreparedSource contract** for submodule-level replaces — this is a documented
   SystemNix helper and its exact behavior on nested replaces is load-bearing for the diagnosis.

---

## f) Next Actions (up to 50, sorted by impact)

### Tier 1 — Unblock the deploy (do first)
1. **Fix the nixpkgs tarball regression** — manually `jq` `flake.lock` `nodes.nixpkgs.original` to
   `type: "github"` with the correct `owner/repo/ref` + matching `locked` rev/narHash. (Documented
   procedure in AGENTS.md gotcha.)
2. **Decide: bump nixpkgs forward, or keep Jan-8 pin?** If bumping: `nix flake update nixpkgs` AFTER
   the manual surgery. Verify `original.type` stays `github`.
3. **Check go-cqrs-lite master** (`git fetch` + `git log origin/master -- idempotency/go.mod
   retry/go.mod`) — if the `v0.1.x` version bump is already there, skip to step 5.
4. **If go-cqrs-lite master is NOT fixed:** edit `/home/lars/projects/go-cqrs-lite/idempotency/go.mod`
   → `require go-idempotency v0.1.1`, drop the `replace`. Same for `retry/go.mod` → `v0.1.0`. Tag +
   push. **Fix upstream, not in SystemNix** (per AGENTS.md rule).
5. **Bump go-cqrs-lite flake input** in SystemNix (`nix flake lock --update-input go-cqrs-lite`).
6. **Bump crush-daily flake input** if it pins the broken go-cqrs-lite revision transitively.
7. **Rebuild vendorHashes**: set `vendorHash = ""` (or `lib.fakeHash`) for buildflow → `nix build
   .#buildflow` → paste `got:` hash → repeat for PMA, mr-sync, file-and-image-renamer. Push upstream
   fixes, bump SystemNix inputs.
8. **Run `nix flake check --no-build`** to confirm no eval errors.
9. **Run `nix build .#crush-daily .#buildflow .#projects-management-automation .#mr-sync
   .#file-and-image-renamer`** to confirm all 5 roots build before a full deploy.
10. **`nix run .#deploy`** — full deploy once the 5 roots are green.

### Tier 2 — Structural hardening (stop the chronic breakage)
11. **Evaluate decoupling `nixpkgs.follows` from Go tool flakes.** Documented fragility: every
    nixpkgs delta risks a vendorHash break. Tradeoff: more nixpkgs instances (closure size) vs.
    stability. Consider letting Go tool flakes use their own pinned nixpkgs.
12. **Add an eval-time assertion** that `flake.lock` `nodes.nixpkgs.original.type == "github"` —
    fails `nix flake check` if the registry rewrites it to a tarball. Prevents silent regression.
13. **Add a pre-commit / CI check** for the tarball regression (the documented gotcha keeps recurring).
14. **Document the mkPreparedSource + nested-submodule-replace contract** — does it strip replaces
    in submodule go.mods? This determines whether the crush-daily class of bug is preventable in
    SystemNix or purely upstream.
15. **Centralize vendorHash bumps**: a script that sets `vendorHash = ""` across all LarsArtmann Go
    packages, builds them in parallel, and reports the new hashes.

### Tier 3 — Verification & monitoring
16. **Cross-system verification**: confirm darwin (`nix run .#darwin-rebuild`/eval) and rpi3 eval
    still pass — the nixpkgs tarball regression affects all three.
17. **CVE/staleness audit**: enumerate nixpkgs security fixes between Jan 8 2026 and now.
18. **Latent-failure sweep**: after the 5 roots are fixed, do a full `nix build .#nixosConfigurations.
    evo-x2.config.system.build.toplevel` to surface any failures hidden behind the abort.
19. **Confirm reproducibility**: re-run `nix build .#crush-daily` post-diagnosis to close the loop.
20. **Check the `cqrs-htmx` transitive input** (crush-daily pulls it) — may have its own broken deps.

### Tier 4 — Documentation & process
21. **Update AGENTS.md** gotcha table: note that the tarball regression RECURRED and the eval-time
    assert (item 12) is the prevention.
22. **Record the `go-idempotency`/`go-retry` publishing** in the GOPRIVATE / mkLarsPackages context
    if they need to be added to `privateGoPattern`.
23. **Add `go-idempotency`/`go-retry` to `mkLarsPackages`** if they become standalone tools (currently
    libraries only).
24. **Post-mortem**: why did the build stay broken — is there no CI gate on `nix run .#deploy`?
25. **Consider a nightly `nix flake check --no-build` CI job** on SystemNix to catch drift early.

### Tier 5 — Broader hygiene (lower priority)
26. Reconcile the 5 go-cqrs-lite lock nodes — consolidate where possible to reduce lock complexity.
27. Audit all `nixpkgs.follows` overrides in `flake.nix` for the same fragility class.
28. Add a `nix run .#preflight` that builds all Go packages before attempting a full deploy.
29. Verify `overlays/linux.nix` overlay ordering doesn't mask version drift.
30. Check whether `crush-daily-backfill` app (flake.nix:700) also breaks (it depends on crush-daily).
31. Review whether the `git insteadOf` SSH rewrite (restored 2026-07-30) interacts with the tarball
    regression.
32. Confirm `go-cqrs-lite-src` (pinned to `idempotency/v4.2.0` tag) is consistent with the master
    state after the fix.
33. Pin go-cqrs-lite to a **tag** rather than `master` once the fix is tagged, to prevent future
    master drift breaking SystemNix.
34. Add a regression test (VM or eval) that builds crush-daily to catch this class of break.
35. Sweep all LarsArtmann Go submodules for other local `replace => ../..` directives that would
    break as transitive deps (preventive — same bug class as go-idempotency/go-retry).
36. Verify the `go-cqrs-lite_3` node (cqrs-lint builder) is also fixed or unaffected.
37. Check if `branching-flow`, `cmdguard`, etc. (buildflow's inputs) have similar local-replace traps.
38. Document the "published submodule must drop local replaces" rule in go-cqrs-lite's CONTRIBUTING.
39. Assess whether a Go workspace (`go.work`) in go-cqrs-lite would eliminate the replace-on-publish
    problem entirely.
40. Review flake.lock node count — 5 go-cqrs-lite nodes suggests over-de-duplication; verify each is
    necessary.
41. Add `nix flake update --flake-nix-show-path` diagnostics to catch registry rewrites.
42. Confirm the `systems` / `treefmt-nix` follows aren't introducing additional nixpkgs instances.
43. Verify `monitor365` (Rust) is unaffected by the Go toolchain staleness.
44. Check whether the stale nixpkgs caused any OTHER silent issues (old package versions, missing
    patches) beyond the build failure.
45. Consider a `flake.lock` linter (statix/custom) for the tarball-type regression specifically.
46. Review the `nix registry` global entries — can SystemNix override the global nixpkgs redirect?
47. Add the tarball check to `pre-deploy-check`.
48. Verify `nix run .#pre-deploy-check` would have caught this (it may not check FOD builds).
49. Tag this status report for `docs-health` HARVEST once fixes land.
50. Schedule a follow-up to verify the tarball regression does not reappear after the next
    `nix flake update`.

---

## g) Questions I CANNOT Figure Out Myself

> These require a human decision or intent I cannot derive from the code.

1. **Approach: rapid unblock vs. structural fix?** Do you want me to do the **fastest path to a green
   deploy** (bump hashes, bump flake inputs, ~15–30 min) and defer the structural problem — or invest
   now in **decoupling `nixpkgs.follows` from Go tool flakes** to stop the chronic vendorHash drift
   (hours, higher risk, but prevents recurrence)? These have very different time/risk profiles and
   it's your call on the tradeoff.

2. **Is the Jan-8-2026 nixpkgs pin intentional or accidental?** A 7-month-old nixpkgs is *so* stale
   that I want to confirm it's the tarball regression (accidental) and not a deliberate stability
   freeze before I "fix" it by bumping forward. (I lean heavily toward "accidental regression," but
   the cost of a wrong guess — pulling in 7 months of nixpkgs changes mid-crisis — is high.)

3. **Scope of this deploy crisis: evo-x2 only, or all systems?** Should remediation target only the
   evo-x2 build that failed, or should I also verify/fix darwin and rpi3 in the same pass (they share
   the nixpkgs tarball-locked node)? The tarball regression affects all three, but you may want to
   isolate the blast radius.

---

## ⚠️ POST-REPORT VERIFICATION (run after initial write — corrects/strengthens claims)

The alarm above prompted re-verification. **Both core claims are now CONFIRMED with git evidence.**

### nixpkgs tarball regression: CONFIRMED (not just "likely")
Proven timeline via `git merge-base --is-ancestor` + per-commit flake.lock inspection:

```
0dbf45ea  "update nixpkgs source to github"   type=github  rev=148bab9  lastMod=1785578396 (~Aug 2 2026)  ← THE FIX
f7241db3  "update flake.lock with latest deps" type=tarball rev=3497aa5  lastMod=1767892417 (Jan 8 2026)   ← REGRESSION
```

`f7241db3` is a **descendant** of the fix `0dbf45ea`. So the fix was applied, then a later
"update flake.lock" commit re-resolved nixpkgs through the global registry → tarball → and the
tarball pointer itself was stale. This is a **double regression**: type reverted to tarball AND
content downgraded from Aug 2026 to Jan 2026.

The nixpkgs node has been `type=tarball rev=3497aa5` for the **last 10+ flake.lock commits**
(verified across `387e8a94` back through `3fcba2dd`).

### Build-label discrepancy EXPLAINED (not an error in the diagnosis)
The paste's build label `nixos-system-evo-x2-26.11.20260802.6438090` references nixpkgs short-rev
`6438090` (Aug 2) — **different** from current flake.lock `3497aa5` (Jan 8). Resolution: the paste is
from an **earlier build attempt** when flake.lock had a newer nixpkgs (`6438090` appeared in commit
`c599a727`). The current lock is older/staler.

**Key implication:** the crush-daily/vendorHash failures in the paste occurred against an **Aug-2
nixpkgs** — so those failures are **independent** of nixpkgs staleness. This **confirms** the
self-critique in section (d): my original claim that stale nixpkgs "contributes" to vendorHash drift
was unsupported. The vendorHash breaks and the tarball regression are **two separate problems**.

### Self-critique resolution
- (d) "asserted a regression without proving the timeline" → **RESOLVED.** Timeline now proven above.
- (d) "conflated nixpkgs staleness with vendorHash" → **CONFIRMED as a real error.** The paste proves
  the vendorHash failures happen with fresh nixpkgs too. They are independent.
- (b) "did NOT verify go-cqrs-lite master" → **STILL OPEN.** Not yet checked.

---

## Session Self-Assessment

**What I did right:** Identified all three root causes; verified the go-idempotency/go-retry
publishing state; traced the 38→5 cascade; understood the flake wiring topology. Post-report, proved
the tarball regression timeline with git evidence.

**What I did wrong:** Presented two hypotheses as facts (nixpkgs→vendorHash link — now disproven by
the build-label evidence; "regression" label — now proven but wasn't at time of writing); generalized
one hash to four; didn't run my own read-only verification initially; didn't check upstream master
before declaring an upstream bug; didn't give a remediation order.

**Net:** Diagnosis is now **evidence-backed** for the tarball regression and the crush-daily transitive
break. The vendorHash failures are a **separate, independent** problem from nixpkgs staleness.
Treat Tier 1 steps as a plan to validate, not gospel.

---

> **RESOLVED — Resolved. Work captured in CHANGELOG.md [Unreleased].**
> All forward-looking items in this report were completed in subsequent sessions.
