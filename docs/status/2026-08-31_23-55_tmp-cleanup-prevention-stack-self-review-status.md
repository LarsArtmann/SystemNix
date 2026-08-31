# tmp-cleanup Prevention Stack — Self-Review & Full Status (Round 2 close-out)

**Session:** 2026-08-31 ~23:00–23:55 (continuation of `2026-08-31_21-35_forgejo-mirror-enoent-root-cause-tmp-cleanup-private-tmp.md`)
**Scope:** execute that report's §7 improvement list (blast radius, mechanism proof, eval guards, VM test) + self-review. No unrelated research.

---

## a) FULLY DONE (verified)

1. **Fix verified live (again, post-deploy):** `system_forgejo_mirror_errors_30m 0`, `scrape_errors 0`, sync age healthy (~7h < 10h stall threshold), 47 `systemd-private-*` dirs alive, gen-744 (21:16:25) still the running system, fix committed (`dd3479e9`, rebased through daemon batch `f00a33ec`).
2. **Blast-radius sweep (§7.3 / Q2):** 4 victims, ~16.9k tmp-ENOENT lines, all four `PrivateTmp=true` (verified in deployed unit files):
   - forgejo 16,318 (known); discordsync 550 attachment-download failures — **self-healed**, post-heal reconcile completed with 0 failures; paperless-task-queue 5 (celery `pymp-*`, 01:30 scheduler); immich-ml 2 (wgunicorn `mkstemp`).
   - `mount-rootfs/tmp` systemd warnings (twenty/fail2ban/caddy/manifest, 3-6 each) identified as a DIFFERENT signature and excluded.
   - **No lasting data loss anywhere.**
3. **Post-20:46 victim check (self-review catch):** the 20:46:38 tmp-cleanup run still used the OLD script (fix deployed 21:16) and "removed 24 stale entries" — swept the window since 20:40: **0 tmp-ENOENT lines**. The old script's final run claimed no visible victims.
4. **`modules/nixos/services/tmp-cleaner-audit.nix`** — eval-time assertion rejecting inline `/tmp/*`-glob + `rm` without `systemd-private` exclusion, across Exec*/script options of every system unit. Auto-imported into evo-x2 (`systems/evo-x2.nix:69`); **zero false positives on the deployed config**.
5. **`scheduled-tasks.nix` self-assertion** — `tmpCleanupText` hoisted to module level; `lib.hasInfix "systemd-private-*) continue"` asserted. Stripping the exclusion now fails `nix flake check` with the incident story in the message.
6. **`tests/test-tmp-cleanup.nix` (VM)** — imports the REAL module; aged fixtures: exactly 2 junk entries removed, fresh + dotfile + **artificially-aged `systemd-private-*` fixture survive**. Plus the **mechanism proof**: deleting a PrivateTmp backing dir host-side leaves the unit's `/tmp` LISTABLE but every file creation fails ENOENT (`machine.fail` asserted; forensic print captured). Upgrades Round 1's "correlation, not repro" caveat to VM-proven fact.
7. **`tests/test-tmp-cleaner-audit.nix`** (pure eval, session-boot-audit pattern) — 4/4 cases: evil inline caught; exempted passes; real config no false positives; tripwire wired+passing. During development it caught its own case-1 wiring bug (audit module missing from the eval) — the test tested itself before it tested the guard.
8. **Gates:** `nix flake check --no-build` PASS (×3 across the session), `nix fmt --no-update-lock-file -- --ci` clean (final state verified), VM test PASS with build-log forensics extracted.
9. **Docs:** AGENTS.md gotcha extended (blast radius, proven mechanism, 4-layer prevention stack); Round-2 sections §9-13 appended to the root-cause report; Aug-21 brutal-self-review HTML card flipped to Resolved with the three disproven claims corrected + `.severity-resolved` CSS added.
10. **Test-import ergonomics solved:** nur-overlay stub + `users.primaryUser = "root"` shim documented inline for any future test importing scheduled-tasks.nix.

## b) PARTIALLY DONE

1. **Mutation negative test** — the "assertion fires when the exclusion is stripped" direction is NOT executed anywhere: source mutation needs a realized store path, impossible under `flake check --no-build`. Replaced by a wiring-presence check; the behavioral half lives in the VM test. Residual risk: the hasInfix predicate itself is untested in its failing direction (trivial semantics, but untested). Documented in the test header.
2. **Q1 (21:16 switch deliberateness)** — evidence gathered (gen-744 shipped the evening's batch: docker-prune + tmp-cleanup guard + crush sops; still current; no later switches). User confirmation pending.
3. **Q3 (keep the 4h timer?)** — recommendation written (KEEP: intraboot junk reclamation, incident class now fenced by 4 layers). Decision pending.
4. **First fixed-script timer tick (~00:46)** — not yet observed (23:52 at writing). Script grep-verified deployed + VM-proven; observation one-liner left in the root-cause report §13.
5. **treefmt `--ci` double-pass behavior** — twice observed: first invocation reports N changed with file mtimes moving; second reports 0. End state verifiably clean; mechanism (cache invalidation?) not root-caused.

## c) NOT STARTED

1. **Forgejo upstream filing** (TODO_LIST:35 — dead-queue silence, TouchMirror masking, credential-helper ENOENT aborts; needs verify-before-filing against current upstream main).
2. **Stale `commit-graph.lock` cleanup** (2 repos; user sudo).
3. **Audit coverage for user units** — `systemd.user.services` / HM-shape / raw-text cleaners evade tmp-cleaner-audit today (session-boot-audit already parses those shapes — machinery is reusable).
4. **Pre-Aug-18 historical sweep** — the timer (and bug class) predates the forgejo credential helper; earlier victims would only exist in rotated-away journal archives.
5. **Cross-service tmp-ENOENT tripwire metric + Gatus check** — the incident's true detection gap: 16,318 lines over 12 days, nothing watched the CLASS (only forgejo-specific metrics, shipped Aug 22, watch one service).
6. **`systemd-private` dir-count drift gauge** (sudden drop = the bug recurring).
7. **Independent discordsync attachment-store spot check** (reconcile self-reported complete; not independently verified).

## d) TOTALLY FUCKED UP (process honesty — nothing user-visible broke)

1. **Three eval-gate round-trips** (lambda application `((import X) {})`, `with`-scoping on absent optional attrs, `writeText`/`toFile` unrealizable under `--no-build`). Each caught by the gate; but the first was avoidable — the correct pattern sat in the memory-guard test I had already read.
2. **A multiedit "failed" with modified-since-read yet had applied** — resolved by slice-view + full semantic validation (flake check), i.e., verification-by-gate rather than certainty about tool state.
3. **`severity-resolved` badge written against a CSS class that didn't exist** — unstyled badge shipped in the annotation; caught in this self-review, class added (`--solution` token).
4. **Missed the post-20:46 victim-window check in the main run** — the 20:46 run was the old script's last execution; I only swept through Aug 30 23:03. Caught now: 0 victims.
5. **Formatting discipline** — ran fmt --ci after major edits but not after the LAST .nix edit (case-fix multiedit); the 23:45 gate showed my file unformatted. Fixed and re-verified. The daemon's pre-commit would have caught it, but I claimed "gates green" before the tree actually was.
6. **Parallel-session flagging came late to the user-facing surface** — docs-health, pool-recovery, gatus-patterns, crush-consolidation sessions were active (one edited AGENTS.md mid-edit-race with me; the daemon batched my code into `f00a33ec` alongside signoz-coverage work). Flagged in tool narrations, surfaced prominently only in the final summary.

## e) WHAT WE SHOULD IMPROVE

1. **Watch the failure CLASS, not the victim:** every monitoring shipped after this incident is forgejo-specific. A generic journal-pattern counter (tmp-ENOENT across ALL units, 30-min window, fail-closed) + Gatus alert would have caught the incident within 30 min regardless of which service died.
2. **Guard user-unit cleaners too** — the audit covers system units only; HM/user services are the next place a naive cleaner appears (session-boot-audit's HM+raw-text parser is the precedent to reuse).
3. **Mutation guards need a runnable surface:** `flake check --no-build` cannot import synthesized modules; a flake app (`nix run .#verify-guards`) running mutation evals with full nix would let every self-assertion have an executed negative test.
4. **HTML-report annotations:** verify CSS classes exist before using them (or add them in the same edit — done here).
5. **treefmt --ci double-pass:** 10-min root-cause or a gotcha note; if the first pass WRITES in a fresh CI checkout, formatting regressions could be silently self-healed instead of caught.
6. **Attribution under daemon batching:** `f00a33ec` mixes three sessions' work; status reports remain the only per-session ledger — keep writing them even for "small" follow-ups.

## f) Next up to 50 (realistic, unpadded — 25)

1. Observe the ~00:46 tmp-cleanup tick (journalctl one-liner; expect "removed N" with forgejo's dirs intact).
2. User: confirm Q1 (21:16 switch deliberate?).
3. User: decide Q3 (keep timer — recommended).
4. User sudo: remove the 2 stale `commit-graph.lock` files.
5. Forgejo upstream filing — run verify-before-filing against current main, draft the 3 issues.
6. Check upstream forgejo ≥15.0.8 for a credential-helper/CreateTemp fix (may make our monitoring the only lasting piece).
7. Extend tmp-cleaner-audit to `systemd.user.services` (+ HM shape + raw text).
8. system-health: cross-unit tmp-ENOENT journal counter (fail-closed, `--since` bounded, timeout-capped — per the journalctl IO-trap rules).
9. Gatus check + Discord alert on that counter.
10. system-health: `system_systemd_private_tmp_dirs` count gauge.
11. Gatus floor assertion on the dir count (drift = recurrence).
12. Independent discordsync spot check: one attachment_id from the error list present in the store.
13. Pre-Aug-18 sweep if archived journal exists under /var/log/journal.
14. flake app `verify-guards`: mutation evals for tmp-cleanup guard (and generalize to other self-assertions).
15. VM probe: cover the `/var/tmp` (var.tmp) half of PrivateTmp (mechanism presumed symmetric, untested).
16. Root-cause or document treefmt --ci double-pass.
17. Link the Round-2 report from TODO_LIST:35 for the upstream-filing context.
18. On the NEXT deploy: confirm switch-to-configuration restarts tmp-cleanup on script-text change (ExecStart store-path swap ⇒ restart expected; verify once).
19. If Q3 = drop the timer: remove it, KEEP audit+tests, note that Gatus /tmp-usage (80%) alerting becomes the only pressure valve.
20. Consider a short note in scheduled-tasks.nix header documenting WHY the timer exists alongside cleanOnBoot (the Q3 rationale, whichever way it lands).
21. Sweep the four victims' journals for OTHER error classes in the incident window (only tmp-ENOENT was swept).
22. Verify paperless celery 01:30 scheduler ran clean post-fix (next 01:30 tick).
23. Verify immich-ml wgunicorn clean post-fix (2 occurrences only — likely already clean; confirm).
24. Re-check `system_forgejo_mirror_erroring` (per-repo flag) decays to 0 in metrics.
25. Optional: TMPDIR-based hardening audit for the 4 victims (do they honor TMPDIR? moving temp roots out of /tmp adds a second fence).

## g) Questions (cannot be figured out from the repo/journal)

1. **Q1:** Was the 21:16:25 switch (gen-744) your deliberate deploy? (It shipped the evening batch: docker-prune rework, the tmp-cleanup guard, crush sops — consistent with intentional, but intent is not observable from here.)
2. **Q3:** Keep the 4h tmp-cleanup timer (my recommendation: keep — now guarded by 4 layers), or drop it and rely on `cleanOnBoot` + the 80% Gatus alert?
3. **Upstream contact:** should a future session run verify-before-filing and DRAFT the 3 forgejo upstream issues for your review, or do you prefer handling upstream contact entirely yourself?

---

**Verification state at writing (23:52):** flake check PASS · fmt --ci clean · VM test PASS · forgejo errors 0 · 47 private dirs alive · 0 tmp-ENOENT lines since 20:40.
