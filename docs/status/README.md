## Live pool addendum (2026-11-21 20:0x)

New live report: `2026-11-21_19-57_window-reverify-monitor365-batch-plus-reviewfix-wave.md`
— verification-only re-pass of the SAME five-task window the 2026-11-21 02:14
closeout already covered (dispatch-time dedup HIT; double dispatch itself
minted as a tq watermark improvement row). All §a landings re-grepped GREEN at
HEAD `c702d9147`; night-1 evidence LANDED CLEAN (compact fired once 03:01,
13.09G→3.85G, count-gate passed; backup + pool-copy each single-fire, fresh
pool copy 04:10:42); the deploy carrying the guard + count-gate fix was
MID-FLIGHT at report time. Ticked TODO rows 3814 + 3838; appended 2 new rows.

## Live pool addendum (2026-11-20 03:0x)

New live report: `2026-11-20_03-04_window-closeout-services-journal-noise-five-task-window.md`
— full-pass close-out of the five-task window 2026-11-17 → 20 (dispatch-time
dedup clean: no prior window report covers the span). Headlines: papdashboard
674/min noise root-caused + fixed UPSTREAM (fleet landing blocked on the
unpushed oci-go-standard-pilot branch), dnsblockd TRACK_METRICS fail-soft
landed upstream unpushed, inboxclean 3.28 TB tile-poll storm driver fixed
in-tree, takeout size_band proven on real racedriver8k data (row premise was
wrong — real forms pinned), migrate-user-tmp sandbox red fixed. Band drift:
none recorded (0 `task.reprioritized` facts since 2026-11-17, tq.db read
fresh). 8 new rows + 3 blocked owner questions appended to TODO_LIST.

## Live pool addendum (2026-11-15 14:2x)

New live report: `2026-11-15_14-21_task-queue-window-reverification.md`
— 5th fire of the 2026-11-10 → 14 five-task window, run as the mandated
VERIFICATION-ONLY pass (dispatch-time dedup hit: the 2026-11-14 09:23
canonical report already closed this window). All §a landings re-grepped
green at HEAD; llama-chat backoff found landed since (row 3605); new
findings: the closeout chain grew a 5th artifact despite a recorded
verdict (rows 1479/1778 reproducer), and dispatched shells cannot read
the live tq journal (TQ_DB stripped — the canonical §h "verified live"
band-drift claim corrected to design-limited; new blocked row minted).
One shell trap lesson recorded in docs/agents/shell-devtools.md.

## Live pool addendum (2026-11-14 09:41)

New live report: `2026-11-14_09-23_task-queue-window-closeout.md`
— 4th-fire closeout of the five-task window (2026-11-10 → 14): two
reviewer-finding fixes (time_series_v2 tick drift `377a242f7`, gatus
count drift `64c124592`), adb mDNS 0.0.0.0:5353 verified intentional
(`316362190`), cvagent/forgejo `MemoryMax` 1G bumps (`d7963ea17`,
deploy pending behind the row-3596 foreign-breakage block), and the
ai-stack 5-item batch (pid churn verdict, restart backoff, re-embed
design, ClickHouse demand profile, 645G write attribution). Predecessor
fires 08-42 (full report, verdict lost) + 09-14 (skeleton + verdict-loss
row) folded into the canonical file with annotations; verdict recorded.
Band drift: none recorded (0 `task.reprioritized` facts).

## Live pool addendum (2026-10-23 07:49)

New live reports: `2026-10-23_07-55_monitor365-data-governance-batch.md` (named ~7 min ahead of wall clock — committed 07:35), `2026-10-23_07-05`→plan not report, `2026-10-23_04-20_monitor365-session-self-review-status.md`, `2026-10-23_03-55_monitor365-rendered-fixture-deploy-deferral-3.md`
— the monitor365 data-governance arc under the owner's IO/s steer: rendered-artifact retention fixture green ×2 + row 446 closed (03:55); self-review owning the `;`-chain push, assert-before-verify regex, and the missed post-push gate re-run that let a foreign-wave eval-red go unnoticed 25 min (04:20); the governance batch — collector cadence set landed inert (process 5 s sampling / network+battery 300 s / location 900 s), tenant-cap governor doctrine pinned everywhere (rec 250 k/day, owner sets it), papdashboard nested-treefmt follows healing the lock-audit red, 4 upstream rows (bounded queue, environ opt-in, rollups, cap observability), deploy force-deferred DOUBLE (PSI + wave-red: hermes IFD + crowdsec-via-unfetched-nixpkgs) (07:55/07:49).

## Live pool addendum (2026-10-23 06:37)

New live report: `2026-10-23_06-37_t04-done-inboxclean-driver-unmasked-self-review.md`
— BTRFS repair lane advanced: T04 safety copy EXECUTED by owner (33m57s, quiesced-DB window) and agent-verified (−39.21 GB pool delta; storage.md P0 row + monitor365.md runbook annotated), with the stale 54G two-leg premise corrected (/data leg pool-side since 2026-08-18); the IO storm's primary driver unmasked as inboxclean-web (3.28 TB read since the 10-20 boot, 1.5 GB DB rescanned ~38×/h via canceled dashboard queries, 6× forgejo's reads — the 10-21 review's "victim" classification overturned); guard blind-spot found (zone-6 action set never touches the top reader); self-review owns two precision failures (whole-Lexar devt misattribution, unstable bare-stop recommendation) + attribution-order lesson; 4 rows harvested (stability ×2, services, upstream).

## Live pool addendum (2026-10-22 02:16)

New live report: `2026-10-22_02-16_health-notifications-review-self-review.md`
— brutal self-review of the 2026-10-21 03:30 health-notifications review: 23 h drift check (storm WORSE — PSI avg300 87%, 25→32 failing endpoints, monitor365 still down, none of the P0/P1 remediations executed), one overclaim fixed in-source (the "zero phantom-greens" sweep scope), process failures named (session-start docs/status pre-read skipped, busctl escape botch), 22 next-things with harvest state, 3 owner questions (FLM decision, SEV1 escalation policy, GitHub billing intent).

## Live pool addendum (2026-10-21 03:30)

New live report: `2026-10-21_03-30_health-notifications-review.md`
— full review of every health-notification surface (gatus Discord/PapDashboard alerts, SigNoz rules, SEV1 bridge, failed units, textfile freshness) against live state amid the immich-incident aftermath + an active IO storm: 25 gatus endpoints in sustained error, 6/46 SigNoz rules firing (all true positives), 10 failed units root-caused each (fastflowlm heap crash, monitor365 SQLite-pool wedge + SIGKILL, catalog-inventory-sync missing bash, ci-watchdog GitHub billing, bless-boot race re-confirmed, tmpfiles CANTCREAT, signoz-provision transient 500s, deliberate btrbk tripwire), 2 active SEV1s at notify-only, alert-noise findings (boot alert-storm ×~25 endpoints, 89+73 flap burns), and 10 follow-ups harvested + 2 existing rows corroborated/extended.

## Live pool addendum (2026-10-17 00:40)

New live report: `2026-10-17_00-40_window-closeout-five-task-window-20261014-16.md`
— closeout of the NEXT five-task window (2026-10-14 → 16: io-psi bundle
durability + trip-persist batch, maintenance-entry-gate family, freeze-29/30
close-out, quiet-window re-bench (scope-swapped, item still open),
boot-phase timing watch). Verifies the whole storm-protection stack LIVE on
gen 914 (bundles 2,915→40, maintenance-entry-gate on PATH, nix-shim removal
live), ticks the owner-vetoed freeze-14 row, appends 3 rows (done-preflight
deliverable-touch check, gen-914 post-deploy sweep, calm-window battery —
the last one owner-BLOCKED), and records the first closeout coverage of
this window (the four prior done-prompt fires covered the 10-13→14 window).

## Live pool addendum (2026-10-15 03:40)

New live report: `2026-10-15_03-29_window-closeout-five-task-window-4th-fire.md`
— fourth fire of the five-task window closeout (2026-10-13 → 14): re-verifies
all three predecessor closeouts (claims held), adds the dispatch-chain
forensics (four fires, zero recorded verdicts: budget gate, dead
`.tq-verify` gate, preflight refusals), ticks the duplicate
`task.reprioritized` row (executes the dedupe row), appends 3 rows
(verify-gate unblock, verdict-durability rule, budget-carve-out question)
plus their pipeline.md library entries, and adds 3 FEATURES.md rows.
Prior closeouts of the same window: `2026-10-14_05-03_*`,
`2026-10-15_00-40_*`, `2026-10-15_00-54_*`.
