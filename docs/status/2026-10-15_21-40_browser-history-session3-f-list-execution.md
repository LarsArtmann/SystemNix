# Browser-history Pareto session 3 — §f-list execution + deploy still PSI-parked (2026-10-15 21:40 CEST)

Scope: the 20-55 report's §f follow-up list (agent-actionable subset) + the 3 owner questions resolved to their bundled defaults by the user's blanket execute directive. Sessions 1-2 covered by the 20-50 + 20-55 reports. Companion plan: `docs/planning/2026-10-15_19-35_BROWSER-HISTORY-SUPERB-ADOPTION-PARETO-PLAN.md`.

## a) FULLY DONE (verified this session)

1. **§f.6 kill-stub rule** — the rule pre-existed (shell-devtools.md:37, 2026-10-06); the session-2 increment (EXIT traps fire rm but their kill hits the stub; kill by recorded PID explicitly) appended to that bullet.
2. **§f.17 quiet-day-503 retirement** — grep verdict: NO living doc carries a stale current-behavior claim (deep-dive HTML + planning docs are point-in-time artifacts; the runbook's 503 mentions are the still-true restart classes). Adjacent stale claims fixed instead: FEATURES.md:102/542 "importUsers() ungated — pending tag/bump chain" → corrected to fixed+live-proven at pinned v4.14.3 (P09 evidence), and "probe user awaits root cleanup" → purged 2026-09-20.
3. **§f.5 `-journal` companion ROOT-CAUSED + fixed** — not a script bug: the 10-15 02:15 backup run was INTERRUPTED by the freeze-29/30 crash (proof: the run's journalctl entries are entirely absent — async journal loss — while the dated file exists at 02:15 mtime; 17 prior nights, zero journals). The interrupted-run class recurs by construction on this box. Fix in browser-history.nix: the backup script now HEALS stale journals at run start (journal + torn sibling deleted LOUDLY — a torn sibling must never look like a good backup) and retention matches `-journal` too. Rides the pending deploy.
4. **§f.4 CHANGELOG** — Added row (adoption-audit arc: AI suite, monitoring, gate verification, lock 5917bad, verify-closes, docs) + Changed row (P08 four-surface removal + hygiene).
5. **§f.18** — the gatus "Browser History" alert text now names the exactly-10.0s response-time signature (client-timeout, the burst-2 forensics class) with the IO-storm check pointer.
6. **§f.11 SigNoz dashboard** — `systemnix-browser-history` (6 panels: users gauge, render p99/mean/rate numbers, p99+p50 timeseries, rate+users grid) registered in `_signoz-alerts.nix`; JSON validated, all layout $refs resolve; rides the deploy (signoz-provision converges it, restartTriggers already wired).
7. **§f.15 negative test** — the inline post-deploy leg extracted to `scripts/lib/browser-history-registration-smoke.sh` (same code the gate runs — the storage-history-smoke pattern) with two hardening fixes the extraction surfaced: (i) the 403 verdict now REQUIRES the registration_closed body (a bare 403 could be the CSRF wall — proves nothing about the gate); (ii) token/cookie initialized (the original inline leg would crash under set -u when the server is down). Fixture battery `scripts/test-browser-history-registration-smoke.sh`: 6 cases against a python3 stub server, INCLUDING the 400-open-gate regression branch (branch-verified by message, not just verdict class) + the bare-403-without-body branch. Flake check `browser-history-registration-smoke-selftest` (sandbox-native buildInputs, wiring tripwire) — builds green.
8. **§f.14 / row 494 closed BOTH surfaces** — (c) `scripts/mutation-smoke.sh` (health-until-ANSWERED + agent-tick journal grep + users-gauge textfile probe; shellcheck clean); (e) the gatus record: the 22:03:16-5x window fell INSIDE gatus's own restart gap (stopped 22:02:49 → started 22:03:33) — no direct blip possible, only artifact = "Health Hub Federation degraded" TRIGGER 22:06:02 (worst-of folded the restart edge); tolerance recorded (sub-~2.5-min stop-windows invisible to the 5m direct check); (a/d bonus) the sanitized stop-window mutation template codified into the runbook (honestly labeled reconstruction — the executed script was deleted by design).
9. **20-55 report harvest** (the session-2 self-harvest debt): §f.10 extension token-auth row (upstream.md + mirror), §f.16 render-p99 calibration watch row (monitoring.md + mirror), count-gap row re-affirmed at v4.14.3. Gate now passes for that report. New rows: upstream.md 1, monitoring.md 1, TODO_LIST mirrors 2.
10. **Verification battery** (daemon-swept-commit discipline — standalone re-runs): shellcheck (4 scripts), bash -n, `nix fmt` 0 changed, deadnix/statix clean, gitleaks FULL-TREE (hook's exact invocation) clean, evo-x2 toplevel eval green at the fully-edited tree (drv `ssaf2d7p…`), selftest check sandbox-green. All edits verified intact at HEAD after daemon batching.

## b) PARTIALLY DONE

1. **§f.1 deploy bundle — PARKED AGAIN, PSI never opened.** avg10 through this session: 20.17 (start, closest) → 69.85 (peak); avg300 ~55 at end; load 40-102; 243 live nix/gopls processes; drivers structural (mr-sync-dashboard ~19 MB/s continuous — stability.md:106 — plus active parallel sessions). The written gate (avg10 <20) was never below 20.17. NOT forced, deliberately: the browser-history FOD at lock 5917bad has NEVER been built (cold go-modules closure), the box froze YESTERDAY (freeze-29/30, 03:24), and the DEPLOY_FORCE_PRESSURE=1 precedent (3/3 recent deploys) was warm-cache toplevel assembly, not cold FOD fetch+build. Everything is staged: eval green, vendorHash upstream-verified, bundle documented in row 364 (now including ALL session-3 riders: journal healing, alert text, dashboard, smoke lib, mutation-smoke). **Owner options: (a) overnight window — run `nix run .#deploy` when `head -1 /proc/pressure/io` shows avg10 <20; (b) owner-authorized force NOW at ~55 (accepting freeze-class risk on a cold FOD); (c) name a window.** Rows 364/479 annotated with the post-deploy battery additions.
2. **emeet-pixyd rider (row 300) — premise drift found:** the lock is at `176c494c…`, NOT the row's `1535ddf` (moved by a later session). The row's verify chain remains valid (the `/api/status` version field proves whatever rev ships) — correct the premise at close time.

## c) NOT STARTED (and why)

1. **§f.7 count-gap fix** — verified NOT fixed at cqrs-htmx HEAD (service_register.go:73 still `readModel.Count()`); real cross-repo work with tests, not a P07-style verify-close. Stays tracked (row re-affirmed).
2. **§f.8 firefox family / time.Duration marshal fix** — tracked ([ready], upstream.md); full buildflow-gated session in the upstream repo, PSI-blocked for its own verification loop tonight.
3. **§f.2/§f.3/§f.9 owner gates** — unchanged (stop-window sudo, OAuth2 ceremony, macOS timing). The stop-window handoff is now sharper: the runbook recipe + `scripts/mutation-smoke.sh` (the post-op probe) + `browser_history_users` expectation (9) are all in place; one owner window executes.
4. **§f.12 (tonight's 02:15 watch)** — row 479 extended with the -journal + missing-journal-entry checks (see §a.3); the observation is tomorrow's.

## d) TOTALLY FUCKED UP (honest)

1. **The fixture battery probed a foreign service before the port-free check existed.** First run: port 18455 was a live foreign listener; my wait-loop curled it and the case ran against SOMEBODY ELSE'S server (verdict garbage, caught by the assertion). Fix: kernel-assigned ports (bind 0, port reported via file) — fixed ports lose at ephemeral-port roulette (32768-60999 overlap; an unrelated ESTABLISHED conn 39452↔9100 reproduced the EADDRINUSE). Lesson: a fixture port is UNVERIFIED attack surface until proven free; bind-0 is the only deterministic answer.
2. **Three broken JSON drafts of the dashboard before one valid one** — junction closes missing between array elements (2 panels × 2 spots), then overcorrections. Each caught by the parse check before anything consumed it, but 4 edit rounds for a mechanical structure is sloppiness, not craft. Should have assembled programmatically and validated once.
3. **The lib extraction briefly SHIPPED A REGRESSION** — my first lib draft deleted the body file BEFORE the registration_closed grep (verdict weakened to any-403) AND dropped the token/cookie init (set -u crash on dead server — the original inline leg had it). Both caught by writing the negative test the §f item demanded — which is the whole point of §f.15, but the honest record is the test caught MY bugs, not just the hypothetical regression.

## e) WHAT WE SHOULD IMPROVE

1. **Fixed-port fixtures: bind-0 or refuse** — codified in the test script comment; generalize when the next fixture server is written.
2. **JSON authoring: build programmatically when >2 nesting levels** — hand-writing SigNoz panel JSON invites brace drift.
3. **Extraction-before-test is a bug factory** — the §f.15 item ordered the work correctly (test the leg); my first draft still shipped the weakened verdict. Extract + test must land ATOMICALLY.

## f) NEXT

1. **The deploy bundle** (row 364 + 505/300 riders) — staged; owner window or PSI lull (§b.1 options).
2. **§f.12/row 479** — tomorrow: tonight's 02:15 backup fresh + quick_check + NO journal remnant + journal entries EXIST.
3. **Stop-window + consolidation ceremony + macOS** — owner-gated; handoffs fully documented (runbook + mutation-smoke.sh + one-pager).
4. **Upstream sessions** (each its own dispatch): time.Duration marshal fix (§f.8, live-visible prod bug), count-gap fix (§f.7), extension token-auth issue (§f.10).
5. **Render-rule calibration** (§f.16 watch) after ~1 week of series.

## g) QUESTIONS FOR THE OWNER

1. **Deploy window:** (a) overnight auto-window when avg10 <20, (b) force NOW at ~55 accepting cold-FOD freeze risk, or (c) a named window? (The bundle is fully staged; one `nix run .#deploy`.)
2. **Stop-window + consolidation ceremony:** ready to execute on your signal (backup → claim-orphaned → compact → mutation-smoke; then E2E login + machine-label + OAuth2 second-identity + revoke dupes → rows 77/79/87/503 close).

---
*All session work committed (pathspec `b89448c7` + daemon-batched earlier edits, verified intact at HEAD). Pre-commit todo gate failed ONLY on a live parallel session's rows (proven failing at HEAD in a throwaway worktree); every other hook leg re-run standalone green. Upstream repos untouched. Foreign files not disturbed.*
