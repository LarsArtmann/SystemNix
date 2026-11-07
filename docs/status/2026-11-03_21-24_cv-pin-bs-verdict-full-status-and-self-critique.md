# cv pin "BS" verdict session — full status + self-critique (2026-11-03 21:24)

**Session window:** ~20:55–21:24 CET. **Trigger:** owner pasted the `lib/flake-input-pin-audit.nix`
cv allowlist row back with "this looks like BS!". **Scope:** this session's verification of that
claim, the corrections it produced, and this session's own errors. No unrelated research per owner
instruction.

**VERIFIED this session (with artifact):** every journal claim re-read from `journalctl -u cv-server`
(boots -2/-1/0 + since-10-25 histogram); generation→binary map from
`/nix/var/nix/profiles/system-{968..975}-link/etc/systemd/system/cv-server.service` ExecStart lines;
CV source at HEAD (`ff1798002`) vs pin (`16a656f4`) via `git show` file diff (panic site lines
105–120 byte-identical); commit content of 80c2c88 and the e168e6d..16a656f4 span; live unit state via
corrected `busctl` object path (`cv_2dserver_2eservice`); eval probe
(`nix eval …toplevel.drvPath` → green); `scripts/check-todo-system.sh` structure check (clean);
daemon commits `6d054b66c` + `b6379612a` carry the corrected content (verified via
`git show HEAD:<file> | grep`).

**NOT verified (and why):** real `pipeline.sqlite` size / `pipeline_events` row count —
`/var/lib/cv/data/` is `cv:cv` permission-denied for the agent shell (sudo blocked); growth is
proxied from journal per-cycle disk reads (~300 MB) and continuous sync logs. `cvagent.md` — never
opened (see §d3). CV repo's own `docs/status`/TODO for parallel-session work on the same bug — not
attempted. Gatus/alerting path for cv — not attempted (why 36 h of crash loop produced no visible
alarm is unknown). Whether rehydration can adopt the `after version` chunk query (`:395`) — assumed
from the signature, not wired. Cause of the fast exit-1 cycles (6 s exits at boot) — unexplained.
gen-974 deploy-time discrepancy (TODO row "15:46" vs link mtime 16:01:35) — noticed, not reconciled.

## a) FULLY DONE

1. **Pin rationale verdict: BS confirmed, claim-by-claim.** Five-row verdict table with evidence
   (80c2c88 attribution false — first SIGSEGV Nov 02 14:06 on cv@aa878d2, hours before the float
   existed; "green 18 h" false — 233 restarts/228 SIGSEGVs on the pinned build during deed9c84;
   window/cadence overstated; post-rollback panics identical on 16a656f4).
2. **Root cause to file:line.** `sqliteOperationTimeout = 5 * time.Second`
   (`career-pipeline/eventstore/sqlite_eventstore.go:65`) wrapping full-scan `All()` (`:405`,
   `ORDER BY timestamp` + full materialization) → deterministic rehydration deadline-exceeded once
   the table outgrew 5 s → chatstore lazy service stays nil → samber/do healthcheck probe
   nil-derefs `sessions_chatstore.go:112` (`addr=0x8`).
3. **Generation→boot→binary map** (gen-968…975): proves 80c2c88 deployed only Nov 03 16:01
   (gen-974), rollback gen-975 18:50, and that every panic through 18:29 ran 80c2c88 while the
   pinned rev had been looping since the previous day.
4. **Rev-independence proof:** panic site byte-identical `16a656f4 ↔ HEAD`; entire
   e168e6d..16a656f4 span is docs/chore commits; journal stack trace names the same file:line on
   Nov 02 (aa878d2 build, pc=`0x20d215c`).
5. **Onset attribution:** restart counter already 17 at first SIGSEGV (counter resets at the 08:12
   gen-969 cv restart → ~17 failures 08:12–14:06, binary unchanged) → state/data trigger crossed
   ~midday Nov 02, not a code change.
6. **Live state pinned:** cv-server **active/running** (pid 1760918 at 21:17) on the pinned gen-975
   build, alternating panic/degraded (3 SIGSEGVs in the 21:00 hour); CRM sync functional between
   panics.
7. **All 7 surfaces corrected** with the verified narrative: `flake.nix` cv comment,
   `lib/flake-input-pin-audit.nix` cv row, `modules/nixos/services/cv.nix` ROLLBACK paragraph,
   `docs/services/cv.md` incident-playbook entry (new SIGSEGV-loop class), `docs/todo/upstream.md`
   fix row (`[blocked:push]`), `TODO_LIST.md` queue one-liner (no drift), `CHANGELOG.md` entry.
8. **Evidence report** written: `docs/status/2026-11-03_21-15_cv-pin-verification-80c2c88-attribution-false.md`
   (cited by both queue surfaces — no dead links).
9. **Gates green:** `nix eval` toplevel drvPath probe green post-edit (two pre-existing unrelated
   warnings only); `check-todo-system.sh` structure clean (the 174 unharvested warnings are
   pre-existing drift from other sessions, not this one).
10. **Daemon commits verified to carry the corrections** (not just working-tree): `6d054b66c`
    (21:15:52: cv.md +14, upstream.md +1, flake.nix, pin-audit, cv.nix), `b6379612a` (21:18:58:
    tag/citation/timestamp fixes). CHANGELOG + TODO_LIST edits still dirty, awaiting next sweep.

## b) PARTIALLY DONE

1. **Data-growth measurement.** Growth proven indirectly (per-cycle ~300 MB disk reads, continuous
   `opportunity created` logs, onset correlation) but never measured directly: DB size and
   `pipeline_events` row count unknown (permission wall; readable alternatives — pool backups
   `pipeline-*.sqlite` — not yet tried).
2. **CRM :8091 slowness.** Observed (`find opportunities`/`create company` timeouts in backfill
   windows, crm-server up since 18:54) and documented as deliberately-not-harvested; not probed
   further — out of session scope per owner instruction.
3. **Interim mitigation.** Options identified (leave looping / stop unit / store shrink), none
   attempted — shrink is data-destruction territory (owner-gated), stop kills a service that is
   partially functional between panics. cv-server is STILL looping right now.
4. **Upstream fix.** Row queued with fix shape (nil-guard + chunked rehydration via the existing
   after-version query); zero code written; CV-repo parallel-work cross-check not done.
5. **Monitoring-gap assessment.** Catalog carries `healthPath=/health/live` for cv and a CV PDF
   Export gatus check exists, yet the 36-hour crash loop produced no owner-visible alarm (nsfw
   precedent: 239 invisible restarts). Why the alarm chain stayed silent — not investigated.
6. **Pin disposition.** Kept with corrected justification (build-hash stability); the alternative —
   drop the pin now since it protects nothing — deliberately not taken (re-lock would trigger a FOD
   vendorHash re-measure for zero functional gain). Defensible, but it IS a judgment call the owner
   may want reversed.

## c) NOT STARTED

1. The actual upstream CV fix (nil-guard `HealthCheck`; chunked/raised rehydration; regression test
   "rehydration-failure boot must stay alive").
2. The pin lift ritual (blocked on 1): drop pin + shim + allowlist row, re-lock, toplevel proof, deploy.
3. `pipeline_events` retention/compaction policy (owner data decision) + snapshot-before-shrink.
4. Gatus/alerting: crash-loop detection (systemd NRestarts-delta check) + audit of why nothing paged.
5. `cvagent.md` review; cv-agent unit/timer impact check (does it share the pipeline store?).
6. `GOMEMLIMIT`/`MemoryMax` retune for cv (subsumed by chunked rehydration, but unstarted).
7. gen-974 deploy-time reconciliation (15:46 claim vs 16:01:35 mtime).
8. Audit of the 2026-11-03 rollback session's "full battery" — how did it certify gen-975 green
   while cv-server was panic-looping? (post-deploy-check blind spot class).
9. Rehydration-duration metrics (so the next deadline miss is observable before it becomes a loop).

## d) TOTALLY FUCKED UP (this session's own errors)

1. **Phantom unit read.** Probed `busctl … /unit/cv_2dservice_2eservice` — that decodes to
   `cv-service.service`, which DOES NOT EXIST — and reported "cv-server inactive/dead". The journal
   then showed pid 1261031 logging. Caught within one tool round, corrected to
   `cv_2dserver_2eservice` → active/running. This is precisely the "an empty/failed read is never
   evidence" doctrine failing in my own hands; it would have poisoned the verdict had I not
   cross-checked against the journal tail.
2. **Wrong timestamp in evidence text.** Wrote "RETRACTED 2026-11-03 21:4x" into three load-bearing
   .nix comments when the actual time was ~21:0x–21:15; only caught by running `date` during the
   follow-up pass (21:17). A fabricated-precision claim in a retraction about fabricated claims —
   exactly the failure mode this session was policing. Fixed in `b6379612a`.
3. **Almost-dead Source link.** The first upstream.md row cited
   `…_21-4x_cv-pin-verification-…md` before that file existed under that name; the todo-system
   dead-link check would have flagged it (or the daemon would have swept a dangling citation).
   Fixed to the concrete filename before the sweep.
4. **Wrong intermediate hypothesis, disclosed.** Mid-session I hypothesized "80c2c88 never
   deployed" — the generation map then proved gen-974 (16:01) DID deploy it. Disclosed here
   because the intermediate wrong direction briefly shaped which checks I ran next; it never
   reached a written surface, but the lesson stands: map generations BEFORE attributing panics.

## e) WHAT WE SHOULD IMPROVE

1. **Run `date` before writing ANY timestamp into evidence** — the first tool call of an evidence
   session, not a later correction pass.
2. **Verify busctl/D-Bus object-path escaping before trusting a property read** (or fall back to
   `systemctl show`-equivalent probes); a nonexistent unit answers "inactive/dead" — indistinguishable
   from a real stopped unit without a second source.
3. **Open ALL sibling runbooks + units** (cv.md AND cvagent.md; cv-server AND cv-agent.timer) when
   investigating a service — the sibling file was one `ls` away and never opened.
4. **Check the fix-OWNING repo's docs/status for parallel sessions** before queueing fix rows (the
   CV repo may already have an agent on this).
5. **Measure the primary artifact before proxying it** — try the readable path (pool backups) before
   accepting a journal-line proxy.
6. **Claim-lint applies to my own prose too** — every date, count, and filename in a retraction
   needs the same verification as the claims being retracted.

## f) Up to 50 things to get done next (brainstorm, impact-ordered in groups; most route through HARVEST/ROADMAP, not auto-commitments)

**Upstream CV fix (the real unlock):**
1. Nil-guard/restructure `ChatstoreSessions.HealthCheck` (`sessions_chatstore.go:112`) so a
   never-resolved chatstore cannot SIGSEGV.
2. Decide degraded semantics: rehydration failure → warn-health + alive (recommended) vs clean exit-1.
3. Chunked rehydration using the existing `query event stream after version` API
   (`sqlite_eventstore.go:395`).
4. Bootstrap-scoped raised timeout for `All()` as the small-hammer alternative.
5. Regression test: rehydration-failure boot keeps `/health/live` answering.
6. Unit test: `HealthCheck` nil-safety.
7. Cross-check CV repo `TODO_LIST.md`/`docs/status` for existing rows on this bug (parallel-session check).
8. Implement + test locally in `~/projects/CV`.
9. Owner push permission → push to origin/master.
10. Capture `go version -m` + a journal goroutine dump as PR evidence.
11. Draft PR/issue body (github-voice) after verify-before-filing gate.
12. Emit a `rehydration_duration` histogram (make the next deadline miss observable).
13. Surface rehydration failure as warn (not pass) on `/health`.

**Data/store:**
14. Measure real `pipeline.sqlite` size via pool backups (`pipeline-*.sqlite`) — readable proxy.
15. Row-count `pipeline_events` on a backup copy (sqlite3, read-only).
16. Owner decision: retention/compaction policy for pipeline events.
17. Snapshot BEFORE any shrink (nightly backup verified current first).
18. One-off shrink to get under the 5 s window (immediate relief even before upstream lands).
19. Verify nightly backup freshness claim (14-day retention) still holds.

**SystemNix lift ritual (after 9):**
20. Drop the 16a656f4 pin + flake.nix comment + allowlist row.
21. Drop the bPvMOBEz vendorHash shim; re-lock past the fix.
22. Re-run toplevel proof; deploy.
23. Post-deploy: verify cv-server NRestarts stays flat across a boot.
24. Update cv.md runbook verification steps post-fix.

**Monitoring/why-nobody-knew:**
25. Audit why 36 h of crash loop raised no visible alarm (gatus catalog healthPath — was it failing
    silently? protectedVHost?).
26. Add crash-loop detection (NRestarts-delta or unit-failure-rate check) for cv-server.
27. Check `/health/live` behavior between panics (does it answer pass while degraded?).
28. Owner-facing impact statement: how long has the CV tile been flapping (Caddy 5xx scan).
29. Document the "invisible crash loop" recurrence (nsfw → cv) in monitoring docs.
30. Review remaining pin-audit allowlist rows for the same unverified-rationale pattern.
31. Hygiene check: does `~/.cache/lockfloat/float-proof-20261102-210359.log` claim runtime
    verification (it should be vendorHash-only)?

**Process/attribution loose ends from this session:**
32. Reconcile gen-974 deploy time (15:46 TODO-row claim vs 16:01:35 mtime).
33. Audit the rollback session's "full battery" — how did it pass with cv down? (post-deploy gap).
34. Annotate `docs/status/2026-11-02_18-27_…gen973…` if it claims cv green (stale-claim sweep).
35. Explain the fast exit-1 cycles (6 s exits at boot) — unexplained failure mode seen in journal.
36. Probe crm :8091 slowness (backfill-window-only?) as its own follow-up.
37. Review cv-agent unit/timer impact; open `cvagent.md`.
38. Decide pin disposition finally (keep-as-stability vs drop-now) — owner may reverse my call.
39. Lessons candidates for crush-config `references/lessons.md` (via commit, owner): busctl escape
    phantom-read; timestamp-in-evidence discipline.
40. Extend `docs/agents/systemd.md` busctl guidance with the concrete object-path escape trap.
41. docs-health VERIFY pass over the 7 corrected surfaces after the daemon sweep (claims vs code).
42. Confirm CHANGELOG/TODO_LIST dirty edits sweep cleanly (no daemon-race fragmentation).
43. Baseline panic cadence (panics/hour) now, for post-fix comparison.
44. Watch cv-server across the next reboot (does deed9c84-style boot still loop?).
45. Consider StartLimit documentation (cv-server currently restarts unboundedly — counter 17+ seen;
    is that intended?).
46. cv.nix: reconsider ExecStartPre CRM-wait usefulness under the storm class (it logged "starting
    anyway" paths).
47. Queue a "[watch] cv-server" stability row linking the evidence report.
48. ROADMAP: events-store scaling design (chunked queries everywhere, not just rehydration).
49. ROADMAP: CV store retention as product feature (prune/compact command).
50. Retro: add "run date first" + "second-source every live probe" to my own session checklist.

## g) Questions I can NOT figure out myself

1. **Push permission:** May I implement + test the CV fix locally and push it to CV origin/master
   myself, or do you want to review the diff / push personally? (The whole lift chain gates on this.)
2. **Data retention ruling:** `pipeline_events` has outgrown its access path. May old events be
   pruned/archived (with a snapshot first) to get back under a fast window — and if so, what
   retention do you want? Any shrink destroys pipeline history unless archived; that call is yours.
3. **Interim stance:** Until the upstream fix lands, do you want cv-server left crash-looping
   (partially functional between panics — my default), stopped (CV tile fully down, clean logs), or
   an immediate one-off store shrink attempted (needs Q2's ruling first)?

— Report ends. Waiting for instructions.

**Harvest log (2026-11-07, T03 wave — items HARVESTED):** DONE f.37 f.38 · already-tracked f.1-13 f.22-24 · OBSOLETE f.20 f.21 f.31 f.32 f.42 f.43 f.50 · NEW rowed: 15 rows → services 5, pipeline 5, monitoring 1, upstream 3, stability 2; f.40 merged into 15-06 §f.11 row
