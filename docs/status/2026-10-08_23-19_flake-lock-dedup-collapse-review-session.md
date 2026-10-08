# Flake.lock dedup collapse + flake review session (dispatch: "review! and deduplicate")

**Date:** 2026-10-08 22:00–23:19 · **Verdict:** CORE WORK LANDED IN-TREE AND PROVEN AT LOCK LEVEL; commit attribution + eval battery + 2 of 5 work items remain, blocked on IO-PSI (storm live at avg10=69% at close — battery stays held per freeze doctrine).

Dispatch: `cat flake.nix flake.lock` + "review! and deduplicate". Mapped to the queued lock-hygiene family: TODO_LIST:485/486/487 (CHANGELOG entry for the 2026-10-02 dedup; flake-compat/git-hooks collapse; legacy-follows migration) + adjacent review rows (upstream.md:121 bank-sync alias, pipeline.md:174 go-health-dashboard, pipeline.md:42 dead systems overrides, pipeline.md:43 AGENTS.md audit naming).

**Headline numbers:** lock collapsed **454 → 444 nodes** (−10: 4× git-hooks + 6× flake-compat copies; both groups verified 1 distinct rev + 1 narHash pre-surgery, so the collapse is a no-op build-wise). Lock proven **byte-canonical**: a `nix flake lock` pass in a throwaway worktree reproduces the file with **zero diff**, and `nix flake metadata --no-update-lock-file` exits 0 (in-sync). Lock-audit standalone verdict `[]`. IMPORTANT REVIEW FINDING: the lock had **REGROWN to 454 nodes — past the 421 pre-2026-10-02-dedup high-water mark** (the 2026-10-02 dedup got it to 387; daemon waves + upstream input-set changes regrew +67). The deep-dup class (flake-parts 9×, treefmt-nix 6×, Go-dep tarballs 5–8×) is upstream-owned and already queued — the regrowth is fresh evidence that queue matters.

---

## a) What the review found (flake.nix + flake.lock as dispatched)

- **flake-compat 7 nodes / git-hooks 5 nodes, all at ONE rev each** (5edf11c4 / a0e4241b, narHash-parity 1:1) — the exact collapse the queue row prescribed.
- **The queue row's consumer list was subtly wrong** (corrected in the close-out): bank-sync/inboxclean/library-policy/overview/project-meta declare **git-hooks** (flake-compat arrives transitively through it); only dankMaterialShell + superfile declare flake-compat directly.
- **pipeline.md:174 (go-health-dashboard "stale node") premise is STALE**: all 5 `go-health-dashboard*` nodes have live parents at 5 distinct revs (discordsync/dnsblockd/root/library-policy/file-and-image-renamer); root maps to `_3`, not `_4`; no orphan exists; the spread is the deliberate own-pin class for a FOD-sensitive Go tool. Closed verified-stale.
- **pipeline.md:42 (10 dead `systems` overrides) already landed**: only flake-utils' and crush-daily's `systems.follows` lines remain and both are live declarations; zero "override for a non-existent input" warnings in a fresh metadata stderr sweep. Closed already-done.
- **bank-sync go-nix-helpers alias contradiction confirmed live** (upstream.md:121): lock edge aliases the root helper (`"go-nix-helpers": "go-nix-helpers"` string) while flake.nix declares non-follow. Chose option (a) — declare the follow honestly (zero behavior change; the alias IS the de-facto state since ≥2026-10-07, rebuilt green ×3 through helper rev moves). Worktree-canonicalized, not yet applied to the real tree.

## b) FULLY DONE (verified this session)

1. **W1 flake-compat + git-hooks collapse (TODO_LIST:486 / pipeline.md:45)** — root-promoted both inputs at the consumers' shared revs (rev-in-URL, documented bump protocol: git-hooks move changes 5 repos' pre-commit evals → `nix flake lock --update-input git-hooks` + `--all-systems` check); 7 consumer follows lines in the infra-follows group; `flake-compat`+`git-hooks` added to `lib/lock-audit.nix` infraDeps (+ header); lock hand-surgery via python (order-preserving) with graph integrity proven (no orphans, no dangling refs, reachability incl. the legal treefmt-nix↔art-dupl cycle). **The nested-edge trap caught and fixed**: root-promoting git-hooks WITHOUT following its internal `nixpkgs` + `flake-compat` makes a re-lock un-follow them (git-hooks locks its own nixpkgs-unstable 39ad350a + a floating flake-compat copy — the nixpkgs_3..9 renumbering cascade observed live in the worktree); both follows now declared. Canonical-form learnings encoded: `original`/`locked` keys sort alphabetically (rev before type), `root.inputs` sorted, follows = arrays.
2. **W4 CHANGELOG entry for the 2026-10-02 dedup (TODO_LIST:485)** — retrospective Added entry landed (421→387, infra-follows group, lock-audit + 5-leg selftest, hermes gate 9f75621d, deliberate-table semantics).
3. **W5 go-health-dashboard row closed** on both surfaces (TODO_LIST:538 + pipeline.md:174) with the corrected parent-map evidence.
4. **Row 42 (dead systems overrides) closed** as already-landed, verified.
5. **Row 43 (AGENTS.md prevention table names lib/lock-audit.nix) DONE** — eval-time row now names the gate in catches + where columns.
6. **Verification battery for the lock work (all but the deferred full check)**: standalone lock-audit `[]`; sync probe exit 0; worktree `nix flake lock` → byte-identical lock (zero diff, twice); flake.nix parse OK.

## c) PARTIALLY DONE (blocked — all on the same gate)

1. **W1 commit attribution** — the auto-commit daemon swept the in-flight work into **5 unpushed heuristic commits** (302b8579 → 63cd23eb → c6a96743 → 302b8579-chain → 6ec488ec → 7dd0d3f1; contents verified: ALL exclusively this session's files). Planned collapse (row-148 sanctioned shape): `git reset --soft origin/master` + two pathspec commits (W1: flake.nix/flake.lock/lib/lock-audit.nix; docs: AGENTS.md/CHANGELOG.md/TODO_LIST.md/docs/todo/pipeline.md). BLOCKED on PSI: the pre-commit hook runs the full flake-check battery the moment flake.nix is staged, and the box sat at avg10 43–69% all session (freeze-15/20/21 class — agent verification batteries into a storm).
2. **W2 bank-sync alias resolution (upstream.md:121)** — flake.nix follow line + canonical lock (incl. the node renumbering cascade Nix forces) validated in the worktree; honest-comment text drafted. Not applied to the real tree (sequenced after the W1 commit; same-file pathspec separation).
3. **W3 legacy-follows migration (TODO_LIST:487)** — python migration proven in the worktree: 125 per-block lines moved into the group, follows-set parity 168==168 EXACT, attached comments migrate with their lines (herdr rust-overlay + crm helper comments verified), parse OK, **lock re-derives byte-identical (zero diff — the no-op proof the row demands)**. Not applied to the real tree (post-W1/W2; then `nix fmt` + re-proof).
4. **Full eval battery** — `nix flake check --no-build` + evo-x2 toplevel eval: NOT run (PSI). One accidental launch was killed within seconds (see §d).
5. **Queue tick rows for 486/487** — deliberately NOT ticked: the rule says a `[x]` claims verification; the battery hasn't run.

## d) TOTALLY FUCKED UP (session mistakes — owned)

1. **Launched the eval battery into a live storm (twice-ish)**: `nix flake metadata` probes + one `nix flake check` ran while PSI was 50–61%. The flake-check launch was killed immediately after backgrounding (02C), but the PSI check should have happened BEFORE the command, not after — the freeze-15/20/21 doctrine exists precisely for this, and I wrote the gate myself two tool-calls earlier.
2. **Three lock-surgery bugs before canonical form**: (i) jq hyphenated bare keys parse as subtraction (`bank-sync` etc. — real jq; spent a debug round), (ii) python surgery deleted `root.inputs` entries without re-adding (caught by worktree canonical diff), (iii) inserted `original.rev` at the wrong key position (Nix sorts original/locked keys alphabetically). All caught by the worktree-canonicalize loop — the recovery pattern worked, but a pre-read of Nix's lock writer format would have made them zero-cost.
3. **Used the jq shim blind**: the bash tool's `jq` is gojq (no `-f`, no `--version`, SORTS object keys — would have silently reordered the whole lock). Loaded the jq skill only AFTER the failures instead of before the first write. Real jq lives at `/run/current-system/sw/bin/jq`; python json was the right order-preserving tool all along.
4. **W3 script round-1 bug**: form-A follows lines' attached comments were orphaned in the source blocks (herdr/crm) — caught by diff inspection, fixed with a lookback patch.
5. **Pre-commit-hook deadlock not anticipated**: I edited flake.nix knowing commits need the battery, while PSI was high — guaranteeing the attribution fragmentation I then had to manage. Committing W1 at a calm window BEFORE starting W2/W3 edits would have kept history clean.

## e) WHAT WE SHOULD IMPROVE (structural)

1. **Lock-node regrowth is unbounded**: 387 (2026-10-02) → 454 (2026-10-08). The eval-time audit guards ROOT-owned edges only — the regrowth is deep edges (upstream flakes' own infra copies) that only upstream `follows` can kill. The upstream queue row should carry the regrowth-rate evidence (67 nodes/week) as its priority argument.
2. **The worktree-canonicalize pattern should be doctrine** for ANY hand lock surgery: copy flake.nix+lock into a throwaway worktree, `nix flake lock` there, diff, adopt the output. It converts "did I encode Nix's canonical form correctly?" from a guess into a byte proof — this session's zero-diff proofs (W1, W3) and bug catches (root entries, key order, nested-edge un-follow) all came from it. Candidate for docs/agents/nix-flakes.md.
3. **Root-promotion of an input requires following its NESTED edges in the same change** — otherwise a re-lock silently un-follows them into fresh pins (observed: git-hooks → own nixpkgs-unstable + floating flake-compat). Worth one line in the nix-flakes.md infra-follows section.
4. **The commit-vs-PSI tension needs a policy answer**: pre-commit runs the full battery on nix-file commits; a session that lands nix work during a storm CANNOT commit cleanly and rides daemon fragmentation. Options: a PSI-aware hook fast-path (defer battery with a warning when avg10 > threshold), or an explicit "hold commits, batch at calm" runbook line.
5. **Status-report-age lock claims need timestamps**: the queue rows' premises (go-health-dashboard `_4`, "10 dead overrides") were both stale by days. The lock-rev half-life rule already exists — rows about lock SHAPE should cite their observation date the same way.

## f) NEXT (ordered; 1–10 are this session's direct completion chain)

1. PSI-calm window (avg10 < ~20 sustained) → run `nix flake check --no-build` + evo-x2 toplevel eval on the current tree.
2. Attribution collapse: `git reset --soft origin/master` + two pathspec commits (W1 code; docs) with attribution footers — single command chain to minimize the daemon race window.
3. Apply W2 to the real tree: bank-sync `go-nix-helpers.follows` line + honest comment; re-derive canonical lock in the worktree; adopt; sync-probe; commit (own pathspec commit).
4. Apply W3 to the real tree: run `/tmp/migrate-follows.py` (script content preserved in this report's session artifacts; re-verify parity + zero-diff in the worktree first), `nix fmt --no-update-lock-file`, commit.
5. Tick TODO_LIST:485/486/487 + pipeline.md:44/45/46 with evidence AFTER the battery; prune `[x]` rows to CHANGELOG per house rules.
6. CHANGELOG entry for TODAY's collapse (454→444, guard extension to flake-compat/git-hooks, nested-edge trap, regrowth finding).
7. Close upstream.md:121 (bank-sync) on both surfaces (row + nix-flakes.md doctrine note: the bank-sync exception to "never follow the helper into Go flakes", with the green-×3 evidence).
8. docs/agents/nix-flakes.md "Infra follows" refresh: flake-compat/git-hooks guarded; nested-edge rule; canonical-form notes (alphabetical originals, sorted root.inputs, arrays = follows); worktree-canonicalize pattern; 454-regrowth datapoint.
9. lock-audit-selftest: add a fixture leg exercising the NEW deps (a `git-hooks`/`flake-compat` dup edge must fail the audit — today's fixtures predate the extension, so the new infraDeps entries are untested in the selftest).
10. Harvest-check: confirm the deliberate table still has exactly its 3 live entries post-W2 (bank-sync needs NO deliberate entry — it follows now).
11. Upstream (queued already; add evidence): LarsArtmann tool flakes should follow flake-parts/treefmt-nix/etc. in THEIR flakes — the 67-nodes/week regrowth argues priority.
12. nix-fmt leg on the W3-migrated flake.nix specifically (collapsed blocks may need alejandra normalization) — the pre-commit formatter will catch it at commit; pre-formatting avoids a red hook.
13. Consider a `git-hooks`/`flake-compat` bump cadence note in the input comment once moved (the 5-repo pre-commit blast radius).
14. Sweep other root inputs whose upstream flakes declare git-hooks/flake-compat (any NEW LarsArtmann tool adopting pre-commit-hooks) — the audit now fails eval on regrowth, which IS the guard; just document that the fix is a group line.
15. Re-run the same-rev duplicate census after the next daemon lock wave — verify the collapse SURVIVES a wave (the audit should hold the line; observation confirms).
16. The `art-dupl` vs `art-dupl-src` root-input pair (same rev 46cc3f5d, fork ref vs default branch) — 1-node dedup possible but couples update semantics; left deliberately (note for the input-graph diet audit, pipeline.md:216).
17. nixpkgs 4× at a7868a7 — all accounted for by root + the 3 deliberate non-follows; no action (accept, documented).
18. Go-dep tarball dups (go-branded-id 8×, go-output 7×, gogenfilter 7×, …) — deliberate FOD-trap class, ACCEPT per doctrine; no action.
19. (from §e.4) Queue the PSI-aware pre-commit fast-path design row.
20. (from §e.2/§e.3) Queue the nix-flakes.md doctrine additions (worktree-canonicalize; nested-edge rule) — or land them with item 8.
21. Post-battery: `nix flake metadata --no-update-lock-file` exit-0 re-probe on the FINAL tree (post W2+W3) as the last sync gate.
22. If the storm persists >1h: consider sequencing the battery as the FIRST action of the next calm-window session instead (this tree is proven at lock level; the battery is confirmation, not exploration).
23. Verify the lock-audit selftest check still builds green in the full check (it evals inside flake check).
24. After commits land: `git log --grep` verification that no heuristic message claims this work (attribution rule).
25. Confirm CI-leg parity: pre-commit runs `--all-systems` per the 2026-09-28 doctrine — the battery item 1 should use the same flag set the hook uses.

(26–50 intentionally not padded — the above is the real list; everything else found this session is either closed in §b or accepted-deliberate in §a.)

## g) QUESTIONS FOR THE OWNER (cannot resolve from the tree)

1. **Attribution collapse sanction:** OK to `git reset --soft origin/master` and re-commit the 5 unpushed daemon commits as 2 pathspec commits (the row-148 owner-directed precedent), or do you prefer they stay as heuristic commits with attribution riding this report only?
2. **bank-sync (a)-vs-(b) confirmation:** I chose (a) — declare the helper follow to match the lock's de-facto alias (zero behavior change, helper bumps may re-hash bank-sync's FOD, got-hash protocol covers it). (b) would freeze bank-sync's helper at its own pin (one controlled FOD re-hash cycle now, +1 lock node, decouples it from fleet helper churn). Proceed with (a)?
3. **git-hooks/flake-compat pin posture:** both root pins are rev-in-URL at the consumers' shared revs (bump = deliberate + `--all-systems` check, documented in the input comment). Alternatively let them float (`?ref=master`) and accept that any lock wave can move 5 repos' pre-commit evals. Keep the deliberate-bump posture?

---

**Session artifacts:** migration script logic (form-A/B follows extraction, comment attachment, empty-`inputs={}` collapse, group generation — reproducible from §c.3 description), throwaway worktree `/tmp/sn-head-probe` (disposable; canonical lock copies `/tmp/flake.lock.pre-surgery`, `/tmp/canonical-v3.lock`, `/tmp/flake.nix.pre-w3`), lock surgery jq program `/tmp/surgery.jq`.

**Self-harvest note (per AGENTS TODO rules):** §f items 9 (selftest fixture leg) and 19 (PSI-aware hook fast-path) are genuinely NEW actionable items not yet in any queue — harvested into TODO_LIST/pipeline at authoring time; items 1–8 are this session's own completion chain (tracked here, not re-queued); item 11 and 16 extend EXISTING queued rows (noted on them).
