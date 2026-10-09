# Docs-Health Full-Corpus AUDIT — Status & Self-Review (2026-10-06 16:49 CEST)

**Session scope:** execute the docs-health skill in AUDIT mode over every active `**/2026-0*` file (~620 dated docs) + make the six living docs superb; prune done todos to CHANGELOG; archive fully-done files with inline strikethrough.
**Commits (this session's legs):** `27001ab1` (annotate sweep + TODO prune, daemon-swept, exclusivity-verified), `79dcbc45` (23 git-mv archives + CHANGELOG bullet + manifest, daemon-swept, exclusivity-verified), `5b72f073` (harvest + living docs + gitleaks gate fix + prune-pass row closure, hand-amended with full pre-commit green).
**Gates at close:** `check-todo-system.sh` rc=0 · `check-doc-links.sh` rc=0 · `nix flake check --no-build` all checks passed · full pre-commit green on the amend · commit-msg enforced (first attempt rejected at 75 chars — see §d).

---

## a) FULLY DONE

1. __Full-corpus classification — every active 2026-0_ file read._* 13 parallel classifier batches over `docs/status/` by date-window (589 files: Aug 22, Sep 1–9 20, Sep 10–15 53, Sep 16–18 66, Sep 19–22 64, Sep 23–25 71, Sep 26–28 46, Sep 29–30 81, Oct 1–2 82, Oct 3 28, Oct 4 24, Oct 5–6 34) + planning (19) + research (8) + reviews/brainstorming/troubleshooting (5). Every file read fully; per-file verdict (ARCHIVE-CANDIDATE / OPEN-CARRIER), MARKED-state, and open-ask inventory returned. Aggregate verdict: the corpus is overwhelmingly OPEN-CARRIER by design (reports carry open §f/§g tails); ~31 candidates were fully resolved; 5 of those cited by live rows → stayed.
2. **Archive sweep: 23 files annotated + moved with manifest.** Banner (`[docs-health 2026-10-06] RESOLVED + ARCHIVED`) + one evidence-bearing inline strikethrough per file; `git mv` → `docs/status/archived/` (20) + `docs/planning/archived/` (3: dozzle evaluation = ADOPTED, both NIX-ANTI-PATTERNS docs = 100% executed per the archived 2026-01-13 completion report); one-line-per-file deciding-reason manifest + updated counts appended to `docs/status/archived/README.md`. Citation sweep before every move: all 23 uncited by TODO_LIST/docs-todo/living docs; the 5 cited candidates stayed in place.
3. **Completed-todo prune: TODO_LIST is now 100% open work.** All 90 `[x]` rows removed (734 lines remain: 0 `[x]`, 647 open rows, structure clean per the gate). Completion record preserved: `CHANGELOG.md` `### Removed` gained one consolidated bullet carrying all 90 row titles verbatim with pre-prune line numbers + the contract citation; this also settles the 23-19 §g Q2 flip-vs-prune policy question (prune wins) and closed the "TODO_LIST `[x]` prune pass" queue row itself.
4. **Harvest: 6 verified-new open asks landed on both surfaces.** forgejo-family eval-gate assertion (freeze-18 §f.5) + port-3000 squat → `TODO_LIST.md` §services + `docs/todo/services.md`; helium launch-guard deploy → `docs/todo/desktop.md`; browser-history empty-dashboard fix chain + CAA domains push → `docs/todo/upstream.md`; gitleaks selftest fixture → `TODO_LIST.md` + `docs/todo/pipeline.md`. Every candidate was dedup-grepped against TODO_LIST + libraries first (7 candidate classes rejected as already-tracked).
5. **Living docs refreshed from verified facts.** README: +3 service rows (Ledger CRM :8091, indexer-web :8105, NetBird :51820 — ports/modules grep-verified in `lib/ports.nix`/`modules/nixos/services/`) + Twenty marked FROZEN (Ledger replacement). FEATURES: +3 rows with honest statuses (root-prune-guard ⚠️ repo-complete/deploy-pending, NetBird 🔧 gated, indexer-web 📋 deploy-queued) + header stamp. ROADMAP: verified-current stamp (content verified, no drift found worth editing). AGENTS.md verified, deliberately untouched (no drift found).
6. **Fleet-gate outage found + fixed at the scanner.** A Pocket ID ULID `user_id` quoted in the parallel session's 14-34 report (landed via a daemon heuristic commit, hook-blind) was failing gitleaks for EVERY manual commit. Fixed in `.gitleaks.toml` (literal allowlist, precedent = the canonical-ULID entry) with the region-semantics lesson in the comment; hook-equivalent staged-tree scan re-run → GREEN; follow-up selftest fixture queued.
7. **Verification discipline held.** Dry-run before every mutation sweep; content-pin (`git rev-parse` + status) before write batches; daemon-swept commits exclusivity-checked (`git show --stat` — all three carried ONLY this session's files); post-amend skipped-lint legs re-run standalone; dangling-pointer sweep over all 23 moved filenames (1 real cross-reference found → repointed in the same change).

## b) PARTIALLY DONE

1. **Archive coverage of fully-done files.** The 5 cited candidates (movie-window 19-43, freeze-13/14/15 autopsies, eval-warning-sweep, 2 pipeline-cited re-fire records) are fully resolved but stay until their citing open rows close — correct per the uncited-at-archive-time bar, but it means the sweep's archive list is a snapshot, not a closure.
2. **Living-docs deep verify.** README/FEATURES were updated where this session had verified facts, but their standing counts (133 Gatus checks, 70 service modules, 31 alert rules, "50 generations") were NOT re-derived from the repo; ROADMAP got a stamp, and its Theme-1 freeze-era framing (#3–#7 era ideas; "82% resolved" root-pressure claim now stale at 81–89% post-freeze-#16–#18) was left alone.
3. **Harvest breadth.** Systematic dedup ran over the recent (Oct) asks; the older Aug/early-Sep agent harvest lists were spot-checked only — some genuinely-untracked asks in 200+ older OPEN-CARRIER reports may still lack queue/library rows (mitigated: the pairing/harvest lints exist as WARNs).
4. **Self-review of the classification itself.** Agent verdicts were trusted after spot-reading 3 files; no second-pass adjudication of borderline OPEN-CARRIERs was done.

## c) NOT STARTED (queued only, no code/docs written)

1. **Completeness-gate decision:** the `grep -rLn '~~'` strict gate is violated by ~1,056 status-archived + 18 planning-archived banner-only files — relax the gate to "banner OR strikethrough" or schedule a mechanical backfill. Recorded in the archive manifest but NOT yet landed as a queue row (self-harvested this report, see Harvest log).
2. **gitleaks-coverage-selftest fixture** for the ULID-user_id FP + allowlist-regex-region semantics — queued (`TODO_LIST.md` + `docs/todo/pipeline.md`), not built.
3. **Research-archive convention** — `docs/research/` has no `archived/` home; the superseded 2026-07-11 btrfs-wiki file (already annotated) stays flat. Owner-call needed; not queued yet (self-harvested this report).
4. **README/FEATURES count re-derivation** (prefer computed counts over hand-maintained ones) — the standing class exists in `docs/todo/pipeline.md` ("Service-completeness manifest audit"); the README/FEATURES-specific numbers were not wired to anything.

## d) TOTALLY FUCKED UP (shipped or caught-late mistakes — full honesty)

1. **First archive-annotation pass picked WRONG strike lines** (metadata `**Date:**`/`**When:**`/`**Created:**` lines on 6 files — useless annotations that would have shipped if I hadn't dry-run + reviewed). Caught in dry-run; fixed with per-file anchored specs. Lesson already codified in-repo as "ALWAYS dry-run the first spec" — I nearly re-proved why it exists.
2. **First gitleaks allowlist attempt silently no-oped** (line-shape regex `user_id:"<ULID>"` — allowlist regexes match the captured secret region, not the line). Cost 2 extra probe rounds; the fix is the literal form. Unknown gitleaks semantics, discovered empirically, now recorded in the config comment + queued fixture.
3. **Violated the repo's own 72-char subject rule on the first amend** (75 chars — rejected by `commit-msg`). This rule is in AGENTS.md AND enforced by a hook I read this session. Sloppy; fixed on the retry.
4. **Pruned 5 netbird `[x]` rows authored by the parallel session the same day, unilaterally.** Contract-compliant ("a `[x]` row must never persist") but it was ANOTHER active session's fresh work; I decided rather than asked. Content preserved verbatim (CHANGELOG + git history) and their footer commits are untouched, but the call should have been the owner's or theirs.
5. **Corpus-count contradiction left unresolved until the end:** my first inventory said 423 active status files (`fd`/`find`), while the per-batch `ls | rg` lists the agents actually read summed to 589 + 31 misc. Both commands were run in this session; I shipped "~620" in the summary and only reconciled the tooling discrepancy after (fd's pattern arg underCounts vs glob; `find -name '2026-0*.md'` still returns 413 post-sweep vs 572 total .md — the delta is non-`2026-0*` files, but the earlier 423 vs 589 gap was my own tooling error). Reported numbers now use the agent-verified per-batch counts.
6. **Minor:** `edit`-tool refusal on dozzle (hadn't read it first), and one daemon race mid-flight — both caught and worked around; no data harm.

## e) WHAT WE SHOULD IMPROVE

1. **Trust `ls | rg` over `fd`/`find` for corpus inventories in this repo** — the classifier batches verified counts per batch; tool disagreement cost a reconciliation round.
2. **Classification agents should also emit per-file "unharvested §f" lists** — the 80-standing-WARN could be driven down mechanically from the same read pass instead of needing a second sweep.
3. **Dry-run review is load-bearing, not ceremony** — two of this session's mistakes (strike lines, allowlist regex) were caught ONLY because the mutation paths printed before writing.
4. **Cross-session [x] rows deserve an ask-first rule** — a same-day prune of a sibling session's completions is contract-legal but ownership-hostile.
5. **Counted claims need computed sources** — README/FEATURES numbers rot silently; the drift-alarm idea in the skill's references (re-derive counts at gate time) is the standing fix.
6. **The daemon heuristic-commit attribution worked here only because exclusivity was checked** — keep `git show --stat` verification mandatory after every sweep landing.

## f) Up to 50 next things (session follow-ups first, then top items noticed this session)

**Session direct follow-ups:**

1. Decide + implement the archive completeness-gate shape (relax to "banner OR strike" vs backfill sweep) — `[decision]`, harvested.
2. Build the gitleaks-coverage-selftest fixture (ULID-user_id FP + real-secret negative control) — queued.
3. Decide the research-archive convention; move the superseded 2026-07-11 btrfs-wiki file when it exists — `[decision]`, harvested.
4. Archive the 5 cited candidates when their citing rows close (movie-window 19-43, freeze-13/14/15 autopsies, eval-warning-sweep).
5. Re-derive README/FEATURES standing counts from the repo (computed, not hand-maintained).
6. Annotate ROADMAP Theme-1 stale framing (freeze era #3–#7 → #8–#18; root-pressure "resolved 82%" claim).
7. Systematic Aug–Sep harvest sweep with per-report unharvested-§f extraction (drive the 80 WARN down).
8. Second-pass adjudication of borderline OPEN-CARRIER classifications (spot-verify 10% sample).
9. Verify the archived/README counts line (1,390/45) against `ls` after the daemon's next sweep.
10. Close out the netbird 14-57 ordering-bug rows the parallel session flipped (their §f.1 says "unfixed in 4 surfaces" — reconcile with their later 15-35 closeout).

**Top items noticed while reading the corpus (high-leverage, not session-specific):**
11. Owner cooling inspection for the thermal-cut family (#8/#9/#11–#18, six consecutive predicted cuts) — the single highest-severity open thread.
12. Deploy the thermal-pstate-guard second rung (deeper throttle) + measurable post-deploy criterion.
13. Deploy the 10-04 polkit agent-race fix chain (deploy → dms restart → one real prompt) — GUI auth currently dead-until-deploy.
14. Forgejo G1 finalize (owner sudo window) — every forgejo-family unit condition-skips by design until then.
15. Deploy the a7868a7 vendorHash wave + dms restart (25 FODs fixed, deploy pending).
16. Land the browser-history empty-dashboard fix chain (queued upstream push → bump → deploy → verify).
17. Free port 3000 (knowledge-graph squat) — forgejo smoke false-PASS.
18. Build the rows-after-closing-footer guard in `check-todo-system.sh` (queued 3×, never built).
19. Build the queue Task-ID/fix-ticket dedup gate (21+ no-op re-dispatches across two tickets).
20. Codify the re-fire evidence-appendix convention + retirement clause in CONTRIBUTING.
21. Fix `check-doc-links.sh` inline-code link FP (lint-scanner doctrine) — queued.
22. Drop the stale `todo-list-ai.inputs.systems.follows` override (warns on every nix command).
23. Land the rows 780–788 owner-question batch (three window closeouts waiting on §g answers).
24. Implement the netbird provision ordering-bug fix across its 4 doc surfaces (parallel session's §f.1).
25. Owner: finish the netbird 7-step go-live (setup key, dashboard route, phase-2 flip).
26. Verify deploy-activation of root-prune-guard after the next deploy (inert on host; .prom + journal + Gatus legs).
27. VM-test root-prune-guard timer wiring (threshold stub + metric contract).
28. Restore the stalled `discordsync-db-backup` nightly dump (82 h stale at last check; wave-5 hard gate).
29. Paperless: persist the 04:00 pocket-id-backup DB snapshot + root-cause the OIDC secret desync.
30. InboxClean: confirm Cloud Console OAuth app is "In production" (the 7-day token bomb otherwise recurs).
31. Fix the `\x2d` label escaping in the system-health textfile writer (whole-file metric rejection class).
32. k10temp thermal Gatus check + fan-telemetry gap (three+ crashes with zero CPU-temp alerting).
33. Zone-6 guard trip-RATE alert (90+ trips/2d rode thermal #12 with no trend signal).
34. Durable hwmon fingerprint→chip mapping table in `docs/agents/monitoring.md`.
35. Write freeze #8/#9/#10/#11 entries into `docs/agents/stability.md` (taxonomy ends at #7).
36. `scripts/crash-autopsy.sh` — codify boot forensics incl. sensors + freeze-series lookup.
37. io-psi-forensics bundle retention + durability (1,716 unpruned bundles; freeze-13 death bundle vanished).
38. Fix the freeze-14 no-heavy-builds gate enforcement leg (driver class identified; nothing enforces).
39. Deploy the memory-guard P2 attribution batch (scrub-staleness check, zone gauges, stray-unit lint, race detector).
40. Offsite-borg go-live ladder: recovery-copy policy + `backup.nix` VM test + EIO inode decision.
41. Locate the EIO `/data` inode path and decide repair-vs-exclude before the first real Borg run.
42. SigNoz GCP receivers re-arm (containment-disabled since the first-deploy falsification).
43. Hot-db wave 1 (gatus) in the first owner sudo window; waves 2–5 after.
44. dnsblockd: run M11 user deploy for the allowlist/devices data + M10 csrf smoke probes.
45. Codify the multi-stamp queue-row compaction convention, then apply it (≥3 re-fire stamps → collapse).
46. Extend `check-todo-system.sh`: DONE-state pairing + stale-tag checks (v2).
47. Fix the 63 queue↔library entry drifts the pairing check surfaced (10 wrong-link + 38 no-entry + 14 completed-but-queue-open + 1 overlap).
48. Extend the CI shellcheck job to `scripts/lib/*.sh` + `.githooks/*` (error-bar blind spot).
49. Private binary-cache decision (cachix/attic) for clickhouse-class uncached giants (~1.5 h per drv-touching bump without it).
50. Triage the 6 failing VM tests (disko-layout/hermes/hot-user-caches/crush-hot-db/browser-history/restic) with provenance.

## g) Questions for the owner (cannot self-answer)

1. **Cross-session prune etiquette:** the sweep pruned 5 netbird `[x]` rows your _other active session_ had flipped hours earlier (contract-compliant, content preserved verbatim in CHANGELOG + git). Should same-day `[x]` rows from a sibling session be exempt from a docs pass's prune, or is any-pass prunes-all the standing rule?
2. **Archive gate:** the strict completeness gate (`grep -rLn '~~' archived/ → nothing`) is violated by ~1,074 existing archived files that carry banner-only resolutions. Relax the gate to "banner OR strikethrough" (codify current practice), or fund a mechanical backfill sweep that adds one inline strikethrough per legacy file?
3. **Research archive:** should `docs/research/` grow an `archived/` convention (the superseded 2026-07-11 btrfs-wiki file then moves), or does research stay flat forever as frozen reference?

## Harvest log (report §f self-harvest accounting, per the status-report convention)

- Item 1 (gate shape) + item 3 (research-archive convention): NEW `[decision]` rows landed in `docs/todo/pipeline.md` this pass (library-only per routing — owner questions never enter TODO_LIST).
- Items 2, 16, 17, 18, 19, 22, 27, 45, 46, 47, 48: already queued this session or standing rows (cited above).
- Items 4–15, 20–44, 49–50: already tracked on their cited surfaces (verified by grep during the harvest dedup); deliberately NOT re-queued — duplicates are the drift class.
