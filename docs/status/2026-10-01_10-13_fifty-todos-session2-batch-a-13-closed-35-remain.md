# Status: Fifty-Easiest-TODOs Execution, Session 2 — batch A landed (13 items closed), 35 remain

**Session window:** 2026-10-01 ~08:00 → 10:13 CEST (resumed from the session-1 handoff; paused per user's status-report request mid-batch-C).

**Scope:** Executing the ranked 50-item plan (canonical list preserved in `docs/status/2026-10-01_03-33_fifty-easiest-todos-execution-session1-three-edits-commit-race.md` §f) under the standing "GET SHIT DONE" directive. Session-1's three §g questions were never answered; I proceeded on the documented defaults (ranked order, batch-per-domain, pathspec commits with footers, edit-only for deploy-gated items).

---

## a) FULLY DONE

1. **Full re-verification pass over all 50 items against the live tree** (the session between the handoff and this one restructured AGENTS.md from ~605KB into a 150-line core + `docs/agents/*.md`, and parallel sessions landed heavily — every item needed a fresh landing-check before editing). Result: **13 of the 50 were ALREADY LANDED** (by the AGENTS.md restructure, other queue sessions, or my own session-1 content edits); editing them blind would have been duplicate work or drift.
2. **Batch A executed + committed: 13 items closed in one atomic pathspec commit `b260baed`** (my first footer-bearing commit this plan — session 1 lost three commit races; the same-call edit→commit discipline fixed it). The commit carries TODO_LIST.md (13 rows marked `[x]` + DONE notes) + 4 library rows (`docs/todo/stability.md` ×2, `docs/todo/services.md` ×1, `docs/todo/pipeline.md` ×1). Verified post-commit: `git show --stat` = exactly the 4 intended files, hook green, docs-only fast path.
3. **The 13 closed items and their landing evidence:**
   - **#1** jan.md GPU row — content landed session 1 (sweep commit `873ffb2e`), jan.md:13 verified intact.
   - **#2** heal-breadcrumb SUDO_USER capture — landed `873ffb2e`; `invoker="${SUDO_USER:-$(id -un)}"` live-tested session 1 (`user=lars uid=1000`).
   - **#3** CONTRIBUTING verify-gate heal wiring — landed `873ffb2e`; the heal line at docs/CONTRIBUTING.md:220 carries the breadcrumb call.
   - **#41** statix hot-user-caches — ALREADY LANDED by a parallel session in `f1e703c5` (`inherit (cfg) device;` verified at hot-user-caches.nix:127); audit-serviceconfig-merge.sh v2 selftest green.
   - **#6** spot-verify-at-queueing — ALREADY LANDED in the AGENTS.md TODO-system Rules (AGENTS.md:65, with the @home-hermes premise example).
   - **#13** dispatch contract → re-dispatch protocol — ALREADY LANDED (AGENTS.md:65 names CONTRIBUTING's protocol explicitly).
   - **#30** report-claim surface rule → Critical Rules — ALREADY LANDED ("A correction claim must NAME the corrected surface(s)", AGENTS.md:97).
   - **#34** producer-inventory doctrine — ALREADY LANDED (CONTRIBUTING.md:235 "Producer inventory before enforcement").
   - **#35** verification-verb doc — ALREADY LANDED (CONTRIBUTING.md:229 "Agent-safe verification verbs" carries all four probes).
   - **#12** fixture assertion-count command — ALREADY LANDED (12-54 report §e1 carries the 14:32 correction; TODO_LIST row 83 the anchored form; I re-ran both commands this session: anchored=22, naive=23).
   - **#50** flake.lock node-printer — ALREADY LANDED (`scripts/flake-lock-node.sh` exists, handles the string-root quirk).
   - **#40** commit-msg subject check to top — ALREADY LANDED (hook is 29 lines carrying ONLY the length contract).
   - **#44** rpi3 nix-settings verify — verify-only closure: rpi3/default.nix:25 imports `../../common/nix-settings.nix`; nix-settings.nix carries plain 7d, **no mkForce exists anywhere on nix.gc.options** (already dropped) — nothing to edit.
4. **Batch C research completed (not yet edited):** read all seven storage-batch targets — agents/storage.md /data-damage context, systemd.md boot-mirror section, storage.md f2-row + P0 row + lineage rows, hot-db.md wave procedure (6 steps), snapshots.nix (no 11d comment yet), and the 02-01 report §b5 (file has moved — archive glob failed, needs a re-find during execution).

## b) PARTIALLY DONE

1. **#42 (caddy.nix shallow-merge) bookkeeping** — the fix itself landed in `f1e703c5` with #41, but I could not find a dedicated TODO_LIST/library row for it (TODO_LIST carries only the harvest rows mentioning it). Untouched this session; needs a decision: backfill a row or close as covered-by-#41's DONE note.
2. **Two already-landed items lack library rows** (the #41 statix row, possibly #42): the queue DONE note names the gap, but the queue↔library no-drift rule is technically violated until a library row is backfilled or the absence is ratified.
3. **Batch C is researched, not executed** — all 7 items (#4, #7, #8, #9, #10, #11, #21) have located targets and known edit shapes; zero edits landed before the pause.

## c) NOT STARTED

**35 ranked items remain** in six batches: storage #4/#7–11/#21 (7); stability docs #14–16/#22–23 (5); services docs #17/#19–20 (3); CONTRIBUTING conventions #18/#24–29/#31–33/#36–38 (13); pipeline code #39/#43/#45–48 (6); AGENTS pointer sweep #49 (1). Plus the #5/#42 bookkeeping marks, the final verification pass (flake check --no-build + fmt --ci), and the closing report.

## d) TOTALLY FUCKED UP

1. **Nothing this session.** The session-1 failure mode (edit→daemon-sweep race) did not recur: batch A's 17 line-edits and the pathspec commit ran back-to-back, and the commit carries exactly my files under my own message. The discipline change held.
2. Minor: I burned one glob on the 02-01 report (`docs/status/archived/2026-09-23_02-01*.md` — not there; the report lives elsewhere or was pruned). Cost: one failed command, no damage; noted as the first step of batch C execution.

## e) WHAT WE SHOULD IMPROVE

1. **Verify-before-edit paid off at scale: 13/50 items were already landed.** The ranked plan was 3 days old against a tree with heavy parallel traffic — per-item landing checks before ANY edit is now table stakes, not paranoia.
2. **Line-number cites in the queue rot within days** (TODO_LIST grew 519→578 lines mid-session; row numbers cited in older items no longer match). Reinforces the landed #31 convention (cite row titles + Source anchors).
3. **The AGENTS.md restructure means several "AGENTS.md" queue rows now target `docs/agents/*.md`** — future harvests should name the post-restructure home, not the old path (rows #4/#10 needed target re-derivation).
4. **Parallel-session overlap risk on TODO_LIST.md is now three-way** (me + tq pool + the durability-plan session whose `53f34af0` landed 10 commits after mine). Next batch should re-verify my 13 marks survived before stacking new edits on the same rows.
5. **The library-row-absent drift class** (items landed, rows pruned, queue rows open) has at least 3 instances in my batch-A set — the pairing-check row (pipeline.md) covers queue→library drift; this is the inverse (closed-work → row pruned mid-flight).

## f) Up to 50 next things

Ranked, batch-grouped, targets verified this session:

**Batch C — storage (7 items, all targets located):**

1. #4 Cross-link the single-victim /data repair recipe (jan.md) from `docs/agents/storage.md`'s /data-damage context (the csum-discriminator paragraph, line 39)
2. #7 Fold `hot_db_entry_mounted{name="gatus"}` presence into hot-db.md wave-procedure step 6
3. #8 Reword the stale "deploy-pending, converged by the next run" clause in storage.md line 94 (per-row script: "guard live + `legal-cases` still gated on the rmdir heal")
4. #9 Reconcile the "~12 vs 11 enumerated" journal residual in storage.md's P0 row (data-damage-set.md:42 already carries the reconciliation; the P0 row needs the pointer/downgrade)
5. #10 Document where `nix run .#boot-mirror-activate` logs (docs/agents/systemd.md boot-mirror section; owner-shell vs journal answer needed from the app definition — `nix run` apps log to the invoking shell, not the journal)
6. #11 storage.md cache-sweep lineage annotations (re-find the 02-01 §b5 report first; rows have shifted)
7. #21 Add the "11d mid-week weeklies expected" comment block to btrfs-verify-snapshots in snapshots.nix

**Batch D — stability docs (5 items):**
8. #14 Annotate freeze-7 report with the corrected scrub-slice decomposition (4.18 TiB @mnt-pool COMPLETED clean + 549.8G @- + 656.3G @data; evidence in 00-31 report §a.5, journal-verified)
9. #15 Document the btrfs-scrub exit contract (0 clean / 1 aborted / 3 errors) in docs/agents/storage.md (no docs/services scrub runbook exists; the agents doc is the BTRFS home post-restructure)
10. #16 Codify cancel-during-storm + attribute the 02:27 manual cancel (pts/22+pts/20) in docs/services/memory-emergency-guard.md
11. #22 Annotate 2026-09-25_05-33 §e5 as answered (heal-breadcrumb convention)
12. #23 Annotate 2026-09-29_23-20 scrub-stop report with post-authoring landings (RE-FIRE-3 root cause, VM test green, `9d9c17ea` churn-metrics fix)

**Batch E — services docs (3 items):**
13. #17 CHANGELOG row + forgejo.md Themes/UI section for the cascade trap (trap currently only in the migrated Agent Notes, line 207)
14. #19 Add the mail-wiring PASS-since-2026-09-05 status to paperless.md's monitoring paragraph (line 267 area)
15. #20 dnsblockd: link the OIDC recovery runbook from the docs index (services.md row 61 pairs it with a healthcheck consideration — link-only per this item)

**Batch F — CONTRIBUTING conventions (13 items, one file, likely 2 commits):**
16. #18 DR-runbook provenance checklist line
17. #24 §f self-audit step in the status-report protocol
18. #25 extendModules/mkOverride-50 recipe in the Eval-Time Guards section
19. #26 deepSeq-inline vs shared-lib probe-pattern note
20. #27 fleet-incident rule (gate failing for ALL agents = environment incident)
21. #28 60-second same-class sibling sweep habit
22. #29 report self-consistency gate (§f vs §a cross-check)
23. #31 Ban bare `TODO_LIST:<line>` cites
24. #32 Name the post-amend lint-heal commands in the daemon-race policy (fmt-cached.sh; flake check on .nix; gitleaks-over-amended-HEAD)
25. #33 Document the soft-reset split as the exclusivity-FAIL repair
26. #36 Convention: DONE-stamped items carry Task-Queue-ID
27. #37 Verify footer commit landed before emitting TQ_RESULT
28. #38 Queue-footer discipline (first commit carries footer)

**Batch G — pipeline code (6 items):**
29. #39 Add the 3 fastflowlm-203 gotchas to docs/gotchas-archive.md (deploy.sh from restricted-PATH shells; flat package layouts vs lib.getExe; phantom-metric same-changeset rule — source 08-17_22-55 §f.10)
30. #43 Restore the ~19 pipeline.md backlog rows deleted by daemon commit `d22ccd48` (from `git show d22ccd48^:docs/todo/pipeline.md`, skip rows later passes closed)
31. #45 golines → base.nix (check nixpkgs attr name first)
32. #46 Create docs/security/rotations.md ledger
33. #47 Set `boot.binfmt.preferStaticEmulators = true` in boot.nix (edit-only; deploy owner-gated)
34. #48 mktemp(+trap rm) the pre-commit per-leg logs (/tmp/shellcheck.log, /tmp/ruff.log at .githooks/pre-commit:372/387)

**Sweep + close (remaining):**
35. #49 AGENTS→runbooks snapshot-pinning pointer sweep (in-place-delete bullets across docs/services/*.md + docs/agents/storage.md)
36. #5 Mark STORAGE-OPTIMIZATION-PLAN annotation landed (content verified at line 86)
37. #42 Decide + record caddy shallow-merge closure surface
38. Batch-mark all edited items `[x]` in TODO_LIST + libraries (same-commit-per-batch)
39. Final verify: `nix flake check --no-build` + `nix fmt --no-update-lock-file -- --ci` on touched .nix
40. Re-verify batch-A's 13 marks survived parallel sessions before stacking batch C
41. Closing status report with measured date

42–50. Buffer: the seven already-landed-not-marked stragglers if more surface during execution; CHANGELOG prune pass for the batch marks if the daemon doesn't sweep first.

## g) Questions

1. **Session-1's three questions remain unanswered and I've been running on defaults** (resume in ranked order; non-queue sessions use footer-bearing pathspec commits; deploy-gated items #45/#47 land edit-only with deploys queued owner-side). Confirm these or correct before batch F/G.
2. **Library-row backfill policy for already-landed items whose library rows were pruned mid-flight** (#41 statix, likely #42): backfill a closed row in the library (restores the no-drift pairing), or is the queue-row DONE note an accepted closure when the library row is simply gone?
3. **Batch F adds ~10 convention paragraphs to CONTRIBUTING.md's Verification section** (already the file's densest area, lines 187–236). Keep the house style (one dated bold-lead paragraph per convention, chronological) or consolidate the new ones into a single "Task-queue & report conventions" subsection to cap section growth?
