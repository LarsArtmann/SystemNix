# §22 CA-parity session — full status + brutal self-review (2026-11-06 22:39)

**Scope of this session:** the live §22 WARN (`trusted and identical, but the bundle appends the same CA 2x … find the second writer`). Re-dispatch verification + steady-state encoding + docs landing + self-review. Nothing else researched.

## a) FULLY DONE

1. **Re-dispatch verification protocol (all 5 steps, docs/CONTRIBUTING.md)** — resolution of 2026-10-30 re-verified LIVE and verdict STANDS: bundle base64 count = 2; both enumerated copies DER-fingerprint-identical `EE:A9:E1:BE:…:49:88` == the sops CA; p11-kit name line `cn=dnsblockd-CA:eea9e1be` present; ONE store output (`nss-cacert-3.131.1`); `nix eval …security.pki.certificates --apply builtins.length` → 1. Queue surfaces for the original row moved together (`[x]` on TODO_LIST:263 + services.md:353). Source-report §f sweep (§f.1–7) CLEAN with adversarial cross-check — every item landed or queued on both surfaces.
2. **§22 WARN semantics encoded** (`scripts/lib/ca-parity-smoke.sh:84-88`) — exactly 2 copies → WARN naming the DOCUMENTED buildcatrust plain+p11-kit-TRUSTED steady state (tripwire kept against copy drift); >2 copies → WARN "a REAL second writer exists" + hunt pointer. The resolved ghost-hunt instruction is gone from the prod message.
3. **Fixture suite 8→9 legs** (`scripts/test-ca-parity-smoke.sh`) — leg 9 pins the >2 branch; leg 7 re-labeled steady state. 9/9 green standalone AND in-sandbox (`nix build .#checks.x86_64-linux.dnsblockd-ca-parity-selftest` realized green).
4. **docs/agents/nix-flakes.md mechanism paragraph landed** ("Packaging, store & CI cache notes") — closes open row TODO_LIST:1837 (ticked RESOLVED; queue-only row, no library twin to sync).
5. **Runbook + CHANGELOG synced** — `docs/services/dnsblockd.md` §22 verdict description + 9-leg count; CHANGELOG 2026-11-06 entry.
6. **Stale reference hunt (self-review finding, fixed)** — the lib header + post-deploy-check.sh (×2 sites) cited `dnsblockd-guards-selftest`, a flake check that DOES NOT EXIST (actual: `checks.dnsblockd-ca-parity-selftest`). All three corrected; `rg` sweep clean; shellcheck green; fixtures re-run green.
7. **Attribution** — `592993588` (proper message: CHANGELOG + mid-session status report) landed via daemon-sweep amend; mid-session report `2026-11-06_22-15_ca-parity-warn-steady-state-status.md` committed.

## b) PARTIALLY DONE

1. **Commit hygiene of the 5-file change** — the lib/test/runbook/nix-flakes/TODO sweep sits in heuristic daemon commit `3e83c2cc8`. My first amend attempt failed on the 72-char subject limit; by the retry, a FOREIGN commit (`61570b988`: flake.lock/flake.nix/expected-locks/pin-audit/crm.nix — parallel session) had landed on top, permanently closing the amend window (rewriting it would absorb the foreign session's work — forbidden). The change IS attributable via `592993588`'s body + status reports, but its own commit message stays heuristic.
2. **Repo-wide message-text consistency** — old WARN text verified ABSENT everywhere except my own trigger quote in the 22-15 report (correct as historical record); nothing further to migrate, but the 4 surfaces restating the semantics (lib header, runbook, nix-flakes paragraph, fixture header) are copy-aligned by hand, not single-sourced.

## c) NOT STARTED (deliberate scoping, all pre-queued)

1. Row 1836 — upstream buildcatrust source-verify + filing (needs verify-before-filing + github-voice; a dispatch of its own).
2. Row 1860 — rpi3-dns duplicate probe at its next deploy window.
3. Row 1861 — docs/services "second writer unidentified" phrasing sweep.
4. Row 1862 — eval-time comment in dns-blocker-config.nix documenting the intentional cacert duplication.
5. Rows 1866 + 1867 — owner-gated decisions (telemetry metric; useCompatibleBundle evaluation).
6. No deploy owed: the §22 change lives in scripts (post-deploy-check runs from the flake source as an app), not in a system unit.

## d) TOTALLY FUCKED UP (own errors, all self-caught or hook-caught, zero damage)

1. **Blind amend risk** — my retry amend absorbed a fresh daemon commit; I verified contents only AFTER (outcome clean: exactly my 2 files), but the house rule demands verifying `git show --stat HEAD` BEFORE amending. Violated the discipline; got lucky with zero foreign absorption.
2. **72-char subject limit** — shipped a 74-char subject into a full pre-commit leg battery (~90s wasted) before the commit-msg guard rejected it. The limit is written in my own operating rules; I didn't count.
3. **`rg -rn` trap, third strike on this host** — typed `rg -rn` (replace-display, not recursive) during the stale-ref sweep; the hook blocked it. AGENTS.md documents this exact trap; I re-introduced it anyway.
4. **Three broken probes before a green one** — (a) awk enumeration with a wrong dir path (`$tmp/c` + `%s/c%04d` → files one level deeper) returned 0 matches; (b) `nix eval --raw` on an integer attr errored; (c) live-driver callbacks passed compound command strings where function names were required. Each self-debugged, but the first versions shipped wrong-looking evidence (a probe that returns "0 copies" reads like a falsification of the resolution).
5. **Missed a stale check-name reference in the file I edited** — I touched the lib header's verdict table but not the header line citing the nonexistent `dnsblockd-guards-selftest`; found only during self-review.

## e) WHAT WE SHOULD IMPROVE

1. **Amend discipline under daemon races**: treat any >1-command git operation as race-exposed — re-check `git show --stat HEAD` immediately before every amend, not once per session.
2. **Commit-msg guard runs LAST** — the 74-char rejection cost the whole leg battery; a subject-length fast-fail FIRST in the hook makes bad subjects cost milliseconds. (Queued as §f.11 below.)
3. **Amend-aware lint legs** — my amend logged "No staged .sh files — skipping shellcheck" while the amended HEAD carried .sh changes; standalone shellcheck covered it this time (existing queued row for the general class).
4. **Single-source the §22 semantics** — four hand-synced restatements (lib header, runbook, nix-flakes paragraph, fixture header) will drift; one canonical table + pointers.
5. **Probe discipline**: the enumeration bug class (path assembled differently from the glob that reads it) deserves the standing check "would this pipeline's reader find the writer's files?" — same family as the awk-offset rule.
6. **Message-substring fixtures**: fixtures assert verdicts only; one substring assertion per message branch would catch accidental message regressions (the WARN text is operator-facing contract).

## f) UP TO 50 THINGS TO GET DONE NEXT (session-scoped; deliberately NOT padded to 50 — no filler)

1. **[P0] Dispatch row 1836**: source-verify buildcatrust `ca_bundle_input` double-emission at current nixpkgs; file upstream (verify-before-filing → github-voice) or close as documented-known.
2. **[P0] Owner decision row 1867**: accept plain+TRUSTED duplication as permanent hygiene, or evaluate `security.pki.useCompatibleBundle`.
3. **[P0] Owner decision (this report §g.1)**: keep the 2-copy steady-state WARN on every deploy vs demote to PASS-with-note.
4. **[P1] Dispatch row 1860**: rpi3-dns dup probe (one `grep -c` on its raw bundle) at the next rpi deploy window.
5. **[P1] Dispatch row 1861**: docs/services phrasing sweep for other hidden cacert-override mechanisms.
6. **[P1] Dispatch row 1862**: eval-time comment/assertion in dns-blocker-config.nix (kills the next duplicate mystery at the source).
7. **[P2] Owner decision row 1866**: §22 duplicate-copy-count textfile metric (make drift from 2-copy steady state alarmable).
8. **[P1] Commit-msg subject-length fast-fail FIRST in pre-commit** (before gitleaks/lint legs).
9. **[P1] Amend-aware lint legs** (existing row): on `--amend`, run the skipped staged legs against HEAD~1..HEAD diff, not the empty stage.
10. **[P2] §22 message-substring fixture assertions** (one per verdict branch).
11. **[P2] Single-source §22 semantics** (canonical table; lib header/runbook/nix-flakes/fixture become pointers).
12. **[P2] Pathspec-commit my 2 stale-ref fixes + this report NOW** (done in this session's closing step; verify afterwards).
13. **[P1] Flag + leave `flake/expected-locks.nix` dirty** — foreign session's in-flight work (flake.lock/flake.nix/pin-audit/crm.nix churn 22:37); never co-commit.
14. **[P2] Investigate why `shellcheck` is off PATH in agent shells** (devshells.nix:32 declares it; agent bash tool shells don't load it → `nix shell` round-trip per lint).
15. **[P3] Retire-or-document the standing `check-todo-system.sh` WARN (191 unharvested §f reports)** — noticed during the guard run; harvest-window debt is tracked elsewhere, but the count keeps growing.
16. **[P3] `nix eval` saved-settings preamble noise** on every eval (cosmetic; could confuse a grep-based gate).
17. **[P3] Probe-harness helper**: a `scripts/lib/bundle-cert-enum.sh` (the crl2pkcs7+awk split) so ad-hoc probes stop re-deriving the path/awk dance that bit me twice today.
18. **[P3] After the parallel lock session lands: re-verify my eval-adjacent claims** (pki eval ran pre-churn; a flake.nix/pin-audit touch could change the eval surface).

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **§22 steady-state verdict level** — the 2-copy buildcatrust duplication is now documented and the WARN self-explains. Do you want it to stay a **WARN on every deploy** (tripwire doctrine, but a permanent yellow line), or demote to **PASS-with-note** while keeping WARN only for >2 copies / fingerprint mismatch?
2. **Row 1867 (existing owner-gated)** — is the plain+TRUSTED bundle duplication acceptable **permanent** hygiene, or should I dispatch an evaluation (and possible upstream filing) of `security.pki.useCompatibleBundle` (which carries the CA once but strips p11-kit trust rules — a trust-semantics change across all consumers)?
3. **Row 1836 (upstream)** — spend a dispatch source-verifying and filing the buildcatrust double-emission upstream (verify-before-filing + github-voice), or close it as documented-known and keep only the local tripwire?

**Harvest log (2026-11-07, T03 wave — items HARVESTED):** DONE f.8 f.10 f.12 · already-tracked f.1 f.2 f.4 f.15 f.18 · OBSOLETE f.13 · NEW rowed: 9 rows → pipeline 6, services 3, monitoring 1 (f.7 restores the lost post-prune row)
