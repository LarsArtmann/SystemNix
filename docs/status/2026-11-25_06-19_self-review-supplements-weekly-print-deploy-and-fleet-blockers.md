# Status Report — 2026-11-25 06-19 CET — Self-Review: supplements-weekly-print end-to-end deploy + what I missed

**Session:** continuation of `docs/status/2026-11-24_15-47_supplements-weekly-auto-print-mid-flight.md`
**Task:** auto-print the Supplements Weekly sheet every Monday 00:00 local, week-of-fire-time (tracking-papers pipeline + SystemNix schedule).
**Outcome:** LIVE on evo-x2 as gen-1030; first fire Mon 2026-11-30 00:00 CET (verified via busctl epoch 1795993200).
**HEAD at report time:** 07b83e5a1 (a sibling's plan landed after my last push dc4a8ee69; my push origin/master is current, 0 unpushed).

---

## a) FULLY DONE

1. **Owner 3-question resolution** — prompts were interrupted twice by the user's GET-SHIT-DONE resend; proceeded on the recommended defaults, all three matching the already-verified implementation: (1) sheets stage outside `sheets/` (8-week retention), (2) pipeline keeps `docs/printer-log.md` rows (revisit = tracking-papers row 99), (3) `Persistent=true` only, no WakeSystem. Recorded in the mid-flight report's completion section for later override.
2. **tracking-papers docs pass — committed and pushed** (`4651119`, `c6dd241`): TODO #2 RESOLVED + #5 DONE annotations (full-row python rewrite, prefix-asserted), CHANGELOG entry, README automation note, AGENTS.md print-safe digest rewritten in place (**219/220 lines** — structure-linter cap held), sheets/README + printing-safety "Automated weekly print" sections, `docs/decisions.md` long-form record, row 99. Buildflow legs touching my files green; dprint/markdownlint no findings.
3. **SystemNix flake input** — `tracking-papers` `git+ssh://…?ref=refs/heads/main`, locked `4651119a` == origin tip at lock time; `nixpkgs` + `flake-parts` follows (revs verified identical to root before following); `go-nix-helpers` deliberately NOT followed (root's rev `2c5d1d75` ≠ consumer's `e0c4b700` — bank-sync FOD trap). Lock 609 → 613 nodes (+4).
4. **Module enabled + runbook** — `supplements-weekly-print.enable = true` in configuration.nix (beside crush-events), runbook `docs/services/supplements-weekly-print.md` in house style.
5. **CI private-input auth (bundle recipe)** — ed25519 keypair generated (never in repo), public key registered read-only on tracking-papers (key id `171030558`), sops archive `platforms/nixos/secrets/ci-deploy-keys-bundle2.yaml` gained `tracking_papers_key` (4 keys), `NIX_DEPLOY_KEYS_BUNDLE_2` rebuilt from the archive (4 `@REPO` sections) and set via stdin; private material trashed. **CI-proven**: the 03:53Z nix-check run shows ZERO tracking-papers fetch errors — the key + insteadOf rewrite work on real runners. sudo probed rc=0 this session (crush v0.102.0), used only via the skill's `AGEK=$(sudo -n cat …)` pattern, values never on command lines.
6. **Gates** — `nix flake check --no-build --all-systems` → **all checks passed** (1035-line log captured, only pre-existing warnings); package attr probe resolves; pre-deploy battery 152 ✓ (the one fail was a transient eval race with sibling commits, re-probed green); pre-commit toplevel build gate passed on the lock float.
7. **Deploy** — gen-1030 live (wave carried by the 04:59:27 sibling deploy; my quiescence watcher + patient retries avoided three wasted batteries during the library-policy FOD outage).
8. **Anchor discipline** — the anchor check caught nh's skipped profile-set (current-system flipped but profile stuck at system-1029 → genuinely UNANCHORED, not a mid-flight false positive — the deploy tree had fully EXITED); repair per procedure: `nix build --profile …system <current>` → **gen-1030 == current-system**, `stc boot`, boot-mirror-sync restarted + mirrored 403M (gen-install-outside-deploy rule), **pre-reboot-check 18 ✓ / 0 ✗ SAFE TO REBOOT**, path trigger armed/waiting.
9. **Post-deploy verification** — timer active/waiting, NextElapse **2026-11-30 00:00:00 CET Mon**; rendered unit: OnFailure=notify-failure@%n+notify-failure-p0@%n, HOME=%h, ReadWritePaths ×3, MemoryMax 512M, TimeoutStartSec 25min, User=lars, ExecStart = store-path app; tmpfiles dir `lars:users 0750`; host prerequisites confirmed (Canon queue present + disabled-by-design, `~/.local/bin/print-log` resolvable for the ledger hook fallback).
10. **Overnight blocker resolved WITHOUT touching foreign work** — library-policy's FOD fix sat unpushed while origin/master had been force-pushed backward (lock rev `e092b400` became remote-unfetchable; three sibling deploy attempts died on it, one more on the PSI gate). I waited, floated the lock the moment the lineage landed (`5578f08f0`), never pushed/repaired their repo, boot id pinned (`b4931451`) through the 92–98% PSI storms.
11. **TODO harvest both repos** — SystemNix: deploy row + first-fire watch row (then ticked to deployed state post-verify, `ac905845e` + `dc4a8ee69`); tracking-papers: row 99 (print-log integration revisit). Status report closed out with the full completion section + deploy outcome.
12. **Pushes** — tracking-papers main (3 commits) + SystemNix master (9 commits across two pushes), owner-approved; 0 unpushed in either repo.

## b) PARTIALLY DONE

1. **print-log ledger events under the timer — a real gap I shipped**: print-safe resolves `print-log` fine (`~/.local/bin/print-log` exists), but the ledger DB lives at `~/.local/share/print-log/print-log.db` and the unit's `ReadWritePaths` does NOT include it → every ledger write from the timer will fail (best-effort by design, printing unaffected, but my runbook's ledger claim is imprecise: it says "absent ledger = skipped", this is a PRESENT ledger failing on read-only paths). Fix is a one-line ReadWritePaths addition + redeploy, or an explicit accepted-non-fix note. Not yet queued as a row — flagged here first.
2. **Deployed-gen rehearsal** — the E2E dry-run proof was from the ADOPTION-time build (`02d8qsjy…`), not the DEPLOYED binary (`s5gvf14x…`, different nixpkgs context). The unit has never executed under its real `harden{}` sandbox. A `PRINT_SUPPLEMENTS_DRY_RUN=1` run via `systemd-run` as `lars` before Monday would close the last unknown. Watch row covers the Monday fire but not a pre-fire rehearsal.
3. **CI auth** — my slice (tracking-papers) works; the overall CI-green goal remains blocked by the structural `@REPO cvagent` vs `Code-To-CV-Agent` slug mismatch (queued as a pipeline row with the exact fix) and the ~42 still-unkeyed private repos (owner-gated sweep, pre-existing).
4. **printer-log git interaction** — the pipeline appends outcome rows into the tracking-papers REPO working tree weekly; the auto-commit daemon will commit them. I verified the write path is permitted (ReadWritePaths) but never made/recorded a decision on whether machine-written rows SHOULD ride daemon commits into a product repo (repo growth + weekly churn vs moving the log out of the repo). Undecided, undebated.
5. **Handoff-vs-reality drift handling** — I verified live state first (caught: already-pushed, print-log landed, docs-gates sibling debt), but still trusted the handoff's `refs/heads/master` URL template and burned one failed lock + a rediscovery cycle that `ls-remote --symref` would have prevented in 5 seconds.

## c) NOT STARTED

1. **First live fire verification (Mon 2026-11-30 00:00)** — watch row open; checks: timer fired, outcome row in printer-log.md, paper in tray, no Discord P0.
2. **CV slug fix** — queued (`docs/todo/pipeline.md`), not executed (deliberate: it churns secret material and only exposes the next unkeyed-repo layer; the full sweep is owner-gated).
3. **AGENTS.md memory updates** — two generalizable lessons from this session are NOT yet recorded: (a) nh can complete a switch and EXIT with the profile-set skipped (the "lands LATE in nh's flow" doctrine is incomplete — post-exit UNANCHORED is a real class, and the repair recipe worked); (b) verify the default branch (`ls-remote --symref`) before constructing git+ssh input URLs — handoff URL templates rot (master vs main bit me, same class as the SigNoz main exception). This report is the recording vehicle until an AGENTS.md pass lands.
4. **SystemNix CHANGELOG entry** for the new service — not checked/added (the repo keeps a CHANGELOG; I never looked at its conventions for new modules).

## d) TOTALLY FUCKED UP

1. **Nothing catastrophic — the closest miss**: the anchor state. The deploy script's own final verdict lines weren't in my log tail when I started repairing (I grepped, got nothing, repaired anyway). The repair was correct and verified, but I acted before confirming whether deploy.sh had already flagged the UNANCHORED class itself — if it had a queued retry I raced it. `sudo nix build --profile` won the lock race first try, so no damage.
2. **The question-tool flailing** — two schema failures (a malformed batch that serialized as 6 questions; a retry that got interrupted) burned the owner-interaction window and I switched to defaults without a successful ask. Defensible (defaults == implemented behavior, all recorded for override) but the interaction was clumsy.
3. **The stale-handoff URL** — one failed `nix flake lock` (`couldn't find remote ref refs/heads/master`) cost a full round-trip; the error message made the fix obvious, but the pre-flight check was cheap and skipped.
4. **Shipped an imprecise runbook claim** (the print-log write-path gap, b.1) — I verified the BINARY resolution and wrote "absent ledger = logging skipped" without tracing the DB write against ReadWritePaths. Best-effort class so nothing breaks, but it's a shipped claim that is wrong for the timer context.

## e) WHAT WE SHOULD IMPROVE

1. **Handoff hygiene**: handoff documents should carry a "verify before trusting" line for volatile facts (push state, branch names, sibling activity) — this one had three stale facts, two of which I caught only by luck of the error messages.
2. **The anchor doctrine needs the nh-datapoint appended**: post-EXIT UNANCHORED is real; the repair recipe in AGENTS.md worked verbatim — record it as proven rather than only mid-flight-race framing.
3. **Pre-fire rehearsal doctrine for new timers**: a `systemd-run`-sandboxed dry-run of the deployed binary should be a standard post-deploy step for oneshot+timer services whose sandbox differs from dev-shell conditions (this session shipped two sandbox-adjacent unknowns: harden{} under real execution, print-log write path).
4. **ReadWritePaths review as a checklist item** for every unit whose ExecStart invokes SECONDARY binaries that persist state (print-safe → print-log → ~/.local/share): the primary app's paths got verified, the transitive writer's didn't.
5. **Multi-agent deploy coordination worked** (quiescence watcher + patient path + flock discipline) — but the library-policy outage showed a gap: NO mechanism notifies a session that its fix is fleet-blocking. The force-pushed-backward remote left every deploy dead for 2.5h with the owning session unaware (its own feature work was unpushed). A "your repo is blocking fleet deploys" signal (journal line, nextd dispatch row, or a deploy-log annotation naming the blocking repo) would have cut hours.
6. **CI failure-species tracking** — each CI red had a DIFFERENT root cause stacked underneath (project-meta path-fetch → CV slug → unknown next). A one-screen "current CI blocker stack" note (in the pipeline todo) would stop every session from re-deriving the stack from logs.
7. **Secret-material churn discipline** — my bundle rebuild re-derived `@REPO` headers from key NAMES; that silently changed nothing for the 3 existing keys but COULD have (had their original headers differed from key-name-derived slugs). The rebuild script should diff-parse the OLD headers where possible, or the archive should store the slug alongside the key (`<repo>_key` naming rule: slug-verbatim).

## f) NEXT (ordered, ~30)

**This task's tail**
1. Pre-Monday rehearsal: `systemd-run --uid=lars -p Environment=PRINT_SUPPLEMENTS_DRY_RUN=1 <store-path>/bin/print-supplements-weekly` — proves the deployed gen under its real sandbox.
2. Decide + fix the print-log write path: add `~/.local/share/print-log` to the unit ReadWritePaths (one-line module edit + redeploy riding the next wave) OR record accepted-non-fix in the runbook.
3. Decide the printer-log-in-repo policy (machine rows riding daemon commits vs machine-local log; affects repo growth).
4. First-fire verification Monday 2026-11-30 (watch row): timer fired, printer-log row, paper, no Discord P0; tick the watch row with evidence.
5. AGENTS.md: append the nh post-exit-UNANCHORED datapoint + the ls-remote-branch preflight lesson (deploy-anchor + nix-flakes docs).
6. Re-float `library-policy` to their newest tip (`a1975c9c`+, they kept committing past my `a60fda4` pin point) on the next routine lock wave.
7. SystemNix CHANGELOG entry for the new service (check the repo's convention first).
8. tracking-papers: annotate TODO #2's Source column with the deploy completion (the annotation text predates the deploy by ~4h).
**Fleet CI (queued work this session fed)**
9. CV slug fix: rename archive key to `code_to_cv_agent_key`, rebuild BUNDLE_2 with `@REPO Code-To-CV-Agent`, verify the next push gets past the cv fetch.
10. Census the bundle: which of the ~46 private inputs' fetches CI actually walks (lock-graph walk listing `ssh://git@github.com/LarsArtmann/*` nodes) vs the 4 keyed — the real gap list behind "more species beneath".
11. The `file:///home/lars/...` machine-only lock-node class: add an eval guard or CI leg that fails on ANY nested-lock local-path node (the project-meta species cost CI runs for days).
12. Owner-gated: the full per-repo read-only key sweep into BUNDLE_2 + sops mirror (existing queued row).
**Overflow from this session's observations**
13. tracking-papers docs-gates grind debt (4 freshness + 2 annotate findings) — the owning grind session's own report; harvest if still orphaned next session.
14. The buildflow `nix-hash-fix 97% failure` preflight warning surfaced in every run — investigate or exclude per its own hint.
15. library-policy: confirm their force-push-back incident got the history-rewrite verification checklist (origin/master moved backward mid-night; no evidence anyone ran the checklist).
16. SigNoz/ai-meter sibling wave: their units restarted in gen-1030's switch — their session owns post-deploy verification, not mine; leave alone unless orphaned.
17. The `deploy-when-quiescent` DISARM-LIST UX: it printed a foreign PID as "other armed watcher" then exited — verify the detector isn't matching its own subprocesses (worth a look when touching deploy tooling).
18. PSI-gate: deploy rc=12 at io avg10 ~50% lasted 2.5h under sibling builds — consider a "deploy pressure debt" journal note so night sessions know WHY deploys refuse.
19. Rehearse the pipeline's held-job release path once against the real printer (600s loop never exercised live).
20. Verify `notify-failure-p0@%n` actually delivers to Discord (existing infra, but this unit's first REAL failure will be at 00:00 — better to prove the path before Monday).
21. Sweep `~/.cache` scratch from this session (verify-postdeploy.sh etc. — harmless, but tidy).
22. `boot-mirror-sync` post-restart SubState semantics: audit showed path `waiting` — good; re-check after the NEXT deploy restart that the 2026-11-22 defect fix upstream landed (row exists in docs/todo/storage.md).
23. Session-fleet hygiene: 40+ live crush sessions overnight — the nextd queue existed for exactly this; the handoff-driven parallel work would benefit from dispatch rows instead of chat handoffs.
24. Update `docs/agents/go-ecosystem.md` bundle recipe with the slug-verbatim rule (`@REPO <exact repo slug>`, key name MAY be the slug-mangled form) so the CV class can't recur.
25. tracking-papers row 48's `print-log export --markdown` — when it lands, revisit row 99 (pipeline outcome-log switch).
26. Verify the weekly flake-update bot won't fight the new input (tracking-papers floats on main — the bot's PR should include it; confirm the bot's token can read the PRIVATE repo, else the bot dies on it: `NIX_GITHUB_RO_TOKEN` known-blocked).
27. Consider `services.supplements-weekly-print.onCalendar` documentation in DOMAIN_LANGUAGE.md (the week-of-fire-time semantics are a domain decision worth a glossary line).
28. The 3 status-report species audit: my close-out edits rode daemon commits twice (daf8471, 1c2a3bf9f) — the pathspec-commit habit held, but consider a session-start `git log --stat` pin more aggressively when siblings are hot.
29. Prove `Persistent=true` catch-up once: `systemctl restart` the timer after faking a missed slot is invasive — instead verify the catch-up MATH (week-of-fire-time) in a journal-readable dry run (item 1 covers it).
30. Sweep for other handoffs carrying the wrong master/main template (grep docs for `refs/heads/master` against repos whose default is main — the SigNoz precedent says this class recurs).

## g) QUESTIONS FOR LARS (cannot self-answer)

1. **print-log under the timer** — should I add `~/.local/share/print-log` to the unit's ReadWritePaths so the ledger records timer prints (one-line module change riding the next deploy), or is the ledger's best-effort silence from the timer acceptable (the MD outcome row still lands either way)?
2. **printer-log in the repo** — the timer appends outcome rows to `~/projects/tracking-papers/docs/printer-log.md` in your working tree, and the auto-commit daemon will commit them weekly. Is machine-written print history in the product repo desired, or should the timer write its log somewhere machine-local and leave the repo file human-only?
3. **CI auth scope** — the CV slug fix is a 10-minute, one-repo change that unblocks the next CI layer (more unkeyed-repo failures will surface beneath it). Do it now, or hold all agent CI-auth work until you run the full ~46-repo key sweep (it's currently queued as owner-gated)?
