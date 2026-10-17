SUPERSEDED-POINTED: completed and superseded same-hour by docs/status/2026-10-18_01-46_shim-fleet-extinct-final-wrapup.md (kept for the record).
# Status: shim fleet extinct — second drop-cycle pass, erraudit root-convergence, full green

**When:** 2026-10-18 01:44 CEST (fourth report of the session chain; covers the second drop-cycle pass — the remaining-8 shims — after `docs/status/2026-10-18_00-40_dropcycle-closeout-13-shims-dropped-full-green.md`)
**Session scope:** owner answers executed ("upstream bumps" for erraudit, "run now" for the remaining shims, "green enough" for art-dupl). No out-of-scope research.
**Format note:** `.md` per explicit dispatch demand (standing pattern, not propagated).

---

## TL;DR

**The consumer-side vendorHash shim fleet is EXTINCT.** The second drop-cycle pass dropped the remaining 8 shims (6 bit-neutral no-ops, branching-flow evidence-based, erraudit via root-convergence — the owner's "upstream bumps" outcome arrived for free because erraudit's channel lock had already drifted onto our root `55bfb4d`), pushed one more upstream fix (file-and-image-renamer `f3f0b82`, whose tip re-floated MID-PASS with a changed graph), re-locked everything to tips, and the final state is **toplevel `--keep-going` exit 0 + `nix flake check --no-build` all checks passed**. Zero active `vendorHash` overrides remain anywhere in the tree; the flakePkgShim helper + class comments survive as documentation. The sweep-surface doctrine expansion (six surfaces) landed in `docs/agents/go-ecosystem.md`. Honest process ledger this pass: one stale-graph re-lock race (caught by the arbiter, one cycle), three malformed multiedit anchors that briefly broke eval (self-caught in minutes), and an `index.lock` removal made on an incomplete process check (harmless, but the check pattern missed a live `git push`).

---

## §a FULLY DONE

| # | Item | Evidence |
|---|------|----------|
| a1 | **Correct enumeration under the orphan-node rule** — all 8 remaining inputs' lock revs read via `nodes.root.inputs` (branching-flow `55e54261`, go-structure-linter `25b9f6a7`, pdd `3e4b57f6`, samber `231a91b4`, go-auto-upgrade `88ccfef0`, fir `891150f1`, erraudit `98827233`), live-session scan clean (no agent cwds in any target repo), all 8 checkouts present. | `/tmp/sfm2.json`; /proc probe |
| a2 | **6 bit-neutral drops** — upstream locus == shim value at tips, go.sum+go.mod verified identical tip-vs-lock for every one: go-structure-linter, project-dependency-graph, project-discovery-daemon, samber-linter, go-auto-upgrade (lars-packages.nix), file-and-image-renamer (overlays/linux.nix). Drop-protocol comments left. | per-repo `rg` + git-show comparisons |
| a3 | **erraudit resolved via root-convergence** — owner chose "upstream bumps"; discovery showed erraudit's OWN channel-tracking nixpkgs lock had already drifted onto `55bfb4d` == our root, so the follower divergence was transiently closed: re-locked `98827233→tip 0cc8ee2c`, shim dropped, upstream's `rIf6DO2D…` governs, build green. **Standing watch documented** in the drop comment + row: nixos-unstable moving past our root re-fires the class. | flake.metadata probe; erraudit row ticked both-wording |
| a4 | **branching-flow dropped evidence-based** — neither upstream tip hash matched the shim (`0IxhvfLi…` was measured at an older rev); re-locked to tip `f129ca8a` and the arbiter validated upstream's own two package hashes (`fFMTnbQ6…`/`hGfwb0GZ…`). NOT bit-neutral — the build was the evidence. | toplevel log |
| a5 | **file-and-image-renamer: live two-round execution** — tip re-floated `8b8d84e9→40176d0` after my graph check; fresh got `4fF/8VOw…` extracted from the arbiter failure, pasted upstream, pushed `f3f0b82`, re-locked, green. The pdd two-round lesson materialized and the flow absorbed it in one extra round. | push output; final build |
| a6 | **Full green at final state** — 14 dropped-shim flake-attr packages build standalone (exit 0); toplevel `--keep-going` **exit 0 / zero errors**; `flake check --no-build` **all checks passed**. | `/tmp/pkg-builds.log`, `/tmp/toplevel-final4.log` |
| a7 | **Doctrine landed** — docs/agents/go-ecosystem.md's two-surface rule expanded to the six-surface hash-literal sweep (lib/, modules/, platforms/, flake.nix, overlays/, systems/, flake/parts/) with the overview incident named; sweep-surface TODO row ticked on both surfaces. | go-ecosystem.md diff |
| a8 | **erraudit row closed with the standing-watch framing** (upstream.md, `[x]`); art-dupl behavioral-diff question answered "green enough" — no follow-up row needed. | upstream.md |

## §b PARTIALLY DONE

| # | Item | Works now | Remains | Effort |
|---|------|-----------|---------|--------|
| b1 | **Shim fleet** | ZERO active overrides; erraudit standing-watch + `crush-daily` (overlays, different wave — bun.lock FOD class, never in scope) are the only live entries | crush-daily's own evidence cycle (owner hasn't scoped it); the ledger is now mostly historical but still worth generating for the standing watches | S/M |
| b2 | **Deploy readiness** | Tree green post-drop-cycle; all packages + toplevel verified | Deploy + anchor + post-deploy battery — owner-run; foreign sessions were still annotating docs at last look (docs-only, no Nix impact) | S |
| b3 | **Attribution hygiene** | TODO rows corrected; §j/§k addenda written | The 23-48 report §i table still carries the incomplete tq attribution (superseded by §j but unannotated in-table) | S |

## §c NOT STARTED

- **Deploy + post-deploy battery** — owner-run.
- **CI-restoration execution** — the systemic fix; two clean closeouts today existed only because siblings hand-did upstream halves.
- **FOD rev-staleness guard** (pipeline row) — re-proved again THIS pass (fir moved between graph check and re-lock).
- **go-cqrs-lite push CI verification** (`853c9161`) + **file-and-image-renamer push CI** (`f3f0b82`) — neither checked.
- **Darwin verification** — still nothing for `aarch64-darwin`.
- **CHANGELOG prune** of the day's ticked rows.
- **crush-daily shim evidence cycle** — out of today's scope; not started (§g2).

## §d TOTALLY FUCKED UP

**Nothing is broken** — final state is fully green and verified. Process wounds, ranked:

1. **d1. The fir re-lock race.** I verified GRAPH-SAME at `8b8d84e9`, then re-locked — onto `40176d0`, which had moved in between and whose graph DIFFERS. One wasted build cycle (the arbiter caught it). The correct order per the doctrine's own two-round lesson: re-lock FIRST, verify graphs at the ACTUAL locked rev, then drop. My order was verify→re-lock, which races any live upstream.
2. **d2. Three malformed multiedit anchors broke eval in-tree** — two of my drop edits omitted the `name =` line from their old_strings, leaving orphaned assignments (`project-dependency-graph =` + a duplicate assignment) → `nix eval` syntax error at :229. Self-caught by immediate grep + eval within the same pass; no dispatch or build consumed the broken state. Root cause: editing from memory of the block shape instead of re-reading after the first failure.
3. **d3. `index.lock` removal on an incomplete process check.** My pgrep pattern (`git (commit|add|rebase|merge)`) missed a live `git push` (PID 430640, under an `mr` wrapper). The rm was harmless (pushes don't take index.lock; the lock was a 25-min-stale daemon leftover) but the verdict "no live git process" was WRONG when I acted on it.
4. **d4. The jq file-argument hazard bit twice more** — `jq '.locks…' flake.lock` (file form) returned garbage/null in the direnv shell; the documented stdin-form workaround exists and I used the broken form anyway, twice, before switching.

## §e WHAT WE SHOULD IMPROVE

**Direct answers to the three questions:**

**What did I forget?**
1. **Re-lock before verify** — the graph identity I checked was for a rev I then didn't lock. The doctrine's two-round lesson exists precisely for moving targets; I applied it for the FAILURE round but not the FIRST round.
2. **The jq hazard** — AGENTS.md documents the direnv jq file-arg failure with the exact fix (stdin form / `env -u DIRENV_DIFF`); I used the broken form twice more.
3. **Broad process patterns** — `git push` is a git process; pattern lists need the whole verb space or `pgrep -af git`.

**What could I have done better?**
1. Re-lock → verify-graphs-at-locked-rev → drop (kills the race class entirely).
2. After the FIRST malformed anchor, re-read every remaining anchor before applying (I fixed all three, but sequentially-reactively instead of once-diagnostically).
3. The erraudit discovery (roots already converged) could have been checked BEFORE asking the owner the terminal-state question — the "upstream bumps" answer selected a path that was already 90% taken. A 10-second `jq` of erraudit's lock nixpkgs rev would have refined the question.

**What could we still improve? (pattern-level)**
- e1. **jq stdin-form discipline** — an agent-shell alias/wrapper (`jq` → `env -u DIRENV_DIFF jq` or a fish function forcing stdin form) would kill this recurring class at the root. Harvested (§h).
- e2. **The shim ledger is now nearly moot but the WATCH list isn't**: erraudit (follower re-fire when unstable moves) + crush-daily + the drop-condition comments deserve one generated surface; the fleet being extinct is exactly when the watch list matters most.
- e3. **CI-restoration** — both of today's upstream pushes (`853c9161`, `f3f0b82`) landed without CI verification; file-and-image-renamer may not even HAVE CI. The systemic row remains the fix.
- e4. **Re-lock-then-verify ordering** as written doctrine (one sentence in go-ecosystem.md next to the pdd two-round note). Harvested (§h).

## §f TOP NEXT TASKS (up to 50 allowed; 20 grounded — filler would dilute; existing rows cited not duplicated)

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 1 | **Deploy evo-x2** (owner, docs-only sessions aside) + anchor check + `pre-reboot-check` + full `post-deploy-check.sh` | Critical | S | Process |
| 2 | **Post-push CI verification** for `go-cqrs-lite 853c9161` + `file-and-image-renamer f3f0b82` + `art-dupl 41980118` (`gh run list` each; note which repos lack CI entirely — feeds CI-restoration) | Medium | S | Process |
| 3 | **crush-daily shim evidence cycle** (the last live override; bun.lock FOD class — nastier, budget accordingly) | Medium | M | Bug |
| 4 | **erraudit follower watch**: alert or pre-deploy leg when `nixos-unstable` moves past our root pin (re-fires the follower class) — pending §g3 | Medium | S | Quality |
| 5 | **jq stdin-form discipline at the shell root** (e1): alias/wrapper in the agent shell config killing the file-arg failure class | Medium | S | Quality |
| 6 | **Re-lock-then-verify doctrine sentence** (e4): add to go-ecosystem.md next to the pdd note | Low | S | Docs |
| 7 | **CI-restoration execution** (upstream.md durable row) — two pushes today with zero CI verification | High | L | Feature |
| 8 | **FOD rev-staleness guard** (pipeline row) — fired three times today (cv ×2, fir ×1) | Medium | M | Quality |
| 9 | **Shim/watch ledger** (23-48 §f5, now nearly moot for shims but the WATCH half grew: erraudit follower + crush-daily) | Medium | S | Quality |
| 10 | **Darwin verification** after the full day's moves | Medium | M | Bug-risk |
| 11 | **rpi3-dns build verification** | Low | S | Bug-risk |
| 12 | **CHANGELOG prune** of the day's ticked rows | Low | S | Docs |
| 13 | **23-48 §i tq attribution annotation** (one line) | Low | S | Docs |
| 14 | **Signoz post-deploy legs** after deploy | High | S | Process |
| 15 | **Gatus/SigNoz sweep for the five re-locked services** (inboxclean, pma, crm, cv, overview rebuilt today) | High | S | Process |
| 16 | **nix fmt scoping fix** — fifth occurrence today (69 files processed, 4 changed, 3 foreign); the data set is complete enough to justify the fix | Medium | M | Quality |
| 17 | **nix-email contract hardening** (tryEval-guard upstream shape reads; carried twice, still open) | Medium | S | Quality |
| 18 | **Dedupe the 10-15 "11 pending" list** — today's evidence says they're all landed upstream; one grep closes it | Low | S | Cleanup |
| 19 | **go-ecosystem.md: add the 2026-10-17/18 wave entries** to the fleet-wave section (evidence chain currency) | Low | S | Docs |
| 20 | **index.lock hygiene note**: stale-lock remedy + the mr-wrapper process-check pattern (`pgrep -af 'git|mr'`) in shell-devtools.md | Low | S | Docs |

## §g QUESTIONS I CANNOT ANSWER MYSELF

1. **Deploy timing** — you said "i will" hours ago; the tree has since moved twice more (drop-cycles + foreign sessions, docs-only since the last green stamp). Still yours to time, or do you want a §11 FOD preview from me at your go?
2. **crush-daily** — the last live shim, from a different wave (bun.lock FOD class, which resists the vendorHash playbook). Run its evidence cycle now, or leave it for a dedicated session?
3. **erraudit standing watch** — ledger note only (current state), or wire an actual alert (Gatus rule / pre-deploy leg) that fires when nixos-unstable moves past our root pin?

---

## §h HARVEST RECORD (self-harvest at authoring time)

**Harvested NOW (direct follow-ups of THIS continuation):**
- `docs/todo/pipeline.md` + TODO_LIST queue: **re-lock-then-verify doctrine sentence** (go-ecosystem.md, next to the pdd note) — `[ready]`.
- `docs/todo/pipeline.md` + TODO_LIST queue: **jq stdin-form discipline at the shell root** — `[ready]` (third-plus occurrence of the documented hazard).

**Deliberately NOT harvested, and why:**
- §f 1/2/14/15 (deploy chain): owner-run timing.
- §f 3 (crush-daily): gated on §g2.
- §f 4 (erraudit watch): gated on §g3.
- §f 5/6 (ledger, doctrine sentence): ledger carried by the 23-48 §f5 row; doctrine sentence harvested.
- §f 9 (git -S diagnosis): carried from the 00-40 report, still unreproduced.
- All other items live in existing rows (CI-restoration, fmt scoping, FOD guard, nix-email hardening) — cited, not duplicated.
- No unverified premise queued: every claim cites this session's first-hand probes.
