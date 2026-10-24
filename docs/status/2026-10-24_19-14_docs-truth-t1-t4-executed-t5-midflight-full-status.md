# Docs-Truth Plan Execution: T1–T4 Executed, T5 Mid-Flight — Full Status

**Date:** 2026-10-24 19:14 CEST · **Session:** 16-43 plan executor (T1–T5 residuals) · **Plan:** `docs/planning/2026-10-24_16-43_SUPERB-docs-truth-october-wave-and-closeout-residuals.md` (EXECUTING tombstone `c8ab3048c`)
**Task:** user dispatch — "READ, UNDERSTAND, RESEARCH, REFLECT. Break this down… Execute and Verify… Repeat until done." → executed T1→T5 in dependency order; interrupted mid-T5 by this report dispatch.

---

## a) FULLY DONE (all verified this session, gates green at each commit)

1. **EXECUTING tombstone** on the 16-43 plan (`c8ab3048c`): plan-marker + immediate commit, per the 2026-10-18 twin-executor rule.
2. **T1 — WARN-composition enumeration** (`dc7c057b0`): replicated the gate's census logic exactly (date-filter + marker-grep + citation-blob) and enumerated all 81. **"All-October" REFUTED: 81 = 22 Sept stragglers (09-26→09-30, ~480 bare §f items) + 59 Oct.** Flipper named: daemon `f12302830` (R091 archive of `2026-09-30_07-42_architecture-catalog-golive-prep-continuation.md` at 11:49, between the 12-04 session's prune-measure and its own report commit — the "parallel session harvested one" hand-wave was wrong). Verified by re-running the census in a worktree at the prune commit (82, one-file diff = the flipper) and at the 12-04 commit (81, zero diff). Corrections applied on 5 surfaces: 12-04 ×2 sites, 13-50 ×2 sites, 16-22 §d.2 (resolution appended), pipeline.md [decision] wave row (+22 Sept, re-pointed 12-11→16-43 plan), plan ground-truth table. Sept stragglers routed into the tracked wave surface (spot-check: ~half tracked by grep; full adjudication = the wave's own classifier job, per T1's "reconcile into the Oct-wave batch lists"). Evidence persisted: `~/.cache/docshealth/t1-{warn-census,warn-census-1204,warn-census-prune,oct-batch-seed,sept-stragglers,unselfcited}.{txt,tsv}`.
3. **T2 — hand-drops re-adjudicated** (`e6f8a58b9`): the 12-04 §a.6 description ("2 contradictory w-with-still-open-evidence rows") did NOT match the artifacts — raw↔spec diffs across b03/b09 showed the actual residue was: (i) `01-14:93` — a **v NOOVERLAP line-targeting error** (agent evidence answered table row 38, not 37) → row 37 struck **v** on fresh evidence (hub exporter emits owners frontmatter, `eventcatalog-hub` README:136-141; built catalog carries `owners: - lars`); (ii) `13-34:143` — a **v BADPATH filename-typo drop** → item 19 struck **v** (dnsblockd runbook carries options + smoke-probe inventory + memo/plan pointers, `docs/services/dnsblockd.md:11-12`); (iii) **bonus defect**: `05-55:23` carried an evidence-FREE `w` strike with an embedded **0x02 control byte** where the evidence was swallowed → restored from b03-raw (`system-796`, CHANGELOG "Batch deploy LANDED" verified). check-rows green on all 3 (01-14 PARTIAL = pre-existing adjudicated-open surface, by canon). 12-04 §a.6 corrected inline; TODO_LIST:1479 + pipeline.md:628 rows closed on BOTH surfaces with the honest description.
4. **T3 — standing doc-counts eval gate LIVE** (content in daemon-swept `9a8ed187a` + `61d35c7ce`, contents verified = exactly mine): `flake/parts/checks/doc-counts.nix` evals TRUTH (`inputs.self` → nixosModules/gatus-endpoints/packages) and compares against what README:82/FEATURES:28/FEATURES:33 assert via single-occurrence anchor regexes — **never assert-against-assert** (neither side hardcoded). A throw fires at EVAL time (guard forced through the derivation's env) — bites pre-commit's eval-only flake check, CI, and every deploy. Drift or a lost anchor both fail. Verified LIVE in both directions: the gate caught my own regex bug during development (FEATURES "asserts 1" vs 131 — ECMAScript-style backtracking shrinks mid-line captures; fixed with `[^0-9]` boundaries), and `nix flake check --no-build` + full build of the check pass green. **3 negative-test legs + pristine control added to `scripts/negative-test-lints.sh` (doccounts group) — harness 15/0 green.** Found + fixed along the way (foreign, parallel-session `d60cc6ab0` code): 2 dead-guard violations (`bank-sync.nix:812`, `paperless.nix:756` — `|| true` per the lint's own prescription), 8 statix findings in `lint-static.nix` (refactored to `getAttr` form — paren-select is load-bearing, verified by eval probe), canonical `nix fmt` churn on 4 unformatted files. One real Nix lesson encoded as a comment in the gate: `"${root}/x"` string-interpolation captures the flake's random-named working-tree copy in the derivation context and fails `derivationStrict` under flake check — `(root + "/x")` is the safe form.
5. **T4 — README/FEATURES row-depth sweep** (`43bca64f4`): all 33 README service rows verified — ports vs `lib/ports.nix` (all match), URLs vs the **live caddy vHost eval** (all claimed URLs exist), enable-claims vs `nix eval`, deploy-state claims vs the **live generation units** (`/run/current-system`) + `pgrep`. **7 README rows fixed**: SigNoz "6 dashboards"→10 + stale "cAdvisor" removed (gone with Docker 2026-10-08); Overview URL —→`overview.home.lan`; DNS Blocker URL —→`dnsblock.home.lan`; indexer-web URL added + "deploy queued"→"deployed"; bank-sync "disabled until sops go-live"→"canary + Paperless/Qonto sync units deployed" (enable=true + units in live gen); Dual-WAN marked "(currently disabled)" (enable=false). **FEATURES:95 indexer-web 📋→⚠️ DEPLOYED+RUNNING** (pgrep-verified PID 2249, indexer 2.12.0 — the row and services.md:43's "has NEVER unit-started" premise were both stale; premise corrected in place, ask preserved). Mullvad + NetBird rows verified ACCURATE (mullvad config-kept-disabled per configuration.nix:998; netbird client live under `clients.evox2`). Both docs stamped; the doc-counts gate still green on the re-worded README (anchors preserved by construction).
6. **Gates at each commit**: check-todo-system structure OK (WARN 81 = the verified wave surface), check-doc-links OK, `nix flake check --no-build` all-checks-passed, negative-test harness 15/0.

## b) PARTIALLY DONE

| # | Item | Works | Missing | Why |
|---|---|---|---|---|
| 1 | **T5 — `docs/status/archived/` manifest README** | waves ENUMERATED from git history: 1,457 files across 35 adding-commits — 2026-07-30 `43c266837` (75), 2026-08-09 `499a6d21b` (152) + `f03d22c31` (96), 2026-09-06 `dd4f5c995` (55), 2026-09-14 `835f61643` (656!) + `a6b4b2ff2` (133) + `6ddc763f0` (38), 2026-10-18 `3202b5da0` (61) + `309d4057c` (35), 2026-10-24 `f12302830` (1) — top waves ≈1,302/1,457; planning-manifest shape read (`docs/planning/archived/README.md`) | the README itself (waves table + sweep pointer + link) not yet written; wave table not yet persisted to cache | interrupted by this report dispatch mid-μ24; ~30 min of work left |
| 2 | FEATURES ✅-row exhaustive verification | flagged rows (⚠️/🔧/📋) + suspects verified vs eval; counts M4-verified; gate enforces the three eval-able counts | the ~90 un-flagged ✅ rows lack per-row evidence checks (README table got full depth; FEATURES got flagged-row depth) | T4 budget (100m) consumed by the README table + live-probe work; honest residue, queued below |
| 3 | T1 Sept-straggler adjudication | 22 files enumerated + classified (bare/struck TSV persisted); ~12-item spot-check; all routed into the tracked wave surface ([decision] row + plan + seeds) | the ~480 bare items are NOT individually adjudicated (tracked-vs-done-since-vs-untracked) | that IS the Oct wave's classifier job (T6–T9); folding was the plan-sanctioned route ("reconcile into the batch lists"), not a shortcut around it |

## c) NOT STARTED (owner-gated by design — the plan holds them)

1. **T6–T9 October wave** (442 root + 57 tasks/ + 22 Sept stragglers) — gated on **Q2** (sequencing).
2. **T7/T8 archive waves** — also gated on **Q1** (~500 cited-but-resolved fates + 10 held Sept candidates).
3. **T10 validator+prompt upstream / T11 transcription relay** (crush-config repo) — gated on tooling-upstream authorization.
4. **T12 canon codification** (Q1/Q3 answers → skill + AGENTS; disposition the 10 held + 2 zero-strike files).
5. **T13 FEATURES header leanness** — [watch], rides the next docs pass.

## d) TOTALLY FUCKED UP (owned, no damage permanent)

1. **Lost 3 daemon commit races in T3** — I batched the whole task (gate + harness legs + foreign fixes + fmt churn) into one commit instead of pathspec-committing each coherent unit immediately; the daemon swept mid-flight three times, one commit died on a pre-commit-ref-lock error mid-hook ("cannot lock ref 'HEAD'"), and the final T3 content sits on TWO daemon-labeled commits with a foreign parallel-session commit (`501886eea`, catalog work) interleaved on top — no clean single T3 commit exists. Contents verified exactly mine at each step; zero content loss; but history readability suffered.
2. **False "flake.nix imports line vanished" alarm** — my own `tail -11` truncated the diff-stat; I nearly "fixed" a non-problem. Caught by checking `git show HEAD:flake.nix` before acting.
3. **First two census classifiers were wrong** (0-bare/0-struck counts) — strike-forms hide line-starts (`~~2~~`) and table cells; sanity-checking against a known file caught it before any claim was written.
4. **Two edit-tool staleness trips** on grep-only-read files (12-04, 16-22, pipeline.md) — the tool caught the mtime drift each time; re-read before edit, no damage. Discipline slip, not once but twice.
5. **T5 wave table not persisted at decision time** — the enumeration lives in shell output + this report only; the persist-tables-at-decision-time rule (paid twice before) was violated again for the T5 TSV. Recoverable from this report's §b.1.

## e) WHAT WE SHOULD IMPROVE

1. **Commit cadence under daemon races: smallest coherent unit, immediately** — T1/T2/T4 pathspec commits survived races cleanly; only the fat-batched T3 lost them. The pattern is now proven both ways.
2. **Persist EVERY enumeration to `~/.cache/docshealth/` at derivation time** — still not reflex (T5 miss above).
3. **The eval-gate pattern is now cheap to replicate** — the scrub-exit-contract shape (eval-forced throwIfNot inside a check) + negative-test legs took ~90m end-to-end including two live bugs found; the next standing gate (SigNoz rule count? service-module count per dir?) should reuse `doc-counts.nix` as the template.
4. **Descriptions of drop-residue should be artifact-checked at claim time** — the "contradictory w-verdicts" description survived two reports (12-04, 16-22) before T2's raw↔spec diff proved it wrong; the drops logs + raw TSVs were available all along.
5. **`pgrep`/live-generation probes belong in the VERIFY default set for deploy-state claims** — "deploy queued"/"never started" claims rotted for 3.5 weeks because nobody looked at the running system; the truth cost one command.

## f) NEXT — ordered, P0 first (harvest state: 1–2 are NEW this session, harvested into queue+library pairs in this commit; 3+ are [tracked]/[owner-gated] continuations)

1. [harvested] **Finish T5: write `docs/status/archived/README.md`** — waves table from §b.1 (one line per bulk wave: date, commit, file count, sweep pointer), link from the 16-22 report context, check-doc-links, pathspec commit; stamp the plan's T2/T3/T4 ground-truth rows while in the plan file. → docs/todo/pipeline.md
2. [harvested] **FEATURES full ✅-row verification sweep** (T4 residue): per-row evidence for the ~90 un-flagged ✅ rows (module exists + enable state + unit shape); fix drift in place; stamp. → docs/todo/pipeline.md
3. [tracked] October wave T6–T9 (442+57+22) — pipeline.md [decision] row (updated this session with the T1 census); owner gate Q2.
4. [tracked] T10/T11 tooling upstream (crush-config) — owner-gated; the validator + prompt + retag rule are proven and documented in the 16-43 plan.
5. [tracked] T12 canon (Q1/Q3) + disposition of 10 held Sept candidates + 2 zero-strike files.
6. [watch] T13 FEATURES header leanness — the header now carries 13 nested layers (this session added one); collapse is overdue.
7. [watch] `/tmp/statix-test.nix` probe file — trivial residue, delete on next touch (trash, not rm).
8. [flagged, not mine] **Parallel session actively working `scripts/catalog-inventory.sh` + untracked `catalog-inventory.pbx.json`** (daemon commits `501886eea`/`21c912fdc`/`ce2e3662d`/`946b81679`) — NOT co-verified by me; owner should attribute before any tree-level operation touching scripts/.

## g) QUESTIONS (cannot be resolved from the repo; all three gate remaining work)

1. **Q2 — October-wave sequencing (blocks T6–T9, the 81-WARN surface, and the 22 Sept stragglers):** ride AFTER the SUPERB masterplan v2 sprints (the default), or start stage 1 (batches 10–14, newest ~110) now? The 16-43 plan proposes NOW; every un-harvested report is un-routed intent, and the surface now includes 22 Sept files whose closure premise ("Sept §f surface: zero") T1 refuted.
2. **Q1 — archive policy for cited-but-fully-resolved reports (blocks T7/T8 scale + T12 + ~500 file fates + 10 held Sept candidates):** keep-in-root (current default, predecessor-consistent) or archive-anyway + let `**Source:**` pointers resolve through `archived/`?
3. **Push authorization:** 9+ commits unpushed on master (T1–T4 + tombstone + daemon-swept T3 content + foreign parallel-session catalog commits interleaved). Push now, or hold until the catalog session lands?

*(Q3 — zero-strike banner canon for fully-resolved reports with zero numbered items, blocking 2 held files — remains asked-and-pending from the 16-22 report; it rides T12.)*

---

## Appendix: session commits (chronological; unpushed unless noted)

`c8ab3048c` EXECUTING tombstone · `dc7c057b0` T1 census + 5-surface correction · `e6f8a58b9` T2 (3 defects + row closes + 12-04 §a.6 correction) · `9a8ed187a` + `61d35c7ce` daemon-swept T3 content (verified = exactly mine: gate + harness legs + foreign dead-guard/statix/fmt fixes) · `43bca64f4` T4 row sweep · this commit (report + 2 harvest pairs). Foreign interleaved: `501886eea`, `21c912fdc`, `ce2e3662d`, `946b81679` (parallel catalog session — not mine).

## Appendix: gates at report time

`nix flake check --no-build` all-checks-passed (post-T3 fixes; doc-counts evaluating green) · negative-test harness 15/0 (doccounts ×3 + 10 pristine controls + toplevel + icons) · `check-todo-system.sh` structure OK, WARN 81 (verified composition: 22 Sept + 59 Oct) · `check-doc-links.sh` OK · shellcheck (repo form) PASS on the touched scripts · annotate check-rows green on all 3 T2 files.
