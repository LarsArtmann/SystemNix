# Status Report — 2026-10-16 19:55 CEST — bank-sync post-cutover: CLI backfill split-brain, SCA re-arm, zero-render diagnosis

**Session scope:** diagnosis + guided remediation of the bank-sync "webui broken / zero transactions" incident after today's fresh-start cutover. **This session authored ZERO SystemNix code changes** — all work was live probing (read-only), source reading in `~/projects/bank-sync`, and constructing correct CLI invocations for the owner to run. The only tree writes are this report + its harvest rows.

**Data freshness:** live probes 16:30–17:10 CEST + one freshness probe at 19:55 CEST. State at authoring: SCA approval still pending (`bank_sync_sca_approval_pending 1`), EUR balance 22353148 still renders total=0 (split-brain persists 3h after the CLI backfill), `bank_sync_sync_total 15`, daemon binary `c220c0b4` (PID 419161, unchanged all session).

---

## Session timeline (what actually happened)

1. Owner ran `bank-sync sync` from `/home/lars` → `[Rejection:wise.api_key_missing]`. Diagnosed: bare CLI invocation, no env/config; daemon's key comes from sops (`modules/nixos/services/sops.nix:575` → template `bank-sync-env`, rendered `/run/secrets/rendered/bank-sync-env`, 0400 bank-sync, unit `EnvironmentFile`).
2. Established why the webui "looks broken": three stacked causes — (i) fresh-start cutover deployed today (archive `/mnt/pool/services/bank-sync-pre-keybump-20261016` exists; daemon on new-key `StreamMarker:` basis), (ii) Wise SCA block (phone-change class, `approval_token_issued=false` since 2026-10-09), (iii) — discovered later — the CLI/daemon projection split-brain.
3. Owner viewed statements on wise.com (re-arm attempt), then ran `bank-sync backfill` from the repo CWD → SQLite CANTOPEN errno 14. Root cause: relative DSN `bank-sync.db` + bank-sync user cannot create files in the repo dir. Constructed the working invocation (`cd /mnt/pool/services/bank-sync` + `set -a; . /run/secrets/rendered/bank-sync-env; set +a` — secret never typed, fish_history-safe).
4. Working backfill ran (owner paste): **15 of 20 balances refused** (`backfill.degraded_source_refused` — statements SCA-blocked, transfers fallback outgoing-only, guard refuses partial history) **but every rejection context shows `approval_token_issued: true`** — the wise.com re-arm WORKED; Wise issues OTTs again (vs. verdict-only 403s since 10-09). Profile 22896772's 5 balances synced non-degraded: fetched 34, **new 10** (EUR 22353148 +6, PLN 28331642 +2, USD 22353271 +2).
5. Owner ran `bank-sync sca approve` CLI → 15× "verification skipped — challenge did not clear" + trailing `wise.sca_status` 404 `ott_not_found`. Explained: non-interactive (no OTP path) + daemon-race + **Wise keeps ONE active OTT per user** — each new probe invalidates the previous, so the CLI's early tokens were dead by balance 15.
6. Owner asked why SCA is needed for `GetTransfer` at all — answered: it isn't; transfers WORKED (the 10 imports ARE transfers). The SCA gate is Wise's on `balance-statements/…/statement.json` (the only full-history surface: deposits/card/fees); `degraded_source_refused` is bank-sync's own guard against writing outgoing-only data as history.
7. Owner asked why ZERO transactions render. Proven with live probes + source: **the CLI backfill ran as a second process; bank-sync projections are fed by each process's in-process watermill bus** (`internal/cqrs/infrastructure.go:647`), so the daemon's projections never saw the CLI's journal events. Evidence: `/partials/transactions?balanceID=22353148` returns total=0/rows=0 for ALL 5 unblocked balances 3h post-backfill; `bank_sync_projection_lag_seconds 867` = exactly time since daemon's own last applied event (16:51:57), DLQ 0, workers_failed 0; daemon ticks (17:07:02) `total_new=0` because regular syncs only cover the recent window and never re-fetch historical chunks.
8. Fix identified: **daemon-side backfill** — dashboard form → `POST /partials/backfill` (`internal/server/server.go:1035`, "the dashboard face of `bank-sync backfill --from`", in-process, SSE progress). Journaled CLI rows dedupe (already-known), no double-import.

---

## a) FULLY DONE

1. **`wise.api_key_missing` root cause + correct-env recipe** — daemon wiring verified end-to-end (sops placeholder → rendered template path → unit EnvironmentFile → WorkingDirectory). Evidence: `/etc/systemd/system/bank-sync.service` read; `modules/nixos/services/sops.nix:575`. Scope: diagnosis only.
2. **SQLite CANTOPEN (errno 14) root cause + working CLI invocation** — relative DSN vs CWD explained; working command constructed and **owner-executed successfully** (paste-1 shows full backfill run). Scope: no file changes.
3. **SCA re-arm field-validated** — `approval_token_issued: true` in all 15 rejection contexts (was `false` since the 2026-10-09 phone change). The runbook's step-0 remedy (wise.com statement viewing) is now PROVEN to restore OTT issuance. Evidence: owner paste-1.
4. **Zero-render root cause proven, not guessed** — per-process bus-fed projections identified in source (`infrastructure.go:647`), live-confirmed by fragment probes (total=0 ×5 balances), projection-lag signature (867s ≡ silence since daemon's own last event; 17.6s at 19:55 with EUR STILL 0), DLQ/workers green, and daemon ticks unable to see historical chunks. Evidence chain complete.
5. **SCA-vs-GetTransfer question answered correctly** — SCA gates statements, not transfers; the guard refusing degraded import is correct behavior, working as designed.
6. **CLI `sca approve` failure fully explained** — non-interactive + daemon-race + single-active-OTT semantics (`ott_not_found` 404 = prior token invalidated by newer probes).

## b) PARTIALLY DONE

1. **Fresh-start post-deploy verification battery** (existing `[blocked:deploy]` row — now UNBLOCKED, cutover deployed today). Done: `/health/ready` 200, empty Sync State, archive dir exists, daemon healthy on new key basis. **Not done:** exactly-once `bank-sync-fresh-start: moved` journal line check; HM `programs.bank-sync` binary rev vs daemon `c220c0b4` parity; sustained-failure push fired?; full `post-deploy-check.sh`; Paperless duplicate check (Sunday-pending). Blocker: none — effort S.
2. **SCA approval** — issuance restored (done), **OTP verification missing** (owner-side; `approval_pending` still 1 at 19:55). 15 balances stay refused until it lands. Blocker: human OTP. Effort S.
3. **Transaction import** — 10 rows journaled via CLI but invisible to the daemon's read model; daemon-side backfill not yet run. Effort S once (2) lands.
4. **SCA knowledge capture** — re-arm procedure field-proven but NOT yet written into `docs/services/bank-sync-sca.md`; single-OTT semantics + CLI race failure mode undocumented. Effort S.

## c) NOT STARTED

1. **Upstream bank-sync issue: CLI backfill vs running daemon split-brain** (warn on live daemon, or journal-tailing projections). Not drafted — owner's repo, owner's call on fix locus. Priority: High (this exact trap cost the owner a cycle today).
2. **Runbook updates** (CLI recipe with CWD+env; relative-DSN errno-14 trap; two-process gotcha; single-OTT `ott_not_found` note). Priority: High, effort S each.
3. **Rehearsal-vs-deployed rev drift check** — rehearsal was on `8e384027` (per docs/services/bank-sync.md §Fresh-start), deployed binary is `c220c0b4`. Nobody has verified what `c220c0b4` is or that it was rehearsed. Priority: High, effort S.
4. **Restart-replay semantics** — if checkpoints are shared in the DB, a daemon restart may SKIP the CLI's journaled events (checkpoint advanced by the CLI's own projection host). Unverified; determines whether "just restart the daemon" is a safe heal. Priority: Medium, effort M.

## d) TOTALLY FUCKED UP

1. **The two-process projection split-brain (systemic)** — daemon + CLI against one SQLite journal, projections fed by per-process buses. The CLI's 10 imported transactions are INVISIBLE to the UI indefinitely via normal operation (regular syncs never cover historical windows). Not data loss (journal holds them; dedup is intact) but it silently defeats the user's primary goal. Workaround: dashboard backfill. Severity: blocks the feature.
2. **My own recommendation error (session-fucked-up, on me)** — I handed the owner the CLI backfill command as a legitimate path with only the CWD/env fix. I had ALREADY established the daemon-race hazard from the `sca approve` failure minutes earlier and still didn't connect that the same two-process split applies to backfill projections. The owner burned a backfill cycle whose output the UI cannot render. The dashboard button was the correct first recommendation.
3. **`bank-sync sca approve` non-interactive UX** — running it while the daemon syncs produces 15× "verification skipped" noise plus a trailing 404 that looks catastrophic. No live-daemon guard, no single-OTT warning. Misleading, not harmful.
4. **Fresh-start rehearsal/deploy rev opacity** — the cutover deployed `c220c0b4` while the runbook records the rehearsal against `8e384027`. Unknown whether they're adjacent revs or something moved mid-flight. Needs the drift check (c.3).

## e) WHAT WE SHOULD IMPROVE

1. **Probe the user-visible surface first.** When the owner first said "webui is broken", I checked `/health/ready` + sentinel metrics but not the transactions fragment — the zero-render state was discoverable in pass one; instead it took two more owner questions. Impact: ~2 round-trips. Fix: for UI complaints, always fetch the exact fragment the UI renders.
2. **Default to the daemon's own surface for anything the dashboard renders.** CLI is a fallback and must carry the split-brain caveat until upstream fixes the class. Impact: avoids repeat of (d.2).
3. **CLI ops recipes belong in the runbook.** The correct invocation (CWD + sourced env + never-typed secrets) had to be reconstructed from the unit file mid-incident. Impact: every future CLI ops session rediscovers this. Fix: bank-sync.md §ops.
4. **Verification batteries run when their gate opens, not when the user pings.** My "ping me and I'll run the battery" offer went stale the moment the incident shifted. Fix: run the battery as soon as the deploying session observes the switch.
5. **Report-format divergence flagged:** skill spec says HTML-canonical; owner explicitly demanded `.md` at this path — honored per skill's override rule, recorded here so the divergence is visible.
6. **Session learnings not yet in memory files** — this report + the queued rows are the write-down; AGENTS.md needs no change (runbook rows own the detail).

## f) Top 50 next tasks (ranked; harvest status marked)

Legend: 🔴 Critical · 🟠 High · 🟡 Medium · ⚪ Low | S <30min · M 30min–2h · L >2h | **[QUEUED]** = harvested this session to TODO_LIST.md + docs/todo/services.md · **[ROW]** = existing row already covers it · **[NOT]** = deliberately not harvested (see reason).

| # | Task | Impact | Effort | Cat | Harvest |
|---|------|--------|--------|-----|---------|
| 1 | Owner: complete dashboard SCA OTP approval (Approve now → Send code → Verify) — unblocks 15 balances | 🔴 | S | user | [ROW] (blocked:user SCA rows) |
| 2 | Owner: run the dashboard backfill form (daemon-side) 2023-02-20→today (or 2021-01-01 pending Q2) | 🔴 | S | user | [ROW] (battery row, step 4) |
| 3 | Verify UI renders post-daemon-backfill: EUR 22353148=17, USD 22353271=15, PLN 28331642=2 | 🔴 | S | verify | [NOT] sub-step of #2's verify; covered by battery row step 4 |
| 4 | Verify all 20 balances repopulate + `bank_sync_sca_approval_pending`→0 post-approval | 🟠 | S | verify | [ROW] battery row |
| 5 | Determine where the CLI's 10 rows physically landed (shared read tables vs CLI-only) — decides restart safety | 🟠 | M | investigate | **[QUEUED]** |
| 6 | Source-verify projectionhost boot replay + shared-checkpoint skip semantics before anyone "just restarts" | 🟠 | M | investigate | **[QUEUED]** (merged into #5's row) |
| 7 | Run full `post-deploy-check.sh` — battery row gate opened with today's cutover | 🟠 | S | verify | [ROW] battery row |
| 8 | Verify exactly-once `bank-sync-fresh-start: moved …` journal line (checklist item 1) | 🟠 | S | verify | [ROW] battery row |
| 9 | Verify HM `programs.bank-sync` CLI binary rev == daemon `c220c0b4` (checklist item 3) | 🟠 | S | verify | [ROW] battery row |
| 10 | Identify rev `c220c0b4` vs rehearsed `8e384027` — rehearsal/deploy drift | 🟠 | S | investigate | **[QUEUED]** |
| 11 | Confirm the expected sustained-failure Discord push fired ~1h post-cutover (checklist item 3) | 🟡 | S | verify | [ROW] battery row |
| 12 | Upstream issue: CLI backfill/sca-approve vs running daemon — warn, or journal-tailing projections? | 🟠 | M | feature | **[QUEUED]** (decision) |
| 13 | Upstream issue: `sca approve` live-daemon guard + single-active-OTT warning | 🟡 | M | feature | **[QUEUED]** (merged into #12's row) |
| 14 | bank-sync.md: add CLI ops recipe (cd dataDir + source `/run/secrets/rendered/bank-sync-env`; relative-DSN errno-14 trap; never type the secret) | 🟠 | S | docs | **[QUEUED]** |
| 15 | bank-sync.md: two-process projection split-brain gotcha (2026-10-16 class) | 🟠 | S | docs | **[QUEUED]** |
| 16 | bank-sync-sca.md: Wise single-active-OTT semantics (each probe invalidates prior → `ott_not_found` 404) + dashboard-first confirmation | 🟠 | S | docs | **[QUEUED]** |
| 17 | bank-sync-sca.md: record the 2026-10-16 field-validation of the re-arm procedure (OT T issuance restored via web statement view) | 🟡 | S | docs | **[QUEUED]** (merged into #16's row) |
| 18 | After first backfilled Sunday: Paperless duplicate-statement check (coverage re-widened) | 🟡 | S | verify | [ROW] battery row step 5 |
| 19 | Confirm weekly canary red-while-SCA-blocked is the ONLY expected red (checklist item 6) | 🟡 | S | verify | [ROW] battery row step 6 |
| 20 | Verify gatus live state for the 4 bank-sync checks | 🟡 | M | verify | [ROW] existing ready row |
| 21 | Update the two stale blocked:user SCA rows (2026-09-30 + 2026-10-14) with today's state (issuance restored, OTP pending) | 🟡 | S | docs | **[QUEUED]** (row-update task inside #14–17 docs sweep) |
| 22 | Update fresh-start battery row with today's partial evidence (health 200, archive exists) | 🟡 | S | docs | **[QUEUED]** (same docs sweep) |
| 23 | Probe `bank_sync_sync_total` semantics (2→4→15 this session, no restart — per-sync increment at 15m cadence; confirm and close the windowing question) | 🟡 | S | verify | [ROW] existing watch/ready rows |
| 24 | Two stray `bank-sync demo` instances `:18777`/`:18778` (`/tmp/bank-sync-bin`, live at 19:55) — verify `/proc` ownership + owning session done, then kill + trash | 🟡 | S | cleanup | **[QUEUED]** (new instances, f.7 pattern) |
| 25 | Classify-verdict-only-403s row: likely OBSOLETE (issuance restored) — verify against current code then close | ⚪ | S | cleanup | [ROW] existing ready row (close path) |
| 26 | Triage + trash the CLI backfill's flight-recorder trace (`traces/snapshot-*.trace.gz`, captured on the 15 expected refusals) | ⚪ | S | cleanup | **[QUEUED]** (merged into #24's row? no — standalone; deliberately [NOT]: zero-risk artifact, fold into next services.md pass) |
| 27 | Dashboard UX: auto-select first account so the transactions panel isn't empty-state on landing | ⚪ | M | feature | **[NOT]** upstream Roadmap fuel, not queued |
| 28 | Dashboard nit: "Last sync" renders UTC without zone suffix (14:51Z shown at 16:51 local) | ⚪ | S | bug | **[NOT]** upstream Roadmap fuel |
| 29 | SigNoz: confirm the backfill 15-failure burst didn't spurious-page any rule | 🟡 | M | verify | **[NOT]** monitoring domain, standing coverage exists |
| 30 | Add gatus/post-deploy probe: transactions fragment total>0 for a known balance (read-model liveness — would have caught today's split-brain) | 🟠 | M | feature | **[QUEUED]** |
| 31 | Journald truncated-file warning (`system@…journal~ is truncated, ignoring file`) hit 4× this session — check rotation health | 🟡 | S | investigate | **[QUEUED]** |
| 32 | Document `/run/secrets/rendered/` path convention in secrets docs | ⚪ | S | docs | **[QUEUED]** (merged into #14's row) |
| 33 | Decide `--allow-degraded` policy: should the CLI offer degraded import for statement-eligible windows at all post-cutover? | ⚪ | M | decision | **[NOT]** Roadmap fuel |
| 34 | Re-verify sync-streak gauge reset semantics after the post-approval restart | 🟡 | S | verify | [ROW] existing ready row |
| 35 | bank-sync.md fresh-start section: mark the cutover EXECUTED 2026-10-16 (status narrative lives there) | 🟡 | S | docs | **[QUEUED]** (docs sweep) |
| 36 | Check the dashboard backfill form's default from-date vs the owner's 2021-01-01 ruling | 🟡 | S | verify | **[NOT]** pending Q2 answer |
| 37 | bank-sync-paperless archival pair post-deploy smoke (existing ready row) | 🟡 | M | verify | [ROW] |
| 38 | MemoryHigh reclaim-thrash review (bank-sync 5k hits; existing row) | 🟡 | M | investigate | [ROW] |
| 39 | Readiness-gate storm tolerance (existing row) | 🟡 | M | feature | [ROW] |
| 40 | Smoke counter windowing — `sync_errors_total` restart-cumulative (existing row) | 🟡 | M | feature | [ROW] |
| 41 | Consolidate a single "bank-sync CLI ops" doc section (source of truth for #14/16/32) | 🟡 | M | docs | **[QUEUED]** (docs sweep) |
| 42 | Upstream design: journal-tailing projectionhost mode (kills the whole split-brain class) | ⚪ | L | feature | **[NOT]** Roadmap fuel behind #12's decision |
| 43 | Design Q: should a second writer on the journal be detectable (lock/heartbeat) and refused? | ⚪ | L | decision | **[NOT]** Roadmap fuel |
| 44 | Verify btrbk snapshots exclude the frozen `bank-sync-pre-keybump-20261016` subvol as ratified | 🟡 | S | verify | **[QUEUED]** |
| 45 | Standing: go-nix-helpers lock alias follow-vs-non-follow decision | ⚪ | M | decision | [ROW] |
| 46 | Standing: un-follow bank-sync's nixpkgs input decision | ⚪ | M | decision | [ROW] |
| 47 | Standing: bank-sync 55s boot activation diagnosis | 🟡 | M | investigate | [ROW] |
| 48 | Standing: bank-sync input-vs-master drift watch (re-probe before re-pin) | 🟡 | S | watch | [ROW] |
| 49 | Standing: browser-history StateShape toplevel fix (was the deploy blocker; cutover shipped today so verify it actually got fixed, then close) | 🟠 | M | bug | [ROW] — UPDATE: today's successful deploy suggests it was fixed; verify + close |
| 50 | Standing: dnsblockd post-deploy probe after its next restartTriggers deploy | 🟡 | S | verify | [ROW] |

**Harvest summary:** 12 items QUEUED (tasks 5+6, 10, 12+13, 14, 15, 16+17, 24, 30, 31, 32, 35, 41, 44 — consolidated into 6 new library rows + queue one-liners), 20 covered by existing rows ([ROW]), the rest deliberately not harvested (upstream Roadmap fuel, user-gated answers, or sub-steps of existing checklists).

## g) Top 3 questions I can NOT figure out myself

1. **Did the dashboard OTP approval ever get attempted-and-failed after 17:10, or just not attempted?** `bank_sync_sca_approval_pending` was still 1 at 19:55. If you clicked Approve now and something failed, WHICH step failed (probe / send-code / verify) changes the diagnosis — e.g. wrong number again vs TTL expiry vs another verdict-only block. I can't distinguish "not tried" from "tried, failed" from the outside, and probing the send-code endpoint myself would fire a real SMS.
2. **Is 2023-02-20 the intended backfill start, or should it be 2021-01-01?** Your 2026-10-08 owner ruling said FULL history 2021→today, but today's CLI run used `--from 2023-02-20`. If the Wise account's first activity is 2023-02 they're equivalent — otherwise the dashboard backfill should start 2021-01-01 and I'd verify the extra window imports.
3. **File the upstream bank-sync issue(s) now?** The CLI-vs-daemon split-brain (and the `sca approve` daemon-race/`ott_not_found` UX) are your repo — want me to draft the issue text (verify-before-filing gate + your voice) for you to file, or keep the fix in-repo / defer?

---

*Report by the diagnosis-only session; no SystemNix tree changes beyond this file + harvest rows. Parallel session was active on `docs/todo/services.md` during authoring (uncommitted changes observed — content-pinned at `6089474a`, re-read before edits).*
