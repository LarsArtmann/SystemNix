# AGENTS.md Audit — Brutal Self-Review + Accuracy Fixes

**Date:** 2026-09-14 16:20 CEST
**Session scope:** docs-health AUDIT of `AGENTS.md` (user: "Is my AGENTS.md superb? What is fucked up about it?"), surgical accuracy fixes, scored verdict, prune proposal. Nothing else. This report covers ONLY this session's run and what it directly surfaced.
**Skill chain:** docs-health (AUDIT/VERIFY + agents-quality-guide + health-report-format) → status-report (this file; user requested `.md` over the skill's HTML default).
**Git at close:** tree clean; all 8 edits daemon-committed (`1029b0d8` carried 7, `7d7c2ead` carried the last). A parallel session's `pool-recovery.nix` work rode `1029b0d8` — flagged to user, untouched by this session.

---

## a) FULLY DONE

1. **Full docs-health audit of AGENTS.md executed and delivered inline** (not written to a file, per skill):
   - Accuracy **7.75/10**, Fitness **6.75/10**, single-file rubric drill-down **3.35/10 → grade D** ("bloated — major rewrite needed").
   - Math shown per the health-report format; no invented baseline (first audit of this file under this skill set).
2. **Measurement:** AGENTS.md = 386,632 bytes / 1019 lines. Section map: Architecture 29 lines, **Key Procedures 617 lines** (the monster), Critical Rules 18, Non-Obvious Gotchas 325, Build & Deploy 17, Platform Constraints ~26. vs the 30 KB budget: **12.9× over**; rubric: >100 KB = "no longer AGENTS.md, it is an archive".
3. **Reference integrity sweep:** extracted 168 unique repo paths from AGENTS.md and existence-checked all: 21/21 scripts, 18/18 test files, all `docs/services/` runbooks, TODO_LIST cross-refs (Phase 1, clickhouse-backup entries), `docs/planning/` + `docs/research/` links — all resolve. Every flagged "MISSING" was triaged to a benign artifact (regex-mangled `/var/lib` runtime paths, git-history blob refs, unicode-ellipsis truncations, prose fragments).
4. **4 verified factual defects found AND fixed** (each verified against live system or repo before editing, re-verified after):
   | Sev | Defect | Fix |
   |---|---|---|
   | Critical | `/rust-cache` bullet still instructed `sudo sgdisk -d 9` against p9 — which since 2026-08-22 is the **live XFS ClickHouse store**. A data-destruction runbook one sudo away from executing. | Rewrote as SUPERSEDED + explicit NEVER-run warning; kept the remaining valid cleanup cmds as "if not already done" (AGENTS.md:649) |
   | Medium | Mount topology wrong in prose: `/nix` claimed `nvme1n1p2` (live findmnt: `nvme0n1p2`), ClickHouse claimed `nvme0n1p9` (live: `nvme1n1p9`). Kernel enumeration flipped again — the file violated its own "never pin kernel names" doctrine. | AGENTS.md now says by-label + "kernel nvme0/nvme1 enumeration FLIPS across boots — live 2026-09-14: …"; same fix applied to the two stale comments in `platforms/nixos/hardware/hardware-configuration.nix` (config itself was already by-label — only comments lied) |
   | Medium | SigNoz exemplar evidence ref read as a SystemNix ghost path (`docs/research/2026-09-14_signoz-exemplar-chain-verification.md` exists only in the **dnsblockd repo**) | Disambiguated: "the dnsblockd REPO's … (~/projects/dnsblockd — NOT this repo)" |
   | Low | `flake.nix (~950 lines)` — actual 1535 | Stale count removed (temporal-pollution class) |
5. **Zone 6 claim verified real** (memory-emergency-guard.nix carries zone6/io_psi_some_avg60) — a suspicious-sounding same-day claim in AGENTS.md checked out; no fix needed.
6. **Duplication metrics computed:** 126 dated bullets, 419 bare date strings, 78 unique commit hashes, 23 "live-verified" markers, "226" class ×7, sudo-sops lesson ×3.
7. **One suspected finding honestly RETRACTED during execution:** the sudo-sops ×3 "duplication" is intentional point-of-use guarding (each carries distinct context: CWD-based `.sops.yaml` discovery, etc.) — not harmful cloning. Announced in the audit report as retracted.
8. **Structural verdict + 3-phase prune proposal delivered** (see c).

## b) PARTIALLY DONE

1. **AGENTS.md structural repair** — diagnosed, scored, proposal written; **zero structural change executed** (owner-gated, see g/Q1). Phases ①②③ defined but not started.
2. **hardware-configuration.nix comment hygiene** — 2 of 3 stale enumeration comments fixed; the Samsung comment (line ~68-70) left as-is because it already reads "nvme1n1 on the 2026-09-05 boot; never pin kernel names" (dated statement, self-annotating). Judgment call: could be unified with the new clickhouse-comment style.
3. **Ref-checker tooling** — the path-existence checker worked in-session twice but was hand-rolled shell each time, not persisted as `scripts/check-doc-refs.sh` (see e/f).

## c) NOT STARTED

1. **Prune Phase ①** — move per-service deep-dive narratives (~450 lines: CV, FastFlowLM, InboxClean, Paperless, Hermes, Mail relay, Miniflux, Google Sync, tq, PapDashboard, Crush keys, llama-rag, Secret Leak Incident) into the *already existing* `docs/services/*.md` runbooks, leaving 5-line pointers. Est. −200 KB.
2. **Prune Phase ②** — distill Non-Obvious Gotchas narratives to one-line enduring rules; push stories to `docs/gotchas-archive.md` (itself 418 KB). Est. −80 KB.
3. **Prune Phase ③** — strip commit hashes/"was-X-now-Y" where current truth suffices; target ≤30 KB.
4. **Archive split-brain merge** — `docs/status/archive` (571) vs `docs/status/archived` (463) vs `docs/archive` (2) vs `docs/archives` (4): 1,040 files across four dirs; AGENTS.md references both spellings.
5. **docs/ top-level graveyard** — ~40 dated point-in-time reports sitting at docs/ root (crash-analysis-*, GITHUB-ISSUES-*, COMPREHENSIVE-*, …) instead of docs/status/.
6. **Sibling-doc audits:** TODO_LIST.md 144 KB (Phase-1 entry alone is a ~1,000-word narrative essay), FEATURES.md 196 KB, gotchas-archive.md 418 KB. Ecosystem total: **1.15 MB of "living" docs**.
7. **Sweep for other stale kernel-enumeration/PCI/sd-letter claims** across AGENTS.md + docs/ (I fixed the 4 I found; the class is documented as recurring — the sweep itself was not run).
8. **CI size gate** for AGENTS.md (prevention of regrowth).

## d) TOTALLY FUCKED UP! (this session's own mistakes — brutal honesty)

1. **Edited before Viewing:** first multiedit attempt was rejected ("you must read the file before editing") — I relied on project_context instead of the View tool. Wasted a round trip; the rule exists precisely for this.
2. **Sloppy ref-extraction regex:** my first path grep mangled ~15 runtime paths (`/var/lib/...` → `lib/...`) into false MISSING hits, which I then hand-triaged. The checker should have anchored on repo-relative prefixes from the start.
3. **Near-misfiled ghost doc:** I initially treated `docs/research/2026-09-14_signoz-exemplar-chain-verification.md` as missing from the repo; only after checking did I find it in `~/projects/dnsblockd`. The AGENTS.md wording was ambiguous, but my checker didn't consider foreign-repo prefixes at all.
4. **Planned a fix I later retracted:** the todo list carried "sudo-sops dedupe" as an execution item before the intentional-similarity judgment was made. Judgment should precede the plan, not follow it.
5. **No git-rev snapshot at session start:** during final verification, `git diff --stat` showing only 1 changed line (despite 8 edits) confused me for a round trip — the daemon had committed mid-session. A start-of-session rev + `git log` check would have made this a non-event on this shared tree.
6. **Silent filter in the final re-check:** I excluded the (now-fixed) exemplar ref from the re-run without documenting the exclusion in the output — correct behavior, undocumented method.
7. **Grade hedging:** the inline report gave rubric 3.35/10 → "grade D" while also citing ">100 KB = Broken/F tier" without explicitly resolving the tension (33.5% lands in D by the letter; F is for skeleton-or-absurd — the call is defensible but wasn't shown).
8. **Unverified "if not already done" cleanup cmds:** I couldn't (no sudo) and didn't attempt to check whether `@go`/`@npm`/`@cargo` subvolumes and `/rust-cache` dir still exist; the rewritten bullet hedges instead of stating fact. Honest limitation, but the attempt wasn't made or documented until now.
9. **"8 edits" arithmetic presented messily** across the daemon commits (5+2+1) — and I only mapped my changes inside `1029b0d8`/`7d7c2ead`, not the full 3-commit daemon batch distribution.

## e) WHAT WE SHOULD IMPROVE!

1. **Stop treating AGENTS.md as the archive.** The file's own header says narratives live in gotchas-archive.md — enforce it. 378 KB is paid as a context tax by EVERY session, every time, forever.
2. **Prevention over audit (the repo's own doctrine, applied to docs):** a CI size gate + a persisted doc-ref checker would have caught the sgdisk-class staleness and the regrowth mechanically. This repo builds eval-time guards for everything else — docs get none.
3. **Kill the archive split-brain** (4 dirs, 2 spellings). One canonical `docs/status/archived/`, references updated once.
4. **TODO_LIST discipline:** entries should be actionable one-liners with evidence links, not 1,000-word essays (the Phase-1 entry carries 6 nested dated updates — it's a status report inside a TODO list).
5. **Enumeration-name rule extended to prose:** the code uses by-label/by-id; the COMMENTS and AGENTS.md keep re-learning this. Rule: prose may only name devices by stable handle (label/id/serial), with dated enumeration snapshots explicitly marked as such.
6. **My own process:** View-before-edit discipline; judgment before planning; snapshot the shared-tree rev at session start; persist ad-hoc checkers instead of re-rolling them.

## f) Up to 50 things to get done next

**AGENTS.md prune (owner-gated by Q1/Q2 — sequenced, each step verifiable):**
1. Phase ① CV section → `docs/services/cv.md` (exists) + 5-line pointer
2. Phase ① FastFlowLM → new `docs/services/fastflowlm.md` + pointer
3. Phase ① llama-rag → new `docs/services/llama-rag.md` + pointer
4. Phase ① InboxClean (3 huge bullets) → new `docs/services/inboxclean.md` + pointer
5. Phase ① Paperless deep-dive → merge into `docs/services/paperless.md` (exists)
6. Phase ① Hermes → merge into `docs/services/hermes.md` (exists)
7. Phase ① Mail Relay → merge into `docs/services/mail-relay.md` (exists)
8. Phase ① Miniflux → merge into `docs/services/miniflux.md` (exists)
9. Phase ① Google Sync (dormant) → new `docs/services/google-sync.md` + pointer
10. Phase ① tq → merge into `docs/services/tq.md` (exists)
11. Phase ① PapDashboard → new `docs/services/papdashboard.md` + pointer
12. Phase ① Crush provider keys → merge into `docs/services/crush.md` (exists)
13. Phase ① Secret Leak Incident → new `docs/security/secret-leak-incident.md` (keep open-action summary + purge-runbook pointer in AGENTS.md)
14. Phase ② distill Gotchas narratives → one-line rules; stories → gotchas-archive.md
15. Phase ② consolidate the "226/NAMESPACE" class (7 mentions) into one canonical gotcha
16. Phase ③ strip/convert commit hashes + "was/now" narratives (78 hashes)
17. Add a "which doc owns what" map to the AGENTS.md header (README/TODO/FEATURES/runbooks)
18. CI size gate: `nix flake check`-style assertion that AGENTS.md < 40 KB (hard fail)
19. Same gate for TODO_LIST.md < 30 KB (anti-essay)

**Repo doc hygiene:**
20. Merge `docs/status/archive/` + `docs/status/archived/` → one dir (1,040 files, `git mv`; owner-gated by Q3)
21. Update all references to the merged archive dir (AGENTS.md uses both spellings)
22. Move ~40 top-level dated reports in docs/ → the archive structure
23. Fold `docs/archive` (2) + `docs/archives` (4) into the same structure
24. TODO_LIST.md HARVEST pass: strike done items, distill the Phase-1 essay into ≤10 lines + links
25. FEATURES.md audit (196 KB — verify statuses against code, docs-health VERIFY)
26. gotchas-archive.md dedupe vs AGENTS.md narratives (the split brain feeding the split brain)
27. Normalize unicode-ellipsis truncated refs (`2026-08-16_21-25…`) to full filenames
28. Sweep docs/ + AGENTS.md for stale kernel-enumeration names (nvme0n1/nvme1n1) and PCI addresses — same class as the 4 fixed here
29. Check `docs/DOMAIN_LANGUAGE.md` freshness (seen but not verified this session)

**Prevention tooling:**
30. Persist `scripts/check-doc-refs.sh` (path-existence checker for markdown docs; anchored on repo-relative prefixes, foreign-repo aware)
31. Wire it into pre-commit + CI for AGENTS.md/TODO_LIST/FEATURES
32. Add `git rev` snapshot habit → maybe a session-start helper script for agents on this shared tree

**Accuracy loose ends from this session:**
33. Verify (sudo) whether `@go`/`@npm`/`@cargo` + `/rust-cache` cleanup already ran → convert the rewritten bullet to DONE or execute
34. Unify the Samsung comment in hardware-configuration.nix with the new enumeration-flips comment style
35. Re-audit the AGENTS.md bullets I did NOT touch for the same stale-runbook danger class (the sgdisk find suggests siblings may exist)

**Ops items noticed while reading (NOT researched — single-glance observations, verify before acting):**
36. `btrfs-emergency-reserve` absent since ~Sep 7 per TODO_LIST — its Gatus check should be RED; verify alert delivery actually fired
37. TODO_LIST Phase-1: delete old QLC `@nix` (118G) after attic store-rebuild sanity — user-run
38. llama-cpp mid-load CPU-spin regression (2026-09-14): pin `llama-cpp-rocwmma` to the 20260905-era build or bisect upstream (RAG currently dark/contained)
39. flm v1.0.3 revert: upstream issue now ELIGIBLE per the staged-bump gate — optional filing
40. QLC root post-ENOSPC recovery: watch chunk-unalloc (68.5 GiB) doesn't re-collapse

*(40 items — items 1-19 sequenced, 20+ independent; 36-40 are notice-only, each needs its own verification pass before execution.)*

## g) Questions I can NOT figure out myself

1. **Prune green-light + target:** Execute Phase ① now (service narratives → existing runbooks, ~−200 KB)? The tradeoff is yours to own: 378 KB is a per-session context tax on every agent, but it also means every lesson is ALWAYS loaded without anyone having to open a runbook. Target size for the final file (30 KB strict, or a pragmatic 60-80 KB)?
2. **Date/hash anchors — keep or strip?** Your memory-maintenance doctrine writes dated forensic anchors at discovery time; the endurance doctrine says strip dates/hashes and state current truth. The two conflict and both are canonical here. For the distilled rules: preserve the (2026-MM-DD) provenance markers, or reduce to current-truth statements with history living only in git/gotchas-archive?
3. **Archive-dir merge:** approve the 1,040-file `git mv` consolidation of `docs/status/archive` + `archived` (+ `docs/archive`/`archives`)? If yes, which spelling survives — `archive/` (the older, larger one) or `archived/` (matches docs-health skill vocabulary)?

---

**Then WAIT FOR INSTRUCTIONS.**
