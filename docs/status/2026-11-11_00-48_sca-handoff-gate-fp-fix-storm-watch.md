# SCA Ceremony Handoff, Gate-FP Fix, Storm Watch (2026-11-11 00:48)

**Session:** this arc ran 21:11 → 00:48 CET under two owner directives — "run it properly" (the failed `bank-sync sca approve`) and then the report-and-wait directive. Continues `docs/status/2026-11-10_21-11_evening-continuation-status-overlay-lift-ab-verdicts-gate-gaps.md` and the 19-44 report lineage.

**Scope line — what this arc VERIFIED (command/artifact), and what it did NOT:**

| Verified | How |
| --- | --- |
| The daemon's real Wise-credential path is `/run/secrets/rendered/bank-sync-env` (`bank-sync:bank-sync` 0400), loaded via `EnvironmentFile` — NOT the runbook's `/run/secrets/bank-sync-env`, which does not exist | `rg` on the deployed gen-997 unit (`3yhv8kp…/etc/systemd/system/bank-sync.service:21-22`) + live `ls -la /run/secrets/rendered/` |
| `bank_sync_sca_approval_pending` = **1** — the Wise approval is still genuinely required | full `bank_sync_sca*` gauge scrape ×3 (21:2x, 23:5x, 00:4x), script `~/.cache/systemnix-probe/banksync-sca-state.sh` |
| The 19:44-evening "SCA challenge no longer surfaces in counters" claim was a probe blind spot (grep `bank_sync_sync*` cannot match `bank_sync_sca_*`) | the corrected claim is committed with the evidence inline (`af1707d07`) |
| The gate-FP fix works both directions | `bash scripts/check-todo-system.sh --selftest` → `SELFTEST OK … possessive-exempt`, rc=0 (bare "tonight" still fails; possessive "tonight's races" passes) |
| `systems/` eval-relevance entry landed in HEAD | `git show HEAD:scripts/lib/eval-relevant-paths.sh` line 32 (daemon sweep `2ce82515e` carried the working-tree fix) |
| All five of tonight's commits landed gate-clean | `4f31a0004` (gate FP fix), `af1707d07` (runbook path + report correction), `645032159`, `632cfb1e3`, `6e79583b3` (earlier arc) |

| NOT verified | Why |
| --- | --- |
| No deploy has happened | agent shells cannot switch (sudo dead); `e4c785e5e` (backup CAP fix) + the overlay lift still ride gen-997's successor — **03:29 is ~2h40m away** |
| The SCA ceremony itself | owner-intrinsic: the Wise key is 0400 bank-sync-owned, sudo is dead in agent shells, and the OTP arrives on the owner's phone into a hidden TTY prompt (or the dashboard UI) — procedure handed off, not executed |
| The `challenges_total 420 → 520` jump (~3.5 h) | observed, not investigated — out of scope per the report directive; queued as a watch item |
| Whether `challenges_total` is restart-reset or lifetime-cumulative | the runbook documents `errors_total` restart-cumulative but is silent on `challenges_total`; 520 now vs "618 cumulative" on 09-30 suggests reset-and-reclimb, unproven |
| Post-approval gauge flip | the ceremony has not run yet |

---

## a) FULLY DONE

1. **SCA failure root-caused and the proper procedure delivered** — the owner's bare `bank-sync sca approve` failed `[Rejection:wise.api_key_missing]` because the key exists ONLY in `/run/secrets/rendered/bank-sync-env` (0400, bank-sync-owned); the runbook's CLI path pointed at a nonexistent file, so even the documented procedure would have failed identically. Handoff delivered: dashboard flow primary (rides daemon creds, OTP in browser), CLI fallback with the corrected path for the owner's root shell.
2. **Runbook stale-path fix landed** (`af1707d07`) — both `sca status` and `sca approve` snippets now point at `/run/secrets/rendered/bank-sync-env` (`docs/services/bank-sync-sca.md:62,80`).
3. **19-44 report SCA claim corrected inline** (same commit) — the "no longer surfaces in counters" line now records the probe blind spot, the true `sca_approval_pending 1`, and why 0-error counters coexist with a pending approval (transfers-only fallback keeps cycles green).
4. **TODO-gate scanner FP fixed at the scanner** (`4f31a0004`) — the time-gated leg matched bare `tonight`, so retrospective possessives ("tonight's commit races", "tonight's banner pushes") FAILED the gate tree-wide (the gate reads the working tree → one bad row froze every session's commits). Possessives of tonight/yesterday/today are now stripped pre-match; bare adverbial "tonight" and all "tomorrow" forms stay matched. Selftest extended BOTH directions (bare still fails; possessive passes) — `SELFTEST OK`, rc=0.
5. **`systems/` eval-relevance gap closed** — third-gap discovery during the previous report's writing (host assemblies in `systems/*.nix`, array blind to it while a sibling edited `systems/evo-x2.nix` live); landed via daemon sweep `2ce82515e`, verified in HEAD.
6. **HM-mirror false alarm killed before filing** — a truncated view nearly produced a "split-brain: HM surface missing the bank-sync mirror" finding; the re-read (`systems/evo-x2.nix:79-81`) shows the identical `65/NbAtF` override on both surfaces. No ghost filed.
7. **Session discipline held under churn** — content-pin before every mutation across ~6 sibling HEAD moves; pathspec commits only; zero foreign work absorbed or reverted.

## b) PARTIALLY DONE

1. **The SCA ceremony: procedure handed off, not completed** — `sca_approval_pending` still 1 at 00:4x. The OTP step is owner-intrinsic by design (phone + hidden prompt or dashboard UI); nothing agent-side can finish it.
2. **Deploy of tonight's commits: still pending, now URGENT** — gen-997 still runs; the CAP_DAC_READ_SEARCH backup fix (`e4c785e5e`) and the overlay lift need a switch. First scheduled backup fire 03:29 (timesheets) / 03:58 (invoices) — without a deploy they repeat today's green-but-empty write.
3. **Backup first-fire verification: queued, not run** (clock-gated; TODO_LIST row carries the deploy-before-fire dependency).
4. **§f harvest: the standing backlog is queued; this report adds the SCA post-approval row** — library pairing in `docs/todo/services.md` (clean now; earlier tonight it was foreign-staged, which is why the 21-11 report recorded the pairing as deferred).
5. **21-11 report's 50-item list: unchanged as a backlog** — this report's §f supersedes ordering, not content, where items overlap.

## c) NOT STARTED

1. **SCA challenge-rate anomaly** — `bank_sync_sca_challenges_total` climbed 420 → 520 in ~3.5 h tonight (~28/h) while `errors_total` stayed 0 and cycles stayed green. Either sub-attempt counting (probe-per-balance-per-cycle inflates the number) or a genuine retry storm. Noticed during routine gauges; NOT investigated (scope directive). The 2026-09-30 note recorded "618 cumulative challenges" over ~2 months — tonight's rate is wildly off that baseline either way.
2. **`crm`'s private nixpkgs node intent** (`1d060086`, unfollowed from root) — carried from 21-11 §g.
3. Everything owner-gated from 21-11 §g (smoke-FAIL triage, re-float timing, patchelf upstream filing) — unchanged.
4. Standing queued arcs (cvagent deploy, CV push wave, llama-embeddings stranding, journal-import battery, rpi3 down, `/data/docker` reclaim, …) — untouched, correctly owned elsewhere.

## d) TOTALLY FUCKED UP

1. **I shipped a wrong owner-facing conclusion: "Bank-Sync recovered / the SCA challenge no longer surfaces in counters."** The probe grepped `bank_sync_sync*` — a pattern that structurally cannot match `bank_sync_sca_approval_pending`, which has been 1 all evening. The owner-facing §g answer ("likely moot") built on it. Two repo rules violated at once: *a "verified" label must cover every fact asserted*, and *assert WHICH question your evidence answers*. The owner's own failed `sca approve` — not my verification — surfaced it. Corrected inline in the 19-44 report + this report; the lesson cost is real: partial-scope probes presented as state claims.
2. **I fixed the gate-FP class at strike three instead of strike one.** The first "tonight's" FP froze all commits ~21:2x; the sibling fixed it AT THE CALL SITE (re-dating their row) — the doctrine says fix the SCANNER — and the class predictably recurred at ~22:4x and ~23:3x, freezing the tree twice more before I patched the scanner. Two additional tree-wide freezes were avoidable.
3. **I nearly filed a false finding into a permanent report** — the HM-mirror "split-brain" from a view that truncated mid-comment. Caught only because the report-writing pass re-opened the file past the truncation. A ghost finding in `docs/status/` would have sent a future session chasing a nonexistent bug.
4. **Commit serialization churn: four blocked attempts across the evening** (two index.lock races — one retried blind before checking for a live holder; three gate-FP freezes). Individually small, collectively ~40 minutes of wall-clock; the holder-check-first habit existed in doctrine and was applied late.
5. **(Carried from the earlier arc, still the biggest self-inflicted costs)** the root-node lock misread (the rule was in-context in the 19-32 report) and the `rg -rn` third strike.

## e) WHAT WE SHOULD IMPROVE

1. **Metric state claims require the whole metric family** — grep `^bank_sync_` (or `^<prefix>_`), never a sub-family, before writing "X is healthy/cleared". Tonight's blind spot was one underscore-segment wide.
2. **Service questions start at the service runbook** — `docs/services/bank-sync-sca.md` answered the "how" immediately; I drafted the first handoff from module comments alone and missed the stale path AND the sanctioned procedure ordering until I read it.
3. **Scanner FPs die at strike two** — one recurrence after a call-site fix is proof the class is scanner-shaped; patch the gate + selftest then, not after a third freeze.
4. **Shared-gate FPs on multi-session days are tree-wide outages** — the fix priority they deserve matches deploy-blocking gates, not lint nits. (The gate reads the working tree BY DESIGN — the scoping decision is queued, §f.)
5. **Truncated reads never become findings; partial greps never become state claims** — both bit tonight; both rules now have live cited examples.
6. Carried: root-resolve every lock read; holder-check-first on index.lock; 72-char subjects; manual eval backstop whenever the hook skips the flake leg.

## f) NEXT (up to 50 — session-scoped; supersedes ordering of the 21-11 list, which remains the backlog)

**Time-critical (before 03:29 tonight):**
1. **Deploy** — `e4c785e5e` (backup CAP fix) + the overlay lift must switch before the first backup fire or it repeats the green-but-empty write. Owner/sudo-gated; `nix run .#deploy`.
2. After deploy: re-verify anchor discipline (`readlink /run/current-system` == newest `system-N-link`) per the deploy-anchor procedure.
3. AM: verify first scheduled backup firings (journalctl + artifacts + quick_check) — queued row, now doubly gated on the deploy.

**SCA arc (this session's core):**
4. Owner runs the approval (dashboard `Approve now` primary; corrected CLI fallback in `bank-sync-sca.md`).
5. Post-approval verification (queued row this report): `sca_approval_pending` → 0, auto-sync fires, statements serve.
6. Investigate the challenge-rate anomaly (420→520 in ~3.5 h): journal challenge lines + per-cycle counting vs retry storm; compare post-approval rate.
7. Determine whether `challenges_total` is restart-reset (the 618-on-09-30 datapoint suggests yes) — one journal/DB probe, then document in the runbook.
8. The runbook path drift existed for weeks — sweep `docs/services/*.md` for other `/run/secrets/` paths vs actual render dirs (one grep, likely zero more hits).

**Gate/tooling (this session's second core):**
9. Decide the gate-scoping question: hard-FAIL legs keyed to the STAGED diff vs working-tree-global (three tree-wide freezes tonight; decision row material — §f.50 of 21-11).
10. Add a gate selftest leg for "tomorrow's" possessive staying flagged (future-by-construction) — the current fix exempts tonight/yesterday/today only; lock the asymmetry in.
11. Sweep TODO_LIST for any remaining retrospective-possessive rows the OLD scanner would have flagged (none known; one grep to be sure).
12. Consider a session-start `check-todo-system.sh --selftest` convention (queued already) so scanner regressions surface before they freeze commits.
13. The gate's `grep -v 'BLOCKED'` matches the word anywhere — a row quoting the marker convention in prose could false-pass; low priority, note only.

**Owner-gated (carried, evidence refreshed):**
14. Bank-Sync §g Q1 resolution — now strictly: run the ceremony (§b.1), then #5 verifies.
15. Triage order (or indefinite acceptance) for the 7 baseline smoke FAILs.
16. Re-float the nixpkgs+dnsblockd pair when tip moves past `f4a03c00` (tip re-confirmed unmoved at 21:1x) + patchelf upstream filing appetite.
17. `crm`'s private nixpkgs node intent (`1d060086`).

**Standing backlog (from 21-11 §f — not re-listed, still queued):**
18. Eval-relevance array: systematic derivation pass + selftest leg asserting coverage of every flake-imported dir (#6/#7 there; `systems` + `overlays` landed tonight via `2ce82515e`/`632cfb1e3`).
19. Adopt the shared array as §11's tree-stamp source (existing row).
20. TODO-gate 84-DRIFT baseline hardness decision.
21. Harvest pass for the now-21 unharvested §f reports (docs-health HARVEST).
22. pipewire `jack.enable` deprecation cleanup.
23. Caddy ghost subdomains `nsfw`/`llama` reconciliation.
24. cvagent dashboard deploy + live battery (owner go).
25. CV push wave (blocked:push).
26. llama-embeddings stranding recovery.
27. journal-import auto-sync post-deploy battery (blocked:deploy).
28. rpi3 (.151) down — LAN DNS failed over (blocked:user).
29. `/data/docker` volumes-only tar + trash (sudo execution).
30. go-humanize-linter vendorHash re-stale probe.
31. tq agent-pool lease extension.
32. Per-commit footer verification habit (queued; tonight's races add evidence).
33. `bank-sync sca status` after approval — `OK` per balance confirmation (the ONLY sanctioned token-value surface; runbook-corrected).
34. Watch the RFC3339 `statement_coverage` writer question post-approval (runbook watch: if it returns, goroutine dump).
35. Confirm the weekly canary's behavior post-approval (Sunday 00:00+jitter — should go green with statements serving).
36. Reconcile the two backup-verification rows' tags into one convention.
37. Reconcile elapse-time discrepancy (03:20/03:50 vs measured 03:29/03:58 — OnCalendar/RandomizedDelaySec read).
38. `indexer-web` ioTier + VM regression rows (services.md, queued).
39. ci-watchdog timer activation row (services.md, blocked:deploy).
40. bank-sync sentinel go-live residual verification row (services.md — check overlap with #5 before dispatching; the new post-approval row may subsume it).
41. quotaboard CI workflow.
42. buildcatrust upstream filing + rpi3 confirmation probe.
43. netbird multi-host parameterization.
44. 192.168.1.16 rogue-DHCP identification.
45. hermes tracing approach decision.
46. fastflowlm alert-firing verification.
47. Guard stateDir persistence audit.
48. CV login-loop test pinning + stored-logins signal.
49. Email forwarding verify (applications@artmann.tech), sibling-corrected tonight.
50. ROADMAP fuel from 21-11 §e: holder-check-first protocol, root-resolve rule into nix-flakes.md, row-drafting micro-checklist, "truncated read ≠ finding" micro-rule.

## g) QUESTIONS FOR THE OWNER (cannot self-answer)

1. **Have you run the SCA approval yet** (dashboard `Approve now`, or the corrected CLI line)? If yes, I verify the pending gauge flipped and statements serve; if the dashboard shows NO banner while the gauge reads 1, that mismatch is itself the next bug.
2. **Deploy tonight?** The backup CAP fix + overlay lift are committed but gen-997 still runs; the first backup fire is 03:29 (~2h40m). Deploy now (`nix run .#deploy`), or accept one more empty write + morning deploy + re-verify?
3. **Is ~28 SCA challenges/hour on your Wise account plausible** (multi-balance statement probing under the degraded fallback), or should the 420→520 jump be treated as a retry storm worth investigating tonight? You know the account shape (balances, statement cadence); I only see the counter.
