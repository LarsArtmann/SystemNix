# Browser-History Zero-Dashboard Fix Session — Status Report

**Date:** 2026-10-07 02:39 CEST
**Session focus:** `https://history.home.lan/` shows ALL ZEROS — find and resolve all root causes.
**Status at report time:** root cause fully identified and evidence-verified; fixed binary is ON DISK but the RUNNING server process is still the UNFIXED binary. **One service restart + one re-login remain.**

---

## Executive Summary

The dashboard renders zeros because the OAuth login resolves to a duplicate user row that owns zero visits, while all visit data sits under the original user. The upstream fix (cqrs-htmx `796ed4f5`, keep-first identity lookups, Oct 4 12:04) is correct (regression test passes, re-run this session) but **never reached the running binary**: the deployed `browser-history-server-68d0b6d` pins cqrs-htmx at `2853fb3a` (Oct 4 06:01 — six hours BEFORE the fix). The current SystemNix tree carries the fix (browser-history `3ebbfbf` → cqrs-htmx `11f75a73`), the fixed binary `browser-history-server-3ebbfbf` is built in the store, and `/etc/systemd/system/browser-history.service` already points at it — but the running process (pid 512961, started 01:51:21) predates every activation and still serves the old binary. The user's own `nh os switch` at 02:36 succeeded but correctly did NOT restart browser-history (unit file had no diff between `s31cl42n` and `vi223xl9`).

**The remaining fix is 10 seconds: `sudo systemctl restart browser-history.service` → log out → log in.**

---

## Root-Cause Chain (all evidence-verified this session)

1. **Duplicate-identity split (from 2026-10-04 report, confirmed live):** 9 user rows share `lars@larsartmann.cloud` + pocket-id subject `88bec46e…`. Newest-wins lookups point every login at `01M2X007JZB9Y1WDYF35AD5GSD` (Sep 19, 0 visits) while 1018 visits + the `agent_tokens` owner sit under original `01M000JA6P0VR4Q1BNEPSJN3ME` (Aug 14). Plus 3179 orphaned `user_id=000…0` rows from the v1 anonymous-token era. Source: Oct 6 pool backup (`browser-history-db-2026-10-06.sqlite`).
2. **The fix is real but was never deployed:** cqrs-htmx `796ed4f5` (keep-first on email map, subject map, live + hydrate paths, tombstone skip; `duplicate_identity_test.go` covers all three) — test re-run this session: `ok github.com/larsartmann/cqrs-htmx/usermgmt/v4`.
   - Note: commit `492e473e` (referenced in the service runbook) is an ORPHANED pre-rebase duplicate; the landed commit is `796ed4f5`, already on origin/master. Runbook citation should be corrected.
3. **Deployed binary predates the fix:** browser-history@`68d0b6d` (Oct 6 15:33) pins cqrs-htmx `?rev=2853fb3a` (Oct 4 06:01). `go version -m` on the running binary shows `usermgmt/v4 v4.14.1 => ./_local_deps/cqrs-htmx/usermgmt` — **the version label is misleading: the `_local_deps` replacement sources usermgmt from the flake-pinned rev (2853fb3a, pre-fix), not from the proxy.** A "v4.14.1" build-info line does NOT mean fixed code when a replace is active.
4. **Journal proof of the symptom:** 01:27:05 tonight, OAuth callback on pid 862342 (gen-828 binary, unfixed) resolved `user_id=01M2X007…`; no `oauth_login` audit event visible; dashboard session stayed on the zero-visit user. That is the "STILL!!!" the user saw.
5. **Deployment gap:** SystemNix lock = browser-history `3ebbfbf` (transcluded lock → cqrs-htmx `11f75a73`, contains fix). No system generation exists after gen 828 (Oct 6 16:49) until tonight's switches. At 02:01:14 another session's deploy updated `/run/current-system` (→ `s31cl42n`, carrying the 3ebbfbf unit) **but died before restarting any services, and left NO profile generation** (profile still `system-828-link` — anomaly, see open questions). Result: unit file updated on disk, process stale.

## Deployment Attempts This Session (what blocked them)

| Attempt | Result |
| --- | --- |
| `nix run .#deploy` #1 (~02:00) | Blocked: deploy lock held by other session (PID 966623). That deploy then died mid-flight (post-activation, pre-restart). |
| `nix run .#deploy` #2 (~02:20) | Aborted at pre-deploy PSI gate: I/O some avg10 = 43.7% + disk busy 101% (crash-#3 precursor class). |
| PSI poll loop | Drained to 15.2% once, then re-spiked (54.4%) → attempt #3 aborted at the gate. |
| `nix run .#deploy` #3 (~02:29) | Aborted at PSI gate again. Storm source: concurrent session's go-cqrs-lite test suite (`metaengine.test`, `duckdbengine.test`, 30m timeouts) + parallel nix builds/checks. |
| User's own `nh os switch` (~02:35, from paste) | SUCCESS in 55s → `vi223xl9` live. Did NOT restart browser-history (no unit diff vs `s31cl42n` — correct switch behavior, both closures carry the 3ebbfbf unit). |

**Live state at 02:39:** pid 512961 (since 01:51:21) still runs `browser-history-server-68d0b6d` (UNFIXED). Unit on disk = `3ebbfbf` (FIXED). Gap = one restart.

---

## a) FULLY DONE

- **Root-cause diagnosis, evidence-first:** identified the duplicate-identity split, the pre-fix deployed binary, the exact journal line of the failed login resolution, and the misleading `go version -m` replace trap.
- **Fix verification (pre-deploy):** cqrs-htmx `duplicate_identity_test.go` passes on the fix commit; confirmed `796ed4f5` ∈ origin/master; confirmed fix ∈ pinned rev `11f75a73` and ∈ published tags `usermgmt/v4.14.0` + `v4.14.1`; confirmed SystemNix lock chain pins `11f75a73`.
- **Ingest-pipeline health check:** agent runs every 5 min, healthy; bh_ token attribution works (351 visits on Oct 5; token last_used Oct 6 00:12). Data IS flowing — the zero dashboard is purely the identity resolution.
- **Flake eval validation:** `nix flake check --no-build` — all checks passed (aarch64-darwin omission expected).
- **Secondary findings documented** (below) instead of silently ignored.
- Live-state forensics: generation/binary/journal timeline reconstructed and cross-checked.

## b) PARTIALLY DONE

- **The fix deployment itself:** binary built, unit updated, closures activated — but the running process is still unfixed. Missing: one `systemctl restart browser-history` + user re-login + post-restart verification (hydration keep-first on live server, login resolves `01M000JA6…`, dashboard non-zero).
- **Status-surface updates:** this report exists; the service runbook (`docs/services/browser-history.md`) correction (orphan SHA `492e473e` → landed `796ed4f5`; replace-trap gotcha) is NOT yet written.
- **TODO harvesting:** none of this session's follow-ups are queued in `TODO_LIST.md` / `docs/todo/` yet (deliberately deferred to avoid mid-storm tree edits; the tree was owned by another session's deploy).

## c) NOT STARTED

- SQLITE_READONLY(8) root-cause hunt (reaper + heartbeat writes fail ~5 min after SOME starts; ingest writes fine; ownership-heal prestart does not prevent recurrence).
- Firefox extraction `raw=0` investigation (agent scans profile `default` = the `opwirq8n.default` stub; the REAL profile `ddkwwxjq.default-1777612573309` with a 5 MB places.sqlite last modified Sep 30 never appears in agent logs).
- Helium noise-filter yield audit: tonight's windows show `raw=5 → filtered_out=5 → kept=0` every run (extension pages, OIDC callback chains, <5s dashboard visits all rejected); the Helium DB holds 5864 visits vs 1018 attributed server-side overall.
- Orphan re-attribution decision for the 3179 `user_id=000…0` rows (the documented `--full-sync` backfill re-stamps them).
- Post-fix data-freshness verification (does the dashboard show recent days after re-login).

## d) TOTALLY FUCKED UP (this session's honest misses)

- **Wrong starting assumption.** I began from the runbook's "deploy pending (2026-10-04)" and spent the first long stretch reconstructing the deploy ladder (push/tag/bump) — when 2 minutes of `go version -m` + `readlink /proc/<pid>/exe` on the RUNNING binary would have shown the real state: fix committed+pushed, binary stale. Verify the deployed surface first, the paperwork second.
- **Missed the 10-second fix while it was available.** After discovering the 02:01 half-activation (unit on disk updated, process stale), the correct move was to immediately tell the user: "restart browser-history now." Instead I re-entered the deploy pipeline and burned ~30 minutes being blocked by the PSI gate (twice) fighting for a full-deploy path to obtain a restart that a single command would have delivered.
- **Contributed to the storm I then had to wait out.** My `nix flake check --no-build` plus repeated deploy pre-stages added load on top of the other session's test suite before the gate started bouncing me.
- **Never verified whether the `usermgmt/v4.14.0` / `v4.14.1` TAGS are pushed to origin.** If they are local-only, the Go module proxy cannot serve them and the nightly `go-deps-audit` (and any non-flake consumer resolving go.sum via proxy) will fail even though flake builds work via `_local_deps`.
- **Left an anomaly unexplained:** 02:01:14 `/run/current-system` changed with NO profile generation created (still `system-828-link`) and no service restarts — this looks like a manual `switch-to-configuration` invocation, which AGENTS.md forbids (no profile generation, skips deploy.sh post-switch steps — exactly the half-state that bit us). Not flagged to the user in the moment.
- **Orphan commit hygiene:** `492e473e` (pre-rebase duplicate of the fix) dangles in the cqrs-htmx repo while the runbook cites it — a citation of an unreachable object. Caught late.

## e) WHAT WE SHOULD IMPROVE

- **Deploy gap detector:** post-deploy (and post-ANY activation) verification should assert process↔unit agreement (`readlink /proc/<pid>/exe` vs unit ExecStart) for restarted-critical services, not just "activation exit 0". Tonight a deploy died between activate and restart and nothing noticed for 40 minutes.
- **`go version -m` replace-trap awareness:** a build-info version label says nothing when a `=> _local_deps` replace is active. The real provenance is the flake-pinned rev. Worth a gotcha in `docs/agents/go-ecosystem.md` and/or a check that diffs the pinned input rev vs the fix commit when chasing "is fix X deployed".
- **PSI gate vs multi-agent reality:** the gate is right (crash-precursor), but when the storm is ANOTHER session's test suite, the deploy is blocked indefinitely with no coordination. Needs a decision: cross-session load arbitration, or user pre-authorization for force.
- **Runbook claim freshness:** "deploy pending" notes must carry the locked rev they refer to, so the next session can diff against the live binary instead of re-deriving the whole ladder.
- **Session discipline:** this session ran 3 concurrent agents (SystemNix deploy race, go-cqrs-lite test storm, this one). The lock conflict and PSI contention were both foreseeable; heavier ops (deploy) should check for sibling-session activity first.

## f) NEXT (prioritized; ~30 items)

**Close out the fix (P0)**
1. `sudo systemctl restart browser-history.service` (or re-run `nix run .#deploy` when PSI allows — deploy.sh explicitly restarts it).
2. Verify post-restart: process = `browser-history-server-3ebbfbf`, hydration logs clean, no readonly in first 10 min.
3. User: log out + log in at history.home.lan; confirm login resolves `01M000JA6…` (journal `user_id` on `/login` 302) and the dashboard shows the 1018 visits.
4. Verify no NEW duplicate user row was created by tonight's logins (users_view count still 9).
5. Update runbook `docs/services/browser-history.md`: landed SHA is `796ed4f5` (not `492e473e`), mark the fix DEPLOYED with the generation/binary revs, add the `_local_deps` replace-trap gotcha.
6. Harvest follow-ups into `TODO_LIST.md` + `docs/todo/` (readonly bug, firefox extraction, filter yield, orphan rows) per the queue rules.
7. Commit this status report.

**Verify integrity (P0.5)**
8. Check whether `usermgmt/v4.14.0` / `v4.14.1` tags are pushed; push if local-only (proxy availability for CI/nightly go-deps-audit).
9. Resolve SystemNix "ahead of origin by 1 commit" (the lock commit) — push after verification.
10. Explain (or at least record) the 02:01 activation-without-generation anomaly; check for other half-activated units from the dead deploy (`systemctl list-units --state=failed`, compare /etc vs profile).

**SQLITE_READONLY(8) class (P1)**
11. Root-cause why reaper+heartbeat writes go readonly ~5 min after SOME starts while ingest writes succeed (different handle/DSN? WAL checkpoint interplay? uid drift mid-boot?).
12. Decide: extend ownership-heal, periodic re-heal, or upstream fix; add a Gatus check that alerts on the journal signature.
13. Re-check the AGENT_FRESHNESS health component interaction with the readonly reaper (freshness writes could also silently fail).

**Agent pipeline data completeness (P1)**
14. Firefox `raw=0`: dump `discoverFirefoxProfiles()` behavior against this profiles.ini (two profiles, name `default` vs `default-1777612573309`); confirm which DB the agent opens; fix discovery or document.
15. Helium filter-yield audit: for a sample day, classify every visit by skip reason (`popup_or_redirect`, `hidden`, `reload`, `gibberish`, `extension_id`, `randomized_path`); quantify how much real browsing the filter eats.
16. Decide filter policy: e.g. TYPED+LINK visits under 5s should probably not be dropped as popups; or emit per-reason counters server-side so the dashboard can show "N noise dropped".
17. Consider per-reason extraction counters in the agent log (currently only `filtered_out` total).
18. The cursor semantics: kept=0 blocks cursor advance (correct for losslessness, but combined with aggressive filtering it can stall windows for hours — verify with data).

**Orphan data (P2)**
19. Decide on re-attributing the 3179 `user_id=000…0` visits via the documented `--full-sync` backfill (deterministic IDs, INSERT OR REPLACE — safe) vs leaving them invisible.
20. After any backfill, verify domain/leaderboard stats reflect the merged history.

**Monitoring (P2)**
21. Gatus check or SigNoz rule: alert when `browser-history` journal shows `readonly` (any) — it currently self-heals silently and nobody knows data writes are being lost (heartbeat records).
22. Alert when the RUNNING binary rev ≠ the unit's ExecStart rev (deploy-gap detector from §e).
23. Agent-activity metric already exists — confirm it stayed green through tonight (it should: ingest worked).

**Upstream/cross-repo hygiene (P2)**
24. cqrs-htmx: garbage-collect the orphaned `492e473e` object concern (it is unreachable; a future gc drops it — just fix the runbook citation).
25. browser-history: the deps sweep bumped go.mod to v4.14.1 while the flake pin controls the actual code — document the "pin wins over go.mod" invariant in the repo's AGENTS.md.
26. Consider a browser-history test that asserts the BUILT binary's effective usermgmt contains keep-first (e.g. a tiny runtime probe or a nix check comparing pinned rev ancestry), so "fixed" claims are testable at the artifact level.
27. Nightly `go-deps-audit` pass after tag push (verify no proxy drift).

**Docs/knowledge (P3)**
28. Add the replace-trap + "verify the running binary first" lesson to `docs/agents/go-ecosystem.md` (or global lessons if it generalizes).
29. Record the multi-session deploy-race lesson (lock conflict → dead deploy → half-activation) in `docs/CONTRIBUTING.md` daemon-race policy if not covered.
30. This report's §d/e items triaged into the improvement backlog.

## g) Questions for Lars (cannot self-answer)

1. **The 02:01:14 activation created no profile generation and restarted nothing.** Did you (or a session you know of) run a manual `switch-to-configuration` around then? I need to know whether this was a human action (fine, but then the profile is now diverged: `system-828-link` is stale and your 02:36 switch re-created a proper generation) or a tool bug worth hunting. If it matters: `sudo nix-env --profile /nix/var/nix/profiles/system --list-generations` vs `/run/current-system` is the check.
2. **Should the 3179 orphaned `user_id=000…0` visits be re-attributed to your user** via the documented `--full-sync` agent backfill (they'd finally appear in the dashboard), or do you consider the v1-era data disposable?
3. **PSI-gate policy for future deploys:** when the gate blocks because ANOTHER session's workload is storming the disk, do you want (a) always wait/report like tonight, (b) pre-authorization for `DEPLOY_FORCE_PRESSURE=1` after N minutes of waiting, or (c) a coordination convention (e.g. deploys claim a lock file the other sessions respect before launching test suites)?

---

## Appendix: Evidence Pointers (short-form revs; full via `git rev-parse <short>`)

- Fix commit (landed, pushed): cqrs-htmx `796ed4f5` — `usermgmt/es_readmodel.go`, `usermgmt/sql_hydrate.go`, `usermgmt/duplicate_identity_test.go`.
- Orphan citation to correct: `492e473e` (pre-rebase duplicate, unreachable from refs).
- Deployed binary (RUNNING, unfixed): `/nix/store/drqz5p2…-browser-history-server-68d0b6d` — pins cqrs-htmx `2853fb3a` (Oct 4 06:01, pre-fix).
- Fixed binary (on disk, not yet running): `/nix/store/…-browser-history-server-3ebbfbf` — tree pins cqrs-htmx `11f75a73` (contains fix).
- Failed-login journal line: Oct 7 01:27:05, pid 862342, `GET /auth/oauth/pocket-id/callback 302 user_id=01M2X007JZB9Y1WDYF35AD5GSD`.
- Data ownership (Oct 6 backup): visits by user — `000…0`×3179 (orphan), `01M000JA6…`×1018 (owner); agent token `01M1QPZT…` → `01M000JA6…`.
- Readonly journal signatures: Oct 7 01:25:41 (pid 862342, heartbeat + reaper), Oct 7 01:56:21 (pid 512961, reaper).
- Lock chain: SystemNix `flake.lock` → browser-history `3ebbfbf` → cqrs-htmx `11f75a73`; generations: 827/828 = `68d0b6d` era; user's 02:36 switch → `vi223xl9` (no browser-history unit diff vs `s31cl42n`).
