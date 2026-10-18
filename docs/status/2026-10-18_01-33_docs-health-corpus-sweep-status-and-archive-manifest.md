# Docs-Health 2026-0* Corpus Sweep — Status & Archive Manifest

**Date:** 2026-10-17/18 · **Task:** "View ALL `**/2026-0*` files! Execute the docs-health SKILL!" (the 2026-09-06 sweep's tracked continuation)
**Mode:** full AUDIT (ANNOTATE + ARCHIVE + HARVEST + VERIFY) · **Toolchain:** skills/docs-health `annotate.go` (repair / repair-partial / check-rows) + mechanical spec verify/recover

## a) FULLY DONE

1. **116 status reports annotated** (2026-08-17 → 2026-09-17, batches 0-5 of 21): ~4,000 per-item verdicts (`done at`/verified/routed/won't/NOT-DO); every spec line machine-verified (target line exists, unstruck, item-shaped) with keyword recovery for drifted line numbers before any apply.
2. **61 fully-resolved reports archived** to `docs/status/archived/` (git mv, renames preserved); dangling references fixed in CHANGELOG.md + docs/todo/services.md; `check-doc-links.sh` green.
3. **check-rows COMPLETE on all 93 item-bearing touched files** — zero PARTIAL/UNTOUCHED tables; ledger exemptions only where routed-pointer mirrors are the content (5 tables).
4. **8 open items harvested** into docs/todo libraries (storage ×2, security ×2, monitoring ×2, desktop ×1, pipeline ×1), each with `**Source:**` provenance.
5. **Living docs verified/updated:** CHANGELOG sweep entry (count-before-claim), TODO_LIST pipeline continuation row + pipeline.md library entry, AGENTS.md /tmp-volatility lesson, ROADMAP stamp. FEATURES + README verified current (no drift found; FEATURES stamp 2026-10-17 00:40 same-day).
6. **Quality gates:** check-todo-system OK (structure clean), check-doc-links OK, check-rows 93/93 COMPLETE.

## b) PARTIALLY DONE

1. **Corpus coverage: 116 of ~420 2026-0* status reports** — batches 6-20 (2026-09-17_00-25 → 2026-09-30, ~300 reports) remain; tracked as a [ready] row in TODO_LIST → docs/todo/pipeline.md. The 2026-10 tasks/ wave is outside the `2026-0*` glob and next in line.
2. **Commit-hash evidence**: agent toolsets had no git executor this session — verdicts cite landed config (`path:line`) and living docs instead; ~40 weak-evidence `dup` rows were dropped (left bare = open signal) rather than struck unverifiable.
3. Twin-file disambiguation (02-21/03-09 pair) was keyword-scored, not author-confirmed — 7 rows reassigned on best token match.

## c) NOT STARTED

1. Batches 6-20 annotate+archive (the tracked row owns it).
2. The 11 appendix-only archived 08-1x reports + 52 appendix-only archived September files (pre-existing rows).

## d) HONEST LEDGER

1. Two annotation misfires into a FULLY-DONE metadata table (03-39) — caught by check-rows, reverted by markup-strip (the daemon had already committed HEAD, so git-restore was useless; the strip is the recovery tool for that class).
2. Agent rate limits forced one-at-a-time retries; /tmp wipe lost the first workspaces mid-pass (lesson now in AGENTS.md).
3. Verdict depth is best-effort grep/read evidence, not re-execution of each claim — the `h` bar (wrong-done is worst) pushed ambiguity to `r`/`v` deliberately.

## e) ARCHIVE MANIFEST (61 files → docs/status/archived/, all classified ARCHIVE: every numbered item resolved inline; opens routed)

2026-08-17_21-05 stayed (1 open) — archived set:
- **Execution-complete incident/recovery reports** (work landed, verdicts cite config/runbooks): 08-18_13-22 fastflowlm-socat, 08-19_05-10 wise-sca, 08-22_01-46 das-usb, 08-22_03-58 gatus-anchored, 08-30_11-15 deploy-unblocked-narhash, 08-31_15-11 niri-storm, 08-31_18-44 startup-error, 08-31_20-46 docker-prune (superseded: Docker removed), 08-31_21-35 forgejo-tmp, 08-31_22-57 august docs-sweep, 09-06_15-31 deploy-smoke, 09-06_19-20 jan, 09-07_16-26 samsung-stuckboot, 09-07_18-30 pre-reboot-script, 09-07_20-36 daemon-flip, 09-08_04-33 jj, 09-08_23-48 tq-pool, 09-09_01-53 tq-polish, 09-09_04-28 rollback-ladder, 09-09_05-30 exit4, 09-09_06-02 deploy-anchor, 09-09_17-45 flm-corpse, 09-11_04-49 scrub task, 09-11_08-02 task (no open items), 09-11_15-09 miniflux-collision, 09-12_03-30 qlc-enospc, 09-12_04-31 sso task, 09-12_06-15 paperless task, 09-12_08-28 pool-smart, 09-13_02-52 signoz-coverage task, 09-13_03-37 website task, 09-13_04-22 push-protection task, 09-13_17-26 interim-pins, 09-13_17-28 mrsync (2 opens→harvested), 09-14_00-45 git-identity, 09-14_01-13 gitleaks-window, 09-14_20-00 wise-sca-gcloud, 09-14_20-02 helium, 09-15_05-46 pixel6, 09-15_06-10 psi-sweep, 09-15_07-32 gitleaks-rerun, 09-15_08-50 window-exec, 09-15_09-05 gh013, 09-15_10-45 freeze-5, 09-15_10-45 fourth-run, 09-15_11-42 git-corruption, 09-15_17-31 geometrikks (GO landed), 09-15_17-40 buildflow, 09-15_17-57 mkif memo (no items), 09-15_18-14 sixth-run, 09-15_19-15 paperless-dash, 09-15_19-27 todo-harvest, 09-16_02-11 hermes (2 opens→harvested), 09-16_02-11 quick-wins (1 open→harvested), 09-16_02-13 deploy-unblock, 09-16_02-34 crush task, 09-16_02-56 niri task, 09-16_03-50 crush task2, 09-16_05-44 crush task3, 09-16_08-27 vendorhash, 09-16_13-06 pin-audit, 09-16_13-07 storm-standoff, 09-16_13-08 imapclient (all-external), 09-16_17-55 hermes-day, 09-16_18-44 browser-history, 09-16_20-42 zero-agent.
- **SKIPPED (stayed in docs/status/, not archivable — bare open rows are the live signal):** every report with ≥1 unresolved item (e.g. 08-17_21-05, 08-18_17-42, 09-09_20-20, 09-10_23-49, 09-15_04-50, 09-16_03-17, 09-17_00-08).

_Waiting for instructions. Continuation row: TODO_LIST → docs/todo/pipeline.md (batches 6-20)._
