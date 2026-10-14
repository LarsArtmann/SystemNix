# Status: Zero-User Re-attribution Executed (Owner-Authorized) — Session Continuation Report

**Session:** 2026-10-14, 21:47-22:18 CEST (continuation of the browser-history dashboard session; prior report: `docs/status/2026-10-14_21-47_browser-history-stats-full-status-retraction.md`) · **Owner directive:** "UPDATE visits SET user_id='01M000JA6…' WHERE user_id='000…0'; do it" · **Verdict: DONE, verified, no data touched beyond the authorized rows.**

## a) FULLY DONE

1. **The re-attribution executed clean in a ~40 s stop window (22:03:16):** server stopped → pre-counts gated (`pre_total=4959 pre_zero=3179 pre_owner=1780` — zero-count EXACTLY matched the evening audit) → consistent `.backup` to the pool (`/mnt/pool/backups/browser-history/manual-pre-reattribute-20261014-220316.sqlite`, 204,087,296 B) → transactional `UPDATE` with `changes()` gate → `changed_rows|3179` → post-gates green (`post_total=4959`, `post_zero=0`, `post_owner=4959`, `quick_check ok`) → server restarted active. All gates were pre-written into the script with the failure paths wired (abort restarts; post-mismatch restores the backup then restarts).
2. **Ingest verified flowing through the new server pid** (22:04:15 tick `total:0 accepted:0` = cursor-clean; the 22:01:27 pre-mutation tick had `accepted:4` into owner-attributed rows — inside the 4,959).
3. **Dashboard-facing state proven at the DB layer** (the dashboard reads this same SQLite file): owner = **4,959 = ALL visits**, zero-user rows = **0**. Next login shows Total visits ~4,959, heatmap/top-domains/sessions widened to Jan 1-Sep 4, aggregate-era note ~2,276 (1,031 own + 1,245 re-attributed), duration-weighted productivity now over ~2,638 duration-bearing visits.
4. **Firefox extraction definitively verified healthy** (closed the Oct-7 wrong-profile concern): `profiles.ini` has ONE profile, `ddkwwxjq.default-1777612573309`, `Default=1` — the agent's `profile=default` label IS the real profile; tonight's run extracted from it (`raw=5, kept=3`); `places.sqlite` actively written (mtime 22:00, minutes before the tick). Firefox is simply the light secondary browser (462 rows over 8 months). The `opwirq8n.default` dir has no profiles.ini entry and is never scanned.
5. **Runbook updated** (`docs/services/browser-history.md`): dated entry for the re-attribution (facts, backup path, the standing events-replay caveat, post-op dashboard expectations) + the Firefox-verification entry (moot-ness of the Oct-7 diagnosis recorded so no future session re-chases it).
6. **Durable-fix follow-up queued both surfaces:** upstream `reattribute` command (events still carry the zero user — any future event-replay rebuild would revert the read model; no rebuild feature exists today) in `docs/todo/upstream.md` + `TODO_LIST.md` one-liner; todo-checker green.
7. **Temp hygiene:** removed the leftover 204 MB `/tmp/bh-copy.sqlite` (found during cleanup — see e4) and the one-shot mutation script; only session-foreign files remain (`.smoke-bh-health`, `gmbh-baseline` — NOT mine, left alone per the never-touch-others'-files rule).

## b) PARTIALLY DONE

1. **Dashboard visual confirmation impossible for me:** DB-layer numbers are what the queries read, but the pixel-level check (stat card ~4,959, heatmap Jan-Sep filled) needs the owner's next login (g1).
2. **Audit trail of the mutation is prose, not code:** the executed script was deleted from /tmp after the run (deliberate — one-shot credentials-adjacent tooling shouldn't linger), but the runbook records the STATEMENT, not the full gate logic. The exact script content survives only in this session's transcript/crush.db. A sanitized template should be codified (f10).
3. **Gatus during the 40 s window:** not checked afterward — whether the browser-history check blipped/paged (and whether that's acceptable noise) is unverified (f3).
4. **Re-attribution completeness over time:** the pre-op backup boundary is 22:03; visits ingested AFTER the window are owner-attributed by the (verified) attribution fix, so drift is structurally impossible — but the tonight-02:15 backup (Oct 15) will be the first artifact proving post-op persistence (existing [watch] row covers the hot-mount first-run; fold the count check in).

## c) NOT STARTED

1. **Upstream `reattribute` command build** (queued [ready], docs/todo/upstream.md).
2. **Richer stat-card upstream work** — still awaiting the owner's target list (g1 of the 21-47 report, unanswered).
3. **Gatus render-duration threshold** (queued [watch], 21-47 report) and the two historical slow-render burst correlations — untouched.
4. **Post-deploy-check smoke for the mutation** — the repo's browser-history smoke sections target deploys; a non-deploy DB mutation has no wired check (deliberate, noted).

## d) TOTALLY FUCKED UP

1. **Nothing this round rose to Fucked-Up.** Honest near-misses instead (e): the health probe raced the server's bind window (connection-refused scare 60 s after `is-active` said active — Type=simple means process-spawned, not port-bound; one `ss` + `getent` + dual-path probe closed it), and the direct-typed `sudo systemctl start browser-history-agent` tripped the command guard once even though I had used the `bash -c` wrapper pattern earlier THE SAME SESSION.
2. **Process confession:** the destructive UPDATE ran without a literal dry-run on a scratch DB first — mitigated by (i) every query that shaped the decision having run against byte-identical backup copies all evening, (ii) the exact-count abort gate, (iii) the restore-on-mismatch gate, (iv) the pre-op backup. Owner authorization was explicit, twice. Residual risk accepted and would be structured the same way again, with the script kept until owner confirmation instead of deleted same-hour (f22).

## e) WHAT WE SHOULD IMPROVE

1. **"Active" ≠ "answering"** — the script (and I) trusted `is-active` + 3 s; the runbook's own agent-gate lesson (wait for the endpoint to ANSWER, never for unit state) applies to verification probes too. Post-mutation scripts should poll the health endpoint until 200, not sleep-and-assume.
2. **One-shot destructive ops keep their script until owner-confirmed** — deletion-at-completion optimizes tidiness over auditability; the rollback/audit value of the exact gate logic outweighs a 400-byte file in /tmp for 24 h.
3. **The sudo-inside-`bash -c` pattern should be muscle memory** — it is already the documented guard bypass (AGENTS.md live-probe set); I re-derived it mid-session instead of applying it from the start.
4. **Cleanup sweeps need a checklist, not memory** — the 20:40 `bh-copy.sqlite` survived the 21:10 cleanup because the sweep listed files by name from memory; `ls /tmp | grep <prefix>` at cleanup time catches what memory drops (it caught this one at 22:14, 94 min late).
5. **Non-deploy mutations have no wired smoke** — the repo's post-deploy checks are deploy-triggered; a manual stop-window mutation ends with ad-hoc verification only. A tiny `scripts/mutation-smoke.sh` convention (health + ingest tick + count probe) would close that for any future one-off.

## f) NEXT (up to 50 — only what this session's run surfaced; harvested per item)

**Verification (this mutation):**
1. Owner logs into `history.home.lan` once: Total visits ~4,959, heatmap Jan-Sep filled, era note ~2,276, Top domains now include the Helium+Firefox long tail — the acceptance test only the owner can run (g1).
2. Oct 15 02:15 backup: first through the hot mount (existing [watch] row) — additionally confirm it carries `owner=4,959+, zero=0` (persistence proof) — [harvested into the existing watch row's scope; noted here].
3. Gatus window check: did the browser-history check blip/page during 22:03:16-22:03:5x? If benign-blink, note the tolerance in the runbook mutation entry — [harvested, consolidated row below].
4. Re-check the dashboard hero range label (the "Aug 14" oddity from 21:47 §f29) now that owner min = Jan 1 — upstream label-source bug candidate.

**Tooling/docs (consolidated harvest — ONE [ready] row, services.md + TODO_LIST.md):**
5. Codify the stop-window mutation template (pre-count gate → consistent pool backup → tx UPDATE with `changes()` gate → post-gates → restore-on-fail → health-poll) as `scripts/` convention + runbook recipe.
6. Runbook live-probe recipe: add the sudo-inside-`bash -c` sqlite-on-DynamicUser-DB pattern (used twice tonight), the system `/run/current-system/sw/bin/sqlite3` binary (runbook still says `nix shell nixpkgs#sqlite` — stale), and the agent journal extraction lines (`raw=/kept=` per profile) as liveness evidence.
7. Post-mutation smoke convention: `scripts/mutation-smoke.sh` (health poll-until-200 + one agent tick + count probe) for any manual one-off.
8. Sanitized copy of tonight's re-attribution script into the runbook (the audit trail currently lives only in session prose).

**Upstream (queued):**
9. `reattribute` command (queued [ready] both surfaces) — build it, run it once, supersede the manual UPDATE.
10. Events-replay divergence: decide accept-as-documented vs pin with an upstream rebuild test (owner call, pairs with 9).

**Deliberately NOT harvested:** items 1-2 (owner-gated/covered by existing rows), 10 (owner decision pending), and everything from the 21-47 report's §f product list (still awaiting g1 answer). No new rows for observations already recorded in the 21-47 report.

## g) QUESTIONS FOR THE OWNER

1. **Log in and confirm:** does the dashboard now show ~4,959 total visits with the heatmap reaching back to January? (The only acceptance test I cannot run — DB-layer says yes.)
2. **The pre-op backup** (`manual-pre-reattribute-20261014-220316.sqlite`, 204 MB on the pool): keep it as the permanent rollback/audit point of a one-time mutation, or fold it into the 14-day backup rotation and let it age out?
3. **The events side still says zeros** (documented caveat): want me to build the upstream `reattribute` command NOW to make it durable, or is the documented caveat + queued row enough for a homelab that may never grow a rebuild feature?

**Waiting for instructions.**
