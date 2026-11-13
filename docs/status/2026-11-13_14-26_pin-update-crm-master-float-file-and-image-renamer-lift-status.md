# Status: crm master-float + file-and-image-renamer pin lift (2026-11-13 14:26)

**Session shape:** owner directive "update to latest fucking versioN!" on the pasted
`flake-input-pin-audit` trace (crm REV-PINNED at 9d96dad, file-and-image-renamer
REV-PINNED at 973dd383). Then a second owner challenge — "what?" on the crm
"deliberate policy pin" — which correctly forced the pin itself to be questioned,
not just rolled.

**Verdict:** tree-side work is complete and verified; nothing is deployed. The
final whole-tree `nix flake check` is RED on a FOREIGN in-flight module
(`journal-mesh`, port 4222 unprobed by gatus), not on any surface this session
touched.

---

## a) FULLY DONE

### 1. crm pin: rolled, then lifted (final state: floats on master)

| Step | Evidence |
| --- | --- |
| goModules FOD probe at `98cd15c` (latest master at probe time) | green, no override (job 005) |
| FULL package build at `98cd15c` lock-free | `rc=0`, `kith-crm-98cd15c…` (job 00C) |
| Pin rolled `9d96dad` → `98cd15c` in `flake.nix` + allowlist row updated | commit `ad8fe3a0d` (daemon-swept) |
| Owner challenge → pin LIFTED, input now `?ref=refs/heads/master` | `flake.nix` crm block + `lib/flake-input-pin-audit.nix` row removed, commit `865e27458` |
| Re-lock to current tip `f6ccd43b2fd41888441215219f4d1b3ad682b9ae` | `nix flake lock --update-input crm --refresh` |
| FULL package build at `f6ccd43` lock-free | `rc=0`, `kith-crm-f6ccd43…` (job 04E) |
| Build through the SystemNix lock | `rc=0` (job 050) |
| Service wire-up proof | `nix eval .#nixosConfigurations.evo-x2.config.services.crm-server.package.name` → `kith-crm-f6ccd43b2fd41888441215219f4d1b3ad682b9ae` |
| Infra follows survived the float | lock node keeps `flake-parts`/`go-nix-helpers` → root arrays, `nixpkgs` → root node, `docs-gates` → crm's own `docs-gates_2` |

Rationale recorded in `flake.nix`: the "vendorHash treadmill" that motivated the
2026-10-14 policy pin is dead — crm's own `vendorHash.nix` bakes the correct hash
from `c626704` onward, and four consecutive roll probes built green with **no**
consumer-side shim. Master advanced from `98cd15c` to `f6ccd43` within hours of
the roll, which is itself the argument against rev-pinning.

### 2. file-and-image-renamer: real root cause found, fixed upstream, pin lifted

The carried-over diagnosis ("the committed `vendor/` tree carries pre-regen
templ-components") was **wrong**:

- `vendor/` is **gitignored** upstream (`.gitignore:102`) — the nix build
  re-vendors every time, so no "committed vendor refresh" could ever be the LIFT
  condition.
- The real blocker: the repo's per-dep `*-src` flake pins had lagged its own
  `go.mod`. Nix's prepared source carries no `vendor/`; the build vendored from
  the flake-pinned local deps and compiled stale generated code.

Upstream fix, pushed as `cc4ed62a` (`ece22b9c..cc4ed62a` on master):

| Input | was | now |
| --- | --- | --- |
| templ-components-src | v1.26.0 (pre-regen) | v1.27.0 (v0.3.1100-regenerated) |
| cqrs-htmx-src | rev `357cdfc` | v4.16.0 |
| cmdguard-src | v5.0.0 | v5.1.0 |
| go-output-src | v0.38.5 | v0.38.7 |
| go-health-src | v0.8.1 | v0.10.0 |
| go-health-dashboard-src | v0.12.2 | v0.13.2 |
| go-datastar-src | v0.6.2 | v0.6.3 |
| go-sse-src | v0.6.2 | v0.7.0 |

- vendorHash re-derived: `sha256-b4OBzRC3EkTKfNUonBLos7d0NXafklDsbDslj7Txh3w=`.
- Clean-tree `nix build .#default` green (`rc=0`), `go build ./...` + `go vet ./...`
  green, pushed.
- SystemNix input flipped to `?ref=refs/heads/master`; lock at `cc4ed62`; package
  built **through the SystemNix lock** green (job 03C).
- Allowlist row removed with a correction note (the 2026-11-11 diagnosis was
  wrong about the mechanism).

### 3. Verification and documentation

- `nix flake check --no-build --all-systems` was **green** after the FIR lift
  ("all checks passed!", job 040).
- Lock diff audit (python node diff of the landed commit): only `crm` plus
  `file-and-image-renamer`'s OWN nested nodes changed
  (`cmdguard-src`, `cqrs-htmx-src`, `go-datastar-src`, `go-health-src`,
  `go-health-dashboard-src`, `go-output-src`, `go-sse-src`,
  `templ-components-src`, `file-and-image-renamer`). No foreign node touched.
- Pin-audit warnings in the final check: only hermes-agent, nixpkgs,
  nixpkgs-hermes, nixpkgs-llama-rag, paperless-gpt-src, qmd — **no crm row, no
  FIR row**.
- Docs updated: `docs/services/crm.md:13` (float + last verified `f6ccd43`),
  `docs/todo/upstream.md` (FIR row resolved `[x]` with the corrected mechanism;
  crm legs marked lifted in rows 260 and 264).

### 4. Cache hygiene

Stray 95 MB `file-renamer` binary produced by the local `go build` was trashed.

---

## b) PARTIALLY DONE

1. **Whole-tree verification gate.** The last two `nix flake check --no-build`
   runs are RED on the foreign module `modules/nixos/services/journal-mesh.nix`
   ("registered port(s) referenced by live units but never probed by any gatus
   endpoint: 4222 (journal-mesh)"). That file appeared mid-session and was
   committed by another session (`cb3a51577`). My surfaces eval clean
   (crm package name eval, pin audit, both package builds); the tree-wide verdict
   is not obtainable while that module is mid-flight.
2. **FIR test coverage.** I ran the nix package build, `go build ./...`, and
   `go vet ./...`. I did **not** run `go test ./...` (and the dep bumps touch
   healthd + filechange too, so a test run is worthwhile).
3. **Doc harvest.** I updated the owning rows but added no `CHANGELOG.md` entry
   for either pin event, and did not run the docs-health sweep.
4. **Upstream commit hygiene.** The two FIR commits are daemon-authored
   (`dda7a9a2`, `cc4ed62a`, "chore: auto-commit N changed file(s) (heuristic)") —
   the repo's own history is full of these, but the pin-alignment wave deserves a
   readable message.
5. **Runtime proof.** Nothing deployed: live crm still runs `9d96dad`, live FIR
   still runs `973dd383`.

---

## c) NOT STARTED

1. **Deploy** (`nix run .#deploy`) — pins are inert until a switch; crm and
   file-and-image-renamer both restart on it.
2. Post-deploy live probes: `crm.home.lan` login/OIDC path at `f6ccd43`,
   `file-and-image-renamer` health endpoints + a rename operation.
3. `nix flake check --all-systems` re-run at a quiescent moment (foreign module
   settled) for the final green verdict.
4. FIR `go test ./...` (with `-race` where feasible) at `cc4ed62`.
5. FIR CI wiring check: its `nix-check.yml` must still build after the dep bumps
   (the repo has CI, unlike most of the fleet).
6. Dep-pin-vs-`go.mod` drift gate upstream (the class that caused this whole
   incident) — no such gate exists in FIR.
7. `CHANGELOG.md` entries for both pin events.
8. `docs/services/file-and-image-renamer.md` cross-reference to the corrected
   mechanism (it had no pin text, so nothing was stale there, but the "vendor
   refresh" folklore lives on in the todo history row I annotated).
9. Pruning the resolved `[x]` row in `docs/todo/upstream.md` into CHANGELOG per
   TODO-system rules.
10. FIFO/`nix flake check --no-build` check for crm's own nested nodes after the
    float (crm has no infra dup, but the float means its nested inputs now move
    on every explicit update).

---

## d) TOTALLY FUCKED UP

1. **Commit race, self-inflicted.** I ran `git add <5 paths>` then
   `git commit -- <paths>` in this shared tree. The auto-commit daemon committed
   between the two, so my commit was a no-op ("no changes added to commit") and
   the work landed as three heuristic commits (`ad8fe3a0d`, `4613dc841`,
   `865e27458`). Correct form in this repo: **`git commit -m … -- <paths>` with
   no preceding `git add`**, or commit immediately after the edit pass.
2. **I did not challenge the deliberate pin** — I rolled `crm` forward to
   `98cd15c` inside the pin regime and only lifted it after the owner's "what?".
   The evidence against the pin was already on the table (four green rolls, no
   shim needed for any of them, upstream baking hashes). A policy pin that
   requires a manual re-roll per wave is a staleness generator: master moved from
   `98cd15c` to `f6ccd43` while I was verifying `98cd15c`.
3. **I trusted a prior report's mechanism claim** for FIR. The "committed vendor/
   tree" story was in the flake comment, the allowlist row, and two status
   reports; it is false (vendor is gitignored). I found it only because the nix
   build log pointed at a prepared source with no vendor dir. A 5-second
   `git check-ignore vendor/` would have settled it at the start.
4. **`vendorHash` measured on a dirty tree first.** The first derivation came back
   as `…-dirty-go-modules` (name carried `-dirty`); doctrine says measure on
   clean HEAD. It happened to be hash-valid (the vendor set does not depend on
   flake.nix text), but the correct order is commit the pin bump first, then
   derive, then paste — which is exactly why a clean re-derivation cycle was
   needed anyway.
5. **`nix flake check` never got a final green on the exact final tree** — the
   last green predates the crm float, and the post-float runs are blocked by a
   foreign module. I should have either waited for quiescence or proven my
   surfaces with a scoped eval (`nix eval` on the crm module) and stated the
   limitation plainly — which I did, but late.

---

## e) WHAT WE SHOULD IMPROVE

1. **Policy-pin re-justification is mandatory at every roll.** If the pin's own
   row says "re-roll per wave", the first question is "should this pin exist?"
   not "what is the new rev?".
2. **Consumer dep-pin audits.** The FIR failure class — a repo's flake `*-src`
   pins drifting from its `go.mod` — is generic across every consumer we build
   from a flake input. A tiny check (`go list -m all` vs flake input list, fail on
   version mismatch) belongs in each consumer repo and in `gogenfilter`-style
   tooling.
3. **Never repeat a mechanism claim without a source probe.** "Committed vendor/"
   was folklore. The rule that saved it — `git check-ignore` — is cheap enough to
   be part of the LIFT ritual.
4. **Vendor is not the unit of truth for nix Go builds.** In this fleet's
   `mkPreparedSource` pattern, the flake `deps` map decides what compiles, not
   the repo's vendor dir. Pin comments should say "deps map" where they now say
   "vendor refresh".
5. **Daemon-race commit discipline.** In a shared tree, pathspec-commit in ONE
   command; never stage-then-commit. After a daemon sweep, verify `git show --stat`
   before claiming your commit exists.
6. **Probe the tip at the moment of writing the comment.** Both pins were written
   with revs that were stale within hours; the comments should describe the
   mechanism (floats, upstream-baked hashes) rather than celebrate a rev.
7. **Status claims need their final check.** "Green" must name the command, the
   tree state, and the timestamp; a check that ran one commit earlier is not
   evidence for the final tree.
8. **Foreign-work acknowledgement.** I flagged the foreign `journal-mesh` module
   only in passing; the TODO system has no "this check is red for someone else's
   in-flight file" marker, which makes triage slow for the next reader.

---

## f) UP TO 50 THINGS TO GET DONE NEXT

1. Deploy with `nix run .#deploy` in a quiescent window (crm `f6ccd43` + FIR `cc4ed62`).
2. Post-deploy probe `https://crm.home.lan` (bare `/login` 303 → Pocket ID; `?manual=1` renders the page).
3. Post-deploy probe file-and-image-renamer `/status` + watcher `/healthz`; run one real rename.
4. Re-run `nix flake check --no-build --all-systems` once `journal-mesh` is gatus-covered.
5. Run FIR `go test ./...` at `cc4ed62` (root + `healthd` + `filechange`).
6. Watch FIR CI (`nix-check.yml`) on `cc4ed62`; fix red legs if any.
7. Author a dep-pin-vs-`go.mod` lockstep check in FIR (flake input versions == `go.mod` requirements).
8. Port the same lockstep check to the other prepared-source consumers (crm, inboxclean, DiscordSync, PMA, project-dependency-graph).
9. Add a CHANGELOG entry for the crm float and the FIR lift.
10. Prune the resolved FIR row from `docs/todo/upstream.md` into CHANGELOG.
11. Verify the crm `docs-gates_2` follow still points at the intended node after the float.
12. Re-measure the SystemNix lock size (node count) after the FIR input re-lock; note any regrowth.
13. Confirm crm's nested inputs (own lock) do not introduce nixpkgs duplication under our graph (`lib/lock-audit.nix` already gates it — record the count).
14. Decide whether crm should float on a tag instead of master once it cuts releases.
15. Add a "policy pin review" checklist item to `docs/agents/nix-flakes.md` (question the pin at roll time).
16. Update `docs/agents/nix-flakes.md` with the corrected FIR mechanism (deps map, not vendor).
17. Add the `git commit -- <paths>` daemon-race recipe to `docs/CONTRIBUTING.md` if missing.
18. Check whether `docs/services/file-and-image-renamer.md` should document the flake dep pin list.
19. Sweep other service runbooks for "committed vendor" claims that are actually gitignored.
20. Audit every remaining `REV-PINNED` allowlist row for "should this exist?" (crm and FIR are gone; the rest are nixpkgs/large-fleet pins).
21. Re-verify the `nixpkgs` pin LIFT condition (patchelf ≥ 0.19) — still blocking the fleet from floating.
22. Re-verify the `nixpkgs-hermes` pin after the patchelf fix lands.
23. Triage the foreign `journal-mesh` gatus-coverage failure (or hand it to the owning session).
24. Re-check `io-tier-coverage-audit` for journal-mesh (the log showed a second audit block above the gatus one).
25. Look at the `nix flake check` log for other new warnings introduced since 040.
26. Decide whether FIR should pin `templ-components` to v1.27.0 or track a branch.
27. Consider moving FIR's per-dep pins to a `versions.nix` single source (pin drift class).
28. Add a probe script (`scripts/probe-input.sh <input> <rev>`) that builds `packages.default` lock-free and reports rc — used 6× this session.
29. Add a "probe receipt" convention: record the drv name + rc in the pin comment (rev embedded in drv name).
30. Update the FIR upstream flake comment to say why each pin matches `go.mod`.
31. Check `go.sum` coherence after the FIR dep bumps (`go mod verify`).
32. Run FIR `govulncheck` (disabled in its flake) manually once after the bumps.
33. Confirm the healthd submodule's vendored templ-components copy (its build-time `cp -r` at flake.nix:1037) still resolves the regenerated tree.
34. Consider dropping the healthd vendor copy step if it is redundant.
35. Add a negative test/fixture for "flake pin lags go.mod" in FIR's CI.
36. Verify crm's `?ref=refs/heads/master` float does not re-encode follows on the next targeted update (lock-edge reuse trap).
37. Record the crm float in `docs/agents/go-ecosystem.md` as the end of the deliberate-pin era.
38. Check `docs/todo/services.md:1134` (auto-forward evaluation row) still describes the crm reference correctly.
39. Look for other docs claiming crm is pinned (grep sweep).
40. Look for other docs claiming FIR is at `973dd383` (grep sweep).
41. Verify the `nix run .#deploy` gate state (IO PSI) before attempting the deploy.
42. Confirm `crm-server` restart block in `scripts/deploy.sh` is active-gated (it should restart on the new rev).
43. Confirm `file-and-image-renamer` restart block likewise.
44. Post-deploy: verify the crm ledger DB opens (no migration happened) and the journal count matches pre-deploy.
45. Post-deploy: verify FIR's watcher still points at the same watched dirs.
46. Watch SigNoz/Gatus for 30 min after the deploy (crm + FIR error rates).
47. Check the crm `kith-crm` FOD is now in the nix store cache for the next deploy (it is, from the probe).
48. Add a status-report section template that separates "foreign blockers" from own work.
49. Re-run `git status` after the foreign session settles and confirm no stale untracked fixtures of mine remain (the `file-renamer` binary was trashed).
50. Consider a small `docs/status/` addendum if the deploy changes any live state this report claims.

---

## g) QUESTIONS I CANNOT ANSWER MYSELF (max 3)

1. **Deploy now?** The tree is verified but `journal-mesh` (another session's
   module) currently makes whole-tree `nix flake check` red. Deploying would
   restart crm + FIR onto the new revs; waiting keeps them on the old revs. Do you
   want the deploy fired now, or after that module is gatus-covered / the tree is
   quiescent?
2. **crm tracking form:** I floated `crm` on `?ref=refs/heads/master` (repo
   default policy). If crm will cut releases, do you want the input on a tag
   instead (and which cadence)?
3. **Upstream gate:** should I author FIR's flake-pin-vs-`go.mod` lockstep check
   (the class that broke this build) and land it in FIR CI, or keep that as a
   fleet-wide tooling task?

---

## Session evidence index

| Artifact | What it proves |
| --- | --- |
| `~/.cache/crm-tip-build.log` | crm `98cd15c` full package build rc=0 |
| `~/.cache/crm-tip-f6ccd43.log` | crm `f6ccd43` full package build rc=0 |
| `~/.cache/sn-crm-lockbuild.log`, `~/.cache/sn-crm-lock2.log` | crm builds through the SystemNix lock, both revs |
| `~/.cache/fir-build1.log` … `fir-build5.log` | FIR failure modes → pin alignment → clean green |
| `~/.cache/fir-build2.log` | stale vendorHash `specified/got` pair before re-derivation |
| `~/.cache/sn-fir-lockbuild.log` | FIR package green through the SystemNix lock |
| `~/.cache/fc-pinupdate.log` | `nix flake check --no-build --all-systems` green after the FIR lift |
| `~/.cache/fc-crm-float.log`, `fc-crm-float2.log` | post-crm-float check, blocked only by `journal-mesh` port 4222 |

**Commits (SystemNix):** `ad8fe3a0d` (crm rev 98cd15c + audit row),
`4613dc841` (FIR lift: flake.nix/lock/audit/docs), `865e27458` (crm float +
lock `f6ccd43` + row removal), `09664af09` (docs: crm.md + upstream.md).

**Upstream (file-and-image-renamer):** `dda7a9a2` (first pin batch),
`cc4ed62a` (aligned pins + vendorHash), pushed `ece22b9c..cc4ed62a`.
