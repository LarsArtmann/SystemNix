# Status Report: clean-wizard → evo-x2 investigation & upstream fix

**Date:** 2026-09-23 01:15 CEST
**Scope:** This session only (per instruction): the "why is /home/lars/projects/clean-wizard not added to evo-x2?" question, the investigation, the upstream fix, and everything noticed along the way. No repo-wide sweeps were run.
**Format note:** Written as `.md` per your explicit instruction — the status-report skill's canonical format is a styled HTML dashboard; your `.md` request wins for this report (one-off override, not propagated into the skill).

---

## Direct answers to your three questions

**What did you forget?**
1. **The `~/go/bin` shadow check** (2026-09-22 doctrine: stray `go install` binaries shadow system tools). Only ran it during report prep — result: no `clean-wizard` in `~/go/bin`, so harmless *this time*, but the check belonged in the original verification pass.
2. **The test suite.** I verified `packages.default` builds and the binary prints a version — I never ran `checks.test` (go test) or `checks.go-vet`. `nix flake check --no-build` does not build them. "Fix verified" is overstated by exactly that margin.
3. **Clean-HEAD proof of the vendorHash.** I measured `sha256-nT7i…` against a dirty tree and justified it with reasoning (flake.nix sits outside `src`'s fileset, so the FOD module set is identical). The reasoning is almost certainly right; the doctrine says prove it with a clean worktree build. I reasoned where I should have measured.
4. **Concurrent-session awareness, late.** A parallel session is actively committing in clean-wizard (3 daemon commits + an untracked ADR *after* my fix). I was briefly confused when `git diff` showed only 1 line of my 2-line fix — I checked `git log` second instead of first (the multi-agent rule is check-the-log-FIRST).
5. **CI assumption.** I carried the CV dead-CI bias into the todo row and never checked whether clean-wizard has CI. It does (`release.yml`, `type-safety.yml`, `website.yml`) — which makes the post-push signal story *better* than I wrote, and raises a new question: none of those obviously builds the nix flake, so the FOD break on master may be invisible to CI.

**What could you have done better?**
- The `flake.nix` edit: I converted `pkgs.buildGoModule {…}` to the `.override { go = pkgs.go_1_27; } {…}` shape with a paired multiedit and got the bracket balance wrong — the first application **deleted the `in` line** and produced a parse error. Two follow-up edits to recover, plus two wasted build cycles. A single balanced edit (or `lsp_replace_symbol`) was the right tool.
- Atomicity: my two-line fix (toolchain override + vendorHash) got chunked by the daemon into commits `b5c782b` (00:58, override only) and `c167fb9` (vendorHash). Between those, HEAD was **unbuildable** (override active, hash stale). Had anyone built in that window they'd have hit a hash mismatch that looks exactly like a broken fix. Landing it as one deliberate commit (needs your commit authorization) kills that window.
- I stated "nix build green" cleanly at the time but should have tagged the claim with its exact tree state (`b5c782b` + dirty vendorHash), because 4 subsequent commits by other sessions mean today's HEAD `e2c08e5` is **not** a state I ever built.

**What could you still improve?**
- The split-commit/unbuildable-HEAD hazard is systemic (auto-commit daemon chunks multi-part fixes). Concrete fix: PATHSPEC-commit multi-line fixes myself when authorized; the daemon then has nothing left to chunk.
- clean-wizard has **no BuildFlow coverage** (no `.buildflow.yml`) — every other quality loop there is hand-run.
- The `go_1_27` override has **no drop-day note** in clean-wizard's AGENTS.md. Every toolchain override in this ecosystem carries one ("drop when nixpkgs default go ≥ 1.27") — without it, this becomes permanent invisible debt.
- The todo row cites the fix but not the final commit SHAs — rows and reality must not drift.

---

## a) FULLY DONE

| # | Item | Evidence |
|---|------|----------|
| a1 | **Root cause diagnosis** — two independent reasons: (1) never wired: zero references in SystemNix (no flake input, no `mkLarsPackages` entry; PATH flow is `lib/lars-packages.nix` → `platforms/common/packages/base.nix:368`); (2) upstream unbuildable: `nix build github:LarsArtmann/clean-wizard/master#default.goModules` died `go.mod requires go >= 1.27.1 (running go 1.26.7; GOTOOLCHAIN=local)` — the CV 2026-09-17 branch-ref-hold class | Probe output this session; go.mod line 3 `go 1.27` |
| a2 | **Upstream toolchain fix** — `clean-wizard = (pkgs.buildGoModule.override { go = pkgs.go_1_27; }) {…}` in `~/projects/clean-wizard/flake.nix` | Daemon-committed as `b5c782b` 00:58:24; still present (3 `go_1_27` occurrences at HEAD, extended by the concurrent session in `86a0559`) |
| a3 | **vendorHash refresh + green build + binary smoke** — hash `sha256-nT7iGAewpqNi1BNbG7BB+dYUR/2PUsVEsfOdDgSCMO0=`; `nix build .#default` green; `./result/bin/clean-wizard --version` → `clean-wizard version 2026.09.23-dirty (b5c782b)` | Store path `p0ll1w4…`; vendorHash now committed via daemon `c167fb9` |
| a4 | **Format check clean** — `nix fmt --no-update-lock-file -- --ci`: 213 files, 0 changed | Session output |
| a5 | **Fleet safety respected** — SystemNix deliberately NOT wired against the still-broken github master (`nix flake check` stricts every package; wiring a broken FOD reds the whole fleet — monitor365 removal class). SystemNix tree: clean, evals untouched | `git status` empty; all session changes daemon-committed (`b754da5d` 01:01 carries the todo row) |
| a6 | **Documentation breadcrumb** — `[blocked:push]` wiring row with the full push→input→`mkLarsPackages`→lock→check recipe in `docs/todo/upstream.md` | Row present (grep-confirmed), daemon-committed `b754da5d` |
| a7 | **Skill compliance** — buildflow loaded before Nix operations in the BuildFlow-covered SystemNix; status-report + brutal-self-review loaded for this report | This session |

## b) PARTIALLY DONE

| # | Item | Works now | Open gap | Blocker | Effort |
|---|------|-----------|----------|---------|--------|
| b1 | **clean-wizard buildability** | `packages.default` builds + binary runs at the `b5c782b`+vendorHash state; fix lines survive at HEAD | Test suite (`checks.test`/`go-vet`) never executed; current HEAD `e2c08e5` (4 daemon commits later, incl. concurrent-session churn) never rebuilt by me; vendorHash proven on a dirty-tree measurement only | None — all local | S |
| b2 | **The user's actual goal: clean-wizard on evo-x2** | Root-caused; upstream fixed locally; exact wiring recipe documented | Push (blocked) + SystemNix wiring (input, `lars-packages.nix` entry, lock update, deploy) not done | Push needs your authorization (harness forbids push without explicit request) | S after push |

## c) NOT STARTED

| # | Item | Why not started | Still wanted? |
|---|------|-----------------|---------------|
| c1 | Push of `~/projects/clean-wizard` master to origin | Harness: never push without explicit ask | Yes — it gates everything |
| c2 | SystemNix wiring: flake input `github:LarsArtmann/clean-wizard?ref=master`, `clean-wizard = flakePkg inputs.clean-wizard;` in `lib/lars-packages.nix`, `nix flake lock --update-input clean-wizard` | Deliberate: upstream master on GitHub is still the broken rev; wiring now would red `nix flake check` fleet-wide | Yes — the todo row carries the recipe |
| c3 | Deploy to evo-x2 + post-deploy `command -v`/`--version` smoke | Depends on c1+c2 | Yes |
| c4 | clean-wizard AGENTS.md drop-day note for the `go_1_27` override | Discovered as a gap only while writing this report | Yes (S) |
| c5 | BuildFlow adoption in clean-wizard (`.buildflow.yml` + `buildflow precommit install`) | Out of session scope; repo currently uncovered | Owner call |

## d) TOTALLY FUCKED UP

| # | What | Severity | Root cause | Mitigation |
|---|------|----------|-----------|------------|
| d1 | **My first multiedit broke clean-wizard's `flake.nix`** — deleted the `in` line while converting the `buildGoModule` call; parse error, 2 fix cycles, 2 wasted builds | Minor, fixed in-session | Paired-edit shape mismatch (bracket balance not thought through) | None needed; lesson in (e) |
| d2 | **Transient unbuildable HEAD** in clean-wizard: `b5c782b` (00:58, go_1_27 + OLD vendorHash) landed ~minutes before `c167fb9` (vendorHash) — anyone building in that window got a hash mismatch that looks like a broken fix | Medium (window closed, self-healed) | Daemon chunks multi-part fixes into separate heuristic commits | Land multi-line fixes as one deliberate PATHSPEC commit (needs your commit authorization) |
| d3 | **github master of clean-wizard is STILL broken** (the original `go >= 1.27.1` FOD failure) and I cannot verify CI would catch it — none of `release.yml`/`type-safety.yml`/`website.yml` obviously builds the nix flake | Medium (standing upstream red until push) | Pre-existing; the fix exists only locally | Push (gated on you); consider adding a nix-build CI job |
| d4 | **Untracked `docs/adr/` in clean-wizard** (`0001-evaluate-go-dag-app-adoption.md`) — invisible to the daemon's commit sweep, invisible to flake sources | Low | Untracked dirs need explicit `git add` | Concurrent session's business — coordinate, don't touch |

Nothing in SystemNix was damaged: no broken evals, no broken flake check, tree clean, no unintended commits authored by me.

## e) WHAT WE SHOULD IMPROVE

1. **Edit-shape discipline:** whole-expression conversions (`f {…}` → `(f.override {…}) {…}`) must be one balanced edit or `lsp_replace_symbol` — never paired multiedits where the second edit's anchor is the first edit's own output.
2. **Daemon-era git hygiene:** check `git log` BEFORE interpreting an unexpectedly small `git diff`; on this box the working tree is never solely mine. Cost this session: one confused roundtrip.
3. **Atomic fix commits:** multi-line fixes that must land together (override + hash) should be PATHSPEC-committed deliberately, or the daemon will split them and mint a transient broken HEAD.
4. **Verification claims carry tree-state stamps:** "build green" must name the exact rev it applies to — 4 daemon commits later, the claim had quietly expired.
5. **VendorHash doctrine adherence:** even when reasoning says the dirt is outside `src`, the 30-second clean-worktree build is cheaper than being confidently almost-right.
6. **Drop-day notes on every toolchain override** — the CV/go-tarball history shows unpruned overrides become invisible debt; write the drop condition into the repo's AGENTS.md at the same commit as the override.
7. **Shadow-check reflex:** any "add tool to PATH" work includes the `~/go/bin` shadow check in the first pass, not during report writing.

## f) Next tasks (up to 50; brainstorm, not commitment — HARVEST fuel for docs-health)

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 1 | Push `~/projects/clean-wizard` master (through `e2c08e5`) to origin — **needs your authorization** | Critical | S | Feature |
| 2 | Before push: confirm with the concurrent clean-wizard session (ADR writing, `86a0559`/`403da09`/`e2c08e5` churn) that pushing now doesn't carry their half-done WIP | High | S | Process |
| 3 | After push: verify GitHub CI green on the new HEAD (`type-safety.yml`, `release.yml`) | Critical | S | Quality |
| 4 | Audit whether any clean-wizard workflow builds the nix flake; if none, add a nix-build job so the FOD-breaks-master class is caught upstream | High | M | Quality |
| 5 | Add flake input `clean-wizard = github:LarsArtmann/clean-wizard?ref=master` to SystemNix `flake.nix` | Critical | S | Feature |
| 6 | Add `clean-wizard = flakePkg inputs.clean-wizard;` to `lib/lars-packages.nix` (alphabetical slot) | Critical | S | Feature |
| 7 | `nix flake lock --update-input clean-wizard` | Critical | S | Feature |
| 8 | `nix flake check --no-build` fleet-green after wiring | Critical | S | Quality |
| 9 | Build the package FROM OUR LOCK post-lock-move (`builtins.getFlake … inputs.clean-wizard.packages.x86_64-linux.default`) per doctrine | High | S | Quality |
| 10 | Decide + record nixpkgs-follows posture for the input (recommend NO follows — vendorHash-stability doctrine, qmd/papdashboard precedent) | Medium | S | Documentation |
| 11 | Deploy evo-x2 (`nix run .#deploy`) | Critical | M | Feature |
| 12 | Post-deploy: fresh shell `command -v clean-wizard` + `--version`; assert the SYSTEM copy serves it (which-entity-served doctrine) | High | S | Quality |
| 13 | Re-run current clean-wizard HEAD (`e2c08e5`) build + smoke — my green predates 4 later commits | High | S | Quality |
| 14 | Run the full clean-wizard check suite incl. tests (`nix flake check` full → `checks.test`, `checks.go-vet`) — never executed | High | S | Quality |
| 15 | Prove vendorHash against a clean worktree at the fix rev (`git worktree add`) | Medium | S | Quality |
| 16 | Flip the `docs/todo/upstream.md` row `[blocked:push]` → `[ready]` immediately after push (unblocks tq harvest) | Medium | S | Documentation |
| 17 | After wiring verified: mark the row `[x]`, prune to CHANGELOG per todo-system rules | Medium | S | Documentation |
| 18 | Verify aarch64-darwin build BEFORE the Mac inherits it via `base.nix` (`mkLarsPackages` is shared; `nix flake check` skips darwin) | High | M | Quality |
| 19 | Commit or trash clean-wizard's untracked `docs/adr/` (owning session's call) | Medium | S | Cleanup |
| 20 | Add drop-day note for the `go_1_27` override to clean-wizard AGENTS.md (drop when nixpkgs default `buildGoModule` go ≥ 1.27) | Medium | S | Documentation |
| 21 | Reconcile the 3 `go_1_27` occurrences at HEAD — the concurrent session extended my 1; verify intent, no split-brain in `flake.nix` | Medium | S | Quality |
| 22 | Reconcile the todo row's Source pointer with final SHAs (`b5c782b`, `c167fb9`, SystemNix `b754da5d`) | Medium | S | Documentation |
| 23 | Adopt BuildFlow in clean-wizard (minimal `.buildflow.yml` + `buildflow precommit install` — fleet convention) | Medium | M | Quality |
| 24 | Functional smoke beyond `--version`: run clean-wizard's actual scan/dry-run once in a sandbox dir | Medium | S | Quality |
| 25 | Tag a clean-wizard release once CI green (enables tag-pinning later, exercises `release.yml`) | Low | S | Release |
| 26 | Check clean-wizard's own pinned nixpkgs (its flake.lock) is recent enough to keep shipping `go_1_27` on ITS bump cadence | Low | S | Quality |
| 27 | Confirm the treefmt `checks.format` gate is wired into clean-wizard CI so format drift can't land | Low | S | Quality |
| 28 | HARVEST this report's (f) items into `TODO_LIST.md`/`ROADMAP.md` via docs-health (waiting for your go) | Medium | S | Documentation |
| 29 | On the Mac (if Q2 = yes): after next darwin deploy, `clean-wizard --version` parity check | Medium | S | Quality |
| 30 | Audit PATH overlap: `superfile` and any other disk-cleanup tools vs clean-wizard's job (avoid tool duplication) | Low | S | Cleanup |
| 31 | Skim `docs/adr/0001-evaluate-go-dag-app-adoption.md` when its session lands — it may affect the flake shape I wired against | Low | S | Documentation |
| 32 | Evaluate wiring clean-wizard into the box's QLC/SLC-cleanup doctrine (scheduled dry-run report) — only after checking overlap with existing cleanup scripts (scope-creep gate) | Low | L | Feature |
| 33 | Add clean-wizard to SystemNix AGENTS.md only if a non-obvious gotcha emerges at wiring (else `lars-packages.nix` is self-documenting) | Low | S | Documentation |
| 34 | If BuildFlow lands there (23): let `nix-hash-fix` own future vendorHash drift instead of manual pastes | Low | S | Quality |
| 35 | Consider a PATHSPEC-commit convention note for multi-line fixes in SystemNix AGENTS.md (multi-agent section) — generalizes lesson d2 | Medium | S | Documentation |
| 36 | Re-check `~/go/bin` shadow for clean-wizard at deploy time (none today; it's a point-in-time fact) | Low | S | Quality |
| 37 | When wiring (5-7): keep the edit + lock update in ONE commit so `nix flake check` never sees input-without-entry or entry-without-lock | Medium | S | Process |
| 38 | If the concurrent session also touched `flake.nix` inputs, re-run `git log -S go_1_27` before wiring to re-baseline what master actually carries | Medium | S | Process |
| 39 | After deploy, verify no `system_service_state` impact — CLI tools add no units; confirm pre-deploy §10 loan list unchanged (no new metrics expected) | Low | S | Quality |
| 40 | Close the loop on this report: annotate (docs-health ANNOTATE mode) once push+wiring land, linking the wiring commit | Low | S | Documentation |

Items 41-50 intentionally unused — the honest list stopped at 40; padding would dilute HARVEST routing.

## g) Three questions I cannot answer myself

1. **Push authorization:** May I push `~/projects/clean-wizard` master (through `e2c08e5`, which includes my `go_1_27` + vendorHash fixes AND three later daemon commits from a concurrent session) to origin now? Everything else in the chain is unblocked on this one yes/no. If yes — before or after coordinating with that other session?
2. **Darwin scope:** Should clean-wizard ride PATH on `Lars-MacBook-Air` too? `mkLarsPackages` is shared, `platforms/common/packages/base.nix` feeds both hosts, and I cannot verify an aarch64-darwin build from this x86_64 box — so if it ships to the Mac, the first real signal is on the machine itself.
3. **Concurrent session in clean-wizard:** Someone (another agent session or you) is actively committing there right now — 3 daemon commits after my fix, 2 additional `go_1_27` references in `flake.nix`, and an untracked ADR proposing "go-dag app adoption". Is that work coordinated with this wiring effort (i.e., should I re-baseline against their HEAD before pushing/wiring), or unrelated churn I should simply push past?

---

**Next step per the status-report skill:** section (f) is HARVEST input for `docs-health` (TODO_LIST/ROADMAP). Awaiting your instructions — the P0 item is already tracked as the `[blocked:push]` row in `docs/todo/upstream.md` (daemon commit `b754da5d`).
