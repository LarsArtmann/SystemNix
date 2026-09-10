# Status Report: nix-cache-pin Evaluation & Self-Review — 2026-09-10 09:32

> Session scope: evaluation of `github:caniko/nix-cache-pin` (worth adding? document? file issues?),
> plus a forced re-audit. Docs-only session — no code, no modules, no deploys.
> Format override: user explicitly requested `.md` (skill default is HTML dashboard).

---

## Session Timeline (what actually happened)

| # | Step | Outcome |
|---|------|---------|
| 1 | User: "worth adding?" → README + repo metadata + our flake topology | Verdict: **skip** — 5-reason table |
| 2 | User: "document it?" | Added AGENTS.md bullet (Nix & Nixpkgs gotchas, next to the `nixos-unstable` bullet) |
| 3 | User: "file an issue? attic blind spot especially" | Loaded verify-before-filing → cloned source → **premise FALSE** (caches option exists, Attic in own preset) + **issues disabled on repo** → corrected my false claim in AGENTS.md |
| 4 | User: mantra repeat → full re-audit of MY claims | Second overstatement found (`lockOnly` exists, default-vs-opt-in), crates.io crate **unpublished** (404) → AGENTS.md entry rewritten to fully-audited form; scratch clone trashed |

---

## a) FULLY DONE

1. **nix-cache-pin evaluation, verdict: REJECT (wrong fit, not bad tool).** Final verified reasons:
   - We're on `nixos-unstable` (flake.nix:14) — Hydra covers expensive builds there; the tool targets `nixpkgs-unstable` gaps.
   - Topology mismatch: its model is SEPARATE side nixpkgs inputs (`pkgsRocm`/`pkgsCuda`); we have ONE root nixpkgs + 46 follows. Pinning the root to "latest fully-cached rev" holds the entire system back for the slowest package.
   - DEFAULT apply-mode rewrites URL-rev pins into flake.nix (runner.rs:264, `lock_only: false` default) — our documented `?rev=`-overrides-lock trap class. `lockOnly` avoids it but is opt-in.
   - Zero adoption: v0.1.0, ~6 weeks old, 0 stars/forks, single author, crate **unpublished on crates.io** (404 despite "crates.io-ready" badge), **issues disabled** (PRs only), nightly Rust toolchain via author's personal `rs-harbor` repo.
2. **AGENTS.md decision record** — single entry in Nix & Nixpkgs gotchas, corrected twice during the session, final form source-audited (file:line evidence for every claim). Uniqueness verified (grep count = 1).
3. **Issue-filing analysis: NO issue filed, correctly.** The user-flagged "attic blind spot" was falsified at source level: `PinConfig.caches: Vec<String>` (config.rs:39), flake-module option `caches` (nix/module.nix:121), README option table (line 160), shipped preset queries `https://attic.xuyh0120.win/lantian`. Filing would have been the classic professional-looking-issue-with-wrong-premise failure.
4. **Source-level audit of the tool**: pin application mechanism (flake_update.rs `update_flake_nix` vs `update_flake_lock_only`), runner branching, crates.io publication status, feature surface scan (closure verification, version constraints, plan transactions with fail-before-write).
5. Scratch clone cleaned up (`trash`, not `rm`).

## b) PARTIALLY DONE

1. **Feature-surface audit**: `verify_closure`/`version_constraints` confirmed at lib level (config.rs), but module-option plumbing only greped — README documents `verifyClosure` (line 174) while my module.nix grep found nothing for it; inconclusive, not chased. Does not affect the verdict.
2. **verify-before-filing skill content**: builtin `crush://skills/verify-before-filing/SKILL.md` returned "Builtin file not found" via the View tool (both with and without suffix). I proceeded on the skill's description mandate alone. Resolution failure unreported at the time it happened — reported here instead.

## c) NOT STARTED (deliberately, per user scoping "just report based on this session")

1. **TODO_LIST.md harvest** of the revisit trigger (status-report skill mandates HARVEST after writing; user scoped this session to reporting only — pending user instruction).
2. Alternatives-ecosystem survey (flake-checker, etc.) — our actual need is already covered by `nixpkgs-compat.yml` daily CI + nixos-unstable jobset; deliberately not researched.

## d) TOTALLY FUCKED UP

1. **I published a materially FALSE claim — twice — and wrote it into doctrine.** "Verifies only Hydra/cache.nixos.org — can't see the private attic cache" appeared in the chat table, then in the first AGENTS.md entry. Root cause: generalized from the README's Hydra-focused examples without reading source. The repo's own doctrine (verify-before-filing, phantom-green class, "probe the surface the config actually lands on") exists precisely for this. It survived exactly one user turn before source verification killed it — the user's push ("this specially feels worth a Issue") was the trigger, not my own rigor.
2. **Second overstatement**: "it institutionalizes URL-rev pins in flake.nix and machine-edits the file" — true only for the default mode; the `lockOnly` flake.lock-only path (which even preserves unrelated dirty lock nodes) existed in the same source file I had already cloned for the attic check. I verified the claim I was challenged on and left my other claims unverified until the mantra-repeat forced the audit.
3. One banned `curl` attempt through bash (security block, wasted call — should have used `fetch` directly).

**Pattern across d): verification was REACTIVE, not DEFAULT.** First-pass evaluation (README-only) produced 2 wrong/partial claims out of 5 rows. Both died only when externally challenged.

## e) WHAT WE SHOULD IMPROVE

1. **Source-clone BEFORE verdict** for any "should we adopt X" evaluation — the README-first pass had a 40% claim error rate this session. Clone is cheap; corrections in doctrine files are not.
2. **Apply verify-before-filing's gate to AGENTS.md writes too** — it currently gates outbound issues; writing a false claim into the repo's own doctrine file is arguably worse (it propagates to every future session). Candidate hard rule: no claim enters AGENTS.md without file:line or command evidence captured in the same session.
3. **Report tool/skill resolution failures immediately** (the crush:// builtin-not-found), not in the eventual status report.
4. Chat-table verdicts should carry confidence labels (README-derived vs source-verified) so the user can see which rows are load-bearing guesses.

## f) Next things to get done (session-scoped; honest count, not padded to 50)

> The user scoped this report to this session's work — a true 50-item list would require repo-wide research that was explicitly ruled out ("DO NOT RESEARCH OTHER STUFF UNRELATED"). These are the real items this session generated:

1. Harvest the nix-cache-pin revisit trigger into `TODO_LIST.md` (docs-health HARVEST) — pending user go-ahead.
2. Fix/verify the `verify-before-filing` builtin skill resolution (crush:// path not found via View) — crush-config territory.
3. Add an "external tool evaluation protocol" mini-rule to AGENTS.md: clone + source-verify before verdict + before doctrine writes.
4. Verify our own attic (`cache.home.lan`) serves unauthenticated narinfo reads — the tool's caches option does plain GETs with no auth-token support; relevant IF we ever adopt.
5. Decide: GitHub watch on caniko/nix-cache-pin for maturity signals, or a quarterly manual re-check entry.
6. If a GPU-overlay nixpkgs input ever lands (pkgsRocm/pkgsCuda style), re-run this evaluation with `lockOnly = true` and the attic in `caches`.
7. Optionally send the author a PR (issues disabled): document `caches`/Attic support more prominently in the README intro — the Hydra-heavy intro is what misled this session's first pass.
8. Optionally PR: remove/fix the "crates.io-ready" badge while the crate 404s.
9. Confirm the auto-commit daemon lands the two AGENTS.md edits + this report cleanly (shared-tree doctrine).
10. Consider a confidence-label convention for evaluation tables in future status docs (README-derived vs source-verified).

## g) Questions I cannot figure out myself

1. **Harvest now or not?** Should the nix-cache-pin revisit trigger go into `TODO_LIST.md` today (skill says yes, your scoping said report-only) — or stay AGENTS.md-only?
2. **Doctrine gate:** do you want the "no claim into AGENTS.md without source evidence" rule formalized in AGENTS.md itself (it adds process weight to every future doc edit), or kept as session discipline only?
3. **Upstream engagement:** do you want ANY outbound contact with caniko/nix-cache-pin (docs PR, badge PR), given we rejected the tool — or zero footprint since we're not users?

---

## Brutal self-review answers (mandated questions)

- **What did you forget?** To verify the crush:// skill resolution failure at the moment it failed; to finish the module-plumbing check; that our own attic's auth posture was assumed, not checked.
- **What is stupid that we do anyway?** (session-level) trusting README-derived claims enough to write them into AGENTS.md. (repo-level, noticed in passing) nothing new investigated — out of scope.
- **What could I have done better?** Cloned the source on turn 1. The entire attic-claim correction cycle would have been a non-event.
- **What can I still improve?** e) items 1-4.
- **Did I lie to you?** No intentional lies. One materially false claim was asserted with full confidence, then retracted and corrected in-writing once source-verified. The record now carries the correction explicitly.
- **Ghost systems / split brains?** None created. The AGENTS.md entry is the single decision record; the chat table's wrong row is superseded by it.
- **Scope creep?** Resisted: no harvest, no unrelated research, no repo-wide audit despite the 50-item prompt.
- **Tests?** N/A — docs-only session; no code paths changed.
- **Removed something useful?** No. (The scratch clone was trash-collected; the AGENTS.md rejections were replacements, not deletions.)

---

*Report written and awaiting instructions. Not committed — the repo's auto-commit daemon owns commits here.*
