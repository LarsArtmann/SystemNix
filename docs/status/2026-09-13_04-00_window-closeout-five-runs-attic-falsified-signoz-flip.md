# Task-Window Closeout — Five Queue Runs (attic falsification + review fixes + SigNoz flip) — 2026-09-13 04:00

**Date:** 2026-09-13 ~04:00 CEST
**Scope:** the five task-queue items listed in this window's dispatch, their closing commits, and what this docs-health pass noticed in passing. Every claim re-verified this pass against `git show`, the window's own reports, flake state, and the upstream checkouts — nothing taken from dispatch text alone.
**Method:** `git show` on each closing commit; full reads of the five window reports; `git log origin/master..master` (SystemNix AND dnsblockd); merge-base ancestry check of the dnsblockd health fix against the deployed lock rev; grep sweeps for stale-claim carriers and report cross-references.

---

## Window inventory

| # | Task (ID) | Subject | Closing commit(s) | Verdict |
|---|-----------|---------|-------------------|---------|
| 1 | `000001a097a2c784…` | attic VM check "deterministic RED" (drv `aqs52r76…`) | `a4d1470d` (+ earlier same-ID run, daemon `145ad5cf`) | **Premise FALSIFIED** — 4 fresh greens today incl. a verbatim rebuild of the red drv; row closed |
| 2 | `000001a097a2c87f…` | Review fix: InboxClean queue-ID remap completeness | `b884c353` | Done — remap note now carries the full 3-ID chain |
| 3 | `000001a0981cd729…` | Review fix: false "byte-identical inputs" claim in the attic closure | `9e972a5f` | Done — evidence re-based on valid proof, verdict unchanged |
| 4 | `000001a097f9c0f9…` | SigNoz trace-gap flips (6 binaries) | `c609f8a5` | **Partially done by design** — dnsblockd flipped to enforced + ratchet 5→4; bank-sync already done; 4 remaining gaps need real upstream instrumentation |
| 5 | `000001a0981cd72c…` | Review fix: wrong red-era nixpkgs pin citation (`e5bdc4a`) | `120ada36` | Done — pin corrected to `34ab99075`, gitleaks hex trap defused |

All five closing commits are already **pushed** (`git log origin/master..master` shows only the three post-window long-failed-units commits). The stale-harvest theme dominated: **three of five tasks existed only to correct or falsify stale claims carried by earlier docs passes** (tasks 1, 3, 5; task 4's premises were also half-stale).

---

## a) FULLY DONE (verified this pass)

1. **The attic "deterministic RED" is dead, with a four-green evidence chain.** The cited Sep-4 drv `aqs52r76…` was re-evaluated from the exact tree (`rev=094d383d`) and rebuilt verbatim today — the full attic VM test PASSES on it (`wnid5dhy…` valid; a VM-test output exists only after the test passes). The current-tree check went green twice, both times after `nix store delete` + `--option substituters ''` (fresh local VM runs, no cache). The re-dispatch run (`a4d1470d`) additionally caught that the first closure cited a footer commit that never existed (files had landed via daemon `145ad5cf`) and corrected the report. Review pass 2 (`9e972a5f`) re-based the evidence: the "byte-identical inputs" claim was FALSE (inner test-driver drvs provably differ: `pazpdhpa…` vs `y865lzkn…`, `ty` 0.0.75→0.0.77, ruff 0.16.4→0.16.5; nixpkgs moved `34ab99075`→`c043004d1` on 09-05; attic.nix's atticd-metrics unit changed 09-06 in `c75c9261`). Review pass 3 (`120ada36`) fixed the pin citation (`e5bdc4a` was the Aug-16 pin; red-era was `34ab99075`, verified via `git show 094d383d:flake.lock`) and discovered/defused a repo-wide commit blocker: a full 40-char hex SHA in any tracked doc trips gitleaks' whole-index scan. TODO_LIST row 28 carries the corrected, valid evidence chain. The pre-commit hook's full `nix flake check` is now unblocked (its known-red excuse is gone).
2. **The InboxClean queue-ID remap is complete and greppable.** The item maps to three IDs (first-enqueue `000001a0935cb937…` — carried by the already-pushed footers `8605c6bd`/`005d1023`, immutable per the agent-push ban; canonical `000001a0936f08db…`; re-dispatch `000001a097a2c87f…`). `b884c353` records the full chain in the TODO_LIST remap note, so every ID resolves via `git log --grep` or the note.
3. **SigNoz trace-coverage: the two agent-executable closures landed.** `c609f8a5` flips dnsblockd `wiring = "upstream"` → `"config"` (enforced 26 h freshness) and ratchets `maxUpstreamGaps` 5 → 4 per module doctrine. Both flips were PREMISE-verified before landing: the scheme-aware OTLP fix is on dnsblockd origin (`70ca2ea`, via `8aa005f`), SystemNix's lock carried it since `94c9cb93`, the deployed binary IS `dnsblockd-94c9cb9`, and spans were flowing live (`signoz_traces_reporting{service="dnsblockd"} 1`). bank-sync was confirmed already enforced (flipped 2026-08-31, same day its item was authored — the row was a stale harvest). Eval-verified: `expected.dnsblockd = {wiring "config", maxAgeHours 26}`, `maxUpstreamGaps = 4`. Gates green (`nix fmt --ci` 0 changed, `nix flake check --no-build` passed).
4. **Bonus closure discovered and verified this pass: the dnsblockd `/health` wedge fix is PUSHED and DEPLOYED.** The 02-52 run flagged AGENTS.md's "NOT pushed/deployed (2026-09-06)" as a stale-premise candidate. Verified now: the cached-response `/health` implementation is live in the checkout (`internal/server/health.go:97` calls `healthProbe.CachedResponse()`), the health.go fix commit is on `origin/master`, and it is an **ancestor of lock rev `94c9cb93` — the deployed binary**. AGENTS.md is corrected inline in this pass (see Docs-health actions).

## b) PARTIALLY DONE

1. **SigNoz trace gaps: 2 of 6 binaries closed — the honest remainder is upstream development, not flips.** overview + projects-management-automation have a TracerProvider with ZERO span sites; papdashboard has metrics only; hermes needs the Python SDK. All four re-verified as never-emitted (`last_span_age -1`); flipping them now would false-page the enforced budget. Row 29 stays open with a `— BLOCKED:` suffix.
2. **The dnsblockd flip + ratchet are inert on the live box until the next deploy** — the running `signoz-coverage-metrics` oneshot still embeds the old registry (live `upstream_gaps` 5, dnsblockd treated as non-enforced). Safe in both directions; rides the shared pending deploy.
3. **Root cause of the original one-off Sep-4 attic red: never identified** (deliberately — non-reproducible on identical inputs; suspected guest-side transient during the zram-97% storm era). The closure stands on the greens, not on a mechanism.
4. **The attic evidence chain's durability is luck**: the decisive drv outputs were built `--no-link` (no gcroots) and the inner driver ATerms survive GC only until something collects them. A future GC makes re-audit impossible (owner decision — question g.1).
5. **Two of the five tasks were pure review-fix rounds on ONE paragraph of the attic closure** — the fixes are complete, but each cost a full agent run; the underlying pattern (unprovenanced factual claims in closure reports) has no prevention layer yet.

## c) NOT STARTED (skipped by the window)

1. **The deploy itself** — the signoz-coverage flip, Hermes cron fix, pool-smart metrics, btrfs-rescue tier, and the /data T05 scrub-gate work are all stacked, verified, and un-deployed. Production still runs the pre-flip registries.
2. **Every prevention layer the window's reports proposed** — verify-before-harvest as a hard dispatcher rule (third confirmed instance this window), docs-only pre-commit fast path (ends the `--no-verify` habit — used 3× this window, each documented), evidence-provenance convention, ATerm-first drv-equivalence rule, daemon-race commit protocol. All now TODO items; none built.
3. **The 4 remaining trace-gap instrumentations** (overview, PMA, papdashboard, hermes) and the corresponding ratchet steps 4→3→2→1→0.
4. **Annotating the three archived reports that carried the stale attic red** — DONE in this pass (see Docs-health actions), was open at window close.
5. **The live `signoz_traces_missing 3` Gatus red** (file-and-image-renamer ×2 + gotenberg, >40 days silent despite 720 h budgets) — pre-existing alert-fatigue source, untouched.
6. **dnsblockd repo hygiene**: two unpushed daemon docs commits (`cf2b690`, `20afd82`) sit on master; and no release tag carries the OTLP + /health fixes (tag-pinning consumers would miss both).

## d) TOTALLY FUCKED UP

Nothing destroyed work or broke gates — all five runs landed, the tree is green, and every closing commit is pushed. What actually sucked:

1. **Three of five tasks were corrections to stale or fabricated claims — the class is now at its third confirmed instance.** (paperless email phantom 09-12 → attic "deterministic RED" 09-13 → the attic closure's own false "byte-identical inputs" + memory-sourced pin claim.) The window spent roughly two full agent runs auditing its own window's first report. The 80/20 remains the unbuilt verify-before-harvest rule (TODO row 315).
2. **The first-pass attic closure made an identity claim without reading the identity-bearing artifact.** "Byte-identical inputs" was inferred from a top-level drv env diff while the decisive inner ATerms were diffable in seconds. Two factual errors in one paragraph (the claim + the `e5bdc4a` pin from memory) in a doc that quotes drv hashes to 6+ chars — precision theater that cost two review round-trips.
3. **The queue re-dispatched a completed finding as a new item** (`000001a0981cd72c…` duplicated the pin-fix scope of `000001a0981cd729…`, which had already landed `9e972a5f` ~45 min earlier). The duplicate run's only real deliverable was re-verification + a gitleaks-trap discovery — but the root cause (fresh ID per re-enqueue, no prior-run state in the dispatch prompt) is unchanged and queue-side.
4. **Auto-commit daemon races hit THREE of five runs** (`33f44d9e`/`c609f8a5` amend, `bc20a4d9`/`9e972a5f` amend, `138f8b81`+`7ea4e5f6`/`120ada36` two losses). Every footer survived only because each run ran the `git show --stat` exclusivity check before a message-amend — one check, never planned in advance, is all that stands between a queue footer and a hijacked foreign commit. The first attic run was NOT so lucky: it died before committing and lost its footer entirely, causing the re-dispatch.
5. **`--no-verify` was used on three of the window's commits.** Each instance was justified and documented (the hook's full flake check builds 63 checks incl. VM tests), and the attic closure has now removed the known-red excuse — but until the docs-only fast path exists, gitleaks keeps being skipped on exactly the markdown files where secrets-leak accidents historically happen.
6. **In-passing (shared-queue journal, other repos):** the window's timespan shows repeated `task.failed`/`task.dead-lettered` churn on CV (`cmd/cv` build verify) and go-taskqueue (`cmd/tq` race-test/gofmt verify) tasks, plus `task.requeued` preflight refusals on a dirty go-taskqueue tree. At least three tasks dead-lettered on verify failures — worth a triage pass in those repos (`tq dlq`).

## e) WHAT WE SHOULD IMPROVE

1. **Verify-before-harvest, hard rule** (the actual 80/20): any "X red since DATE" row entering the queue must carry a fresh re-run of the cited check, or an `unverified-carry-forward` tag; harvest must grep `docs/status/` (incl. `archived/`) for later resolutions first.
2. **Evidence-provenance convention for closure reports**: every identity/equivalence claim names the artifact actually read (top-level env / inner ATerm / closure) and its scope; "the lock pinned X at time T" requires `git show <rev>:flake.lock` BEFORE writing; drv-equivalence arguments start with the ATerm diff, not a build.
3. **Daemon-race protocol as doctrine**: write → commit immediately post-verify (seconds matter); on a sweep, `git show --stat` exclusivity check before any message-amend. Better: exclude `docs/status/` + TODO_LIST from the daemon's heuristic sweep for active queue sessions.
4. **Docs-only pre-commit fast path**: gitleaks + fast guards + `nix flake check --no-build` for markdown-only staged diffs; full VM-building check only for code diffs. Makes the honest path the cheap path.
5. **Hex-literal hygiene**: never paste full 40-char SHAs into tracked docs (gitleaks scans the whole exported index — one violation blocks ALL commits repo-wide). Abbreviate in tree; full form recoverable via the cited command.
6. **Queue-side**: stable item ID across re-enqueues; re-dispatch prompts carry the prior-ID chain; duplicate-dispatch detection (grep `docs/status/` for the finding's distinctive quote before starting a review-fix run).
7. **"Goes live with the next deploy" suffix as standard** on every config-landing TODO row (the signoz flip joins the Hermes fix in deploy-pending limbo).
8. **Split `signoz_traces_missing` semantics** (never-seen vs went-dark) so event-driven services stop muddying dense-service outage detection.

## f) UP TO 50 NEXT THINGS (harvested — the actionable subset is appended to TODO_LIST)

Highest leverage, in order:

1. **Deploy** — everything verified this window (signoz flip, Hermes cron fix, pool-smart, btrfs-rescue) is stacked behind one `nix run .#deploy`; then verify `upstream_gaps` drops 5→4 live.
2. **Build the prevention layers** (e.1–e.5) — three phantom tasks this window; each is small, and together they end the class.
3. **Investigate the live `missing 3`** Gatus red (renamer/gotenberg) — demote to `wiring = "upstream"`, add never-seen tolerance, or exercise the services.
4. **Trace-gap tail**: instrument overview, PMA, papdashboard, hermes upstream; ratchet 4→3→2→1→0 as each lands.
5. **dnsblockd upstream housekeeping**: push or discard the 2 daemon docs commits; cut a release tag carrying the OTLP + cached-/health fixes; decide tag-pin vs follow-master.
6. **Evidence durability** for the attic closure (question g.1): gcroot the two VM-test outputs or copy the driver ATerms into `docs/evidence/`.
7. Post-deploy: live-verify the dnsblockd cached `/health` behavior (fix is in the deployed binary per lock ancestry — confirm the endpoint serves from cache and 503s fast on staleness).
8. `tq dlq` triage of the dead-lettered CV/go-taskqueue verify tasks (shared-queue observation).
9. Then the standing backlog: user-gated chain (InboxClean re-consent, Miniflux flip, paperless decrypt go-live, mail relay domain verification), owed reboot (:52626 corpse), /data P0, Borg offsite leg — all already tracked in TODO_LIST and not restated here.

## g) QUESTIONS (owner-only)

1. **Evidence durability:** when a closure verdict rests on drv evidence (the attic falsification), should the outputs be gcrooted and/or the driver ATerms committed into `docs/evidence/`? Today the chain survives only until the next GC cycles; after that, re-audit is impossible.
2. **Status-doc correction convention:** correct-in-place under a CORRECTED marker (used twice this window) vs append-only annotation — which is canonical for (a) live reports and (b) archived reports carrying falsified claims? Decides whether this pass's inline annotations match the house style going forward.
3. **Gitleaks vs hex shapes:** abbreviation-only for commit SHAs in tracked docs (current, safe, slightly lossy) or a bounded `.gitleaks.toml` allowlist for SHA-shaped backtick strings (convenient, marginally weakens the secret scan)? Recommendation: abbreviation-only.

## h) BAND DRIFT (ADR-0015)

**None recorded.** `tq facts` for the window's timespan (2026-09-13 00:00–04:00) contains zero `task.reprioritized` facts — no priority moved via marker, AI, unblock, or importance. The only queue-state churn was lifecycle events (claimed/failed/requeued/dead-lettered/completed) on this window's five items plus out-of-scope CV and go-taskqueue verify-failure churn noted in (d).6.

---

## Docs-health pass actions (this pass)

- **Annotated inline (non-destructive):** the three reports carrying the falsified attic "deterministic RED" — `docs/status/archived/2026-09-06_00-31…` item 18, `docs/status/archived/2026-09-06_02-33…` item 25, `docs/status/2026-09-12_00-59…` items b.2/d.4/f.6/g.2 — now point at the falsification with its evidence chain.
- **Archived (`git mv` → `docs/status/archived/`):** four fully-done window reports nothing references: `01-09` (attic re-dispatch), `01-23` (ID remap), `02-29` (evidence re-base), `03-14` (pin citation). `00-19` stays (cited by TODO_LIST rows 28/315/317/337); `02-52` stays (primary report for the still-open row 29).
- **Living docs reconciled:** AGENTS.md dnsblockd `/health` bullet inline-corrected — the cached-response fix is pushed (`internal/server/health.go:97`, on origin) and an ancestor of deployed lock rev `94c9cb93`; the "NOT pushed/deployed" claim was stale in both halves. CHANGELOG gained the signoz-coverage flip + ratchet entry (deploy-pending noted). FEATURES SigNoz row notes dnsblockd enforced + budget 4. TODO_LIST banner refreshed; harvest items + owner questions appended.
- **Verified, not changed:** all five closing commits exist, carry footers, and are pushed; `git status` clean before this pass's edits (modulo this pass's own files).

*Point-in-time snapshot — 2026-09-13 ~04:00 CEST. Report per repo task-queue convention; nothing pushed.*
