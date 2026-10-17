# Status: shim fleet extinct — full wrap-up of the second pass + tail lessons

**When:** 2026-10-18 01:46 CEST (fifth and consolidating report of the session chain; supersedes the draft at `2026-10-18_01-44_shim-fleet-extinct-second-dropcycle-pass.md` — same content plus the tail deltas; that draft file stays, this is canonical)
**Session arc this report covers:** the owner's three answers executed ("upstream bumps" / "run now" / "green enough") through the second drop-cycle pass, its incidents, and the tail close-out.
**Format note:** `.md` per explicit dispatch demand (standing pattern, not propagated).

---

## TL;DR

The consumer-side vendorHash shim fleet is **EXTINCT**: all 21 historical shim sites across the LarsArtmann fleet are shim-free (only `crush-daily` remains in `overlays/linux.nix` — a different wave, never in scope, plus the `flakePkgShim` helper/class-doc comments which are documentation). The second pass dropped the remaining 8: six bit-neutral, branching-flow evidence-based (green against upstream's own two package hashes), erraudit via **root convergence** (their channel lock drifted onto our exact root `55bfb4d` — the owner's root-bump choice was moot; no push needed). One more upstream fix pushed (file-and-image-renamer `f3f0b82` — its tip moved mid-pass and the graph changed). Final state: toplevel `--keep-going` **exit 0**, `nix flake check --no-build` **all checks passed**, all 14 flake-attr packages green individually. The sweep-surface doctrine expansion landed in `docs/agents/go-ecosystem.md` (six hash-literal surfaces, the overview misdiagnosis named as the class).

---

## §a FULLY DONE

| # | Item | Evidence |
|---|------|----------|
| a1 | **The 8 remaining shims dropped** — 6 bit-neutral (upstream locus == shim value, graph verified identical tip-vs-lock: go-structure-linter, project-dependency-graph, project-discovery-daemon, samber-linter, go-auto-upgrade, file-and-image-renamer) + branching-flow (re-locked to tip `f129ca8a`, neither upstream hash matched the shim → evidence-based drop, arbiter validated) + erraudit (root convergence, see a2) | edits across `lib/lars-packages.nix`, `overlays/linux.nix` |
| a2 | **erraudit resolved without a push** — its channel-tracking nixpkgs lock had already drifted onto `55bfb4d` (== our root), closing the follower divergence: input re-locked `98827233→0cc8ee2c`, upstream's baked `rIf6DO2D…` governs. FRAGILITY DOCUMENTED: when nixos-unstable moves past our root, the class re-fires — erraudit is the canonical follower-case watch | upstream.md row ticked with the standing-watch note |
| a3 | **file-and-image-renamer mid-pass re-float handled** — tip moved `8b8d84e9→40176d0` between my graph check and the re-lock (graph changed); fresh got `4fF/8VOw…` pasted upstream, pushed `f3f0b82`, re-locked. The pdd two-round lesson materialized live and the flow absorbed it in one round | push output; final build green |
| a4 | **Full verification** — 14 dropped-shim flake-attr packages build green individually (`/tmp/pkg-builds.log`, exit 0 — the scope-isolator that unblocked verification during the concurrent monitor365 eval-block); final toplevel `--keep-going` **exit 0** with zero errors + `flake check` **all checks passed** (`/tmp/toplevel-final4.log`) | logs; rev-stamped |
| a5 | **Doctrine landed** — `docs/agents/go-ecosystem.md` root-nixpkgs-drift paragraph now names ALL SIX hash-literal surfaces (lib/, modules/, platforms/, flake.nix, overlays/, systems/, flake/parts/) with the overview incident as the named class; harvested row ticked on both surfaces | doc diff; TODO_LIST + pipeline.md ticks |
| a6 | **All close-out surfaces clean** — erraudit row ticked (with standing-watch), sweep-surface row ticked, TODO-system validator "structure clean" | validator output |

## §b PARTIALLY DONE

- **b1. Deploy** — tree green at the post-everything lock; deploy + anchor check + post-deploy battery remain owner-run ("i will", hours ago; the tree has moved several times since — §g1).
- **b2. erraudit standing watch** — documented in the drop comment + ledger row, but nothing WATCHES it: no Gatus rule, no pre-deploy leg, no root-rev comparison anywhere automated. When nixos-unstable moves, the first signal will be a red FOD in someone's build (§f6).
- **b3. The tq attribution in the 23-48 report §i** — rows corrected, report table itself still says "re-float" without the sibling re-pin half (§j of that report supersedes; the table is unannotated).
- **b4. CHANGELOG prune** — the day's `[x]` rows (≈8 across two surfaces) await the docs-health pass.

## §c NOT STARTED

- **CI-restoration execution** (the treadmill's root) — untouched; today's clean closeout existed only because siblings hand-did the upstream half.
- **FOD rev-staleness guard** (pre-deploy leg) — re-proved needed today (cv ×2, file-and-image-renamer ×1).
- **Darwin verification** — never done for any of today's input moves.
- **go-cqrs-lite post-push CI check** (`853c9161`) — never verified.
- **jq agent-shell hygiene fix** — see §e1/§h (new).
- **Deploy + battery** — owner's.

## §d TOTALLY FUCKED UP

Nothing is broken: toplevel exit 0, all checks passed, zero active shims. The honest wounds, ranked by how much they cost:

1. **d1. The jq file-argument hazard bit THREE times in this continuation.** AGENTS.md documents it (direnv shells: file-arg jq breaks; stdin form works) and I used file-form repeatedly — `jq -r '...' flake.lock` returned `?`/null garbage twice, and the `.locks.nodes` vs `.nodes` SHAPE confusion (metadata JSON vs flake.lock) compounded it into a third strike. Each hit cost a debug cycle. The fix is a one-liner in the agent-shell config (§e1) — not queued until now (§h).
2. **d2. The verify→re-lock ordering raced itself.** For file-and-image-renamer I verified GRAPH-SAME at tip `8b8d84e9` and then re-locked onto `40176d0` — a tip that had moved in between — so the verification verified the WRONG rev and the build failed. Re-lock FIRST, verify at the actual locked rev: the correct order, learned at the cost of one failed build cycle.
3. **d3. `rm .git/index.lock` with a too-narrow process check.** My pgrep pattern (`git (commit|add|rebase|merge)`) missed the live plain `git push` (PID 430640 under an `mr` wrapper). Push doesn't take index.lock so the rm was harmless — but that's luck, not procedure. The lock itself WAS stale (25-min-old daemon leftover), so the action was right; the check was not.
4. **d4. Three malformed multiedit anchors** (omitted `name =` lines in the go-auto-upgrade, project-discovery-daemon, project-dependency-graph drops) left orphaned assignments that broke eval — caught by immediate grep + `nix eval` within the same pass, fixed in minutes, zero external exposure. The anchor discipline: include the full block, always.

## §e WHAT WE SHOULD IMPROVE

**Direct answers to the three questions:**

**What did I forget?**
1. **The jq hazard rule — three times.** Documented in AGENTS.md (shell-devtools section), applied zero times until the third hit. Documented lessons that aren't mechanical (aliases/wrappers) get forgotten under load — hence §e1.
2. **Two different JSON shapes.** `nix flake metadata --json` nests under `.locks`; `flake.lock` nests under `.nodes.root`. I conflated them mid-pass. The metadata shape is what the doctrine examples use; the raw lock is what I was reading.
3. **Ordering as verification.** Verifying a graph at a rev I was ABOUT to move is verifying a moving target — re-lock first, then the graph check is load-bearing.

**What could I have done better?**
1. Re-lock → verify at the locked rev → decide (the fir race disappears by construction).
2. Fix the environment once, early: the jq wrapper (§e1) would have deleted three debug cycles AND the flake.lock shape confusion (stdin form forces reading the actual file).
3. The multiedit anchor discipline: never anchor on a partial block when the block has a `name =` line — the three breaks were one mistake pattern replicated.

**What could we still improve? (pattern-level)**
- e1. **Agent-shell jq wrapper**: alias/wrap `jq` to `env -u DIRENV_DIFF jq` in every agent shell (crushrc/nix level) — the documented hazard is environmental, so the fix belongs in the environment, not in agent memory.
- e2. **Post-push CI verification as a named step**: an upstream commit isn't done at push; it's done at CI-green (where CI exists). Feeds CI-restoration.
- e3. **Package-level builds as the scope isolator** — when concurrent eval-audit work blocks the toplevel, `nix build .#<pkg>` isolates YOUR scope cleanly. Worth a line in the multi-agent discipline docs.
- e4. **FOD rev-staleness guard** — three live instances today (cv ×2, fir ×1).
- e5. **The fleet is shim-free — keep it that way**: the next `nix flake update` blanket move will re-stale upstream-pinned hashes wherever upstream lags; the CI-restoration row remains the only durable closure.

## §f TOP NEXT TASKS (up to 50 allowed; 20 grounded — filler would be noise; existing rows cited, not duplicated)

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 1 | **Deploy evo-x2** (owner, at a quiescent moment) + anchor check + `pre-reboot-check` + full `post-deploy-check.sh` | Critical | S | Process |
| 2 | **Post-deploy service sweep for the five re-locked services** (inboxclean, pma, crm, cv, overview — all rebuilt today) + signoz frontend serving | High | S | Process |
| 3 | **Wire the agent-shell jq wrapper** (e1): `env -u DIRENV_DIFF jq` at the crushrc/nix level; three strikes today justify the environment fix | Medium | S | Quality |
| 4 | **FOD rev-staleness guard** (existing pipeline row): store-name rev vs lock rev pre-deploy leg — four live instances today | Medium | M | Quality |
| 5 | **CI-restoration execution** (upstream.md durable row) | High | L | Feature |
| 6 | **erraudit root-divergence watch**: pre-deploy leg or textfile metric comparing nixos-unstable tip vs our root pin (the re-fire alarm for a2's fragility) | Medium | S | Quality |
| 7 | **crush-daily shim** (overlays): same evidence-pass treatment (its bun-lockfile FOD class is nastier — see the todo-list-ai row) | Low | M | Bug |
| 8 | **Shim ledger, final form**: now near-empty — a one-screen "live overrides" surface (crush-daily + tq's git/doCheck legs + class docs) plus the erraudit watch | Low | S | Quality |
| 9 | **go-cqrs-lite post-push CI check** for `853c9161` | Medium | S | Process |
| 10 | **Darwin verification** post-day's moves | Medium | M | Bug-risk |
| 11 | **rpi3-dns build verification** post-drop-cycle | Low | S | Bug-risk |
| 12 | **CHANGELOG prune** of the day's `[x]` rows | Low | S | Docs |
| 13 | **art-dupl behavioral check** — owner said "green enough"; revisit only if dedup output looks off (per their answer) | Low | Watch | Watch |
| 14 | **nix-email contract hardening** (tryEval-guard, carried from 05-39) | Medium | S | Quality |
| 15 | **Annotate the 23-48 §i d3 table** with the tq re-pin half (one line) | Low | S | Docs |
| 16 | **`git log -S` empty-result diagnosis** (carried from 00-40 §d2 — never reproduced) | Low | S | Bug |
| 17 | **Fmt scoping fix** (fourth+ data points recorded; the queued row is ready to execute) | Medium | M | Quality |
| 18 | **Post-drop-cycle re-verify before ANY deploy**: the tree moved twice during the passes; one §11 FOD preview at deploy time | High | S | Process |
| 19 | **Multi-agent discipline doc**: add the package-level-builds scope-isolator pattern (e3) + the mr-wrapped-git awareness to the index.lock hygiene note | Low | S | Docs |
| 20 | **Update go-ecosystem.md fleet-wave section** with the 2026-10-17/18 wave entry (doctrine's evidence chain stays current) | Low | S | Docs |

## §g QUESTIONS I CANNOT ANSWER MYSELF

1. **Deploy timing, re-confirmed** — the tree has moved several times since your "i will" (drop-cycle passes + foreign sessions all night). Is the deploy still yours to time (I hold), or do you want a §11 FOD preview + green re-stamp from me at a moment you name?
2. **crush-daily shim** — same evidence-pass treatment now, or leave it for its own wave? Its deps FOD is the bun-lockfile class (the todo-list-ai row documents frozen-lockfile breakage), so the pass is NOT purely mechanical.
3. **jq wrapper appetite** — the fix touches the agent-shell config (crushrc/nix, deployed via home-manager + crush-config repo). Wire it now, or doc-only until a quieter window?

---

## §h HARVEST RECORD (self-harvest at authoring time)

**Harvested NOW (direct follow-ups of this tail):**
- `docs/todo/pipeline.md` + TODO_LIST queue: **agent-shell jq wrapper** (e1/§d1) — `[ready]`, fix-in-environment doctrine applied to the documented direnv hazard.

**Deliberately NOT harvested, and why:**
- §f items 1/2 (deploy chain): owner-run, gated on §g1.
- §f item 7 (crush-daily): gated on §g2 (scope + the bun-lockfile nastiness).
- §f item 6 (erraudit watch): folded INTO the queue only if the owner wants automation beyond the ledger note — the note itself is already in the drop comment + row (done).
- §f items 3/4/5/8-20: existing open rows (CI-restoration, fmt scoping, FOD guard, nix-email hardening, jq-wrapper new) or owner-gated; cited, not duplicated.
- No unverified premise queued: every row cites this session's first-hand probes.
