# 2026-11-14 ~14:07 — pin-state update session: cv lift falsified twice, nixpkgs pin verified + lock residue converged, 3 fleet inputs enumerated broken

Trigger: the owner surfaced the two deliberate-pin lines (cv 066f76c, nixpkgs f4a03c00) with "WTF?! UPDATE!". This session attempted the lifts, falsified them first-hand, and documented the actual state. **The cv pin itself is OWNED by the rollback-deploy session's round 3** (flake.nix + `lib/flake-input-pin-audit.nix` + cv.nix TWENTY-FIRST entry, landed ~13:28 — it re-pinned 066f76c with compile-level evidence and incorporated this session's hash evidence); this report records the OTHER legs: my falsification sequence, the nixpkgs findings, and the fleet-input breakage enumeration.

## a. cv lift attempt — falsified twice, then ended by the parallel session's compile evidence

1. **Lift condition seemingly met**: the owner PUSHED the go-sum tidy fix — `9e3687b9` ("drop stale httputil v1.8.0 go.sum entries", 10:00:31Z, confirmed ancestor of master via gh compare; my morning read of "owner-push gated / UNPUSHED" was already stale when written). I re-floated the input (`nix flake update cv` → eb951951) and ran toplevel keep-going.
2. **Falsification 1 — tip eb951951 re-trips the guard**: the tip ("restore module-graph go.sum entries", 12:30Z) re-added entries the module graph drops; the fail-closed tidy guard refused with the committed go.sum running ~166 lines fat of tidy (first-hand: ~/.cache/cv-lift-keepgoing2.log, `-L` builder output).
3. **Falsification 2 — the fix rev itself is not buildable**: rev-pinned 9e3687b9, guard passed (zero `ERROR: go mod tidy`), but the go-modules FOD died on a **vendorHash mismatch**: CV bakes `ejjizmFeryl5SNML0X6Q5LO+evJwzU3QMj+JHYNh43M=`, our clean-tree FOD produced `IX/nWy4ACSxe1/9K/axJkFQZaOGO8qbOMu0wIogILKI=` (first-hand: ~/.cache/cv-lift-keepgoing4.log) — upstream never re-baked after the go.sum drop (their 11-13 checkout was DIRTY, docs/status/2026-11-13_09-41). `gh api` confirms nix/packages.nix at 9e3687b9 bakes ejjizmFe…
4. **The deeper blocker (rollback-deploy session, round 3)**: 9e3687b9's vendored go-credentials-store (CV's own hard pin e3697ed4, pre-templ-1100) calls `templ.JoinURLErrs`/`templ.ResolveAttributeValue`, deleted in templ 0.3.1100 — compile-broken regardless of hash (~/.cache/signoz-fod-fix/cv-pkg-build.log). They re-pinned **066f76c** (gen-1004-deployed, H8atokSb baked+proven, FOD reproduced green today in their keepgoing-post4.log) with the round-3 row + LIFT (guard-green go.sum AND templ-1100-aligned g-c-s, then float + proof). My intermediate "round 2 at 9e3687b9" surfaces were superseded by round 3; my stale TWENTIETH cv.nix comment (claiming a 9e3687b9 pin) is DELETED — the TWENTY-FIRST entry carries the full story including my hash numbers.
5. Run-3 lesson: my first "keep-going #3" produced rc=1 with ZERO error lines because the **eval-time flake-input-pin-audit threw** (my `?rev=` URL had no allowlist row after the lift edit) — the gate worked as designed and the "guard passes" I initially celebrated was unproven; every green claim above is backed by an actual build log.

## b. nixpkgs — pin VERIFIED standing; the URL-vs-lock residue converged

- **LIFT condition unmet**: patchelf on nixos-unstable tip is STILL 0.15.2 (gh probe of pkgs/development/tools/misc/patchelf/default.nix @ nixos-unstable, 2026-11-14 ~12:3x) — and the second half (floated tools green on the floated rev) remains gated on the heavy proof; the 11-10 float triple-break + TODO_LIST.md:3500 row stand. The pin stays; no attempt made (thermal freeze #52/#53 pressure same-day + proof4-red precedent).
- **Discovery — the lock node contradicted the URL pin since 2026-11-13 01:06**: `flake.nix:38` rev-pins f4a03c00, but the lock's nixpkgs node held `original: {ref: nixos-unstable}, locked: 177d0540` (a float-test residue; the 19:20 blanket float class). **Proven inert**: `nix flake metadata` resolves orig=locked=f4a03c00 — the URL rev governs eval (the deployed toplevel's own version string says `26.11.20261107.f4a03c0`); plain `nix flake lock` does NOT repair the original field (it is bookkeeping only).
- **Fix**: the node was grafted from nix's own computed locks object (metadata JSON) → on-disk original now rev-pinned f4a03c00, locked f4a03c00, idempotent under `nix flake lock` (a follow-up pass made no change). Survived the parallel session's re-lock. Committed by the daemon sweep.

## c. Fleet inputs enumerated broken at the run-4 locks (first-hand; SUPERSEDED within the hour — see §d)

| input @ run-4 lock | failure | evidence |
| --- | --- | --- |
| erraudit@75cfc15 | go-modules FOD hash mismatch: upstream bakes prAXFWSn…, clean FOD got POIy8+72… | keepgoing4.log |
| health-hub@caf9970 | FOD dies mid-tidy: `internal/env: no required module provides package` (import landed before go.mod/go.sum) | keepgoing4.log |
| invoices@9496b1d8 | compile break: `undefined: UpsertPaylinkAssignmentParams`, Querier missing GetPaylinkAssignmentByInvoice | keepgoing4.log |

CORRECTED same session: the parallel fixwave re-locked past all three broken revs (erraudit→1e512051, invoices→ee4d6ee4, health-hub input gone from the lock) and run 5 is fully green — the three [blocked:push] rows this report queued into docs/todo/upstream.md were removed again (unactionable: the tree no longer consumes the broken revs). The table stays as the historical record of those upstream failure modes; if a future daemon float lands a consumer near those revs, expect exactly these failure classes.

dbus-1 / man-paths / mandb / polkit unit drvs appear in the run-4 enumeration as dependency-level victims (never ran; `nix log` unavailable) — all absent from run 5's green census.

## d. Final verification

- **Run 5 (toplevel keep-going on the round-3 tree, this session's independent run): GREEN — rc=0, zero errors, cv legs build at 066f76c** (~/.cache/cv-lift-keepgoing5.log + .rc, 2026-11-14 ~14:0x). Combined with the rollback-deploy session's own keepgoing-post4.log green reproduction, the round-3 pin state is double-verified: `nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel --keep-going` passes end-to-end at HEAD's lock.

## f. Follow-ups

- ~~The 3 fleet-input re-float rows~~ queued then REMOVED same session (§c correction: the fixwave re-locked past the broken revs; run 5 green) — the enumeration lives in §c as history.
- CV upstream ask (guard-green go.sum + templ-1100 g-c-s bump + vendorHash re-bake in one commit; expected got IX/nWy4A… if nothing else moves) → owned by the rollback-deploy session's round-3 surfaces; NOT duplicated here.
- nixpkgs float proof (patchelf >= 0.19 + floated tools green) → remains on TODO_LIST.md:3500; probe evidence recorded in §b.
