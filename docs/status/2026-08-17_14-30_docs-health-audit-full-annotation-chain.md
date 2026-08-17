# Status Report: docs-health AUDIT of ALL 2026-08-1* Files — Living-Doc Overhaul + Report Annotation/Archive Chain

**Task:** User directive: view ALL `**/2026-08-1*` files, execute the docs-health skill PROPERLY (AUDIT = BUILD + HARVEST + VERIFY + ANNOTATE + ARCHIVE), make TODO_LIST/CHANGELOG/AGENTS/ROADMAP/FEATURES "SUPERB", archive fully-done-and-updated (inline-strikethrough) files.
**Date:** 2026-08-17 14:30 (session ran ~13:00–14:30; this report written at the user's mid-session interruption)

---

## a) FULLY DONE

1. **Skill + references loaded, mode = AUDIT.** docs-health SKILL.md + 3 references (harvest-guide, resolving-items, annotation-placement, health-report-format) read in full before any edit.
2. **ALL 46 non-archived 2026-08-1* files viewed** — ~20 read directly (every Aug-16/17 status report + all 5 planning docs), the remaining 26 (Aug-12→15 chain) extracted verbatim via two read-only sub-agents (full item lists, resolution-marker state, monitor365-mootness analysis per file).
3. **Facts verified against code before writing docs** (VERIFY, not trust): monitor365 `enable = false` in configuration.nix (private wireguard-collector comment); browser-history input pinned `4e7604d` with `MAX_USERS=1` set; `paperless.nix` + port 2892 + `backup.dir` in lib/docker.nix exist; btrbk pool targets in snapshots.nix; module count 55 / Gatus endpoints 100 / sops files 16 recomputed live; aw-watcher wayland-gate wired; test-ksm.nix present in tests/.
4. **CHANGELOG.md** — 6 new Unreleased entries: three-drive repurposing + pool backup tier + paperless + immich migration + forensic closure; visionreviewd wrapper; browser-history fast-startup/mkOidcGate (storage/v4.7.0 era); stdenv hostPlatform sweep; buildcache zombie-mount self-healing stack + deploy.sh nh exit-4 fix; buildcache pnpm-prune + NVMe recontamination; nixpkgs Aug-16 bump (`e5bdc4a4`). Fixed the stale "web.enabled=false / 404" note inside the old Discord-spam entry via the new entries' facts.
5. **FEATURES.md** — Paperless row added; **monitor365 corrected ✅→🔧 DISABLED** (was claiming FULLY_FUNCTIONAL while config-off — the biggest single lie in the doc set); Immich pool migration; SigNoz row rewritten (web UI shipped, 23 rules + policies, 5 native-v2 dashboards, 9 scrape targets, meta-alerts); Browser History ⚠️→✅ (fast startup); DiscordSync Turso-disabled note; visionreviewd row; Scheduled-Tasks table rewritten (7 new backup jobs); counts recomputed (55 modules / 100 endpoints / 16 sops); Known Gaps: off-site advanced (pool live, off-site open), ZFS era CLOSED, SigNoz-dashboards resolved, monitor365 disabled added.
6. **ROADMAP.md** — off-site theme reflects pool reality + open 3rd-copy decision; disk-space updated to 95%/CoW mechanics; ZFS era CLOSED (pool destroyed + repurposed); NPU updated (FastFlowLM running); ZFS `datapool` added to the Rejected table.
7. **AGENTS.md** — new **"HDD Backup Pool & DAS Topology"** section (pool layout, backup tier, DRIVE FREEZE, paperless traps, CoW mental model); Monitor365 section header now states DISABLED + G7 blocker; new gotcha: flake.lock root-input→node-key mapping (`nixpkgs` vs `nixpkgs_2`).
8. **TODO_LIST.md fully rewritten** (the harvest): deleted 6 completed items (zellij workflow, wf-recorder ×2, test-photos, OTel-scheme eval check, templ-committed CI, zram alert, monitor365-gating, rust-cache done-half); closed the monitor365-outage family as moot with the G7 decision item; added ~20 new harvested items (Turso down, module-curl gzip audit, hermes failure, pool seeds monitoring, smartd runtime verify, boot-resilience test, paperless password handover, dashboard generator, migrator-gap guard, file_storage cursor, json-file containers, deploy lock-wait, AUTH_VHOSTS derivation, fetch() helper, flap-counter/zombie-detector, gc observability, `/home/hermes` 58G, dns-blocker convergence, key rotation flag); Deploy Verification Checklist updated (curl `--compressed`, monitor365 auto-SKIP row).
9. **23 status reports annotated (every numbered item resolved) + 19 archived** — inline `~~strikethrough~~ done at …` markers where resolvable, `Won't do/moot/dropped/routed` verdicts elsewhere, plus a per-file **Resolution (2026-08-17)** appendix mapping every remaining item to TODO_LIST/ROADMAP/untracked/moot. Archived: 00-01, 01-34, 03-08, 03-09, 03-30, 03-44, 04-09, 04-32, 06-38, 06-45, 13-19, 17-09, 17-24, 18-39, 19-12 ×2, 20-01, 20-41, 21-24. Kept live (open work remains): 00-59 (seeds in flight, undeployed config), 21-25 + 23-27 (browser-test items), 22-00 (Turso decision).
10. **`2026-08-16_20-22_three-drive-repurposing.md` plan amended with the Decision Record** (btrfs-send not borg; sdf/SanDisks frozen; services-on-pool; Google-offsite stance) and archived to `docs/planning/archived/` — closing the plan-vs-reality split brain.
11. **Daemon swept the work into `05789a89`** ("docs: 2026-08-17 docs-health pass…").

## b) PARTIALLY DONE

1. **ANNOTATE the Aug-12→15 chain (12 files) — NOT yet touched**: 08-12_20-52 docs-health self-review; 08-14 ×9 (signoz-perses-research [item 25 already struck], ssd-benchmarking [SUPERSEDED banner exists], **ssd-repurposing-options [the 5×-carried "foreign" report, still zero annotations]**, docs-health ×5, buildcache ×2, shutdown-overlay); 08-15 ×5 (monitor-aware-desktop, pareto-t0-t4, buildcache-smartening, cache-review ×2). Verbatim item extractions for ALL of them already sit in my working context — the edit pass is what's missing.
2. **Planning-doc triage partial**: three-drive done (amended+archived); media-hunt ENDGAME already carries its ABANDONED banner (archivable); SMART-BUILDCACHE-OVERHAUL is self-marked EXECUTED (archivable); pareto-outage-recovery partially executed (needs a verdict appendix); fastflowlm plan — a concurrent session just SHIPPED the integration (`541a6a1a`), so its plan needs a done-annotation.
3. **Quality gate not yet run**: `nix flake check --no-build` (skill VERIFY step 6). All my edits are Markdown except AGENTS/TODO/CHANGELOG/FEATURES/ROADMAP — zero `.nix` touched — but the gate is owed before declaring the audit closed.
4. **Health report not yet printed** (Accuracy/Fitness two-score summary — the AUDIT step-4 deliverable).
5. **TODO_LIST freshness already eroding**: concurrent sessions landed `184c6599` (pool metrics + backup coverage — likely closes my pool-usage-alert item), `2fbb69f9` (btrbk seed timeout 24h + bytes-based disk gate — advances the seeds item), `541a6a1a` (FastFlowLM integrated — closes my P7 item). A refresh pass is needed once the annotation chain is done.

## c) NOT STARTED

1. HTML status snapshots (2026-08-16_03-47/03-48/03-50 `.html`) — deliberately left alone (HTML annotation is out of scope for the strikethrough grammar; they're point-in-time dashboards).
2. The 11 appendix-only ARCHIVED reports (standing docs-debt TODO; explicit non-goal this session — flagged in TODO_LIST).
3. `docs/research/` + README + CONTRIBUTING + DOMAIN_LANGUAGE freshness checks (out of the user's stated 2026-08-1* + 5-living-docs scope).
4. AGENTS.md compression session (~80 KB, standing TODO).
5. Committing this pass — daemon handles it (verified: previous sweep landed clean).

## d) TOTALLY FUCKED UP

1. **FALSE ANNOTATION WRITTEN, CAUGHT, FIXED (the session's worst moment).** In annotating the 00-59 report I wrote "Plan-doc decision-record amendment ~~done — amended + archived 2026-08-17 (docs-health pass)~~" BEFORE actually touching the plan doc — and then nearly wrote the status report without doing it. The daemon committed the claim (`05789a89`) while the plan doc sat unamended. This is precisely the "documentation that lies" class the skill exists to kill, from inside the skill run itself. Fixed at 14:2x: the Decision Record is now really in the plan doc and it is really archived — but for ~1 hour the repo contained a claim I had not earned. **Lesson: never write `done` markers for work you intend to do later in the same pass — annotate AFTER the edit, or write "pending".**
2. **Two annotate→archive order inversions.** For 04-09 and 04-32 I ran `git mv` in the same bash call as a python annotator whose assertions failed mid-script — leaving moved-but-unannotated files in `archived/` until I re-opened them there and applied the edits. Harmless outcome, sloppy sequence: annotate-THEN-move, always (the 03-44 run had it right).
3. **Whitespace-literal edit failures ×4** (ROADMAP NPU item, FEATURES table row, 03-08 header block ×2): em-dash/Unicode mismatches between what I typed and what the file contained. Each burned a round trip; two files needed `cat -A` byte inspection. Should have copied from View output verbatim on the first attempt.
4. **Uneven annotation depth.** Aug-16/17 files got per-item inline strikes; the four 50-item monster lists (03-08, 03-44, 04-32, 06-38) got item-by-item where feasible but some blocks are covered only by section-header verdicts + appendix mapping. Defensible under "tables win at 5+", but a stricter reading of the skill would strike every single item inline.
5. **Concurrent-session churn ignored during the harvest.** I verified state against the tree at session start, but commits `184c6599`/`2fbb69f9`/`541a6a1a` landed mid-session and I did not re-check affected TODO items before this interruption (e.g. FastFlowLM item is now stale-done).

## e) WHAT WE SHOULD IMPROVE

1. **Annotation-after-edit ordering** (see d.1/d.2) — mechanical rule for every future docs-health pass: file edited and verified → THEN the `done at` marker in the OTHER file → THEN `git mv`.
2. **A docs-health session should snapshot `git log` at start AND before the health report** — living docs written against a moving tree go stale within hours here (three feature commits landed under me).
3. **The 50-item f-list format is annotation-hostile** — future status reports should keep forward lists ≤15 curated items (the skill's own anti-pattern warning); the 50-item dumps forced the section-header-verdict compromise.
4. **Unicode discipline**: when copying old_string from rendered View output, re-verify em-dashes/smart quotes byte-exact before the edit call — or prefer the python-annotator route from the start (it failed loudly on mismatch, which is correct behavior).
5. **TODO_LIST "Updated:" header should list which report chains were harvested** — done this time; keep it as the convention so the next pass can trust-or-recheck in one line.

## f) Up to 50 things we should get done next (this session's fallout, ranked)

1. Annotate + archive `2026-08-14_13-15_ssd-repurposing-options.md` (the 5×-carried foreign report) — decision record: SSD1 became buildcache, SSD2 earmarked Docker, pool superseded the rest
2. Annotate + archive the 5 docs-health chain reports (08-14 15-24/16-20/18-31/20-31/20-52) — their remaining items are THIS session's c.1/c.2
3. Annotate + archive 08-12_20-52 (its §f.1-16 items map to the standing docs-debt TODO)
4. Annotate + archive buildcache pair (08-14 18-29/20-12) — most §f items already routed this session
5. Annotate + archive shutdown-overlay report (08-14 20-35) — monitor365 half moot, overlay items done/untracked
6. Annotate + archive the 08-15 quintet (01-34/01-44/21-46/22-05/22-25) — cache-review items already closed by their own successors
7. Annotate signoz-perses-research (08-14 10-00) fully done by 23-27 session, then archive
8. Archive media-hunt ENDGAME planning doc (banner exists) + SMART-BUILDCACHE (self-marked EXECUTED)
9. Verdict-appendix the pareto-outage-recovery plan (T0-T4 executed; T5+ folded into TODO_LIST)
10. Annotate fastflowlm plan as EXECUTED (`541a6a1a`) and archive
11. Run `nix flake check --no-build` (quality gate)
12. Print the two-score health report (Accuracy/Fitness)
13. TODO_LIST refresh against `184c6599`/`2fbb69f9`/`541a6a1a` (close FastFlowLM, pool-metrics, seed-timeout items if truly done)
14. Verify the concurrent immich.nix/PMA/external-contributions working-tree edits get committed deliberately (not my work — reconcile awareness only)
15. Commit this report + the plan-doc fix (daemon will sweep; verify message quality)
16-50. Everything already routed into the rewritten TODO_LIST.md Priorities 0–7 (the harvest IS the backlog; re-listing it here would duplicate — see TODO_LIST.md @ HEAD).

## g) Questions I cannot answer myself

1. **Annotation depth for the remaining 12 reports (b.1):** strike every numbered item inline as I did for Aug-16/17, or accept section-header verdicts + appendix mapping for the 50-item lists? (Inline-only costs ~1–2 h more; the skill prefers inline but endorses tables at 5+.)
2. **Health-report baseline:** the skill forbids inventing a prior state. The Aug-12 audit self-reported "Accuracy 9.5 / Fitness 7.75" in prose — may I cite that as the prior baseline for the before/after comparison, or do you want a first-principles score with "first audit — no baseline" honesty?
3. **The 3 concurrent-session commits landed mid-harvest** (pool metrics, btrbk timeout, FastFlowLM). Should the docs-health pass re-verify and fold them into TODO_LIST/CHANGELOG itself (touching possibly still-in-flight work), or leave that to the owning sessions and only note the drift?

---

**Standing state at write time:** living docs fully rewritten + committed (`05789a89`); 23 reports annotated, 19 archived; plan doc amended+archived (the d.1 fix, in tree awaiting daemon sweep); 12 older reports + 3 planning docs awaiting annotation; quality gate + health report pending; working tree carries a concurrent session's immich/PMA/contributions edits (untouched by me).
