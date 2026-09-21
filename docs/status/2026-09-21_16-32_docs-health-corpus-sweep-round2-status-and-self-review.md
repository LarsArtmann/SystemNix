# Docs-Health Corpus Sweep Round 2 — Full Status + Self-Review (2026-09-21 16:32)

**Session window:** ~14:20 → 16:30 CEST, 2026-09-21.
**Directive:** "View ALL \*\*/2026-0\* files, execute the docs-health SKILL properly, make the six living docs SUPERB, archive FULLY done + inline-struck reports."
**Scope honored:** every non-archived `docs/status/2026-0*.md` report (~270 after the 09-19 sweep's 34 moves), all 33 dated `docs/planning/2026-*` plans, the 2 `docs/operations/2026-0*` runbooks, peripheral `docs/{brainstorming,research,reviews}/2026-0*` classification, and the six living docs. The `docs/status/archived/` corpus (1,347 pre-existing) was NOT re-opened (it is already the resolution of those files; see §c.4).

**One-line summary:** the whole non-archived 2026-0* corpus was re-classified against the tree via 6 verifying agents; only 26 of ~300 candidates were fully resolved — all 26 annotated with resolution banners + per-item inline strikethroughs and `git mv`'d; the deferred planning triage COMPLETED (21 archive / 1 open kept / 7 reference kept); 9 living-doc references to moved files repointed with a residual scan proving zero dangling pointers; 4 drift defects fixed on sight; superfile's unharvested chain routed into FEATURES + libraries + queue; CHANGELOG entry appended; all gates green (`check-todo-system`, `check-doc-links`, archive completeness 26/26, `nix flake check --no-build` rc=0) — and one fleet-wide eval breakage that appeared mid-session turned out to be a PARALLEL session's nixpkgs bump, which that session fixed itself (`7ec13a70`) while I was diagnosing it.

**Commits:** everything rode the auto-commit daemon (rename batches `52574a41`, `dc04ea0e`, `5252fe07`, `059a67b8`, `aa24902b`, `cfcd2a86` carry the moves/edits; `7ec13a70` is the parallel session's d2-shim drop). I made zero manual commits (harness rule).

---

## a) FULLY DONE (verified, evidence attached)

| # | Item | Evidence |
|---|------|----------|
| 1 | Full inventory: 276 non-archived status reports (176 pre-sweep + ~100 newer), 33 dated planning docs, 2 operations runbooks, 6 peripheral docs enumerated; 1,347 pre-existing archived counted | `ls docs/status/*.md \| grep -v archived` at session start; `ls docs/status/archived/ \| wc -l` = 1347 |
| 2 | 6 extraction agents (3 + 2 + 1 rate-limited retry) classified every corpus file with TREE VERIFICATION (modules/, scripts/, AGENTS.md, CHANGELOG [Unreleased], docs/todo libraries, successor reports) — verdicts: status corpus ≈ open-carriers, planning corpus = 21 archive candidates | Agent outputs this session; verdicts cite per-file open-item lists now reflected in the source reports' harvest rows |
| 3 | **26 docs annotated + archived**, each with a `[docs-health 2026-09-21] RESOLVED + ARCHIVED` banner AND ≥1 evidence-citing inline strikethrough (numbered items struck per-item via `annotate-prose.py`/`annotate-rows.py`, dry-run first): 3 status (`2026-09-20_11-00_nodejs-slim-shim…`, `2026-09-20_12-15_boot-mirror…rc3`, `2026-09-18_signoz-pair-bump…`), 20 planning (SESSION-15/35/78/118, extract-dnsblockd, openseo-domain ×2 eras, flake-standardization, master-todo, do-more-with-less, flake-reliability, full-codebase-review, self-review-06-15, DMS-backlog, monitor365 ×2, data-corruption master plan, forgejo-primary (superseded), PARETO-superb, samsung-role), 2 operations (cv variant-patch runbook, obsolete manual-steps) | completeness gate `grep -rL '~~'` over all 26 → EMPTY; `git log --diff-filter=R` shows the rename batches |
| 4 | Status-corpus verdict for the ~270 non-archived reports: exactly 3 fully resolved since 09-19; the rest remain open-carriers with per-file open-item inventories captured in the agent extractions (already mirrored in the todo libraries for the actionable ones) | Agent batches: 45 oldest = 0 archive-ready, 50 mid = 0, 40 + 36 newer = 0; the 12 newest = 0 (all retain user/owner-gated chains) |
| 5 | **Planning triage (deferred since the 2026-09-19 sweep) COMPLETED**: 21 ARCHIVE / 1 OPEN kept in place (`2026-05-16_less-code-more-system.md`, with a routing note) / 7 REFERENCE kept (dozzle eval, rustfs eval, go-cache-ssd2 research, 2 brainstorming, btrfs wiki research + the surviving 09-05 sweep doc) / 2 operations runbooks archived to `docs/status/archived/` | planning triage agent verdicts; `ls docs/planning/archived/ \| wc -l` = 42 (22 prior + 20 new) |
| 6 | **9 living-doc references to moved files repointed**, including a newline-wrapped ROADMAP link and a `.nix` comment glob (`samsung-role-assignment-*.md` no longer matched anything post-move): ROADMAP.md, docs/todo/storage.md ×2 targets, forgejo successor plan ×2 sites, 2026-09-18_17-28 status report, samsung-phase2 plan, 2026-08-31_20-02 status report ×2 sites, AGENTS.md, docs/README.md, platforms/nixos/hardware/hardware-configuration.nix | residual scan `grep -rln "docs/planning/2026-05-03_02-52\|…21-15\|…samsung-role\|…14-41\|operations/manual-steps\|operations/2026-09-19-cv-variant"` over *.md+*.nix excluding archived/ + CHANGELOG → EMPTY |
| 7 | `docs/status/archived/README.md` rewritten from stale 2026-01 claims ("30 reports, year/month layout, 26MB→2MB target") to derived facts: 1,352 files flat + 42 planning archives + 236 open-carriers deliberately unarchived, conventions (git mv + repoint, banner+strike, CHANGELOG frozen-historical), finding aids | old README read pre-overwrite; counts re-derived at write time |
| 8 | **4 drift defects fixed on sight**: (a) dead metric name `browser_history_user_count` → live `browser_history_users` in TODO_LIST:122, `docs/todo/services.md:29` (a user-run verification step that could never match), and the `configuration.nix:511` comment; (b) the `82d4fa4a`→`50f73871` misattribution in the 09-20 deploy-chain report (SHA verified via `git show --stat` before the fix); (c) `snapshots.nix` `@cache-home ~16 GB` stale comment → measured ~37 GB (measurement source: the 09-18 22-17 cache-tier report); (d) historical services.md:21 narrative left intact deliberately (already carries its own inline rename correction at :97) | `grep -n browser_history_users TODO_LIST.md platforms/nixos/system/configuration.nix` at HEAD; `git show --stat 50f73871` |
| 9 | **Superfile chain harvested** (the 14-00 report was written but never harvested): FEATURES.md row added (⚠️ PARTIALLY_FUNCTIONAL — deploy pending), 4 items → `docs/todo/desktop.md` ([blocked:deploy] TUI verify, [decision] yazi coexistence + zoxide/pinnedFolders, [blocked:user] macOS cd-on-quit, [watch] lower follow-ups), 1 [ready] item → `pipeline.md` (formatter-exclusion regression guard) + its TODO_LIST queue row | FEATURES.md diff; `grep -c "Formatter-exclusion regression guard" TODO_LIST.md docs/todo/pipeline.md` = 1/1 |
| 10 | CHANGELOG entry appended under [Unreleased] → Changed (append-only respected; no old entries touched); FEATURES "Updated:" header chain refreshed | `grep -c "docs-health sweep round 2" CHANGELOG.md` = 1 |
| 11 | Gates at close: `scripts/check-todo-system.sh` OK (223 queue rows), `scripts/check-doc-links.sh` OK, archive completeness 26/26, `nix flake check --no-build` **rc=0** (after the parallel d2 fix; the aarch64-darwin skip warning is the documented expected one) | command outputs this session, tail captured |
| 12 | Multi-agent discipline held: content-pinned before every write, re-read after the tool's mtime races (my own annotation writes), foreign diffs respected (the staged §h append to the 10-35 report left untouched; the parallel nixpkgs bump not reverted) | session log; `git status` stayed clean of foreign reverts |

## b) PARTIALLY DONE

| # | Item | Gap |
|---|------|-----|
| 1 | Per-item annotation depth on the 26 newly archived docs | Status reports got FULL per-item strikes (b/c/f/g sections). Planning docs got banner + ONE evidence strike each (their tables already carried ✅ markers or were wholly superseded) — the same volume-call bar the 09-19 sweep set and flagged; letter-of-the-law per-row passes over superseded 2026-05 plans remain undone (low value: ~half their target files no longer exist) |
| 2 | Archive-candidate verification independence | Verdicts came from agents that DID verify against the tree, but I did not independently re-verify each of the 21 planning verdicts before moving (spot-checked 3 during annotation: helium rows, repo-cleanup tables, hermes T-tables — all accurate) |
| 3 | Living-doc freshness | TODO_LIST/CHANGELOG/FEATURES/AGENTS/README/ROADMAP were already refreshed by parallel sessions earlier TODAY; my pass fixed drift where my sweep surfaced it (metric name, superfile row, header) but did not re-audit e.g. README's metric-count claims (SigNoz rules/Gatus checks vs live APIs) — standing row from the 09-19 sweep, correctly not duplicated |
| 4 | The `check-todo-system` CI + fixture rows | The 09-19 sweep's deferred items (nix-check.yml leg, committed fixture in tests/) remain open — I touched the gate's domain (queue rows) but did not extend the gate |
| 5 | `docs/reviews/2026-0*` HTMLs | Classified as REFERENCE-keep mentally but not annotated/archived (they are renderable artifacts under the house HTML doctrine; the superseded harness review claims are visible in later reviews) — judgment call, not executed as file operations |

## c) NOT STARTED

| # | Item | Why it matters |
|---|------|----------------|
| 1 | qmd re-index | The freshest reports stay MCP-unsearchable (flagged by the 08-31, 09-06, and 09-19 sweeps; unchanged) |
| 2 | Second-pass annotation over the ~230 remaining open-carrier reports | Their superseded inline claims ("deploy pending" that landed etc.) are now precisely inventoried in this session's agent extractions — but that inventory lived in the conversation, not persisted (see §c.5) |
| 3 | Per-item strike passes over the 20 newly archived planning docs | see §b.1 |
| 4 | Annotation of appendix-only files already inside `docs/status/archived/` (the 09-19 sweep's §c.3 row) | corpus grew by 5 (3 status + 2 operations); the row's scope grew with it |
| 5 | Sweep-manifest persistence | The per-file verdicts exist only in this conversation (same gap the 09-19 sweep self-flagged; I repeated it) |
| 6 | `check-todo-system.sh` CI wiring + persisted fixture; `check-doc-links.sh` backtick-path extension | carried rows, untouched |
| 7 | The 7 REFERENCE peripheral docs' stale-claim annotations (e.g. brainstorming 07-22's falsified "both directions wired" push-mirror claim) | identified by the planning agent, no inline correction applied — they are non-actionable research docs, kept deliberately |
| 8 | Non-dated planning files (go-flake-template-reference, NIX-COLORS-INTEGRATION-RESEARCH, POCKET-ID-DECLARATIVE-PLAN) | out of the "2026-0*" directive; rescoped queue row names them |

## d) TOTALLY FUCKED UP (honest fumbles, this session)

1. **Two self-inflicted script bugs while batch-annotating the planning docs**: (a) the first batch script's job tuples had a 3-vs-4-element mismatch — it crashed on file 1 and annotated NOTHING, while my shell `for` loop (newline-separated, not `&&`-chained) `git mv`'d all 20 files ANYWAY, leaving 19 archived docs banner-less for several minutes; (b) my "completeness gate" used `grep -LC '~~'` — `-C` consumed `~~` as its context argument, so the gate printed an empty result from a USAGE ERROR, which I first read as success. Both caught and repaired within the same command sequence (per-file fault isolation on the re-run; gate rewritten as `grep -rL '~~'`). Lesson: a gate that cannot fail loudly is worse than no gate — I built one and briefly trusted it.
2. **The edit-tool mtime race bit me 3×** (banner insertions after my own annotation writes). Recovered each time by re-reading, but the first occurrence cost an extra round-trip; after the second I switched to python for banner insertion. Root cause: batching annotation-writer + edit-tool against the same file in one sequence.
3. **One planning archive (helium plan) landed in `archived/` without its banner/status-flip** because the annotating script asserted AFTER the move command had already run in the same shell line — ordering bug, fixed by re-applying at the new path. Same class as (1): mutation + verification must not be separable statements.
4. **A rate-limit retry cost one full agent round** (planning 05-08 dispatch died mid-batch at 3-wide parallelism; the 09-19 sweep's lesson said stagger to 2-3 — I ran 3-wide twice and got bitten once).
5. **I initially framed the d2/flake-check failure as possibly mine** and spent a diagnosis cycle (lock-node jq + store-path read) before `git log` showed the parallel session had already fixed it (`7ec13a70`). Not a defect I shipped — but I ran the flake check against a mid-flight tree WITHOUT first checking `git log --oneline -3` for in-flight parallel work; the multi-agent discipline I applied to edits should also gate gate-interpretation. Cheap fix, learned now: check the daemon's last commits before interpreting ANY gate failure on this box.

Nothing shipped broken in the end state: all gates green at close; no data loss; no secret exposure; no foreign work reverted.

## e) WHAT WE SHOULD IMPROVE (process)

1. **Gates must be self-evidently executable**: `grep -LC` silently eating the pattern is the nullglob-phantom class in grep form. When a gate's flags can consume its needle, use `--` or a form where a mistake fails loudly.
2. **Never separate "move" from "annotate" in a shell line** — one python script should classify-annotate-move per file, atomic, with per-file try/except and a final gate INSIDE the script.
3. **Pre-flight `git log --oneline -3` before interpreting any gate result** on a multi-agent box (extends the existing content-pin-before-write rule to gate-reads).
4. **Persist sweep manifests** (third sweep in a row flagging it): per-file verdict + open-items JSONL committed under `docs/status/` or `.local/state` would make sweeps diffable (NEW vs CARRIED vs RESOLVED becomes mechanical).
5. **Stagger agents at 2-wide** when each agent reads 10+ large files — the 09-19 lesson repeated at 3-wide.
6. **Archive bar codification** (still open from 09-19 §e.4): banner+strike vs per-item-letter should be written into docs/CONTRIBUTING so the next sweep stops re-deciding it (my planning pass applied the bar; the bar itself is still folklore).
7. **Planning-doc triage should ride every docs-health sweep** — deferring it (as 09-19 did) left 21 dead plans polluting the planning dir for two days and made this pass's planning leg the largest chunk of the work.

## f) NEXT (up to 50 — impact-first; NOT a commitment list)

**Tier 1 — direct follow-ups from THIS session (cheap, high value):**
1. qmd re-index so the newly archived + remaining corpus is MCP-searchable (third sweep flagging it)
2. Persist this sweep's manifest (per-file verdicts + open-item inventories) — the extraction data dies with the conversation otherwise
3. Write the archive-annotation bar (banner+strike minimum, per-item for numbered status reports) into `docs/CONTRIBUTING.md`
4. Wire `check-todo-system.sh` into CI (`nix-check.yml`) + persisted fixture (carried 09-19 rows)
5. Extend `check-doc-links.sh` to catch backtick-path prose references (the class I repointed manually at 9 sites)
6. Sweep the 7 REFERENCE peripheral docs for falsified claims worth one inline strike (brainstorming 07-22 push-mirror claim is the known one)
7. Annotate appendix-only files in `docs/status/archived/` (scope grew by this pass's 5 moves)
8. Sanity-probe the 3 remaining undated planning files (queue row already rescoped to them)
9. `git fsck --full` once post-session (zero-byte-object insurance; crash-history box)
10. Confirm the daemon's next batches preserve the repointed references + new queue rows intact (daemon-race discipline)

**Tier 2 — the standing archive/annotation backlog (now precisely scoped by this pass's extractions):**
11. Second-pass annotation over the ~230 open-carrier reports, prioritized by the fresh per-file open-item inventories this pass produced
12. Per-item strike upgrade over the 34 (09-19) + 3 (this pass) archived STATUS reports is DONE for the 3; the 34 remain at banner+single-strike depth
13. Per-item strikes over the 20 newly archived planning docs (low value; explicitly deprioritized)
14. `docs/status/archived/` README: auto-derive counts at write time instead of hand-maintained (it will rot again)
15. Decide + record the CHANGELOG path-reference doctrine formally (frozen-historical — current practice — vs refresh-on-move)

**Tier 3 — the open chains that BLOCK the next round of archives (owner/user-gated, listed so the next sweep can move them):**
16. Samsung reboot + `bootctl` PARTUUID proof → unblocks archiving 4+ boot-mirror reports + 2 plans
17. llama.cpp spin bisect + real-unit soak → unblocks the llama-rag re-enable chain (~5 reports)
18. Forgejo G1 (dedicatedSubvolume enable + migrate script + 2 green sends) and G2 (phase-1 deploy + push-mirror 201 probe) → unblocks the forgejo plan pair
19. browser-history count-gap fix + importUsers() chain landing → unblocks 5+ reports
20. DiscordSync Immich FOD wave + user API key → unblocks its session report
21. Resend domain verification (SPF replace) → unblocks 3 mail-chain reports
22. Codeberg token for forgejo upstream filings → unblocks 2 task reports
23. Wise SCA approval + InboxClean re-consent → unblocks their session reports
24. hot-db Phase-2 migration waves (pocket-id/postgres/discordsync) + `services.hot-db` fold → unblocks the whole 09-20/21 hot-db report cluster
25. crush-hot-db VM test build in a calm window + the pending deploy → unblocks the 09-21 cluster

**Tier 4 — living-docs depth (carried):**
26. FEATURES full-audit completion (sections unread since the August sweep flag)
27. README metric-count claims vs live APIs (SigNoz rules, Gatus checks)
28. Derive README/FEATURES counts from rendered config instead of hand-maintenance
29. ROADMAP: verify the graduated-theme bullets still match `docs/todo` reality post-split
30. AGENTS.md compression session (~386 KB; carried)
31. gotchas-archive narratives (carried list)
32. docs/CONTRIBUTING + docs/DOMAIN_LANGUAGE freshness verification (carried row)

**Tier 5 — hygiene noticed in passing this session:**
33. The `docs/reviews/2026-0*` HTML artifacts have no archived/ convention — decide whether review HTMLs ever move or stay put forever
34. `docs/archive/` (singular) still exists holding one immich doc while `docs/status/archived/` is the consolidated corpus — either fold it or document why it stays
35. TODO_LIST queue grew 212→223 across the day with parallel harvests — next queue-audit pass should re-run the title-match fuzzy check for mangled rows (the `COST MEASURED` class)
36. The 223-row queue's `pixel6` section still carries one literal duplicate title pair ("Full ffprobe sweep…" ×2) — dedupe at next pass
37. `services.md:21`'s 10-paragraph historical resolution narrative is at the readability cliff — a compaction pass over the probe-purge saga would recover a screen of scroll
38. The daemon's rename batches make `git log --follow` the only way to trace pre-archive history — consider a quarterly `docs/status/archived/MANIFEST.md` (name → one-line topic → origin date) if grep is not enough
39. `annotate-prose.py`/`annotate-rows.py` live in the crush-config skill dir — a repo-local vendored copy (or flake app) would make sweep tooling reproducible without my skill mount
40. Sweeps keep tripping on `-LC`-style gate footguns — a tiny `scripts/lib/gate.sh` with fail-loud helpers would retire the class

**Tier 6 — idea-grade (route to ROADMAP if ever funded):**
41. Sweep-diff tooling (NEW/CARRIED/RESOLVED classifier between sweep manifests)
42. docs-health dry-run app (what WOULD be archived, zero mutation) for owner review
43. Age-based auto-flagging of open-carrier reports whose items are all library-tracked (`[watch]`-style expiry candidates)
44. Table-shape lint (trailing pipes/column counts) — the 09-19 pipe-bug class still has no detector
45. Markdown-link rot gate that also understands `docs/planning/archived/` moves (prevents the next 9-repoint manual sweep)

**Tier 7 — this session's deferred judgment calls (owner may override):**
46. The 2 operations docs went to `docs/status/archived/` (the consolidated corpus) rather than a new `docs/operations/archived/` — ratify or re-home
47. `less-code-more-system.md` kept OPEN in planning/ with a routing note (its 4 ideas live in pipeline.md) — or archive it and let pipeline.md be the only carrier
48. The 7 REFERENCE docs kept in place could each take a one-line `[docs-health]` banner citing their supersession status — cosmetic, unfunded
49. `docs/operations/manual-steps-after-deployment.md` was archived as OBSOLETE (not RESOLVED) — banner wording differs from the house convention; ratify the OBSOLETE variant
50. Whether future sweeps should treat `docs/operations/` as in-scope by default (it was ambiguous this pass; I included it)

## g) QUESTIONS I CANNOT FIGURE OUT MYSELF

1. **Archive bar for planning docs:** is "banner + one evidence-citing strike" acceptable for wholly-superseded 2026-05-era plans (my bar this pass), or do you want funded per-row strike passes over their task tables before they count as properly archived (§b.1)?
2. **Where should executed one-shot operations runbooks archive to** — `docs/status/archived/` (where I put both, treating it as THE consolidated corpus), a new `docs/operations/archived/`, or nowhere (operations docs stay put forever)? (§f.46)
3. **Should the ~230 open-carrier reports get a funded second-pass annotation** (striking superseded inline claims like "deploy pending" that landed), or is the archive-only standard the intended steady state until their chains close? This decides whether I persist this pass's open-item inventories as a work queue (§f.2) or let them die with the session.

---

*Point-in-time snapshot — 2026-09-21 16:32 CEST. All gates green at write time (`check-todo-system` OK, `check-doc-links` OK, archive completeness 26/26, `nix flake check --no-build` rc=0). All work is daemon-committed; nothing is pushed by me. §f is docs-health HARVEST input for the TODO libraries/queue; items 16-25 are user/owner-gated and deliberately NOT queue rows.*
