# Status: Docs-Health 2026-0* Corpus — Mission Closed (Closeout Spine M1–M7)

**Session date:** 2026-10-24, ~12:20 → 13:50 (closeout executor; continuation of the batch 01–09 session)
**Task:** user dispatch — "READ, UNDERSTAND, RESEARCH, REFLECT … Execute and Verify … Repeat until done" over the closeout plan `docs/planning/2026-10-24_12-11_SUPERB-docs-health-corpus-closeout-and-october-wave.md` (M1–M7 spine; M8–M13 owner-gated). Owning row TODO_LIST:609 → docs/todo/pipeline.md:582; owning plan `2026-10-19_05-06` (tombstone now EXECUTED).
**State in one line:** the tracked 2026-0* corpus mission is CLOSED — final check-rows enumeration justified, non-status triage applied (10 plans archived + 8 banners), living docs re-derived and stamped, owning rows closed on both surfaces, all gates green; the 2026-10 wave (442+57) stays owner-gated (Q2).

## a) FULLY DONE

1. **Tombstones**: EXECUTING marker written + committed on the 2026-10-24_12-11 plan FIRST (`3ca14936f`); flipped the owning 2026-10-19 plan to EXECUTED at close.
2. **M1 — corpus-wide check-rows enumeration** (the b4/d.5 debt): all 292 on-disk Sept files enumerated (294 corpus − 2 archived; disk-vs-list diff verified exact). 93 files carry PARTIAL tables = the adjudicated-open surface: (i) all 40 validator drops re-adjudicated — 34 struck via repair spec (`m1-repair.tsv`) + 1 chained-fragment hand edit (07-47 #32 DMARC) + 3 cause-skipped (2 already struck by other verdicts, 1 snippet exists nowhere in the target file) + 2 BADPATH fabrications stay dropped; (ii) 16-file sample across both corpus halves: every bare row is a phrased-open ask, tracked item, or non-ask — none verifiably-done. Committed `40e71f0b1`.
3. **M2 — non-status 2026-0\* triage applied**: 50 files re-classified by one read-only agent (the lost 52-file table re-derived with verdict quotes; conservative deltas from the prior pass are evidence-cited): **10 EXECUTED** `git mv`'d to `docs/planning/archived/` (check-rows gate BEFORE every move; manifest = NEW `docs/planning/archived/README.md`), **13 SUPERSEDED** (8 banners written 2026-10-24 — 7 html + 1 md; 4 more were already self-bannered; 07-09 .d2/.svg left as satellites of the bannered html), **21 REFERENCE-KEEP**, **6 ACTIVE**. Living-surface refs repointed to `archived/` paths (16 surfaces incl. module comments + TODO_LIST); historical status-report/CHANGELOG mentions left per discoverability precedent. Moved-pointer notes added to the 4 reports citing the 2 archived status files (d.4 debt closed). `check-doc-links.sh` OK throughout. Landed `9e2037fe9` (daemon-swept, contents verified = exactly my 17 files) + `7c05aeacd` (statix fix on boot-mirror.nix:181 rode along).
4. **M4 — README + FEATURES counts re-derived** (the 2026-10-06 §f.5 debt): nixosModules 55→**131** (canonical eval), packages 30→**46** (eval), Gatus checks 133→**228** (endpoints eval), SigNoz 31/6→**47 rules/10 dashboards**, service modules 70→**118**, desktop 10→**13**, lib 10→**15**, HM programs 19→**20**; derivation commands embedded in README; stale **Ollama (ROCm)** mention removed (system-removed 2026-10-12); both files stamped. Committed `8823b46b8`.
5. **M5 — ROADMAP Theme-1 + cross-theme staleness pass**: Samsung-migration row → SHIPPED (doctrine-C `+C` subvols, NOT the debated XFS; trailing docker end-state moot), boot-mirror noted as the shipped shutdown option, `/data`-consolidation + firewall + rocm-module + attic rows de-Dockerized, voice-agents row RESOLVED, ttmPagesLimit framing aligned to the settled GTT-first doctrine. **AGENTS pass**: all 33 referenced paths exist (zero MISSING); 37 dated citations are deliberate incident anchors, not pollution; 57 KB size accepted-by-design (the 2026-10-01 routing-table architecture). Committed `684d4f2f8`.
6. **M6 — harvest dedupe ledger** (see §Ledger): sampled-open reconciliation vs TODO_LIST/docs/todo found **3 untracked items** — all harvested this session (§f); everything else verified tracked or owner-gated.
7. **M3 — gates + close**: `nix flake check --no-build` **all checks passed** (Darwin omission = expected signature); `check-doc-links.sh` OK; `check-todo-system.sh` structure OK (81 unharvested-§f WARNs, ALL 2026-10 wave — the M8–M11 surface); CHANGELOG sweep entry landed (count-before-claim below); owning rows closed on BOTH surfaces with successor state.
8. **M7 — qmd**: NO SystemNix collection exists (qmd indexes only `cv`), so the "re-index after mass moves" premise is void — nothing to re-index; recorded here so the next sweep does not re-chase it.

## b) PARTIALLY DONE

| # | Item | Works | Missing | Blocker |
| --- | --- | --- | --- | --- |
| b1 | October wave (442 root + 57 tasks/) | plan M8–M11 fully decomposed (~25 batches, proven pipeline, batch lists derivable) | execution | owner gate Q2 (sequencing vs masterplan v2 sprints) |
| b2 | Tooling upstream (validator + relay → docs-health skill) | validator + prompt proven 9×; artifacts under ~/.cache/docshealth | upstreaming to crush-config | owner gate (M12–M13) |

## c) NOT STARTED

1. Nothing in the M1–M7 spine. M8–M13 are owner-gated by design (see §g).

## d) TOTALLY FUCKED UP (caught, all)

1. **The classifier's line numbers in drops were the AGENT's claimed lines, not relocated ones** — recovery required per-row content grep; the drops.log alone was insufficient (fixed by the m1-drops-full.tsv join + manual relocation; 3 rows dropped for cause).
2. **A false alarm on `2026-09-30_15-39` "empty table rows"** — the table's content lives in wide columns beyond my 160-char cut; verified full-width before acting (no damage done; lesson re-confirmed: truncation displays lie).
3. **Commit-subject length twice** (88 then 74 chars vs 72 house limit) — hook caught both; subjects shortened. The house limit is stricter than the general 72 rule implies: em-dashes and "(M5)" suffixes count.
4. **My earlier session's "52 files" classification count was unverifiable** — the table was never persisted; this pass re-derived it from scratch (50 files on disk) rather than trusting the summary. Two prior-count deltas (17→10 EXECUTED etc.) are the conservative, verdict-quoted classifications landing now.

## e) WHAT WE SHOULD IMPROVE

1. **Persist classification tables to the workspace cache at decision time** — the lost 52-file table cost a full re-derivation; one TSV under ~/.cache/docshealth would have saved it.
2. **The drops.log should record the RELOCATED line (or the snippet's true position) at drop time**, not the agent's claimed line — the recovery join then becomes mechanical.
3. **qmd**: the plan carried a re-index step for a collection that does not exist — plan authors should verify the premise surface exists before scheduling a step against it.

## f) NEXT — ordered, P0 first

**Harvest state: items 1–2 are NEW untracked-actionable finds from the M6 ledger, harvested NOW per the self-harvest obligation (queue + library pairs below; the sweep-time no-new-rows contract no longer applies — the corpus sweep is complete, this is the closeout commit). Item 3 is an owner question routed to ROADMAP. Items 4+ are tracked/owner-gated continuations.**

1. **ClickHouse native-BACKUP restore drill** (dir-mode → fresh cluster; prove signoz dbs recover) — landed TODO_LIST + docs/todo/services.md. Source: `docs/status/2026-09-23_04-00_*` row 30/§f.4.
2. **desktop-alerting runbook** (`docs/services/desktop-alerting.md`: tiers, DND scope, bypass toggles, urgency map, Discord channels) + AGENTS Quickshell DND one-liner — landed TODO_LIST + docs/todo/desktop.md. Source: `docs/status/2026-09-24_00-07_*` §f.4/5.
3. **Owner decision: 32 frozen forgejo archives keep-all vs prune** — routed to ROADMAP Theme-1 (git-fsck row note); not a task.
4. October wave M8–M11 — owner gate Q2; successor `[decision]` row in docs/todo/pipeline.md.
5. Validator + prompt upstream to docs-health skill (crush-config) — M12–M13, owner-gated.
6. AGENTS.md AGENTS-section spot updates for anything the M4/M5 passes surfaced — none found this pass (GPU section already current).

## g) QUESTIONS (carried, unchanged)

1. **Q1 archive policy** for cited-but-fully-resolved reports (defaults keep-in-root; decides ~500 files during the Oct wave).
2. **Q2 October-wave sequencing** — after SUPERB masterplan v2 sprints (default) vs interleave now.
3. **Q3 zero-strike closure canon** — header-banner form for zero-numbered-item closure reports (2 files still held).

---

## Appendix: M6 harvest dedupe ledger (sampled surface)

Method: the 93 PARTIAL-flagged files' bare rows are the corpus's open surface; 16 files sampled across corpus halves (≈17% of flagged set, ≥40 distinct rows read); representative open-asks grepped against TODO_LIST + docs/todo.

| Sampled open ask | Tracked? | Disposition |
| --- | --- | --- |
| Single-source GOTOOLCHAIN purity predicate (09-22_06-48) | TODO_LIST:759 + pipeline.md | already tracked |
| hot-user-caches ↔ tmpfiles ordering cycle (09-25_02-20) | TODO_LIST:204 + stability.md:76 + pipeline.md:216 | already tracked |
| Caddy deploy rows [blocked:deploy]/[ready] (09-30_15-39) | queue rows in-situ | already tracked |
| Hermes restore drill (09-23_04-00 adjacent) | storage.md:28 | already tracked |
| Offsite borg restore drill | storage.md:68 [x] | done+tracked |
| Owner decision: 32 frozen archives (09-18_16-45) | NOT tracked | → ROADMAP (§f.3) |
| ClickHouse native-BACKUP restore drill (09-23_04-00) | NOT tracked | → harvested (§f.1) |
| desktop-alerting runbook (09-24_00-07) | NOT tracked | → harvested (§f.2) |
| "Nothing else" / policy-question / owner-observation rows (misc) | n/a | non-asks — bare is honest |

Sept §f surface: `check-todo-system.sh` reports ZERO unharvested Sept reports (81 WARNs all-October) — the systematic harvest reconciliation holds beyond the sample.

## Appendix: gates + commits

- Gates: `nix flake check --no-build` all-checks-passed; `check-doc-links.sh` OK; `check-todo-system.sh` structure OK; annotate.go self-test green (start of session).
- Commits this session: `3ca14936f` (tombstone) · `40e71f0b1` (M1 recovery) · `9e2037fe9`+`7c05aeacd` (M2) · `8823b46b8` (M4) · `684d4f2f8` (M5) · this commit (M3 close: CHANGELOG + row closes + harvests + tombstone flips).
- Workspace: `~/.cache/docshealth/m1-*.{txt,tsv,log}` (corpus list, drops join, repair spec, both check-rows runs).
