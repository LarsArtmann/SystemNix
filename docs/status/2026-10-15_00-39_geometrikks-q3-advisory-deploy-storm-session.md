# GeoMetrikks Status-Page Session Continuation: Q3 Ground Truth, Advisory Disposition, Deploy-Storm Endurance — Session Status

**Written:** 2026-10-15 00:39 CEST
**Session scope:** continuation of the 18:34/19:30 GeoMetrikks status-page fix sessions. Owner pasted two fresh page captures (Status page + Debug Logs). This session: answered the open Q3 (DB row counts) from the database itself, dispositioned the private-address advisory, fixed the §18 sweep's nix-daemon false positive, survived a 5-hour deploy storm (locks, gates, a sibling session's own deploy loop), repaired the boot anchor twice-class, root-caused the node-exporter journal spam, and closed out honestly rather than force anything. Parallel agent session(s) were live the entire time — attribution is called out wherever their work and mine touch.
**Format note:** status-report skill is HTML-canonical; user explicitly demanded `.md` at the timestamped path — override honored here once, not propagated (same ruling as the 19-10 report).

---

## a) FULLY DONE

| # | What | Evidence |
|---|------|----------|
| 1 | Baseline content-pin + live verify before any write: all 3 earlier session commits are ancestors of HEAD; geometrikks runs the patched venv; `/health` green pre-work | `git merge-base --is-ancestor` ×3 OK; PID 3139026 on `g5n5sbdiw…` venv; `/health` `missingFiles:[]` |
| 2 | **Q3 (DB `~0 rows`) answered from the DB, not the UI: NOT a defect.** Exact counts via `sudo -u postgres psql` throwaway (peer auth): `access_logs=0`, `geo_events=0`, `access_log_debug=1218` (+105 during probe); **0 chunks ever created** on both hypertables; persistence gated on `record.access_log` (`services/ingestion/service.py` `_process_record`), built only for GeoIP-resolvable IPs (`logparser.py:547-564`) — the app's own advisory text says private requests "never reach the map or Access logs". UI number = `approximate_row_count()` (chunk reltuples) | probe scripts /tmp/geometrikks-db-probe{,2}.sh outputs; source files read at `/nix/store/mxlwk7…-source` |
| 3 | **`APP_PROXY_ADVISORY=false` shipped** (traffic mix is deliberate LAN-direct; upstream `docs/configuration.md` prescribes false for deliberate mixes) + **`restartUnits` on the `geometrikks-env` sops template** — template-content changes previously never restarted the service (only secret rotations did) | `modules/nixos/services/geometrikks.nix` template block; live: `/health` `advisories:[]` after the 22:08 restart |
| 4 | **§18 sweep exempts `nix-daemon.service`** from its CPU leg (the 18:57 exit-3 was the deploy's own closure work + concurrent builds during the 10s sample) | `scripts/lib/service-sanity-sweep.sh:38`; `scripts/test-post-deploy-service-sanity.sh` → "all fixtures green"; live §18 CPU PASS in the 21:52 deploy's post-check |
| 5 | Caddy malformed-noise (paste #2) investigated and **deliberate-design verdict recorded** — the global `access.log` tail is the 2026-09-30 safety-net topology; upstream captures malformed unconditionally; module comment corrected (old "drops runtime lines harmlessly" claim falsified by live data) | `caddy.nix:408-429` rationale; corrected comment in `geometrikks.nix` logPaths block; runbook gotcha |
| 6 | Runbook: 3 new gotchas (`~0 rows` by design; debug-noise bounded; advisory toggle + restartUnits semantics) | `docs/services/geometrikks.md` Gotchas |
| 7 | CHANGELOG entry covering the whole status-page wave | `CHANGELOG.md` → "GeoMetrikks status-page accuracy wave (2026-10-14)" |
| 8 | Upstream harvest ×2: os.access availability-probe issue + malformed-capture filter idea — library rows + queue mirrors | `docs/todo/upstream.md` + `TODO_LIST.md` |
| 9 | **node-exporter ~448 lines/min root-caused live**: scraper broken-pipe spam (`error encoding and sending metric family … broken pipe`, 2,241 lines/5 min) — scraper times out on storm-slowed `/metrics`, then node-exporter errors per remaining write; storm-transient by mechanism. Enriched the existing monitoring row (no duplicate) | journal sample 00:34; `docs/todo/monitoring.md` row UPDATE |
| 10 | **UNANCHORED root-cause row enriched with the decisive datapoint**: the profile-set no-op fired TWICE more (mkg0p71f, 6hd6lr16) WITH the no-heavy-builds gate fully removed — shim/env_keep eliminated as causes; nh's profile-set leg (or a raw switch path) is the suspect | `docs/todo/pipeline.md` row UPDATE; deploy log `21-52-43` exit 14 |
| 11 | **Anchor repaired and verified**: profile-set + `switch-to-configuration boot` → `system-891` = `6hd6lr16` = `/run/current-system`, proven with `readlink -f` (first verify used bare `readlink` and false-alarmed — see §d); `nix run .#pre-reboot-check` → 20 passed / 0 failed | /tmp/anchor-repair.sh output; pre-reboot-check summary |
| 12 | **The "exit 0" in tonight's deploy logs unmasked as fake**: `21-19-14.log` was MY OWN attempt, job-killed mid-battery while holding the lock; the trap recorded 0. Would have closed rerun_now on a fabricated success | log tail: battery header → "1. Flake syntax validation" → `deploy exited code=0` with nothing between |
| 13 | **Deploy-loop economics corrected**: killed my own retry loop when the evidence showed each refused attempt burns a ~7-min battery of IO *feeding the storm it waits on*; guard tripped 5×/60 min at 00:34, so the trip-recency gate refuses regardless of PSI | `journalctl -u memory-emergency-guard` count = 5; PSI history in session |
| 14 | Gate-removal live-proof datapoint: bare `nix flake check --no-build` passes under 90% PSI (no shim refusal) — also falsifies the hermes-re-pin row's RED premise as of ~20:25 | job 07E output "all checks passed" |

## b) PARTIALLY DONE

| # | What works | What remains | Blocker | Effort |
|---|-----------|--------------|---------|--------|
| 1 | **rerun_now substance**: both fixes + sweep exemption are in the RUNNING system (carried by the operator's forced deploys ~22:08 and ~22:34; live `/health` verified) | A **clean exit-0 deploy** observed end-to-end; tonight produced zero real ones (all gate-refused or lock-refused) | Real IO storm: nvme0n1/sdb >100% util windows; memory-emergency-guard 5 trips in the last hour → trip-recency gate refuses regardless of PSI | S (at next calm window; nothing functional waits) |
| 2 | Post-deploy verification at API level (`/health` advisories `[]`, `missingFiles:[]`, ingestion counters climbing) | UI-level confirmation (the Status page card actually gone in a browser; Debug Logs behavior after next Caddy reload) | Needs a browser (owner) or a rendered-page probe | S |
| 3 | Upstream filings scoped and evidence-complete (os.access probe; malformed filter) | Actually **filing** — needs verify-before-filing re-check + github-voice drafting at dispatch time | Queued `[ready]`, deliberate (outbound-posture gates) | M each |
| 4 | Gate-removal TODO row: contributed live evidence (bare nix works; anchor class persists) | Row not closed — it belongs to the gate-removal session and its acceptance ("anchor check") explicitly FAILED tonight | Owning session's close-out protocol | S |
| 5 | My tree edits (module, sweep, docs) are in the working tree and provably built into the deployed generations (toplevel builds eval'd them) | Per-file **commit attribution** not audited — the daemon swept everything into heuristic commits; `git log --stat` audit not run for each | Daemon-race bookkeeping, cosmetic | S |

## c) NOT STARTED

Deliberately out of scope tonight, with reasons:

1. **Calm-window exit-0 deploy** — waiting on the storm; queued in §b1. Not forced (freeze doctrine: batteries wait).
2. **File the two upstream issues** — queued `[ready]` in `docs/todo/upstream.md`; needs the outbound gates (verify-before-filing re-check on current main, github-voice draft).
3. **node-exporter calm-window recurrence test** — queued `[ready]` in `docs/todo/monitoring.md`; storm-transient by mechanism, calm-window rate is the decider.
4. **UNANCHORED repro/trace** — `[blocked:user]` in `docs/todo/pipeline.md`; needs a journal-level trace of a failing nh profile-set (now with gate causes eliminated).
5. **`nix fmt` RED on `hot-db.nix` + `maintenance-entry-gate.nix`** — sibling session's IN-FLIGHT files; touching them mid-edit is the damage class AGENTS forbids. Their lane.
6. **boot-mirror resync** — pre-reboot-check advisory: mirror tree stale vs `/boot` after tonight's generations; fix is `systemctl restart boot-mirror-sync` (systemd action, advisory-only, sync timer also exists).
7. **UI verification of the advisory card** — owner's browser (or a rendered-page probe later).
8. **rpi3 dns-blocklists propagation check** — the ipify whitelist ships to both hosts; rpi3 verifies at ITS next deploy. Not tonight's deploy surface.
9. **sops-template `restartUnits` systemic audit** — tonight's find (env-only template changes never restarting services) is likely a CLASS across services; audit queued in §f.
10. **deploy.sh gate-ordering + anchor self-repair proposals** — authored into §f, not implemented tonight (deploy.sh is shared, sibling session had in-flight deploy-adjacent work).

## d) TOTALLY FUCKED UP

Radical honesty — all mine tonight:

1. **I launched deploys into a held flock. Twice.** My first `nix run .#deploy` (job 08C) and the v2 loop's early attempts all collided with the sibling session's deploy loop. The pre-flight check (`pgrep -f /bin/deploy` before launching) is trivial and I only adopted it hours in. Severity: wasted cycles + lock thrash for both sessions. Mitigation now: wait-for-lock-free phase added.
2. **I killed my own in-flight deploy that was holding the deploy lock** (job 094, attempt 5 → `21-19-14.log`). Worse: the death trap logged `deploy exited code=0`, and I initially read that as a PASS. It took reading the raw log tail (battery header → nothing → exit 0) to see it was a corpse. If I hadn't cross-checked, rerun_now would have been closed on a fabricated success — exactly the "assert WHICH entity served it" class AGENTS warns about. Root cause: no kill-discipline (check what a background job holds before killing) + trust in exit codes over evidence.
3. **My retry loop fed the storm it was waiting out.** ~11 attempts × ~7-min pre-deploy battery each (flake checks + evals) during a real IO storm on a freeze-prone box. The cheap guard-trip pre-check (one journalctl count that would have skipped every attempt) existed and I wired it hours late. Severity: contributed load during crash-#3-precursor-class windows.
4. **Verification predicate bug in my anchor repair**: compared `readlink profiles/system` (a symlink PATH) to the store path and printed ANCHOR-MISMATCH on a SUCCESSFUL repair. A wrong verifier is worse than none — it nearly triggered a redundant re-repair during a lock window.
5. **Wrapper instrumentation lies**: captured only `tail -6` of deploy output (couldn't see WHICH 2 checks failed on the 20:44 attempt — re-ran a full 7-min battery standalone to find out), and an awk field mislabel logged `avg60` as `psi`. Small, but they cost real minutes under pressure.
6. **The 2026-10-04 module comment my earlier session wrote was wrong** ("tailer drops runtime lines harmlessly by construction") — live data showed runtime lines land in `access_log_debug` as malformed (1,113 of 1,113). The claim pattern-verified against `parse()` but not against the capture path. Corrected tonight.
7. **Attribution gap left open**: the ~22:34 switch to `6hd6lr16` has NO deploy log covering it (all logged deploys in that window exited 12/13/14 without switching). Someone ran a raw switch path outside deploy.sh. I did not chase the actor (per the session-discipline /proc + crush.db protocol it is findable) — flagged in §f instead of resolved.

## e) WHAT WE SHOULD IMPROVE

1. **Pre-flight lock check before ANY deploy attempt** — one `pgrep -f '/bin/deploy'` saves a 13s cycle and a confusing code-13 line. Should be muscle memory; tonight it wasn't.
2. **Full-log capture in wrappers** — `tee` to a file, never `tail -N`. The 20:44 "2 failed" attempt was unreadable from my wrapper and cost a full battery re-run to diagnose.
3. **deploy.sh: run the cheap gates BEFORE the 7-minute battery.** The pressure/trip-recency gates run AFTER the full pre-deploy battery, so every guaranteed-refusal still spends ~7 minutes of IO. Reordering makes refused deploys ~10× cheaper during exactly the storms the gates exist for. (Proposal; deploy.sh is shared surface.)
4. **deploy.sh: add an anchor self-repair leg** — the AGENTS discipline (verify `readlink -f` profile == current-system; repair + pre-reboot-check) is currently manual and was needed twice tonight. Wiring it into the deploy tail turns a tribal ritual into an enforced gate.
5. **Verification predicates must assert the resolved thing**: `readlink -f` + explicit equality, never bare `readlink` string comparisons.
6. **Kill discipline**: before `job_kill` on anything, ask what locks/fds it holds (deploy lock, flock'd scripts) — a killed deploy mid-battery is how the fake exit-0 was born.
7. **Behavior-level proof for env changes**: tonight's APP_PROXY_ADVISORY proof is symptom-level (card gone). Stronger: read the process environ (root) or the rendered env file. Note for the verification checklist.
8. **Fast-path triage: read the app's OWN explanation first.** The advisory card literally said private requests "never reach the map or Access logs" — the ~0-rows mystery was half-answered in the paste itself; I went source-deep first (right evidence standard, wrong order).
9. **Storm etiquette between sibling sessions**: assume the other session is ALSO loop-deploying; minimum lock-sleep 300s (learned at loop v3 after thrashing at 120s).
10. **§18 journal-leg baselines**: node-exporter sits in the smoke baseline as a standing FAIL — while it does, NEW journal-rate regressions camouflage (the monitoring row already says this; tonight re-proved it live).

## f) Top 30 things to get done next (this session's observations only; ranked by impact)

**Harvested at authoring time:** items 1-2 were already queued earlier tonight (`docs/todo/upstream.md` + `TODO_LIST.md`), item 3 in `docs/todo/monitoring.md`, item 4 in `docs/todo/pipeline.md` — all enriched/updated, queue-library pairs intact. Items 5-7 are NEW actionable rows queued now (see below the table). **Items 8-30 are deliberately NOT harvested**: per the skill's larger-N rule they are brainstorm/ROADMAP fuel, most need owner decisions or calm windows; recording them here as a backlog snapshot, not commitments.

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 1 | File geometrikks os.access availability-probe issue upstream (patch exists; drop-once-fixed) | High | M | Bug/upstream |
| 2 | File geometrikks malformed-capture filter/knob suggestion upstream | Medium | M | Feature/upstream |
| 3 | Confirm node-exporter journal rate → ~0 in a CALM window; only then raise scrape_timeout / trim collectors | High | S | Bug |
| 4 | Root-cause nh profile-set no-op (gate causes eliminated tonight; needs repro/journal trace of the leg) | High | L | Bug |
| 5 | **NEW: reorder deploy.sh gates before the battery** (refusals become ~10× cheaper during storms) | High | S | Quality |
| 6 | **NEW: add anchor verify+self-repair leg to deploy.sh tail** (readlink -f equality; repair + pre-reboot-check automatically) | High | M | Quality |
| 7 | **NEW: audit all sops env templates for missing `restartUnits`** (env-only template changes silently not applied — tonight's find is likely a fleet-wide class) | High | M | Bug |
| 8 | Land the clean exit-0 deploy at the next calm window (closes rerun_now's formality; carries §a3/§a4 into a properly anchored generation) | High | S | Ops |
| 9 | Owner: UI-verify the advisory card is gone on `geo.home.lan/settings/status` | Medium | S | Verification |
| 10 | After next Caddy reload: assert `access_log_debug` grows by ~19 (validates the bounded-noise claim quantitatively) | Low | S | Verification |
| 11 | Watch: `access_logs`/`geo_events` get real rows once public traffic resumes (`approximate_row_count` starts meaning something) | Low | S | Watch |
| 12 | Attribute the ~22:34 raw switch to `6hd6lr16` (no deploy log covers it; /proc + `.crush/crush.db` forensics protocol) | Medium | M | Attribution |
| 13 | Re-sync boot-mirror after tonight's generations (`systemctl restart boot-mirror-sync`; pre-reboot-check advisory) | Medium | S | Ops |
| 14 | Fix `nix fmt` RED: `hot-db.nix` + `maintenance-entry-gate.nix` (sibling's in-flight files — THEIR session) | High | S | Quality |
| 15 | Close/update the gate-removal TODO row with tonight's evidence (gate live ✓; anchor class persists ✗) | Medium | S | Docs |
| 16 | Owner: InboxClean Google OAuth re-consent (inboxclean-sync still failed; existing blocked:user row) | Medium | S | Ops |
| 17 | Investigate the advisory summary string growth: `/health` showed "evo-x2 (100%) ×4" vs the UI paste's ×2 — does the source list accumulate stale entries over time? | Low | S | Bug |
| 18 | rpi3: verify ipify whitelist propagated at its next deploy (dns-blocklists.nix is shared) | Medium | S | Verification |
| 19 | Consider a `SYSLOG_IDENTIFIER`-level rate attribution in §18's journal leg (currently counts by unit; broken-pipe spam is node_exporter's own errors, not its scrapees') | Low | M | Quality |
| 20 | Sibling-coordination marker file for deploy intent (/tmp/.systemnix-deploy-intent with session id) to reduce loop-vs-loop thrash | Low | S | Tooling |
| 21 | Make the lock-holder detection in deploy.sh check /proc ALIVE against the log's own exit lines (a dead PID was reported ALIVE at 21:21 tonight) | Low | S | Bug |
| 22 | Verify the rendered env file contains APP_PROXY_ADVISORY=false at the environ level (root read of /run/secrets-rendered or /proc/PID/environ) — upgrade the symptom-level proof | Low | S | Verification |
| 23 | Queue geometrikks UI nicety upstream: show "0 (expected for LAN-only)" context next to `~0 rows` (links to the advisory) | Low | M | Feature/upstream |
| 24 | Audit whether OTHER EnvironmentFile-only units (oidc.env pattern) have the same env-change-no-restart trap as the sops template had | Medium | M | Bug |
| 25 | Consider deploy.sh printing the guard-trip count in the refusal message (it prints the override hint; the count explains WHY PSI looked fine) | Low | S | Quality |
| 26 | Sweep the two remaining 2026-10-04-era "verified against v0.19.0 source" claims in geometrikks docs for the same falsified-claim class (drop-claims verified against capture paths, not just parse paths) | Medium | M | Docs |
| 27 | After next calm deploy: re-run the FULL §18 battery and confirm `PASS 141+ / FAIL 0-new` (tonight's only post-check had the node-exporter journal FAIL) | Medium | S | Verification |
| 28 | Check whether the sibling's 22:08/22:34 deploys left any post-deploy §19/§17 legs unrun (both exited 12/14 before or during checks) — the standing post-deploy assertions haven't had a green full pass since 18:57 | Medium | S | Verification |
| 29 | Document the storm-deploy decision tree (refuse-12 vs lock-13 vs unanchor-14 + force semantics) as a runbook table in docs/agents/ (tonight's archaeology of deploy logs to learn exit codes should never be needed again) | Medium | M | Docs |
| 30 | Consider upstream geometrikks docs note: LAN-only deployments should expect `~0 rows` (the advisory covers the map, not the Database panel) | Low | S | Docs/upstream |

**Deliberately not harvested:** items 8-30 (except where a matching row already exists). Reasons: calm-window/owner-gated (8, 9, 13, 16, 27, 28), sibling-owned (14), upstream-outbound gates (2, 23, 30), watch/verification gated on future events (10, 11, 18, 22, 26), ideas needing owner sign-off before touching shared surfaces (19, 20, 21, 24, 25, 29), attribution exercise (12, 15, 17). They live in this report as the backlog snapshot; docs-health HARVEST may promote them later with routing rigor.

## g) Questions I can NOT answer myself

**Q1. The ~22:34 switch to `6hd6lr16` has no deploy log — was that you (or your other session) running a raw switch (`switch-to-configuration switch` / `nh os switch` outside `deploy.sh`)?**
What I tried: every deploy log 20:00-00:05 read tail-to-head (all that window's entries exited 12/13/14 without switching); /proc scans showed holders only for logged deploys; the anchor moved twice with the profile lagging both times. If it WAS a raw switch path, the UNANCHORED row's root cause is "switch mechanism that skips the profile", not "nh profile-set bug" — the whole investigation direction forks on this answer.

**Q2. rerun_now close-out: is substance-live enough, or do you want the exit-0 ceremony babysat?**
State: both fixes verified live, sweep fix proven in the one real post-check, anchor repaired and boot-audit clean. A clean exit-0 deploy requires a calm window (guard tripped 5×/hour at 00:34; the trip-recency gate refuses for ≥60 min after each trip). I can run a CHEAP pre-gated watcher (guard-trip count check before any battery, ~zero IO while refusing) overnight, or we let the next natural deploy close it. Which?

**Q3. Keep `APP_PROXY_ADVISORY=false` permanently, or re-enable after you've seen the card gone once?**
It is the canary for a future tunnel/proxy-fronting misconfig (the exact class that would silently zero out geo resolution). Your call defines the runbook's default posture; re-enabling later is a one-line revert.

---

## Evidence appendix (this session)

- `git merge-base --is-ancestor 98a4b2a4|471283ad|451b3c6d HEAD` → all OK (prior fixes intact).
- `pgrep -af geometrikks` → litestar/ granian on patched venv `g5n5sbdiw…`.
- `fetch http://127.0.0.1:8102/health` (×3 through the session): pre → advisory `proxy-peer-private`; post-restart → `"advisories":[]`, `missingFiles:[]`, parsed 9,47→15,338 climbing.
- DB probe (throwaway, `sudo -u postgres psql -d geometrikks`): `access_logs=0`, `geo_events=0`, `access_log_debug=1218`; `approximate_row_count` both 0; `pg_stat` n_live_tup=0/never analyzed; chunks = 0 for both hypertables, 1 for debug.
- Upstream source (store `mxlwk7…`): `service.py:512` (`if record.access_log:`), `logparser.py:547-564` (None unless GeoIP-resolvable), `docs/configuration.md` APP_PROXY_ADVISORY semantics.
- `nix flake check --no-build` (bare) → "all checks passed" under io some avg10≈90% (gate removal live).
- `nix build .#nixos…toplevel` → `l59invrn` (20:3x tree), `g5xmdzms`/`k6jr6ih3` (later trees — sibling churn).
- Deploy logs read: `21-09-16`(12), `21-19-14`(0-fake/killed), `21-21-18`(12), `21-30-29`(12), `21-39-52`(12), `21-52-43`(14 UNANCHORED, §18 CPU PASS + node-exporter journal FAIL, FORCE ×2), `22-05…23-56` (13/12 series incl. FORCE lines, none switching), `23-51-12`(1, 19s).
- Anchor: `readlink /run/current-system` vs `readlink -f /nix/var/nix/profiles/system` → both `6hd6lr16…` post-repair (system-891); pre-repair profile was system-890 with current-system at 6hd6lr16.
- `nix run .#pre-reboot-check` → "20 passed, 4 warnings, 0 failed — SAFE TO REBOOT" (advisory: mirror tree stale).
- `journalctl -u memory-emergency-guard --since -60min | grep -c` → 5; node-exporter: 2,241 lines/5 min, all `http.go:231 … broken pipe`.
- §18 sweep: `nix fmt` clean on my files (RED is sibling's `hot-db.nix`/`maintenance-entry-gate.nix`); `test-post-deploy-service-sanity.sh` → "all fixtures green".

**Then wait for instructions.**
