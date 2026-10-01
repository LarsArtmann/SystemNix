# Status Report: AGENTS.md Restructure → Domain Library (2026-10-01 02:54)

**Session scope:** the user's request — AGENTS.md is "~10x too big"; (a) clean it up,
(b) split into referenced .md files on a need-to-know basis. Emphasis: "most superb
job possible, nothing less."

**Headline result:** root `AGENTS.md` 605,658 B / 1,327 lines → **34,035 B / 150 lines
(−94.4%)** with **line-level zero knowledge loss** (audit: 0 of 1,021 original
non-blank content lines missing from the new layout). Content now lives in
`docs/agents/` (12 domain files + provenance README), 15 new service runbooks,
21 runbook appendices, and one CONTRIBUTING appendix.

Commits: `d89029cf` (daemon-swept bulk, heuristic message — the daemon raced the
session mid-flight), `8e6409dd` (session-authored completion: strays merged,
pathspec-scoped). Pre-commit gates passed on `8e6409dd` (gitleaks, whitespace,
`nix flake check --no-build --all-systems`).

---

## a) FULLY DONE

1. **Inventory + mapping**: full header map of the old file (78 real sections),
   bullet-level routing for the mixed "Other Services" / "Infrastructure Patterns"
   grab-bags (24 + 17 individual bullets routed by keyword table).
2. **`docs/agents/` library created** (12 files + README): `nix-flakes`,
   `go-ecosystem`, `integration-registry`, `systemd`, `storage`, `stability`,
   `sso-dns`, `secrets`, `desktop`, `monitoring`, `shell-devtools`, `git`.
   Each with authored header ("Read when" + index), bodies moved **verbatim** via
   scripted `sed` extraction (no hand transcription).
3. **15 new service runbooks** for services that had none: inboxclean,
   browser-history, fastflowlm, llama-rag, google-sync, searxng, monitor365,
   dnsblockd, github-auto-assign, emeet-pixyd, nix-email, journal-hot,
   wifi-failover, bank-sync, projects-management-automation.
4. **21 runbook appendices** ("Agent Notes (migrated from AGENTS.md 2026-10-01)")
   + CONTRIBUTING appendix (HTML-report house pattern).
5. **New lean AGENTS.md**: routing table ("working on X → read Y first"),
   architecture, TODO system, prevention-layers table, universal critical rules
   (3 long rules condensed to 2-line pointers; full text in git.md/nix-flakes.md),
   session discipline, build/deploy, platform constraints. 4KB boot-mirror
   paragraph moved to systemd.md with pointer.
6. **Deduplication**: the verbatim-doubled Gatus `pat()` paragraph inside
   "Adding a Service" step 9 collapsed (1,303 B; dangling `**` seam fixed).
7. **Reference integrity**: ~18 stale `AGENTS.md <section>` references updated
   across flake.nix (3), scripts (10), flake-update.yml (1), CONTRIBUTING (4),
   runbooks (5: signoz-coverage, discordsync, offsite-borg ×2, data-damage-set ×2).
   `scripts/check-doc-links.sh` LIVING_DOCS extended to cover `docs/agents/*.md`.
8. **Verification stack run green**: line-level conservation audit (0 missing),
   header audit (78/78), code-fence balance (0 unbalanced), `check-doc-links.sh`
   OK, `check-todo-system.sh` OK, pre-commit `nix flake check --no-build
   --all-systems` OK (on commit `8e6409dd`).
9. **Post-delivery staleness fixes on sight**: AGENTS.md "every service has a
   runbook" overclaim softened, `docs/README.md` gained `agents/` row + corrected
   AGENTS.md description, stale test comment (test-inboxclean-paperless) repointed,
   provenance README now names both migration commits.
10. **Self-harvest executed** (per TODO System rules): 6 queue rows + full library
    entries in `docs/todo/{pipeline,services}.md` (checker green after).

## b) PARTIALLY DONE

1. **"Clean it up" vs "move it"**: the split is verbatim-preserving; the *prose
   itself* was not rewritten/tightened (deliberate: zero-loss migration first).
   Superseded-chain narratives ("SUPERSEDED 2026-09-30", corrected claims) survive
   as-is inside the new files — accurate but verbose.
2. **Critical Rules**: 3 long rules condensed in core with pointers; the remaining
   ~15 kept bullets are still dense (several 1-2 KB lines). Platform Constraints
   (~12 KB of the 34 KB core) retained — debatable whether it belongs in core.
3. **Anchor audit**: hand-verified ~30 slugs; found+fixed 1 real mismatch
   (`gitleakstoml`). No automated anchor checking exists yet (queued).
4. **Daemon race handling**: land-on-top commit `8e6409dd` completed the work, but
   history now carries a heuristic-message commit (`d89029cf`) containing 1 foreign
   file (the parallel session's `tests/test-dns-blocker-render.nix`) — amend was
   correctly refused for that reason; a single clean commit was not achievable.

## c) NOT STARTED

1. Editorial merge of the 21 appendices into runbook narratives (queued).
2. Runbook backfill for ~11 services still lacking one (queued; claim softened).
3. CHANGELOG entry (queued).
4. Wiring `check-doc-links.sh` into any automated gate (it is manual-only —
   grep-verified absent from `.githooks/` and `.github/`).
5. Anchor validation automation (queued).
6. Any crush-side context automation (hook injecting the matching docs/agents file
   by edited paths) — owner decision queued.

## d) TOTALLY FUCKED UP (all caught + fixed in-session; none survived)

1. **The `app()` shell-function bug (worst of the session)**: `shift` then `$1`
   inside the loop referenced the CHUNK NAME, so all 21 runbook append `cat`s wrote
   into extensionless stray files (`docs/services/cv`, …) instead of the `.md`
   targets. Banners landed; content didn't. **21 files silently wrong.**
2. **The first append verification was inadequate**: I checked `wc -l` of only 3
   files with output truncated by `tail -4`, misread it, and moved on — the bug
   survived ~15 minutes of subsequent work until the conservation audit forced a
   real look. Direct violation of the house "TEST AFTER CHANGES" rule (batched
   21 edits, verified 3, partially).
3. **The conservation audit itself was initially broken**: `grep -qF "$line"` with
   lines starting `- ` was parsed as OPTIONS (859 false "missing"). The broken
   audit is what surfaced the real bug — two errors cancelling into discovery is
   luck, not method. Correct form: `grep -qF -e "$line"`.
4. **Daemon race**: the auto-commit daemon committed mid-flight (`d89029cf`),
   including the stray files; cleanup then required a second commit. My restructure
   was never atomic. Mitigated per documented policy (verify `git show --stat`,
   refuse amend on foreign file, land-on-top pathspec commit).
5. **Near-miss knowledge loss**: the "Docker & Containers" section was initially
   routed nowhere — caught by my own anchor/provenance audit and recovered from
   `git show HEAD:AGENTS.md` (the working tree had already lost it).
6. **`monitoring.md` assembled wrong twice**: first version duplicated the
   backup-coordination bullets + had an empty section; rebuild then left
   "Gatus Health Check Design Patterns" as a bold line (dead anchor) instead of a
   heading. Both caught by self-audit, fixed.
7. **Smaller fumbles**: `newsvc()` chunk-extension bug (13 header-only files,
   re-run), `extract.sh` sanity-assert abort midway (crit-rules range started on a
   blank line; 55/99 chunks; re-ran), one anchor slug mismatch.

## e) WHAT WE SHOULD IMPROVE (session lessons)

1. **Verify each mechanical step immediately with a content probe, not a line
   count** — `wc -l` after a batch proves nothing (banner-only files passed);
   grep a distinctive payload phrase per target.
2. **`grep -F` on arbitrary lines needs `-e`** — lines starting with `-`/dashes
   are parsed as options. Encode in shell-devtools reference.
3. **Avoid `$1`-after-`shift` in shell helper functions**; prefer explicit
   `target=$1; shift` capture BEFORE shifting (the exact shape that silently
   misdirected 21 writes).
4. **Commit large mechanical migrations in smaller atomic steps** (or immediately
   after the risky step) so the daemon cannot bake intermediate garbage into
   history; a single 50-file batch invites exactly this race.
5. **A repo this doc-heavy needs the link/anchor checker WIRED into a gate** —
   the restructure's integrity currently rests on manual runs.
6. **The routing table is only as good as agent discipline** — new sessions get a
   34 KB AGENTS.md; whether they actually read the routed domain file is
   unenforced (hook idea queued).

## f) NEXT (harvested; queue + library rows landed)

1. Wire `check-doc-links.sh` into pre-commit/CI (pipeline).
2. Heading-anchor validation in the checker (pipeline).
3. CHANGELOG entry for the restructure (pipeline).
4. Backfill ~11 missing service runbooks (services).
5. Editorial fold of the 21 appendices into runbook narratives (services).
6. Owner decision: crush hook injecting `docs/agents/<domain>.md` by edited paths.
7. Owner decision: slim the core further (Platform Constraints detail →
   storage/stability) or accept 34 KB.
8. Rewrite superseded-chain narratives inside docs/agents files (accuracy pass).
9. Condense remaining mega-bullets in Critical Rules to pointers where full text
   has a domain home.
10. Cross-link `docs/agents/integration-registry.md` step 9 ↔ `monitoring.md`
    Gatus patterns (both carry pat() rules).
11. Add "see docs/agents/<x>.md" pointers as comments in the owning module files
    (e.g. fastflowlm.nix → its runbook).
12. Sweep remaining prose `AGENTS.md` mentions repo-wide and classify each
    (historical-claim vs live-pointer).
13. Consider a generated TOC/health check for docs/agents files (index links
    currently hand-maintained).
14. The parallel session's mr-sync `wantedBy` outage fix (their bullet already
    landed in mr-sync.md Agent Notes) needs its deploy — track theirs.
15. Fold the shell lessons (§e2/§e3) into `docs/agents/shell-devtools.md`.

## g) QUESTIONS (cannot figure out myself)

1. **Core size target**: is ~34 KB / 150 lines the right landing zone for
   AGENTS.md, or should Platform Constraints + Build&Deploy detail also move out
   (~20 KB core)? Tradeoff: hardware facts (GTT-first, disk layout) are broadly
   load-bearing vs. lean-ness.
2. **Appendix editorial pass priority**: fold the 21 "Agent Notes" blocks into
   runbook narratives now (touch-all-files churn while parallel sessions are
   active), or only per-file on touch (slower convergence, zero race risk)?
3. **Context automation**: want a crush hook that auto-loads the matching
   `docs/agents/<domain>.md` when a session edits that domain's files, or is the
   routing table + agent discipline sufficient?

---

**State at close:** working tree carries only this report + the harvest edits +
the parallel session's in-flight files (`modules/nixos/services/mr-sync.nix`,
`mr-sync.md` bullet, `tests/test-dns-blocker-render.nix` — theirs, untouched).
All checks green at last run. No deploy needed (docs-only session).
