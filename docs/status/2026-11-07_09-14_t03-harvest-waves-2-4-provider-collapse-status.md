# 2026-11-07 09:14 — T03 harvest waves 2–4, provider collapse to zai-only, deploy blocker moved

Session: continuation of the SUPERB backlog masterplan (v5) T03 harvest lane + handoff recovery. Owner directive standing: full TODO list, verified.

## a) Executive summary

- **T03 unharvested §f-reports: 159 → 115** this session (predecessor took 203→159). Waves 2–4 processed 45 reports, minted 262 rows (41+27+194), all queue-mirrored, strict-gate-verified after every wave.
- **Subagent provider landscape collapsed to zai-only**: gemini banned by owner directive (no subscription — two runs landed before the stop), hyper has no credits, huggingface demands pre-paid credits. Rule recorded in AGENTS.md (`174cebbc3`).
- **Deploy still blocked but the blocker MOVED**: 06:46 papdashboard float → 07:35/07:51 `float-register` aborts on unpushed sibling-session work (emeet-pixd +9, go-cqrs-lite +2, crush-config +1 commits ahead of locked revs). Parallel-session lane; owner Q1 context updated, still unanswered.
- **Todo-gate scanner hardened**: the marker-grep case bug (capital-H "Harvest log" silently unregistered) fixed with `[Hh]arvest log` + a selftest leg (`00a98d1dc`).

## b) Work completed

1. **Handoff recovery / git integration**: 2 unpushed commits + origin moved mid-flight. Survived 3 parallel-session races (my rebase aborted externally, my merge aborted externally, daemon concluded a merge state) — final resolution: verified our tree is a content-superset of the only-behind commit `f1081420e` and used conflict-immune `merge -s ours` (`8515822d6`), then clean pushes.
2. **Wave 2 (b03 batch)**: 15 reports (10-06→10-10), 123 DONE / 142 tracked / 6 obsolete / 1 premise-falsified (inboxclean URL casing already canonical at flake.nix:301 — row NOT queued). 41 rows. Gate 159→144. Commit `7684f4a6f`.
3. **Scanner fix**: check-todo-system.sh:270 `[Hh]arvest log` + selftest-harvest-ci leg; `--selftest` OK; row pair (TODO_LIST:2157 + pipeline.md:745) ticked with evidence. Commit `00a98d1dc` (script hunk daemon-swept into `c6b876ef1`, contents verified).
4. **Wave 3 (b04 batch)**: 15 reports (10-11→10-15), 179 DONE / 148 tracked / 4 obsolete. 27 rows across 7 libraries. Gate 144→129. Commit `52fa4f4d4` (clean, pure appends).
5. **Wave 4 (b05 batch, largest)**: 15 reports (10-15_05-20→10-17_20-59), **565 items triaged**: 40 DONE, 208 already-tracked, 92 obsolete, ~225 OPEN → 194 new rows minted (2 dup-title rows dropped against richer existing rows). Gate 129→115 (incl. +1 brand-new 08-47 report from a parallel session). Bulk daemon-swept; remainder committed `4b8f67fc4`.
6. **Deploy forensics** (read-only): gen-985 still live; 07:35 + 07:51 deploys exit-12 with a NEW failure signature — float-register refuses to float sibling checkouts with unpushed local commits. Not the papdashboard FOD anymore.

## c) Verification evidence

- Strict gate after every wave: 159→144→129→115 (each −15 exactly, +2 genuinely-new reports accounted: 08-47 decrypt-overlay, and 21-40 regression caught+fixed).
- All 15 wave-4 markers verified present in real files after ghost recovery (15/15 grep=1).
- Premise spot-checks at queue time (the queue-author rule): starship.nix:80 docker_context ✓, darwin shells.nix:55/75 ✓, CHANGELOG qmd entry corrected 1416→1418 ✓, boot-metrics.md absent ✓, shell-devtools sqlite mention unrelated ✓, inboxclean casing FALSIFIED (row suppressed).
- Duplicate-row gate fired on 2 minted rows → both dropped, re-run clean.
- `bash scripts/check-todo-system.sh --selftest` OK including the new case-forgiving leg.

## d) Own-goals and incidents (honest record)

- **mark() suffix bug**: wave-4 script appended `.md` onto filenames already ending in `.md` — all 15 markers landed in `.md.md` ghost files. Caught via gate arithmetic (+2 delta investigation). Recovered: markers moved into real files, ghosts trashed. **15 deletions are staged-but-uncommitted**: the pre-commit hook runs a full `nix flake check` on ANY deletion and the tree eval is currently RED from parallel-session edits — committing them waits for a green window.
- **21-40 marker lost** to a parallel-session file overwrite mid-wave; re-applied manually, then deduped a double marker.
- **Wave-2 commit absorbed a parallel session's ADR-0021 row tick** (directory-glob pathspec — later waves used exact file lists; no repeats since).
- **Commit subjects >72 chars rejected twice** by the hook (amended/recommitted).
- **Provider cascade on b05**: gemini-4-argon dispatched before the owner ban landed (massimo b03 rerun + amy b04 ran on it; amy showed a $99.99 cost display); owner stopped it; hyper → "no credits"; HF gpt-oss → "purchase pre-paid credits"; zai default succeeded (francis, excellent quality, 565 items).
- One flake-check run burned by the hook while the tree was red (the failed wave-4 commit attempt).

## e) Numbers

| Wave | Batch | Reports | Items triaged | New rows | Gate before→after |
|------|-------|---------|---------------|----------|-------------------|
| 2 | b03 | 15 | ~270 | 41 | 159→144 |
| 3 | b04 | 15 | ~355 | 27 | 144→129 |
| 4 | b05 | 15 | 565 | 194 | 129→115 |
| (predecessor) | b00-02 | 44 | — | ~250 | 203→159 |

Remaining: 115 unharvested (b06–b13 sliced ~15 each + new tail). Queue ready-rows grew by ~260 mirrored one-liners this session.

## f) Follow-ups (self-harvested at authoring time — see TODO_LIST/library rows)

1. Commit the 15 `.md.md` ghost deletions when the tree eval is green again (pre-commit deletion rule) → pipeline.
2. Continue harvest waves b06+ (b06/b07 pre-sliced; add the new 08-47 decrypt-overlay report + recheck 21-40) → pipeline.
3. Owner Q1 refresh: blocker is now sibling unpushed work, not papdashboard — answer still pending → services [blocked:user].
4. Provider-credits decision (hyper/HF) if subagent fan-out beyond zai is ever needed → pipeline [decision].
5. ADR-0021 ride-along attribution note in the wave-2 commit (cosmetic, recorded here; no action).

## g) Open owner questions (unchanged from 07-17 report, Q1 context updated)

1. **Float policy** — pin/revert and deploy, or leave to the parallel session? (Blocker moved: now unpushed sibling work.)
2. **Agent-sudo scope** — may agents run the irreversible [blocked:user] reclaim ceremonies?
3. **Grind priority** — finish T03 to zero (115 left) vs ~1300-row queue sweeps vs 4% chain?

**Session state: WAITING for owner answers; b06 dispatch is the always-safe continuation lane.**
