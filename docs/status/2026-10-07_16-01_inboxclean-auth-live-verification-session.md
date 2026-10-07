# Status Report — InboxClean Auth Live-Verification Session

**Date:** 2026-10-07 16:01 CEST
**Session scope:** One user question — "InboxClean auth is all good?" — answered via live-state
verification on evo-x2 (journal reads, HTTP probe, process/store-path inspection). **Read-only
session: zero file edits, zero commits, zero deploys by this session.**
**Report scope discipline:** per owner instruction, no unrelated research — every item below
traces to this session's observations or to queue rows this session directly touched.

---

## TL;DR

**InboxClean auth IS all good right now — both Gmail grants (`main`, `work`) are live and
syncing.** But three adjacent reds were observed and are NOT auth failures: (1) `/health`
answers 503 `{"status":"timeout"}` — the known handler-budget class, still red in prod after
today's deploy; (2) 3 sync ticks today exited 75/TEMPFAIL on transient IO (`query sync_state:
context deadline exceeded`), each recovered on the next tick; (3) a HARD DEADLINE exists:
`main`'s grant was re-consented 2026-10-04 07:45 — if the Google OAuth client is still in
Testing mode, the 7-day bomb fires **~2026-10-11 07:45**.

**New fact discovered:** the vendorHash-wave switch HAS ALREADY RUN — current-system
(`a7868a7`, containing `inboxclean-b514bda`) activated **2026-10-07 12:20:58**. This de-stales
the "switch pending" premise in `docs/status/2026-10-07_12-17_vendorhash-wave3-fod-unblock.md`
and `docs/todo/monitoring.md`'s post-deploy-check row.

---

## a) FULLY DONE

1. **Live auth verdict delivered: both grants PROVEN working** (the question asked, answered
   with ground truth, not doc claims).
   - Evidence: sync tick **2026-10-07 15:15:46** fully green — `main` cursor → **37278006**
     (7 new messages pulled, Paperless archiving ran: 7 scanned / 0 uploaded, corpus considered
     7 / stored 7); `work` cursor → **5269550** (clean tick, 0 new); unit "Deactivated
     successfully".
   - **Zero** `invalid_grant` / `token_revoked` lines in the 48h journal window for both units.
   - Cursor movement is the strongest possible grant-alive proof (it requires successful Google
     API auth on every tick).
2. **Deployed binary identified: the new build is LIVE.** Running processes execute
   `/nix/store/zpvarm079nf8mrzx87i0wr8avwhjaw15-inboxclean-b514bda/bin/inboxclean` (web + sync);
   `/run/current-system` = `nixos-system-evo-x2-26.11.20261003.a7868a7`, activated
   **2026-10-07 12:20:58**. ⇒ The 2026-10-07 12:17 report's §b.1 open item ("the switch
   itself — owner go") is **resolved: the switch landed at 12:20:58**, ~4 minutes after that
   report was written.
3. **`/health` failure classified, not misread:** HTTP probe returned **503 with body
   `{"status":"timeout"}`** — exactly the signature documented in
   `docs/services/inboxclean.md` (2026-10-06 handler-budget incident). Correctly NOT reported
   as an auth failure or app outage; sync ticks are the auth ground truth, `/health` redness is
   a separate known class.
4. **All 6 TEMPFAIL ticks in 48h classified as transient-IO, not auth:** 75 successful vs 6
   failed ticks (Oct 05 23:51, Oct 06 00:21, 00:51, Oct 07 12:20, 13:50, 14:50). Failure body:
   `account "work": load sync state: query sync_state: context deadline exceeded
   family=transient code="" retryable=true exit_code=75`. Every failure was recovered by the
   next tick. Exit 75/TEMPFAIL is the correct honest signal for this class.

## b) PARTIALLY DONE

1. **`/health` redness root-classification is incomplete.**
   - Works: 503 body captured; matches the known timeout class; deployed rev identified
     (`b514bda`).
   - Open: whether the 8s-budget fix (upstream `c4d62a3`, pushed 2026-10-06) is an ancestor of
     deployed `b514bda` is **UNVERIFIED** — the local `~/projects/InboxClean` checkout does not
     know rev `b514bda` (`fatal: Not a valid object name b514bda`), so the ancestry check died
     locally.
   - Blocker: local checkout staleness; remote (GitHub API) check not attempted (session was
     scope-limited to the auth question).
   - Effort to finish: S (one `gh api repos/LarsArtmann/InboxClean/compare...` call, or simpler:
     time-to-503 measurement — see §e.2).
2. **Post-deploy verification chain is half-open.**
   - Works: this session proved the switch ran (12:20:58), which was the blocker on
     `docs/todo/monitoring.md`'s `[blocked:deploy]` post-deploy-check row.
   - Open: `post-deploy-check.sh` itself (HTTP smoke + auth-gateway 500/502 + SigNoz
     impersonation) was NOT run this session — the session answered the auth question directly
     instead of running the full gate.
   - Effort: S.
3. **Self-critique questions (session opener) partially answered** — "what did you forget /
   do better / improve" is answered concretely in §e rather than exhaustively re-audited
   against every doc surface (scope discipline).

## c) NOT STARTED

1. **Run `scripts/post-deploy-check.sh`** — now unblocked (switch landed 12:20:58). Not
   started: session was Q&A-scoped; owner instruction pending. Priority: High.
2. **Verify `c4d62a3 ∈ b514bda` via GitHub compare API** — not started (local checkout lacks
   the rev; remote check not attempted per scope). Priority: High.
3. **Confirm Google Cloud Console "In production" publishing status** — owner-only UI gate;
   not started; deadline quantified this session: **~2026-10-11 07:45** for `main`'s grant.
   Priority: Critical (time-boxed).
4. **Update stale queue premises** (monitoring.md `[blocked:deploy]` row → switch landed;
   `docs/todo/upstream.md` /health-fix deploy row → lock bump + deploy happened) — not
   started, deliberately: owner's explicit WAIT-for-instructions gate this session; recorded
   here as the harvest-disposition surface instead (see §f block at the end).
5. **Remove obsolete "restart `inboxclean-web` after re-auth" runbook advisories**
   (`modules/nixos/services/inboxclean.nix` header + `docs/services/inboxclean.md`) — the
   workaround documented the `01d2c5e`-only lazy-reconnect bug; `b514bda` is deployed, so the
   advisories are now stale. Owned by the deploy row's doc pass; not started. Priority: Medium.
6. **Classify the `inboxclean sync` process seen in `ps` after the last tick deactivated** —
   most likely explanation: a later tick (cadence ~25–30 min) was in flight when the snapshot
   was taken; unverified because `systemctl status` is an agent-banned command and the ps
   snapshot lacked a co-recorded timestamp. Not started. Priority: Low.

## d) TOTALLY FUCKED UP

Radical honesty — nothing in this session's own work was damaged (no writes to break), but
the observed surface contains three genuinely red things:

1. **`/health` is red in prod RIGHT NOW, post-deploy — and the fix chain's arrival is
   unproven.** Severity: degrades the gatus liveness leg and any consumer of the health
   endpoint; makes the health endpoint untrustworthy as an auth signal. Root cause: undetermined
   — either `c4d62a3` (3s→8s budget + 60s verdict cache) is NOT in deployed `b514bda` (two lock
   bumps and the fix still hasn't reached prod would be the story), or it IS in the build and
   8s is still insufficient under current IO pressure. Workaround: none needed for sync (ticks
   prove auth); `systemctl restart inboxclean-web` rebuilds clients fresh (old interim, per
   runbook). This is the session's top open investigation.
2. **A hard deadline is ticking on `main`'s grant: ~2026-10-11 07:45.** The OAuth client sat in
   Testing mode when it killed `main` exactly 7 days after consent (2026-09-04 incident). The
   current grant was consented 2026-10-04 07:45 → 7 days lands **Sunday morning**. If the
   Console was never flipped to "In production" (the residue item is still open in
   `docs/todo/services.md`), sync dies again on schedule. Severity: High (full `main` sync
   outage + OnFailure every tick). Mitigation: 10-minute owner UI check; re-consent ceremony if
   missed.
3. **The journal store has a TRUNCATED archived file** — every `journalctl` call this session
   (4/4) printed `system@00065cc9ec260c9d-20347b685c25bbc7.journal~ is truncated, ignoring
   file`. That window's forensic data is silently absent from queries — exactly the class that
   has burned crash autopsies before (freeze investigations rely on journal replay). Severity:
   Medium (forensic coverage loss, not live-data loss). Root cause: unknown — crash-truncation
   on the hot-tier journal subvol is the candidate class. Needs one `journalctl --verify` pass.

## e) WHAT WE SHOULD IMPROVE

1. **What I forgot (session opener, answered):** I did not TIME the `/health` request.
   Elapsed-time-to-503 is a free discriminator — ~3s to failure = old budget, ~8s = fixed budget
   — and would have answered "is `c4d62a3` deployed" without any ancestry research. Measuring
   status but not latency was the miss.
2. **Probing order cost a round trip:** the fetch tool hides non-2xx bodies; the python3
   urllib probe that captured the 503 body should have been the FIRST call, not the second.
   Lesson for localhost HTTP diagnostics: go straight to a body-capturing client.
3. **Dead-end handling on rev verification:** when the local checkout doesn't know a rev
   (`b514bda`), the right fallback is the GitHub compare API (`gh api .../compare`), not
   stopping at "can't verify locally". Pattern worth remembering for every upstream-flake
   verification.
4. **Process snapshots need timestamps:** `ps -C inboxclean` without a co-recorded `date`
   left the in-flight-tick ambiguity in §c.6 unresolvable. Trivial fix: always snapshot
   wall-clock alongside process state.
5. **Single-question sessions still shed durable anomalies:** the journal truncation was
   noticed incidentally; without this report it would have evaporated. This report is the
   capture surface (harvest dispositions below) — keep doing this deliberately.

## f) UP TO 50 THINGS WE SHOULD GET DONE NEXT

Ranked by impact. Each item is specific and traceable; "tracked→" points at the existing queue
row it belongs to. Per the no-drift rules, rows already fully owned by `docs/todo/*` are
referenced, not duplicated; genuinely NEW items are marked **[NEW]** with harvest disposition
at the end of this section.

| #  | Task | Impact | Effort | Category | Tracker |
|----|------|--------|--------|----------|---------|
| 1  | Confirm Google Cloud Console OAuth client is "In production" (7-day bomb on `main` fires ~Oct 11 07:45 otherwise; if it fires, re-run the consent ceremony) | Critical | S | Bug | tracked→ services.md `main` OAuth residue row; **[NEW]** deadline quantified |
| 2  | Run `scripts/post-deploy-check.sh` — unblocked, the switch landed 12:20:58 (HTTP smoke + auth-gateway 500/502 + SigNoz legs) | Critical | S | Verification | tracked→ monitoring.md `[blocked:deploy]` row (premise now satisfied) |
| 3  | Time the `/health` request (elapsed-to-503 discriminates 3s vs 8s handler budget ⇒ tells whether `c4d62a3` is live without any ancestry research) | High | S | Verification | **[NEW]** |
| 4  | Verify `c4d62a3 ∈ b514bda` via `gh api` compare (local checkout lacks the rev) | High | S | Verification | **[NEW]** |
| 5  | Branch on #3/#4: if fix absent → bump lock to the fix rev + deploy; if present and still 503 → file upstream "8s budget insufficient under IO pressure" issue with today's evidence | High | M | Bug | **[NEW]** |
| 6  | Determine whether the gatus "ALL Gmail dead" aggregate check gives a VERDICT under a 503-timeout `/health` or is silently blind right now (timeout semantics of the check) | High | S | Bug | **[NEW]** — adjacent to the tracked per-account decision |
| 7  | Decide the per-account `auth_expired` Gatus check (main sat dead 26 days once; today's aggregate blindness is more evidence FOR) | High | M | Decision | tracked→ services.md `[decision]` row |
| 8  | Update monitoring.md `[blocked:deploy]` row: switch landed 12:20:58 (stale premise) | Medium | S | Documentation | **[NEW]** |
| 9  | Update the `/health`-fix deploy row in upstream.md/services.md: lock bump + deploy happened; verify and close | Medium | S | Documentation | tracked→ upstream.md row (/health timeout fix) |
| 10 | Remove obsolete "restart web after re-auth" advisories from `inboxclean.nix` header + `docs/services/inboxclean.md` (`b514bda` deployed; `01d2c5e`-only bug) | Medium | S | Documentation | tracked→ deploy row's doc pass (previously not-harvested item #23) |
| 11 | Verify gatus InboxClean checks' behavior during today's 503 windows (did alerts fire? flap count?) | Medium | S | Verification | **[NEW]** |
| 12 | `journalctl --verify` pass on the hot-tier journal; classify the truncated `system@00065cc9…journal~` (crash-truncation class) and decide rotation/repair | Medium | M | Bug | **[NEW]** |
| 13 | Attribute today's 3 TEMPFAIL ticks (12:20/13:50/14:50) to the IO-pressure class or open a dedicated investigation (open since the 2026-10-05 report §29) | Medium | S/M | Verification | tracked→ 2026-10-05 report open item |
| 14 | Audit the OnFailure wiring for TEMPFAIL noise: 6 exit-75s in 48h each triggered OnFailure= — surfaced how? report-only or permanent-fail noise? | Low | S | Verification | **[NEW]** |
| 15 | `work`-grant age audit: consented ~Aug 29, repeatedly alive past 7d — quantify actual expiry behavior while Testing mode persists (the 7-day model may be wrong for this client) | Medium | S | Verification | **[NEW]** |
| 16 | Calendar a hard check for Oct 11 morning: `main` grant health probe IF #1 not confirmed by then | Critical | S | Process | **[NEW]** |
| 17 | Runbook addition: document the exit-75 TEMPFAIL transient class + "next tick recovers" expectation so on-call doesn't chase ghosts | Low | S | Documentation | **[NEW]** |
| 18 | Upstream: dedicated gmail-verdict-cache regression test (60s TTL pin via counting VerifyAuth fake) | Medium | S | Quality | tracked→ services.md `[ready]` row |
| 19 | Upstream: fix the pre-existing red tests (fold/scenario + RenderEventsFromStore) that mask regressions | Medium | M | Quality | tracked→ upstream.md hygiene row |
| 20 | Rename flake input URL `inboxclean` → `InboxClean` (lock already resolves via redirect) | Low | S | Cleanup | tracked→ 2026-10-07 12:17 report f.13 |
| 21 | Paste the bank-statement PDF password into `inboxclean-decrypt.yaml` (sops editor), then run the decrypt-repair dry→live + prune runbook | High | S | Feature (go-live) | tracked→ services.md `[blocked:user]` |
| 22 | Rotate the InboxClean→Paperless API token (user chose NOW on 2026-09-03 — **34 days and still pending**; flag the slip) | High | S | Security | tracked→ services.md `[blocked:user]` |
| 23 | Delete the two byte-identical duplicate bank statements (2026-09-03) via `--backfill --prune` | Medium | S | Cleanup | tracked→ services.md `[blocked:user]` |
| 24 | Retro-decrypt repair (`--backfill --decrypt-repair --dry-run` → live) after #21 | Medium | M | Feature | tracked→ services.md `[blocked:user]` |
| 25 | Verify `inboxclean-backup.timer` actually produced today's 04:30 backup (dir listing on `/mnt/pool/backups/inboxclean`) | Low | S | Verification | **[NEW]** |
| 26 | Confirm the gatus `/health/projections` check is green while `/health` is red (isolate the blast radius of the timeout) | Low | S | Verification | **[NEW]** |
| 27 | Check SigNoz for InboxClean alert noise around today's 12:07 restart + 503 windows (alert-fatigue audit) | Low | S | Verification | **[NEW]** |
| 28 | Classify the post-tick `inboxclean sync` ps sighting (in-flight tick vs stray process): `systemctl status` + timestamped ps | Low | S | Verification | **[NEW]** |
| 29 | Upstream feature: loud `/health` verdict when a sync cursor is stale > N days (the 26-day dead-`main` class; cursor-age is orthogonal to the landed dead-grant honesty chain) | Medium | M | Feature | **[NEW]** |
| 30 | Health-hub federation decision (is InboxClean a federated remote? its custom health JSON + current 503 make this concrete) | Low | M | Decision | tracked→ services.md `[decision]` row |
| 31 | Close the nested art-dupl consumer pre-deploy worry with post-state: the 12:20:58 switch built + deployed WITHOUT a FOD failure ⇒ evidence the `b2a3b4ec` concern was moot for this wave; record and close | Low | S | Verification | tracked→ pipeline.md row |
| 32 | Upstream: assert the /health budget in a regression test (the fix currently has no pin; today proved red can survive two lock bumps unnoticed) | Medium | S | Quality | **[NEW]** — sibling of tracked row 294 |

**Stop at 32:** the instruction allows up to 50, but items 33–50 would be re-listings of
`docs/todo/{services,monitoring,stability,upstream}.md` rows this session only brushed against
grep output, not work — padding the table would violate the no-drift rules. The full inventory
lives in the domain libraries; consult those for items 33+.

**Harvest disposition (per AGENTS.md self-harvest rule):** NEW items = #1 (deadline), #3, #4,
#5, #6, #8, #11, #12, #14, #15, #16, #17, #25, #26, #27, #28, #29, #32. All others map to
existing tracked rows (no new surface needed). Deliberately NOT harvested this session because
the owner's explicit instruction for this report was "THEN WAIT FOR INSTRUCTIONS" — every NEW
item's disposition is recorded HERE instead; on your word I land them in `TODO_LIST.md` +
`docs/todo/services.md`/`monitoring.md` in one pass.

## g) QUESTIONS ONLY YOU CAN ANSWER

1. **Is the Google Cloud Console OAuth client now "In production"?** I tried: no local config
   or journal can reveal publishing status; the docs only record the residue as open. This
   decides whether `main`'s grant dies **~2026-10-11 07:45** and whether I should prep the
   re-consent ceremony + a Sunday-morning probe (#16).
2. **Who/what ran the switch that activated current-system at 12:20:58 today** (you via
   `nh`/`nix run .#deploy`, or another session)? The 12:17 report declared the switch pending
   at its authoring time; activation landed 3 minutes later. I can read the mtime but not the
   actor — and the post-deploy verification ownership (#2) plus the daemon-race/quiescence
   accounting for that window follow from the answer.
3. **Today's 3 TEMPFAIL ticks (12:20/13:50/14:50): file under the known IO-pressure class
   (freeze-20 `[watch]` row) or open a dedicated root-cause investigation now?** The evidence
   is consistent with the known class (transient, self-recovering, IO-timing), but three in
   one afternoon post-switch is a cadence bump — your priority call.

---

*Awaiting instructions. Nothing was committed by this session (harness rule); the auto-commit
daemon will pick this report up.*
