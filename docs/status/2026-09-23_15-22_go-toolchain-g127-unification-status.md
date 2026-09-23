# Status Report: Go Toolchain Session — go_1_27 Unification Audit + Template Fix

**Date:** 2026-09-23 15:22 CEST
**Session scope:** Go version configuration Q&A → tree-wide inventory → one code fix
**Repo state at close:** `502db45d` (HEAD), master, unpushed commits ahead of origin

---

## 1. What This Session Did (chronological)

1. **Answered "how is Go version configured?"** — summarized the ratified three-wiring-points doctrine from AGENTS.md: (a) the go-standard flakeModule's `goPkgAttr`, (b) the NixOS-module lambda's `goPkg` (go-auto-upgrade), (c) direct `mkPreparedSource` consumers needing `buildGoModule.override { go = ... }` (papdashboard pattern). Plus the floor-chase context (ecosystem floors 1.27.1 vs nixpkgs `go_1_26` = 1.26.7) and the vendorHash-invalidation coupling.

2. **Probed "can we just be on latest raw nixpkgs go?"** — live evals:
   - `nix eval nixpkgs#go.version` → **1.26.7** (below the 1.27.1 ecosystem floor → raw `go` breaks the `-go-modules` FOD under `GOTOOLCHAIN=local` today)
   - `nix eval nixpkgs#go_1_27.version` → **1.27.1**
   - Verdict delivered: no today; explicit `go_1_27` narrows vendorHash blast radius to deliberate bumps. Flip condition: nixpkgs default ≥ slowest ecosystem floor and stays there.

3. **Probed "remove GOTOOLCHAIN, keep GOEXPERIMENT=jsonv2 only for Go < 1.27?"** — two-step verification, first attempt was CONTAMINATED:
   - First probe (`GOEXPERIMENT=jsonv2 go env …`) inherited the session env and mislead.
   - Clean-env probe (`env -i PATH=… nix shell nixpkgs#go_1_27 -c go env GOEXPERIMENT GOTOOLCHAIN`) → **`GOEXPERIMENT=` empty, `GOTOOLCHAIN=auto`** — jsonv2 has NOT graduated as default in 1.27; `GOEXPERIMENT=jsonv2` still needed on 1.27.
   - Verdict delivered: dropping `GOTOOLCHAIN=local` is safe today (floors satisfied) but reverses the loud-failure design — `auto` silently downloads toolchains + splits the build cache when floors run ahead again (2026-08-15 incident class). Recommended: drop neither; revisit when clean-env `go env GOEXPERIMENT` shows `jsonv2` as default.

4. **Inventoried "can everything be on go_1_27?"** — `rg` sweep of the tree found exactly four remaining `go_1_26`/older spots and classified each:
   - `overlays/shared.nix:9` (`go_1_25 = go_1_26` sops-nix shim) — KEEP until sops-nix > `13616fff`
   - `modules/nixos/services/_signoz-packages.nix:38` (`buildGoModule.override { go = go_1_26 }`) — probe on 1.27 first (sonic patches verified on 1.26 only; SigNoz is not our code)
   - `templates/go-flake-parts/flake.nix:50` (`goPkg = go_1_26`) — FIX NOW (done, below)
   - CV flake input — blocked on upstream's one-line `goPkgAttr = "go_1_27"` fix (branch-ref governed hold, `65c8fcd5` floor > 1.26.7)

5. **"fix" → executed the one safe fix:**
   - Edited `templates/go-flake-parts/flake.nix:50`: `goPkg = pkgs.go_1_26` → `pkgs.go_1_27`
   - `nix flake check --no-build` → **all checks passed**
   - Commit raced the auto-commit daemon (see §4d): the daemon landed my staged one-liner as `ebf2f3da` ("chore: auto-commit 1 changed file(s) (heuristic)") while my pre-commit hook ran; my amend onto it failed rc=128 (`HEAD` had advanced to `502db45d`, another session's properly-messaged docs commit). Per multi-agent discipline I did NOT rebase/absorb the foreign commit; the change is landed, the message is only the heuristic one.

---

## 2. a) FULLY DONE

| Item | Evidence |
|---|---|
| Go wiring doctrine answered + verified live (nixpkgs go versions) | `nix eval` outputs in transcript |
| Clean-env probe of go_1_27 defaults (GOEXPERIMENT/GOTOOLCHAIN) | `env -i` probe |
| Tree-wide go_1_26/go_1_27 inventory with per-spot classification | `rg` sweep, 4 spots found |
| Template flip to `go_1_27` | `templates/go-flake-parts/flake.nix:50`, change verified in `ebf2f3da` diff |
| Post-change validation | `nix flake check --no-build` green (twice: standalone + inside pre-commit) |

## 3. b) PARTIALLY DONE

| Item | State | Missing |
|---|---|---|
| "Everything on go_1_27" migration | 3 of 4 spots resolved correctly (template flipped, sops shim + CV correctly justified as keep/blocked) | SigNoz flip not attempted (needs probe first — see below) |
| Commit hygiene for the template change | Change is committed and landed | Commit message is the daemon heuristic (`ebf2f3da`), not the drafted descriptive one; no CHANGELOG/docs line added |

## 4. c) NOT STARTED

- **SigNoz on go_1_27 probe**: flip `buildGoModule.override` to `go_1_27`, build the schema-migrator FOD to surface a fresh `got:` vendorHash, and verify the sonic v1.15.4 + loader v0.5.2 patches still apply/compile on 1.27 (they were verified on 1.26 only). Not started — deliberately, requires a heavy FOD build.
- **CV upstream one-liner**: draft + push `goPkgAttr = "go_1_27"` in the CV repo, then probe `goModules` at origin HEAD and re-lock (would lift the branch-ref governed hold). Not started (upstream-repo work, needs owner go-ahead per CV CI-dead probe discipline).
- **GOTOOLCHAIN/GOEXPERIMENT revisit trigger registration**: the "drop when clean-env `go env GOEXPERIMENT` reports `jsonv2` default" condition exists only in this conversation — it is not recorded in AGENTS.md or TODO files yet (I wrote the answer, did not persist the trigger).
- **AGENTS.md/CHANGELOG annotation of the template flip**: the 2026-09-17 wave section and the pin-policy notes don't mention the template now riding go_1_27.

## 5. d) TOTALLY FUCKED UP

Nothing damaged. Honest accounting of the two stumbles:

1. **Contaminated probe (recovered in-session)**: my first `GOEXPERIMENT=jsonv2 go env` check inherited the session env and would have produced a wrong "graduated in 1.27" answer had I stopped one probe earlier. Caught it by re-checking under `env -i`. Cost: one extra command.
2. **Daemon race on the commit (accepted, not resolved)**: my `git add` + commit raced the auto-commit daemon — it swept my staged file into heuristic commit `ebf2f3da` mid-hook; my amend then failed because HEAD had advanced to a parallel session's `502db45d`. I stopped instead of rebasing (correct — do not rewrite commits containing foreign work), so the landed commit carries a low-information message. Per the 2026-09-14/09-19 multi-agent rules this is the sanctioned outcome, but a pathspec-scoped `git commit` fired *before* the daemon's ~10-min window would have avoided it entirely.

**Parallel-session activity observed (flagged per concurrent-agent rules):** `docs/services/offsite-borg-restore.md` was modified and staged by another session during mine, landed as `502db45d` ("docs: correct sops re-render gating in Borg DR restore runbook", 9+/3−). Not my work, not verified by me, left untouched.

## 6. e) WHAT WE SHOULD IMPROVE

1. **Probe hygiene**: any `go env` behavior check must run under a scrubbed env (`env -i`) by default on this box — the session exports (GOTOOLCHAIN, GOEXPERIMENT, caches) poison default-observation probes.
2. **Commit-before-daemon**: fire the pathspec commit immediately after the edit while `nix flake check` runs in parallel — not sequentially after it. The ~10-min check window is exactly the daemon's commit window.
3. **Persist revisit triggers**: when an answer ends in "revisit when X", X goes into AGENTS.md or a TODO file in the same session, not just the transcript. This session ended with two unpersisted triggers (jsonv2 graduation; CV upstream fix eligibility).
4. **"fix" scope ambiguity**: "fix" was correctly read as "apply your own recommendation", but the recommendation table had four rows with different risk classes — stating which rows I would/wouldn't touch *before* editing (I did after) would have made the boundary explicit up front.

## 7. f) What To Do Next (prioritized, session-scoped)

1. Add the template flip + the four-spot go_1_27 inventory table to `CHANGELOG.md` (or the pin-policy section of AGENTS.md).
2. Register the jsonv2-graduation revisit trigger in AGENTS.md (Build Cache cache-key bullet or the Go section): "drop `GOEXPERIMENT=jsonv2` when clean-env `go env GOEXPERIMENT` on go_1_27 reports `jsonv2` default; drop `GOTOOLCHAIN=local` only if accepting silent toolchain downloads."
3. SigNoz probe: `nix build` the schema-migrator FOD with `go = pkgs.go_1_27` in a scratch expression to surface the fresh `got:` hash + verify the two sonic patches still apply (dry-run `git apply --check` against the 1.27 FOD graph).
4. If the SigNoz probe passes: flip `_signoz-packages.nix:38`, refresh `collectorVendorHash` + the signoz vendorHash, build all three packages, deploy behind the existing signoz migration-review discipline.
5. If the SigNoz probe fails on 1.27: record the failure signature in `_signoz-packages.nix` comments so the next probe doesn't re-derive it.
6. CV upstream: draft the `goPkgAttr = "go_1_27"` one-liner in `/home/lars/projects/CV`, probe `nix build github:LarsArtmann/CV/<rev>#default.goModules` (CV CI is dead — no upstream signal), push, then `nix flake lock --update-input cv` and re-verify the FOD reproduces.
7. After the CV lift: re-check whether the `platforms/nixos/secrets` cv-evaluation items and the CV docs breadcrumbs can be pruned.
8. Add a template smoke check: a flake check that instantiates `templates/go-flake-parts` (sed `REPLACE_ME` → a dummy) so a future template regression fails at eval instead of at first use.
9. Audit the remaining `go_1_26` mentions in docs (darwin default.nix:45 note says "nixpkgs go_1_26 is already 1.26.1" — stale; the drop-day language in AGENTS.md "Drop every override the day …" is satisfied but unreferenced).
10. Sweep for droppable go-tarball overrides (`goTarballVersion`/`goTarballHash`) upstream on touch — AGENTS.md says browser-history, papdashboard, crush-daily, PMA still carry now-droppable overrides; none break, but each is a future FOD trap.
11. When sops-nix > `13616fff` lands: drop the `go_1_25 = go_1_26` overlay alias (`overlays/shared.nix:9`) — add a tracking line so the drop-day isn't missed.
12. Confirm `base.nix`'s `go_1_27` package comment (line 204, "pinned ahead of the nixpkgs default") still reflects reality after this session (it does; note it).
13. Decide the GOTOOLCHAIN question permanently (see question 3 below) and encode the decision either way.

## 8. g) Questions I Cannot Answer Myself

1. **SigNoz timing**: should I run the go_1_27 probe + potential flip now (risk: an observability-stack FOD break during a nixpkgs-forward window, plus a vendorHash refresh wave), or hold SigNoz on go_1_26 until the next upstream signoz/collector rev lands and probe once then?
2. **CV upstream**: do you want me to draft and push the `goPkgAttr = "go_1_27"` fix to the CV repo this week (lifting the branch-ref governed hold on the SystemNix lock), or is CV frozen while other sessions own it?
3. **GOTOOLCHAIN stance**: when floors next run ahead of the pinned go, do you prefer the current loud FOD failure (`GOTOOLCHAIN=local`, forces a deliberate bump) or accepting silent `auto` toolchain downloads in interactive/dev-shell contexts (only; nix builds stay pinned by buildGoModule regardless)?

---

*Verification trail: `nix eval nixpkgs#go.version` → 1.26.7; `nix eval nixpkgs#go_1_27.version` → 1.27.1; clean-env `go env` probe → GOEXPERIMENT empty / GOTOOLCHAIN auto; `rg` inventory → 4 spots; `nix flake check --no-build` → all checks passed (post-edit, pre-commit, and post-amend-attempt); landed change: `templates/go-flake-parts/flake.nix:50` in commit `ebf2f3da`.*
