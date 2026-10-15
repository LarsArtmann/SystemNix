# Browser-history Pareto session 2 — status + brutal self-review (2026-10-15 20:55 CEST)

Scope: THIS session only (the P07–P14 execution run; session 1 of the arc landed P01a/P02/P03-lock/P04/P05/P06/P12-AD-2 and is covered by `docs/status/2026-10-15_20-50_browser-history-pareto-session2-p07-p14.md` §a — this file adds the honest layer on top). Companion plan: `docs/planning/2026-10-15_19-35_BROWSER-HISTORY-SUPERB-ADOPTION-PARETO-PLAN.md`. Format note: `.md` at the user's explicit demand (status-report skill default is HTML; brutal-self-review's HTML/reviews variant is deliberately NOT duplicated here — one report, one conversation).

## a) FULLY DONE (verified this session)

1. **P07 heartbeat — verify-closed, zero new code.** Shipped upstream `b1fd4d8` 2026-09-20 (`SendHeartbeat`, same auth/trace/retry; server records freshness on empty batches, ingest.go:220). Contained in deployed `fff6034` (merge-base proven). Live: `/agents/health` 200 `{active:1}`, 13-byte empty `POST /ingest` answered 200. The deep-dive's "503×354 this boot" was the previous server process.
2. **P08 probeRegistrationCleanup — ripped from all four surfaces.** configuration.nix wiring+comment, module option/ExecStartPre/assertion block, entire `_browser-history-scripts.nix` (git rm), fixture check. Eval green (toplevel drv + checks attrNames + rendered unit grep). Verdict recorded: RIP.
3. **P09 registration gate — live-proven + wired.** CSRF dance = exactly `403 usermgmt.registration_closed` (live); post-deploy-check leg added with a deliberately-invalid email (gate-before-validation ⇒ open-gate regression answers 400, zero debris by construction); bash -n + shellcheck clean. `/auth/import`: bare=403 csrf_invalid, valid-dance-no-session=401 — unreachable unauthenticated. registrationMu sweep at PINNED usermgmt v4.14.3: 3 `NewRegisterUserCmd` sites, all gated.
4. **P12 — all three.** Bursts: burst-1 inside PSI 57% + gatus "I/O Stall Rate" TRIGGERED; burst-2 2 min after PSI 34% + 10.6 GiB nvme1 write burst, preceded by the 10.0s health-timeout signature — both PRE-hot-tier, explained. Render-proof: page 1 = 20 rows / 0 firefox; Limit trace pinned at fff6034:346; `?browser=firefox` top row = the wikivoyage Appleton landing. Alerting: SigNoz render-p99 >5s rule + `browser-history` scrape job (histogram proven absent from SigNoz BEFORE the job via live API query — phantom-metric discipline held); signoz-query-lint green.
5. **P10** — macOS one-pager in the runbook, decision row annotated. **P11** — extension DROPPED, live-probed (no auth/CSRF ⇒ 403 bare, 401 with dance; upstream-token-auth is the re-open condition). **P13** — owner consolidation runbook (one ceremony closes rows 77/79/87, post-gates defined). **P14** — 3 verify-closes with first-hand evidence (import-gate already in pinned rev; empty-dashboard converged; `reattribute` superseded by `claim-orphaned` measured dry-run). Count-gap row deliberately left open (v4.14.3 still uses `readModel.Count()`).
6. **Queue hygiene:** 12 library rows closed + 2 annotated (macOS decision, lock-bump bundle note) + 8 TODO_LIST mirrors closed — including the PREVIOUS session's missed P06 gatus-row closure and a glued-newline formatting bug in TODO_LIST 1272. check-todo-system: structure clean. Commit `8729f4de` + pushed; `nix fmt` on all my nix edits: 0 changed (verified post-hoc).

## b) PARTIALLY DONE

1. **P03 FOD+deploy — parked all session by PSI discipline** (avg10 46→81, avg300 ~67; drivers: gopls 99% CPU, live nix-daemon, wireguard_colle 824%, parallel crush/buildflow sessions). The row's own precondition (avg10 <20%) never approached. Everything EXCEPT the build+switch is done: lock at `5917bad`, eval green, the deploy bundle grew and is documented in the lock-bump row (now carries: P08 removal, P09 smoke leg, signoz job+rule, P06 gatus check, AI-suite env). One cheaper step I did NOT think of in-time: eval-only confirmation that the FOD derivation references resolve (`nix eval .#…goModules.drvPath`) — marginal, noted for the executor.
2. **P14's cqrs-htmx push-chain staging** — became MOOT (the import-gate fix is already in the pinned rev; the chain's whole purpose evaporated). Not staged because there is nothing left to stage; recorded in the row close instead.

## c) NOT STARTED (and why)

1. **Owner-gated items** (correctly not attempted, agent-safe scope): stop-window `claim-orphaned -yes` + compact (sudo + service stop; recipe + measured numbers ready), OAuth2 first-login rejection test, E2E login + machine-label UI, revoke 4 bring-up users (all sequenced in the P13 runbook).
2. **CHANGELOG row for this arc** — neither session wrote one; the repo's "sessions document themselves" precedent (09-21 wave row) says it should exist. Not forgotten-forever: listed in §f.
3. **Upstream repo work** — none needed in the end (P07 verify-only; the upstream rows that remain are the firefox family + count-gap, out of this session's package scope).

## d) TOTALLY FUCKED UP (honest)

1. **The `-journal` landmine — my own confident mistake.** First harness run copied the 1,024-byte journal companion "for recovery" — its bogus recovery SILENTLY ROLLED BACK the visits table on the copy ("no such table: visits"), and I burned 3 debug rounds on it. A 1KB journal next to a 200MB `.backup`-API product should have been SUSPICIOUS, not trusted; I even wrote a wrong justification comment before testing. Root cause of the missed inference: I reasoned from "journals mean recovery" instead of "what does the backup script actually produce".
2. **Four harness servers leaked — repeating a lesson I had READ that morning.** The 21-47 report §d2 documented exactly this process-management failure class; my cleanup still relied on (a) EXIT traps that fired `rm -rf` fine but whose `kill` was this shell's UNSUPPORTED BUILTIN (rc=2, and silently no-op the first time because I hid stderr), and (b) no explicit PID-file kill. The processes survived THREE kill attempts (one `kill -9` "executed" against a stub) while holding ~200MB unlinked sqlite copies each, until `/run/current-system/sw/bin/kill` ended them. On a box with 28 freeze incidents, leaking 4 niced Go servers is precisely the mess the lesson exists to prevent.
3. **P12 took 6 harness iterations for want of one env var.** The misses: journal copy (d1), `/health` vs `/readyz` (drain gate), in-memory projection ignoring my UPDATE (the load-bearing `USE_SQLITE_READ_MODEL=1` sat at config.go:45 — in a file I READ at session start — and I skipped over it), a `/visits` page that renders 3 bytes, an HX-Request guess. ~40 minutes + d2's leak. The 21-47 "repro recipe" named the trick but the env var lived only in the old transcript — which is WHY I codified the recipe into the runbook this time.
4. **Count error in the commit message: "13 queue rows closed".** True count: 12 library + 8 queue-mirror closures (+2 annotations). The report said "closed/annotated" (accurate); the commit subject line rounded to a wrong integer. Same class as the repo's count-claim rule — embarrassing in a session that enforced that rule on the previous session's P06 gap.
5. **Two edit-tool races and one partial-block edit.** The services.md multiedit failed twice on "file modified since read" (daemon mtime churn — re-view + re-apply each time); the fixtures-migrations.nix edit removed only the fixture HEADER because my old_string stopped mid-block, leaving the body orphaned until a follow-up edit. Both caught by verification, but both were avoidable with full-block anchors + a pre-edit content-pin (written policy).
6. **Pushed a foreign file.** My push necessarily carried daemon commit `6fbfd5fe` (parallel session's `boot-metrics.nix`). I inspected its contents only AFTER pushing; the correct order was inspect-then-decide. Flagged to the user, but the sequencing was wrong.

## e) WHAT WE SHOULD IMPROVE

1. **Env-contract-first for repro harnesses:** read the target binary's config surface (env tags) BEFORE writing any harness — half of d3 was one skipped env var. The runbook recipe now encodes this.
2. **Kill-stdlib hygiene for agent shells:** assume `kill` is a stub; always `/run/current-system/sw/bin/kill` by absolute path, never hide its stderr, and always kill by recorded PID (traps are unreliable here). Deserves a line in the shell-devtools agent doc (§f).
3. **Suspicious-file reflex:** a journal companion on a backup that should be standalone is a STOP signal, not a copy-along. Added to the runbook recipe; the WHY the journal exists at all is §f item 3.
4. **Integer claims get counted, not estimated** — the commit-message count error (d4) would not survive a `rg -c '\- \[x\]'` before writing.
5. **Close-out verification should diff the FILE, not trust the summary** — the P06 row gap survived a full session because "rows closed" was asserted from memory. A one-line `rg` per claimed row is cheap insurance (this session did it; keep it).
6. **Inspect foreign commits BEFORE pushing past them** (d6) — add to the daemon-race policy's push step.
7. **CHANGELOG discipline** — two sessions in this arc shipped user-visible changes (module removal, monitoring additions, smoke leg) without CHANGELOG entries; harvest (§f).

## f) NEXT (get done; ≤ this arc's honest scope)

1. **The PSI-gated deploy bundle** (lock `5917bad` FOD verify → `nix run .#deploy` → anchor verify `readlink /run/current-system` == latest system link) — then the post-deploy battery: AI first summary + `/chat` smoke, CSRF-gate leg live-fire, gatus users-count green, `http_request_duration_seconds` series EXISTS in the SigNoz query API (render rule un-phantoms), probe-purge-absence sanity.
2. **Owner stop-window:** backup → stop → `claim-orphaned -yes` → `compact-visit-journal -yes -vacuum` → start → health-poll → post-gates incl. `browser_history_users` stays 9 (recipe + measured numbers in the runbook).
3. **Owner consolidation ceremony** (P13 runbook order: E2E login + machine-label → OAuth2 second-identity rejection → revoke dupes) — closes rows 77/79/87.
4. **CHANGELOG rows** for both arc sessions (adoption-audit wave: P02 AI env, P04 hygiene, P06 check, P08 removal, P09 leg, signoz job+rule, P10-P14 docs).
5. **Investigate the stale `-journal` companion** in the backup dir — a `.backup`-API product should be standalone; if the 02:15 script leaks journals, every future harness copy re-arms the d1 landmine (check the backup unit's sqlite invocation).
6. **Shell-devtools agent doc:** add the `kill`-stub + absolute-path + never-hide-stderr rule (d2 lesson, generalizes to every agent session).
7. **Upstream count-gap fix** (cqrs-htmx usermgmt): make the gate count from the authoritative store or assert Count()≥1 post-hydration — the last known registration-bypass class (verify-before-filing at HEAD first).
8. **Upstream firefox family** (upstream.md:189-195): behavioural-sync `time.Duration` marshal fix (live today: engagement_metrics empty, ALL browsers), downloads=0 mechanism, search/omnibox extraction, redirect-chain landing-page decision row.
9. **macOS agent go/no-go** (one-pager ready) — owner timing/label call.
10. **Extension upstream issue/feature:** agent-token auth for the MV3 extension (the drop rationale becomes the feature request; verify-before-filing at HEAD).
11. **SigNoz dashboard panel** for browser-history render p99 + users gauge (rule exists; no visualization yet).
12. **Watch row 476:** tonight's 02:15 backup through the hot mount — verify pool-side fresh + quick_check tomorrow.
13. **emeet-pixyd deploy row + hot-db CAP_DAC_OVERRIDE row (502)** — same PSI lull as item 1; ONE window lands all three.
14. **Row 491 residue:** `scripts/mutation-smoke.sh` convention + the Gatus blip-tolerance note.
15. **Post-deploy-check leg negative test:** a fixture proving the 400-open-gate branch fires correctly (the repo's selftest pattern; the leg currently has no negative test).
16. **Render-rule threshold calibration:** after ~1 week of real series, check p99 baseline vs the 5s target (13-19ms normals ⇒ enormous headroom; confirm no false-fire from cold-start renders).
17. **Upstream `/health` 503-on-quiet-day is now historical** — retire any remaining "quiet-day 503" mentions in older docs (grep; the heartbeat made them stale).
18. **The 10.0s `/health` gatus-timeout signature** (burst-2 forensics) — consider naming it in the gatus check's alert text so the signature is recognizable in future forensics.

## g) Questions I CANNOT answer myself

1. **Deploy gate override:** the storm is driven by YOUR parallel sessions (gopls, nix-daemon, wireguard_colle, buildflow). The written gate says PSI avg10 <20 — never reached. Do you want (a) wait for a genuine lull (possibly overnight), or (b) an owner-authorized deploy NOW at ~50 avg10 accepting freeze-class risk, or (c) park it for a scheduled window you name?
2. **Stop-window timing:** run the `claim-orphaned` + `compact` window tonight (I prep-verify post-gates agent-side), or bundle it with the deploy ceremony once the PSI question is settled? It rewrites 135k events — one window, one backup, ~15 min down.
3. **macOS agent:** go now with `machineId = "lars-macbook-air"` (one-pager wiring + a bh_ token mint from evo-x2), or defer until after the stop-window lands so the dashboard baseline is clean first?

---
*Post-report state: report left for the auto-commit daemon (no manual commit without instruction). Parallel-session edits visible in TODO_LIST.md / docs/agents/nix-flakes.md / docs/todo/monitoring.md were NOT touched.*
