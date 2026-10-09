# Browser-History Zero-Fix VERIFIED + Lockout Resolution — Session Report #2

**Date:** 2026-10-07 03:02 CEST
**Covers:** 02:39 → 03:02 (delta over [the 02:39 report](./2026-10-07_02-39_browser-history-zero-dashboard-fix-session.md), which holds the full root-cause chain)
**Headline:** The duplicate-identity fix is **DEPLOYED AND PROVEN LIVE** — the 02:49:03 OAuth login resolved to the data owner `01M000JA6…`. The readonly lockout cleared on restart (0 readonly errors in the new process, ingest accepting again). And the night's context exploded: the box crashed AGAIN at 02:49:28 (**freeze #24**, IO-livelock class — separate autopsy: [freeze-24 report](./2026-10-07_02-59_freeze-24-live-autopsy-io-livelock-pinned-guard-ineffective.md)).

---

## Timeline of this window (all journal-verified)

| Time         | Event                                                                                                                                                                                                                                                                      |
| ------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 02:39–02:46  | Old pid 512961 (unfixed binary) still serving; 4 more readonly errors (reaper + heartbeat) — user locked out, `create_session` fails readonly on every login attempt                                                                                                       |
| 02:48:57–58  | **User restarted browser-history** → pid 3015803 running the FIXED binary `browser-history-server-3ebbfbf`                                                                                                                                                                 |
| **02:49:03** | **`oauth_login` audit event: `user_id=01M000JA6P0VR4Q1BNEPSJN3ME`** — login resolved to the ORIGINAL data owner. Keep-first fix works in production. User saw their dashboard.                                                                                             |
| 02:49:28     | **FREEZE #24** — machine dies 25 s after the successful login. IO-livelock class (PSI avg60 ≈ 60%, disk 99.9%, memory healthy). 4th crash tonight (#21 00:00, #22 00:58, #23 01:28, #24 02:49).                                                                            |
| 02:51:56     | Recovery boot auto-starts browser-history (pid 9360, same fixed binary)                                                                                                                                                                                                    |
| 02:52:11+    | Ingest flowing: `accepted=1` at 02:57:10; **0 readonly errors** in pid 9360 — the restart also cleared the write wedge                                                                                                                                                     |
| 02:52:14     | "session authentication failed / authentication required" DEBUG lines — the user's fresh session from 02:49:03 likely did not survive crash #24 (session INSERT written 25 s before death; WAL not necessarily checkpointed) → **user probably needs to log in once more** |

---

## a) FULLY DONE

- **The original complaint is resolved and evidence-verified:** login resolves to the data owner (`01M000JA6…`, 1018 attributed visits); the fixed binary (`3ebbfbf`, cqrs-htmx `11f75a73` keep-first) is the running one across two restarts. The 02:49:03 `oauth_login` audit line is the proof — the exact event that was MISSING in the failed 01:27 attempt.
- **The readonly lockout diagnosed and cleared:** the wedged process (512961) could not write sessions/heartbeats/reaper since ~01:51 despite perfect uid/permission match; restart produced a fully healthy writer (0 readonly since 02:49, ingest `accepted=1` at 02:57). Root-cause chain for the lockout handed to the user within one exchange.
- **The nh/nix "why no restart" question answered precisely:** restarts are diff-based against `/run/current-system`; the dead 02:01 half-activation poisoned the baseline; NixOS has no runtime-drift detection — and a concrete mitigation was designed (see `#drift-check` proposal in the conversation, backlog item below).
- **"Is there a nix doctor" answered:** no stock tool covers running-process-vs-unit drift or current-system-vs-profile divergence; gap mapped against `nix doctor`, `nix-store --verify`, `systemd-analyze verify`, `systemd-delta`, `systemctl --failed`.
- **Cross-session context integrated:** located and read the concurrent session's freeze-24 autopsy + the 02:45 deploy-storm report; my PSI-gate deploy blocks and the crash loop are now one coherent story, not two mysteries.
- Earlier session's full root-cause chain, evidence appendix, and improvement backlog (02:39 report) — all still standing, fix claims now upgraded from "pending" to "verified".

## b) PARTIALLY DONE

- **Final user-visible verification:** the fix is proven at the protocol level (oauth_login → data owner), but whether the user's CURRENT browser session works post-crash-#24 (or needs one more login) is unconfirmed from here; and the dashboard's date-range completeness (data through Oct 5/6 vs today) depends on the still-open agent-filter gaps.
- **The readonly "some starts wedge" class:** cleared in the new process, but the ROOT CAUSE of why pid 512961 went write-dead while 14915 wrote fine (same uid, same files, 3 min apart) is still unknown — the class can recur on a future start.
- **The PSI/deploy interplay:** the pre-deploy gate that blocked my deploys twice was in fact watching a REAL crash class (freeze #24, IO-livelock) — correct behavior, but the gate blocked ~50 min while offering no path for a near-zero-load service restart. No policy resolution yet.
- **Report hygiene:** my 02:39 report was auto-committed by the daemon (good), but its §g questions were never answered (superseded by events); its runbook-correction items (orphan SHA `492e473e` → `796ed4f5`, `_local_deps` replace-trap gotcha) remain unwritten.

## c) NOT STARTED

- **Drift-check tooling** (`nix run .#drift-check`): process-exe vs unit-ExecStart comparison, current-system vs profile-generation check, post-activation journal signature scan — designed in conversation, zero code written (awaiting go-ahead).
- **Agent extraction data completeness** (unchanged from 02:39 report, still open): Firefox `raw=0` (real profile never scanned), Helium noise-filter rejecting ~100% of fresh visits tonight, per-reason filter counters, cursor-stall semantics.
- **Orphan re-attribution** of the 3179 `user_id=000…0` visits; `usermgmt/v4.14.x` tag-push verification; TODO harvest of this session's follow-ups; runbook updates.
- **IO-livelock response improvements** — owned by the freeze-24 autopsy track (guard action ineffective for this class; storm re-arms in recovery boot); my session only contributes the observation that the deploy PSI gate and this crash class are the same storm.

## d) TOTALLY FUCKED UP (this window's honest misses)

- **I saw crash #23's evidence at 02:41 and did not flag it.** While diagnosing the lockout I read the kernel log: boot at 01:29:47 with `start tree-log replay` (dirty shutdown!) — I registered it only as "explains the restart churn" and moved on. That was crash #23 of an active crash LOOP, sitting inside the very window I was reporting on. The user should have heard "your machine hard-crashed at 01:28" from me at 02:41, not discovered it via another session's autopsy at 02:59.
- **I framed the PSI storms as "the other session's test suite"** — partially true, but the deeper truth (a repeating crash→cold-cache→livelock→crash loop that killed the box 25 s after the user's login) was visible in my own timeline (01:29 boot, 02:49 gap) and I didn't connect it. My deploy-gate frustration report under-sold a live stability incident.
- **My 02:39 handoff did not anticipate the lockout consequence.** I said "restart then log in" — correct — but the user executed logout FIRST and hit the readonly wall on a server I KNEW couldn't write sessions. I should have led with "the server currently cannot create sessions at all; until it is restarted NO login can succeed" instead of burying that in paragraph three.
- **Still no proactive verification of the `usermgmt/v4.14.x` tag push state** (carried over from the 02:39 report — second miss).
- **The 503 /health freshness state** (degraded because heartbeat recording failed) went unmentioned in the lockout response — the user may have also seen the service "unhealthy" in monitoring without an explanation from me.

## e) WHAT WE SHOULD IMPROVE

- **Say the outage plainly, first.** When a service cannot perform its core write path, lead with "you are locked out until X" — not with the investigation narrative.
- **Cross-session incident correlation.** Four crashes, three agent sessions, two deploy attempts, one lockout — each session saw a slice. A shared "tonight's incidents" surface (even just the status dir + a naming convention) would have let me cite freeze-#23 within minutes instead of missing it.
- **Restart-vs-drift tooling** (the drift-check from the conversation): tonight produced TWO independent proofs that diff-based restart logic + dead deploys = stale processes.
- **The readonly-wedge class needs a probe:** a post-start self-check that performs a trivial write (or checks `-wal` creation) and screams into the journal/monitoring if the DB is write-dead — tonight that state persisted 58 minutes silently (01:51–02:48) with only 503s as a symptom.
- **Gate policy for outages vs storms:** when the box is in a crash loop, "wait for PSI to drain" and "the service is down" need an explicit priority rule. (Freeze-24 track owns the storm; my track needs a documented "service-down overrides pressure gate for non-build actions" path.)

## f) NEXT (consolidated; carried + new)

**P0 — close the user-facing loop**

1. User: log in once more (crash #24 likely ate the 02:49 session) — confirm dashboard shows Aug 14 → Oct 5 data.
2. Verify no NEW duplicate user was created by tonight's four login attempts (users_view count still 9).
3. Gatus/health state: confirm /health returns 200 now that heartbeat recording works (freshness heals on next agent tick).
4. Runbook `docs/services/browser-history.md`: fix landed-SHA citation (`492e473e` → `796ed4f5`), mark fix DEPLOYED+VERIFIED with binary rev `3ebbfbf`, add the replace-trap and readonly-wedge gotchas.
5. Harvest follow-ups into `TODO_LIST.md` + `docs/todo/` (readonly-wedge class, Firefox extraction, filter yield, orphan rows, tag-push check).
6. Commit this report.

**P0.5 — stability coordination (overlaps freeze-24 track)**
7. Decide deploy/build freeze while the crash loop is unconfirmed-over (4 crashes tonight; storm re-arms in ~6 min post-boot).
8. Build the `drift-check` app (process-exe vs unit ExecStart; current-system vs profile gen; post-activation journal scan) and wire into deploy.sh post-switch.
9. Post-start write-probe for browser-history (or generic hardened DB services): trivial write at start + alert on readonly — the 58-minute silent write-death must not recur silently.
10. Reconcile the profile-generation divergence record: gen 829 was created by a raw `nh os switch` bypassing deploy.sh (per 02:45 report) — document whether that is sanctioned for interactive use.

**P1 — browser-history correctness**
11. Root-cause the readonly-wedge onset (why 512961 went write-dead; 14915 wrote fine): capture `sudo ls -la /var/lib/private/browser-history` + `/proc/<pid>/fd` next time it happens; consider strace during a planned restart.
12. Firefox extraction `raw=0`: profile discovery vs this profiles.ini (two profiles; agent scans the stub).
13. Helium filter-yield audit (tonight: raw=5 → filtered 5 → kept=0 repeatedly) + per-reason counters.
14. Decide orphan re-attribution for 3179 `user_id=000…0` visits (documented `--full-sync` path).
15. Verify `usermgmt/v4.14.0`/`v4.14.1` tags are pushed (proxy availability for CI/nightly go-deps-audit) — second reminder.
16. AGENT_FRESHNESS interplay: freshness armed at start + heartbeat writes failing = permanent 503; consider freshness signal independent of the wedged write path.

**P2 — hygiene**
17. cqrs-htmx orphan commit `492e473e` cleanup note; browser-history AGENTS.md "flake pin wins over go.mod" invariant.
18. Artifact-level fix assertion (nix check: pinned cqrs-htmx rev ancestry or runtime probe) so "fixed" is testable on the binary, not inferred from build-info version labels.
19. Session handoffs: adopt "one incident index file per night" for multi-agent nights (tonight had ≥3 overlapping incident reports).

## g) Questions for Lars (cannot self-answer)

1. **Dashboard confirmation:** after one more login (crash #24 probably invalidated the 02:49 session) — does history.home.lan now show your history with roughly the expected range (Aug 14 → Oct 5)? This is the only acceptance test I cannot run myself.
2. **Deploy/build moratorium:** with 4 crashes tonight and the storm re-arming in recovery boots, do you want a hard freeze on deploys and heavy builds (including mine) until the freeze-24 track declares the IO-livelock handled — or per-action judgment with the PSI gate?
3. **Drift-check go-ahead:** shall I build `nix run .#drift-check` now (pure reads, ~4 assertions, wired into deploy.sh post-switch), or park it behind the stability work?

---

## Evidence pointers (short-form revs)

- Fix live: 02:49:03 `oauth_login user_id=01M000JA6P0VR4Q1BNEPSJN3ME` (pid 3015803, binary `browser-history-server-3ebbfbf`).
- Readonly window: pid 512961 only — 4 errors 02:41–02:46, ZERO in pid 9360 since 02:51:56; ingest `accepted=1` 02:57:10.
- Crash #24: death 02:49:28, recovery boot 02:51:56; class + guard analysis in the freeze-24 autopsy (concurrent session, 02:59).
- Prior chain (root cause, deploy ladder, store-path forensics): [02:39 report](./2026-10-07_02-39_browser-history-zero-dashboard-fix-session.md).
