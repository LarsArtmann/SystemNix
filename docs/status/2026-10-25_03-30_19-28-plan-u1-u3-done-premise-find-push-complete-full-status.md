# 19-28 Plan Execution: U1–U3+U11/U12 Done, Premise-Find on T5, Push Complete — Full Status

**Date:** 2026-10-25 03:30 CEST (session ran 2026-10-24 ~19:28–20:05 + this report) · **Plan:** `docs/planning/2026-10-24_19-28_SUPERB-docs-truth-remainder-living-docs-completion-and-oct-wave-gates.md` (EXECUTING marker carries the done set) · **Predecessor report:** `2026-10-24_19-14_*` (T1–T4)
**Task:** user dispatch (plan authoring re-fire, then execute-and-verify re-fire) → authored the Pareto successor plan, executed every non-owner-gated task it defines, closed rows on both surfaces, pushed everything.

---

## a) FULLY DONE (all verified, gates green at each commit)

1. **19-28 SUPERB plan authored + U12** (`6ce9696cf`): Pareto decomposition (1% living-docs completion → 4% Oct stage 1 → 20% stages 2-3+tasks → rest tooling/canon), two-level task tables (12 macros, ~40 named micros + batch repeats), mermaid execution graph, 11-point Verschlimmbesserung contract (adds the commit-cadence + persist-at-decision + tail-truncation lessons). The 16-43 plan's T2–T4 ground-truth rows stamped EXECUTED and its tombstone flipped EXECUTED-superseded — same commit.
2. **U1/T5 — archive manifest, executed as MERGE after a premise-find** (`8dec2669a` daemon-1/3 + `a9e7383d2` mine-2/3, contents verified): **the 16-43 plan's "no dir-level manifest" premise was FALSE** — `docs/status/archived/README.md` has been a maintained manifest since ≤2026-10-12 (per-wave sections 2026-10-03+, conventions, a gate-drift finding note). The write tool refused my create-over-existing and caught it — the inherited-unverified-claim class for the THIRD time this mission (after "all-October" and the "contradictory w-verdicts"). Executed as merge: counts refreshed (1,457 status / 55 planning, re-derived), the 14 pre-2026-10-03 historical bulk waves table added (2026-07-30 `43c266837` through 2026-10-24 `f12302830` — the wave history its own sections lacked), future-waves convention note; every existing section preserved untouched. Premise corrected on 4 surfaces (16-43 table, 19-14 report §b.1, queue row, library row). Wave TSV persisted `~/.cache/docshealth/t5-waves.tsv` (the persist-at-decision rule, honored this time).
3. **U2 — FEATURES ✅-row sweep, full surface** (`e3d61ec36` daemon-6/7 + `9497cefab` mine-1/7): the "~90 un-flagged rows" estimate was wrong — **269 ✅ rows exist**; every one covered mechanically: 145 cited paths existence-checked (bare names tree-resolved), 57 service-module rows enable-evaled. **7 drifts fixed**: Docker row + image-updates CI row + check-image-updates.sh script row → 🚫 REMOVED (the 2026-10-08 Docker-removal residue FEATURES still carried — ROADMAP was cleaned in M5, these three survived); `monitoring.nix` ghost → `platforms/common/packages/base.nix`; `platforms/shared/dns-blocklists.nix` → `common/` (rename drift); dnsblockd "source in platforms/…" → flake input (flake.nix:194) + `dns-blocker.nix` module; **forgejo-repos ✅→🔧 DORMANT** (enable=false since 2026-09-18 — redundant vs the LIVE forgejo-github-sync 6h timer; the ✅ row was the wrong-done class, caught by the enable leg). 4 external-path citations verified false-positives (upstream-repo/runtime paths). Verdicts persisted `~/.cache/docshealth/u2-verdicts.txt`.
4. **U3/T13 — FEATURES header collapse** (`552a363c6`): 17 nested "(previous:" layers (5,403 chars) → 3 inline + verbatim "## Update history" footer (header now 1,247 chars). The line's paren chain was NEVER balanced (44 open vs 31 close — historical sloppiness), so the split is verbatim-preserving without rebalancing; the doc-counts gate anchors re-verified green on the new header (they live on lines 28/33, untouched — but verified, not assumed).
5. **U11 — residues**: `/tmp/statix-test.nix` + 8 scratch files trashed (`trash`, not rm).
6. **Row closes + plan progress marker** (`b21627a5e`): U2/T13 rows closed on BOTH queue surfaces with evidence; the 19-28 plan's EXECUTING marker now names the done set and warns against re-executing U1–U3 while U4–U10 stay owner-gated.
7. **Push — complete**: the authorized push (dispatch step 8) was interrupted before execution at the last dispatch boundary; verified state just now: a parallel session (the catalog work) had already pushed everything through `552a363c6` (my commits rode their push — push was authorized for me anyway), and I pushed the final `b21627a5e` — **remote fully synced, 0 unpushed**.
8. **Gates**: check-doc-links OK, check-todo-system structure OK (WARN 81 = verified wave surface), doc-counts gate eval-green post-header-collapse, all pre-commit legs green per commit.

## b) PARTIALLY DONE

| # | Item | Works | Missing | Why |
|---|---|---|---|---|
| 1 | U2 depth | every ✅ row mechanically covered: path existence + enable truth; 7 drifts fixed | prose-depth per row (each row's full claim text vs behavior) remains M4/T4-era verification only | mechanical depth catches the ghost/wrong-done classes (the dangerous ones) at 269-row scale; prose-depth × 269 is corpus-grade work with diminishing returns vs the wave |
| 2 | 19-28 plan | U1–U3, U11, U12 done; marker accurate | U4–U10 owner-gated (Q2/Q1/tooling-auth) — see c) | the owner gates ARE the plan's design |

## c) NOT STARTED (owner-gated — unchanged from the 19-14 report, pressure increased)

1. **U4–U6 Oct wave stages 1–3** (+22 Sept stragglers as batch 10-pre) — gated on **Q2**, asked 4× now.
2. **U7 tasks/ wave** — after U6.
3. **U8/U9 tooling upstream** (validator+prompt / relay → crush-config) — owner auth.
4. **U10/T12 canon** (Q1/Q3) + 10 held Sept candidates + 2 zero-strike files.

## d) TOTALLY FUCKED UP (owned)

1. **The authorized push was left unexecuted at the last boundary** — dispatch step 8 said push; the report interrupt arrived first and I yielded without finishing the standing authorized step. No harm (completed now; the parallel session's push had already carried most of it), but the discipline is: finish authorized mechanical steps before yielding to a report dispatch.
2. **The T5 premise was MY OWN unverified claim this time** — not inherited: at 19-14 I wrote "the README itself (waves table + sweep pointer + link) not yet written" without ever `ls`-ing the target directory. The inherited-unverified-claim class (which I had just spent T1/T2 hunting in OTHERS' reports) reproduced under my own pen one report later. Caught by the write tool's staleness check, not by my discipline. This is the session's most instructive failure.
3. **The "~90 ✅ rows" estimate in my own queue row** — the real count is 269. Count-before-claim violated in a row I authored hours after writing the rule down in a report.
4. **Three more daemon race splits** (U1: 1+2 files, U2: 6+1 files, plus the U3 clean commit) — pathspec-early discipline kept every split verifiable (each verified with `git show --stat` before amend/move-on), but history readability suffers; contents never lost.

## e) WHAT WE SHOULD IMPROVE

1. **`ls` the target before writing "doesn't exist"** — premise-checks are not just for inherited claims; the cheapest verification in the whole toolbox defeats the most embarrassing failure class.
2. **Count the rows when the row-count is the claim** — `grep -c` before writing N.
3. **Finish standing authorized steps before yielding** (the push).
4. **The mechanical ✅-row sweep pattern is now proven** (paths + enables = 269 rows in ~35 min): extend it with a standing variant? A `checks.features-drift` eval gate could re-derive the enable-truth for the service rows the way doc-counts does for counts — candidate for T10's upstream batch.
5. **Daemon-split commits are now the norm, not the exception** (7 splits this mission): the close-out discipline of verifying + citing both halves (daemon hash + mine) each time is what keeps history honest — keep it mechanical.

## f) NEXT — ordered (harvest state: 1 is NEW, harvested in this commit; 2–4 [tracked] continuations; 5 [watch])

1. [harvested] **Standing FEATURES enable-drift gate** (e.4): `checks.features-drift` evaling `services.<name>.enable` for every FEATURES service row's ✅/🔧 state, fail on mismatch — kills the forgejo-repos class permanently; negative-test leg. → docs/todo/pipeline.md
2. [tracked] U4–U7 October wave + 22 Sept stragglers — pipeline.md [decision] row; owner gate Q2.
3. [tracked] U8/U9 tooling upstream (crush-config) — owner auth; now includes the doc-counts gate template + the enable-drift pattern.
4. [tracked] U10/T12 canon (Q1/Q3) + dispositions (10 held + 2 zero-strike).
5. [watch] U2 prose-depth residue (269 rows at M4/T4-era verification) — fold into the wave's per-batch passes rather than a dedicated dispatch.
6. [watch] Parallel catalog session (scripts/catalog-inventory.*) still live at last observation — attribution remains with the owner.

## g) QUESTIONS (cannot resolve from the repo)

1. **Q2 — October-wave sequencing (4th ask; blocks U4–U7 + the 81-WARN drain incl. the 22 Sept stragglers):** start stage 1 now (the 19-28 plan's proposal), or hold for the SUPERB masterplan v2 sprints?
2. **Q1 — archive policy for cited-but-fully-resolved reports (blocks U5/U6 scale + U10 + ~500 fates + 10 held):** keep-in-root or archive-anyway?
3. **Q3 — zero-strike closure canon (blocks 2 held files + the wave's zero-item closures):** header-banner form for fully-resolved reports with zero numbered items, or keep holding them in root?

---

## Appendix: session commits (all pushed; remote synced 0-unpushed)

`6ce9696cf` 19-28 plan + 16-43 EXECUTED flip/stamps (U12) · `8dec2669a` daemon-⅓ of U1 (verified) + `a9e7383d2` U1 rest (premise-corrected merge) · `e3d61ec36` daemon-6/7 of U2 (verified) + `9497cefab` U2 rest · `552a363c6` U3/T13 header collapse · `b21627a5e` row closes + plan progress marker · this commit (report + f.1 harvest). Earlier-session commits (T1–T4, tombstone, 19-14 report) rode the parallel session's push through `552a363c6` and mine above.

## Appendix: gates at report time

check-doc-links OK · check-todo-system structure OK (WARN 81, composition verified 22 Sept + 59 Oct) · doc-counts eval gate green post-collapse · pre-commit all-green on every commit · `git status` clean · `origin/master..HEAD` = 0.
