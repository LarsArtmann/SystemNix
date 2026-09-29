# Status Report — GOTOOLCHAIN=local Shell Removal (2026-09-29 07:05 CEST)

**Scope:** THIS SESSION ONLY (per instruction: no unrelated research). The session was one task — "Remove GOTOOLCHAIN=local from the shell" — plus the closure work the task surfaced.

**Format note:** Skill default is styled HTML; the explicit `.md` instruction wins, so this is Markdown.

**Deliverable state:** the change is IN THE TREE and FULLY VERIFIED, but **not deployed** — the running system still has the pin until the next `nix run .#deploy` + fresh login shell.

---

## a) FULLY DONE (evidence cited)

| # | Item | Evidence |
|---|------|----------|
| a1 | **Shell pin removed** — `GOTOOLCHAIN = "local"` deleted from `platforms/nixos/users/home.nix` sessionVariables; comment block rewritten to record the 2026-09-29 user decision and the rationale (2026-09-17 go 1.27.1 wave made the pin fail LOUDLY on every floor-ahead repo in plain shells: mr-sync, clean-wizard, CV hold class) | Rendered-output proof: `nix eval .#nixosConfigurations.evo-x2.config.home-manager.users.lars.home.sessionVariables` → `GOEXPERIMENT = "jsonv2"` present, **no `GOTOOLCHAIN` key**. Committed by the auto-daemon as `2e3ca9e1` (heuristic message, contents verified `git log -1 --stat`: only home.nix) |
| a2 | **Dead fish override removed** — the interactive `if test "$GOTOOLCHAIN" = local … set -gx GOTOOLCHAIN auto` block (landed `9be027c8` as a go.work workaround) was unreachable once the pin was gone; deleted | Same commit; `grep -n 'GOTOOLCHAIN.*auto' platforms/nixos/users/home.nix` → rc=1 (no match) |
| a3 | **base.nix `go_1_27` comment updated** — rationale now "the shell's `go` must satisfy the 1.27.1 floor natively so the built-in auto mode never downloads a toolchain" (was "GOTOOLCHAIN=local forbids downloads") | In working tree (unstaged); `nix fmt --ci` clean over the file |
| a4 | **AGENTS.md doctrine bullet updated** — "Cache-key unification" rewritten: removal decision, dead fish override, default-auto stance, nix-build pinning unaffected, the 2026-08-15 fork-class watch, and the GOEXPERIMENT jsonv2 revisit trigger (registering the trigger was itself an open item from the 2026-09-23 15:22 report) | In working tree (unstaged) |
| a5 | **CHANGELOG entry landed** under `[Unreleased] → Changed` | In working tree (unstaged) |
| a6 | **Verification batch (all green, actually run):** (1) `nix flake check --no-build` → "all checks passed"; (2) `bash scripts/test-gotoolchain-guard.sh` → "SELFTEST OK"; (3) orphan `scripts/check-flake-inputs.sh` → rc=0 "All checks passed" (after fixing d1 below); (4) rendered sessionVariables eval (see a1); (5) `nix fmt --no-update-lock-file -- --ci` → "0 changed" (matters: the daemon bypasses pre-commit, so formatting was unproven until this run); (6) CI-hygiene scope proof: both greps (`.github/workflows/nix-check.yml:162`, `scripts/check-flake-inputs.sh:37`) are `--include="*.nix"` only, so AGENTS/CHANGELOG prose cannot trip them; (7) `grep GOTOOLCHAIN ~/.config/direnv/lib/zz-smart-nix.sh` → no match (closes a previously unverified assumption about the direnv `use_go_env` lib) | Command outputs in session transcript; nothing above is claimed without a run |
| a7 | **Self-harvest at authoring time (AGENTS TODO doctrine):** TODO row 355 premise updated (fish FP source removed; NEW residual class noted — .nix comment prose can trip the crude grep, proven live by d1); new queue row "Land the GOTOOLCHAIN shell-removal follow-ups"; pipeline.md library entries added (`[ready]` follow-ups + `[watch]` buildcache fork watch) | `TODO_LIST.md` rows near 362; `docs/todo/pipeline.md` tail |

---

## b) PARTIALLY DONE (what works, what remains, blocker)

| # | Item | Works | Remaining | Blocker |
|---|------|-------|-----------|---------|
| b1 | **Activation of the change** | Tree + eval + rendered config proven | Deploy (`nix run .#deploy`) + fresh-shell probes: `go env GOTOOLCHAIN` (must not say local), `command -v go` → go_1_27 | Owner timing: the deploy carries far more than this change (undeployed 09-25..29 batches ride the same activation) and the pressure gate applies |
| b2 | **Commit hygiene** | All edits are in the tree; daemon swept home.nix into `2e3ca9e1` | base.nix, AGENTS.md, CHANGELOG, TODO harvest, and this report are uncommitted; `2e3ca9e1` carries a heuristic message that buries a doctrine-relevant decision | Harness forbids commits without explicit user request; house amend-forward doctrine conflicts — harvested as `[ready]` queue item (see §g Q2) |
| b3 | **GOTOOLCHAIN predicate single-sourcing (row 355)** | The original FP source (home.nix fish lines) is GONE | Two stale grep copies remain (CI hygiene step + orphan script); the crude line-grep over .nix is now PROVEN to catch comment prose (d1), not just assignments | The delete-orphan-vs-wire-CI decision is owner-gated (tracked in row 355) |
| b4 | **2026-09-23 go-toolchain report's open items** | Its queued "revisit trigger" registration is now DONE (a4); its item "Decide the GOTOOLCHAIN question permanently" is now DECIDED (reversing that report's own "drop neither" recommendation — on the owner's explicit call) | The old report is not yet ANNOTATED with the reversal (docs-health ANNOTATE mode) | Not yet done — queued in §f |

---

## c) NOT STARTED (periphery of this session's task; why)

| # | Item | Why not started |
|---|------|-----------------|
| c1 | `templates/go-flake-parts/flake.nix:166` devshell still sets `GOTOOLCHAIN = "local"` | Deliberately out of scope: "the shell" = your interactive session env. The template pins `goPkg = go_1_27` so its local pin is coherent; whether the template should match the new shell stance is a policy decision (§g Q1) |
| c2 | Automated jsonv2-graduation probe ("drop GOEXPERIMENT when clean-env `go env GOEXPERIMENT` reports jsonv2 default") | The trigger is now DOCUMENTED (a4) but nothing executes it periodically; needs a tiny script/timer decision |
| c3 | GOTOOLCHAIN `off`-exclusion contract (row 362) | Pre-existing BLOCKED decision; my change only removed one of its surfaces |
| c4 | Staged-file drill for the guard block (row 360) | Pre-existing; untouched |
| c5 | CI gate reality: statix finding (row 353) still red → the GOTOOLCHAIN selftest (mine included) has NEVER executed on a runner | Out of scope this session; remains the single blocker for the whole CI tail |
| c6 | Buildcache toolchain-fork watch (one build-heavy week of observation) | Can only start post-deploy; `[watch]` library entry landed (a7) |

---

## d) TOTALLY FUCKED UP (radical honesty; severity-rated)

Nothing catastrophic — no data risk, no runtime damage, no broken gates left behind. But four real misses, all self-caught:

| # | What happened | Severity | Root cause | Mitigation status |
|---|---------------|----------|------------|-------------------|
| d1 | **I introduced a lint failure while removing a lint false-positive.** My FIRST base.nix comment draft put `GOTOOLCHAIN` and `auto` on one comment line; the orphan hygiene grep (crude `GOTOOLCHAIN.*auto`, .nix-only) FAILed on it. I had argued in-message that "the fish lines were the FP source, so that item self-resolves" — then my own replacement re-tripped the same class | Minor (self-caught pre-commit, fixed + re-proven rc=0) | I knew the pre-commit guard's ASSIGNMENT-shaped predicate but forgot the orphan/CI copies use a cruder line grep that also matches prose | Fixed; row 355 premise updated with the new "comment-shape" residual class |
| d2 | **Overclaim in the first close-out.** I stated the CI FP "self-resolves" as fact WITHOUT running anything. The evidence-rule pass during THIS report's authoring is what caught d1 | Minor (corrected before any commit rode the claim) | Verification verbs ran at report time, not at close-out time | §e1 improvement; the report-claim SURFACE rule (pipeline row) already covers the pattern |
| d3 | **Wrong rc capture on the first orphan-script run** (`… \| tail -6; echo rc=$?` reported tail's rc=0 while the output said "❌ FAIL: 1 hard violation") — the exact pipefail-class trap this repo has documented twice | Trivial (output text carried the true verdict; second run captured rc correctly) | Piped command + `$?` | Corrected in the re-run |
| d4 | **First multiedit failed one block** (misread the anchor: `npm_config_cache` line is followed by the PLAYWRIGHT line, not by the fish block) | Trivial (one wasted round trip) | Rushed context read | Fixed with correct anchor |
| d5 | **Heuristic commit message in master history** for a doctrine-relevant change (`2e3ca9e1` "chore: auto-commit 2 changed file(s)") | Low (searchability debt only; tree is correct) | Chose the harness no-commit rule over house amend-forward doctrine — a genuine rule conflict I resolved conservatively | §g Q2 asks you to pick |

---

## e) WHAT WE SHOULD IMPROVE (process/design; harvest ground)

1. **Run the verification batch BEFORE the close-out message, not during the status report.** d2/d1 cost nothing only because the report-time pass existed. The repo already codifies the verbs (pipeline row "Verification-verb template doc") — the missing piece is TIMING discipline: close-out claims must be run-claims.
2. **Comment prose vs line-grep guards is now a proven trap class.** Two guards grep raw lines over `.nix` (hook predicate is shape-aware; CI hygiene + orphan are NOT). Writing about GOTOOLCHAIN in a .nix comment trips the crude ones. Fix: make the hygiene greps consume the hook's predicate (single-sourcing, row 355) — kills both the stale-FP and comment-trap classes at once.
3. **Daemon-commit vs amend-forward needs a final policy.** Every session that touches doctrine hits the same conflict (d5; row 365 tracks the general daemon-race policy). Until decided, heuristic messages keep burying decisions.
4. **When a prior report's recommendation is reversed, cite the reversal at the reversal site.** Done here (AGENTS bullet + this report cite the 2026-09-23 15:22 report whose "drop neither" verdict was overridden) — cheap, prevents future sessions re-litigating from the stale recommendation.
5. **The 2026-08-15 buildcache fork class has no automated tripwire.** With shells back on auto, a floor-ahead repo will silently fork the cache again before anyone notices. A single buildcache-usage/fork grep in the existing `buildcache-metrics` collector (or a journal scan for toolchain download lines) would close it — queued as `[watch]` for now, automation candidate.

---

## f) NEXT — up to 50 (session-adjacent only, ranked; ⚠ brainstorm, not commitment)

Session-direct first, then the adjacent queue rows I directly read this session. Deliberately NOT listed: the broader unrelated backlog (per your scope instruction; it lives in `TODO_LIST.md`).

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 1 | Deploy the tree (`nix run .#deploy`) — carries the pin removal AND the undeployed 09-25..29 batches in one window; pressure gate applies | Critical | S | Ops |
| 2 | Post-deploy fresh-shell probes: `go env GOTOOLCHAIN` (not local) + `command -v go` → go_1_27 + open-new-terminal reminder | High | S | Verification |
| 3 | Amend-forward `2e3ca9e1` + commit the sibling edits (base.nix, AGENTS, CHANGELOG, TODO harvest, this report) with a proper message — pending §g Q2 | Medium | S | Git |
| 4 | Re-test a plain-shell BuildFlow/bank-sync pre-commit flow post-deploy (the 09-23/09-24 reports documented plain-shell floor failures under the pin — they should be healed now) | High | S | Verification |
| 5 | Annotate the 2026-09-23 15:22 go-toolchain report (docs-health ANNOTATE): decision reversed, trigger registered | Low | S | Docs |
| 6 | One-week buildcache fork watch per the landed `[watch]` entry (buildcache.prom growth + `go.mod requires go >=` journal scan) | Medium | S | Watch |
| 7 | Fix the statix finding in `modules/nixos/services/hot-user-caches.nix` (`inherit (cfg) device;`) — unblocks the ENTIRE CI tail (row 353) | High | S | Bug |
| 8 | After 7 lands: verify the "GOTOOLCHAIN guard selftest" CI step finally executes green on a real runner (never run yet; 06-48 §f30) | Medium | S | CI |
| 9 | Single-source the GOTOOLCHAIN predicate (hook extraction consumed by CI step + orphan, or delete the orphan) — also fixes the comment-trap class (e2) | Medium | M | Quality |
| 10 | End-to-end staged-file drill for the guard block (row 360) | Medium | S | Quality |
| 11 | Decide the `off`-exclusion contract (row 362) | Low | S | Decision |
| 12 | Decide CI live-signal vs known-dark (row 361) — gates the priority of 7/8/17/18 | High | S | Decision |
| 13 | CI consecutive-red tripwire (row 358) | Medium | S | Tooling |
| 14 | Fix CI VM-test deploy-key gap, `NIX_DEPLOY_KEY_BRANCHING_FLOW` not loaded (row 354) | High | S | CI |
| 15 | Allowlist the secret-history scanner's own canaries (row 356) | Medium | S | CI |
| 16 | Input-hygiene ghost probe: monitor365 removed from packages surface yet still probed (row 364) | Low | S | Quality |
| 17 | mktemp (+trap) the pre-commit hook's per-leg logs (row 367) | Low | S | Quality |
| 18 | Extend CI shellcheck to `scripts/lib/*.sh` + `.githooks/*` (row 366) | Medium | S | CI |
| 19 | Scheduled clean-HEAD `nix flake check --no-build` CI job — would have caught the /run/binfmt class in hours (row 369) | Medium | S | CI |
| 20 | `scripts/verify-status-citations.sh` — directly relevant: THIS report cites bare SHAs (`2e3ca9e1`, `9be027c8`) against actual diffs (row 350) | Medium | M | Quality |
| 21 | Automation candidate from e5: buildcache toolchain-fork tripwire (fold into `buildcache-metrics` or a journal scan) | Medium | S | Tooling |
| 22 | Automation candidate from c2: weekly jsonv2-graduation probe writing a TODO/alert when `env -i … go env GOEXPERIMENT` reports the default | Low | S | Tooling |
| 23 | Template decision (§g Q1), then either drop `GOTOOLCHAIN = "local"` from `templates/go-flake-parts/flake.nix:166` or document why the template stays hermetic | Low | S | Decision |
| 24 | Live direnv probe: `direnv exec` into a Go repo and confirm no GOTOOLCHAIN pin leaks from any direnv lib (static grep was clean) | Low | S | Verification |
| 25 | Daemon-race policy decision (row 365) — resolves d5/b2 permanently | Medium | S | Decision |
| 26 | Regression test for BOTH env-less cache reap sites (row 359 — adjacent, read this session) | Medium | M | Quality |
| 27 | Eval-time audit: secret-looking redirect paths need UMask 0077 (row 357 — adjacent) | Medium | M | Quality |
| 28 | Eval-Time Guards doctrine note: which guards are inline-deepSeq vs shared-lib (row 363 — adjacent) | Low | S | Docs |
| 29 | Formatter-inflated disk-layout HTML re-splice (row 351 — adjacent, noticed in queue) | Low | S | Cleanup |
| 30 | Queue dedup preflight decision (row 352, BLOCKED on owner) | Low | S | Decision |

---

## g) QUESTIONS I CANNOT FIGURE OUT MYSELF (max 3)

1. **Template hermeticity vs consistency:** `templates/go-flake-parts/flake.nix:166` keeps `GOTOOLCHAIN = "local"` in its devshell (with `goPkg = go_1_27`, so it is coherent and floor-safe). Should future generated projects also drop the pin to match your new shell stance, or is the template deliberately hermetic? (I read the template and the 09-23 report; the intent is yours to set.)
2. **Commit policy for this session's work:** the daemon landed home.nix as heuristic `2e3ca9e1`; house doctrine says amend-forward into a proper message, the harness forbids unrequested commits. Want me to amend-forward `2e3ca9e1` now, folding in base.nix + AGENTS.md + CHANGELOG + TODO harvest + this report — or leave it to a dispatch?
3. **Deploy timing:** activating this change requires `nix run .#deploy`, which ALSO carries every other undeployed in-tree batch (09-25 binfmt-cycle fixes, memory-guard batch, visionreviewd, restic, …). Deploy now (pressure gate permitting), or hold for a deliberate window? If now: I will run pre-deploy checks first and stop at any gate.

---

**WAITING FOR INSTRUCTIONS.**
