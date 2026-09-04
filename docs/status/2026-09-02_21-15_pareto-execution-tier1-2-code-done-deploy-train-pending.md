# Pareto Execution Session: Tier 1+2 Code-Complete, Deploy Train PENDING — Self-Review & Full Status

**Date:** 2026-09-02 21:15 (CLI) · **Session:** "GET SHIT DONE" execution of `docs/planning/2026-09-02_19-13_PAPERLESS-SSO-CLOSEOUT-AND-BOX-STABILITY-PARETO-PLAN.md` (T01–T19)
**Inputs:** the plan above + T01 user answers (question tool, 19:40).

---

## What was forgotten / could have been better (the honest ledger)

1. **Two variable-name mismatches in edit old_strings** (PMA_HEURISTIC_FALLBACK_OVER plural/singular) cost a failed multiedit + a re-read. Fix: copy identifiers from the view output, not from memory.
2. **Self-inflicted permanently-red-gatus bug caught pre-deploy:** my first pocket-id collector block initialized `POCKET_ID_BUSY_SCRAPE_ERRORS=1` but never flipped it to 0 on success. Caught by self-review minutes later — this is EXACTLY the class runtime verification (T03 doctrine) exists for; it would have sat red from the first deploy.
3. **Tracked-files trap bit me live** despite being documented in AGENTS: the new `scripts/lib/metrics-gate.sh` was untracked when I first built the flake check → `metrics_gate_classify_absence: command not found` inside the sandbox. Then a SECOND sandbox bug: the check ran the test as a bare store file with no sibling `scripts/lib/` → had to stage a scratch repo layout inside the check.
4. **Sloppy fixture-test stage-isolation assumptions** (3 broken assertions): calling the pressure lib with partial args still hits real `/proc` defaults which overwrite the last verdict. Rewrote the assertions as text-greps over captured output — stage-order-proof.
5. **Test-script syntax error from my own multiedit** (unterminated `echo "` + lost `$out` capture block). `bash -n` caught it before anything shipped.
6. **Runbook first draft contained INVALID placeholder commands** (`sudo cd`, a nonsense `changeparser` line). Cleaned to the interactive `paperless-manage changepassword` flow. Lesson: never draft shell commands as "shape hints" — write real ones or none.
7. **T10 negative test not yet verified:** the documented ad-hoc `nix eval --impure … config.assertions` command is BOTH slow (full evo-x2 eval) AND sits in a known-latent crash class (forcing ALL assertion messages hits the sops-template `owner=null` coercion bug, AGENTS-documented). I killed the stuck eval. The assertion itself is written; proving it fires needs a mutated-tree `nix flake check --no-build` instead.
8. **Concurrent-session duplication:** the "priority-4" session independently implemented the SAME T07 (pressure semantics + selftest flake check) and T08 (caddy exact `/admin`) while I was doing them. We merged cleanly (no duplicate blocks — verified), but the effort was spent twice. Root cause: both sessions read the same plan/handoff. Mitigation for next time: claim tasks in the plan file itself before implementing.
9. **Did not re-run `nix flake check --no-build` after the last edit** (pocket-id.nix assertion) before the status interrupt — the eval was still running. The assertion edit is committed (daemon) but not yet check-verified.
10. **flm-warm/PSI-calm deploy window was never even checked** — I went deep on Tier-2 code and never started the deploy train. All live verification (T04 metrics, T06 check green, /admin 403) is queued behind it.

---

## a) FULLY DONE (verified)

| Item | Proof |
|---|---|
| **T01** — 3 gating questions asked & answered | bounce-back OK (T14 closed); API clients "unsure" (T13 → research-first); memory → "will up the RAM - UMA Frame in the BIOS when we start again" (T02 disposition direction) |
| **T03** — Gatus Paperless SSO check runtime-verified | python3 urllib against the EXACT gatus URL (`http://localhost:2892/accounts/login/`): all 5 conditions PASS on the live body (200, 82ms, `oidc/pocket-id`+, `getElementById`+, no `type="password"`). External vHost through Caddy+house-CA also verified (SSO flow present, no password form). Alert trustworthiness: confirmed. |
| **T04** — pocket-id SQLITE_BUSY SPOF monitoring (code) | system-health.nix: `collectPocketIdBusy` option (auto-gated on `services.pocket-id.enable`), threshold 10/24h, journal-doctrine scan (`--since -24h`, `timeout 30`, exit≤1 valid, fail-closed scrape_errors), 3 metrics (`system_pocket_id_busy_{events_24h,over_threshold,scrape_errors}`). Collector derivation BUILT through nix (shellcheck+bash-n gate passed, 14 refs confirmed in the built script). Gatus "Pocket ID SQLite Health" check (anchored `\n` patterns, Discord alert). gatus-pattern-lint green. Live journal evidence: 30 "database is locked" events/24h measured. |
| **T05** — deploy.sh exit-trap logging | EXIT trap on every death path: structured final line (code, timestamp, elapsed, log path) → logfile + `systemd-cat -t systemnix-deploy` + 30-line context tail → `-t systemnix-deploy-tail`. `bash -n` green. Post-mortem query: `journalctl -t systemnix-deploy`. |
| **T06** — textfile-scrape-error class visible forever | Existing "Textfile Collector Health" check upgraded to the anchored doctrine form `pat(*\nnode_textfile_scrape_error 0\n*)` — verified to MATCH the live body (metric followed by further lines). Live value currently 0 (healthy). |
| **T07** — post-deploy pressure logic no longer lies | Extracted to `scripts/lib/pressure-report.sh` (sourced by post-deploy-check.sh): I/O <20 pass / 20-80 elevated / >80 saturated; NEW memory-PSI verdicts mirroring the deploy.sh gate (≥20 storm, ≥5 elevated); combined pre-freeze zone (zram≥95% + PSI≥5); MemAvailable <10% floor. Fixture-tested (`scripts/test-post-deploy-pressure.sh`, 9 assertions incl. the regression "PSI 77% never yields PASS") + flake check `post-deploy-pressure-selftest` GREEN through nix. (Merged with the concurrent session's identical fix — verified no duplication.) |
| **T08 (code)** — paperless bare `/admin` closed | Exact-match `handle /admin { respond 403 }` added before the catch-all. Rotation procedure documented (DB-first nuance) in the runbook — the rotation itself is deliberately USER-RUN interactive. |
| **T09 (mostly)** — `docs/services/paperless.md` runbook | Architecture table, SSO-only semantics (JS auto-submit ≠ 302; what DISABLE_REGULAR_LOGIN does NOT cover), auto-break-glass, rotation runbook, monitoring map incl. the root-gatus-sqlite one-liner (F09), API caveat, logout-bounce decision recorded. **AGENTS.md link not yet added (F30 open).** |
| **T11** — §10 gate logic tested | Classifier extracted to `scripts/lib/metrics-gate.sh`; pre-deploy-check.sh sources it; `scripts/test-pre-deploy-metrics.sh` covers ALL branches (clean pass, textfile-dark warn, forgejo-scan-failed warn, pocket-id-scan-failed warn, known-new warn, phantom hard-fail); flake check `pre-deploy-metrics-selftest` GREEN through nix. NEW: `POCKET_ID_SCAN_FAILED` downgrade branch added symmetric to forgejo's. |

**Validation state at time of interrupt:** `nix flake check --no-build` GREEN (rc=0, only known-benign warnings) — but BEFORE the pocket-id.nix assertion edit. `nix fmt --no-update-lock-file -- --ci` clean (0 changed). All new scripts `bash -n` clean.

## b) PARTIALLY DONE

- **T04/T06/T08 LIVE verification** — code committed but NOT deployed; the new metrics are absent from the running scrape (KNOWN_NEW_METRICS entries ride in pre-deploy-check.sh so the gate won't block its own deploy). Everything waits on the deploy train.
- **T10** — assertion WRITTEN into pocket-id.nix (paperless SSO-only client shape: clientId+pkce+exact callback, option-existence-guarded, negative-test command documented in-module). NOT verified: the ad-hoc eval is slow + sits in the sops assertion-coercion crash class; `nix flake check` not re-run after this edit.
- **T09 F30** — runbook exists; the AGENTS.md paperless-section link to it is missing.
- **T13** — only the runbook's API-caveat note exists; the actual research (token vs password surface, mobile-app impact) not started.

## c) NOT STARTED

- **DEPLOY TRAIN (the critical one)** — no deploy ran this session. T04+T06+T08 (+T10 assertion) all ride it. Requires flm-warm + PSI-calm window check immediately before.
- **T02** — memory-pressure disposition writeup (decision input now known: BIOS RAM/UMA-frame change planned by user).
- **T12** — deploy round-7 forensics (time-boxed journal hunt).
- **T15** — emission-guard lint for textfile collectors.
- **T16** — forgejo journal-scan performance profile/tuning.
- **T17** — dnsblockd goroutine-dump readiness verification.
- **T18** — other-owner coordination ledger + bank-sync vendorHash upstream check.
- **T19** — Layer-1 SSO-only rollout survey.
- **Post-approval harvest** — TODO_LIST.md entries for the genuinely-new items.

## d) TOTALLY FUCKED UP (nothing shipped broken — but these were the near-misses)

- The **permanently-red scrape_errors bug** (my own T04 block, §2 above) would have shipped without the self-review pass — one more argument for "runtime-verify every monitoring change" being non-negotiable.
- The **untracked-lib flake check** shipped red twice before the scratch-layout fix — I wired a check whose artifact sourcing I hadn't reasoned through. (Silver lining: the failure mode was loud, not phantom.)
- The **T10 negative-test command I documented in the module comment** is likely un-runnable as written (sops coercion crash) — the comment needs the mutated-tree `nix flake check` variant once verified. Right now the module carries a doc of a command that may not work — fix before this counts as done.

## e) WHAT WE SHOULD IMPROVE (process, from this run)

1. **Task-claiming in shared plans** — two sessions executed the same T07/T08. A one-line "claimed by session X, 20:45" per task in the plan file would have saved the duplicate work.
2. **Check-wiring needs the sandbox-sourcing decision UP FRONT** (store file vs repo layout) — encode the scratch-staging pattern into a reusable snippet next to the flake checks.
3. **`config.assertions` negative tests have a landmine** (sops template coercion) — the house pattern should standardize on mutated-tree `nix flake check --no-build` or a throwaway extendModules eval that only forces the ONE message (`builtins.match` over a filtered list still forces all messages — a `let a = ...` lazy filter doesn't avoid it). Needs a proven recipe once.
4. **Deploy early, deploy small:** I front-loaded ALL Tier-2 code before any deploy. The plan's "one deploy train" discipline is right, but the train should have left the station ~30 min into the session window; everything since sits undeployed and unverifiable-live.
5. **KNOWN_NEW_METRICS lifecycle is manual** — entries were added by TWO sessions independently tonight. The post-deploy retirement step should be part of the deploy train checklist itself.

## f) NEXT — up to 50 things, ordered

**The deploy train (do first):**
1. Re-run `nix flake check --no-build` (covers the pocket-id.nix assertion edit).
2. Check flm warm + PSI some avg10 <5% + zram state (deploy gate inputs).
3. `nix run .#deploy` — ONE train carrying T04 + T06 + T08 (+T10 assertion + T11 gate changes + concurrent sessions' niri/mail-relay work already in master).
4. Post-deploy smoke must pass; check `journalctl -t systemnix-deploy` for the NEW exit record (T05 live verification).
5. Verify `system_pocket_id_busy_*` metrics LIVE in `:9100/metrics` (expect events_24h ≈ 30, over_threshold 1 — the alert WILL fire, truthfully).
6. Verify gatus "Pocket ID SQLite Health" + "Textfile Collector Health" go green (sqlite root one-liner if in doubt).
7. Verify `https://paperless.home.lan/admin` → 403 (exact match) — no 301.
8. Retire the confirmed-live entries from KNOWN_NEW_METRICS (pocket-id pair + PMA trio + niri pair if live).
9. Expect + acknowledge the SQLITE_BUSY Discord alert (or tune threshold if user prefers).

**T10 closeout:**
10. Prove the assertion fires: copy tree state, mutate oidcClients callback, `nix flake check --no-build` on the mutated tree (or a scoped eval recipe), then fix the in-module negative-test comment to the verified command.

**T02 disposition:**
11. Write the §findings (flm 28 GB + 27 crush sessions + 56 GB cache vs guard zones) into the plan's annotation + a TODO_LIST item.
12. Record the user decision: BIOS RAM/UMA-frame change at next start; link the existing IO-PSI guard + crush-cap TODO items.
13. Flag the zram-sizing/MemAvailable-baseline review that the UMA-frame change REQUIRES (see question 3).

**T13 (research-first per user answer):**
14. Read paperless v3 docs/source: REST auth surface (token vs session vs password), what DISABLE_REGULAR_LOGIN actually blocks for the API.
15. Inventory live API consumers (paperless-ai token; any others in journals).
16. Write recommendation; only implement on explicit user go.

**T12 forensics (time-boxed 45m):**
17. Journal hunt for round-7 silent death (nh exit codes, unit restarts in the window).
18. Document verdict; point at T05 logging as the recurrence guard.

**T15 emission-guard lint:**
19. Design scope (collector unit scripts, warn-level).
20. Implement grep-based CI lint over `modules/nixos/services/*` textfile collector scripts.
21. False-positive sweep; wire as flake check.

**T16 forgejo scan perf:**
22. Profile current scan duration from the timer journal.
23. If >15s sustained: narrow `--grep` / add `-n` cap; verify counts unchanged.

**T17:**
24. Verify `scripts/dnsblockd-goroutine-dump.sh` exists + preconditions documented (root + wedged instance; SIGQUIT = restart).

**T18 ledger:**
25. bank-sync: eval lock subtree rev vs upstream (is the vendorHash override droppable?).
26. Message/mail-relay owner: paperless email wiring go-live checklist exists in runbook.
27. CV typst /export/pdf + PMA KNOWN_NEW_METRICS — coordinate, don't touch.

**T19 survey:**
28. Read-only config survey: gatus/forgejo/immich/browser-history local-login exposure.
29. Compose the single preference question for the user.

**Housekeeping from this session:**
30. F30: link `docs/services/paperless.md` from AGENTS.md paperless section.
31. Plan annotation: mark T01–T11 statuses in the plan file (never rewrite).
32. TODO_LIST harvest: T04 (done→closed), T08-rotation (user-run), T10 closeout, T13 research, deploy-train checklist item.
33. Annotate the plan with the concurrent-session convergence note (T07/T08 double-implementation).
34. Re-check `git status` for the still-dirty `scripts/pre-deploy-check.sh` (foreign uncommitted edit present at 21:15 — not mine).
35. Push state check (daemon pushes; verify origin sync at the end).

**Stability follow-ups observed mid-session:**
36. `system_crush_sessions` was 27 (threshold 6) all evening — the alert presumably fired; decide monitor-only vs action with the user post-BIOS-change.
37. zram 97.5% at session start — re-measure after the BIOS change; revisit zram sizing (~28.2 GiB was sized to ~94 GB visible).
38. Guard Zone semantics vs the " BIOS UMA up" plan: less visible RAM → tighter margins; the disposition (T02) must say this explicitly.
39. Consider capping concurrent crush sessions via the workload-admission wrapper if the post-BIOS state still rides >90% zram.

**Verification debt:**
40. Post-deploy: re-run the T03 urllib verification (the deploy touches caddy + system-health).
41. Post-deploy: confirm `pre-deploy-metrics-selftest` + `post-deploy-pressure-selftest` also pass in CI (they're new checks; CI run will confirm wiring).
42. Watch one full 2-min collector cycle post-deploy for the pocket-id block's actual runtime (timeout 30 headroom check).
43. First post-deploy `journalctl -u system-health-metrics -n 20` — confirm no shellcheck-era drift between built script and expectations.
44. VM test `.#checks.x86_64-linux.paperless` still green after caddy/module changes (was green pre-pocker-id-edit).

## g) Questions I CANNOT answer myself (max 3)

1. **Deploy train timing vs the BIOS reboot:** you said you'll "up the RAM - UMA Frame in the BIOS when we start again". Should I run the deploy train NOW (flm is warm, PSI was 0% — everything is committed and waiting), or does "when we start again" mean a reboot happens first and the deploy should follow it? (Deploying first means the monitoring for the next boot is already live; rebooting first means one less activation cycle on a zram-full box.)
2. **T13 appetite:** for the REST API password-auth question you answered "unsure — research first". Should I (a) do the research and just RECOMMEND, or (b) research + implement the closure behind the finding that nothing uses password auth (with a VM test), riding the NEXT deploy after your sign-off?
3. **UMA frame semantics:** upping the UMA frame CARVES MORE RAM AWAY from the CPU (the current 18 GiB carveout is why only ~94 GB is visible). Do you mean (a) physically adding RAM, (b) increasing the UMA frame (LESS system RAM — would make the zram situation worse, not better), or (c) both? The T02 disposition and the zram/MemAvailable baseline review depend on which it is.

---

*Reported 2026-09-02 21:15. Session state: Tier 1 + Tier 2 code-complete and check-verified (one flake-check re-run pending); deploy train is the single blocker for all live verification. Now waiting for instructions.*
