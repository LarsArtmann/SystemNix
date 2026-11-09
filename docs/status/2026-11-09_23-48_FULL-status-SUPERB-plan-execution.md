# Full status update — SUPERB CV credential & session plan execution

- **Date:** 2026-11-09 23:48 CET
- **Session:** Crush (zai/glm-5.3), tombstoned execution of
  [docs/planning/2026-11-09_19-45_SUPERB-cv-credential-session-excellence.md](../planning/2026-11-09_19-45_SUPERB-cv-credential-session-excellence.md)
- **Supersedes:** the 22:40 working draft (`2026-11-09_22-40_SUPERB-plan-execution-status.md`,
  §3 was a placeholder — this report is the full accounting)
- **Session instruction:** report, then WAIT for owner instructions (no
  deploy, no lock action taken while a parallel deploy is mid-flight)
- **Live system state at report time:** gen-**994** (the 21:15 parallel
  deploy, tree as of 21:15 = BEFORE this session's code), anchored OK. A
  parallel session's 23:37 deploy is **mid-gate with a RED float proof**
  (`float-proof-20261109-233745.log` ends "Reason: 1 dependency failed" —
  the cv@2a8ec62 templ placeholder-hash FOD). Lock: cv `2a8ec623`, registry
  regenerated + committed by that session at ~23:37. IO PSI ~36% and
  falling. 3 further heavy check-builds from other sessions are running.

## a) Fully done and verified

| Item | Proof (evidence class) |
| --- | --- |
| **P0 tombstone** — plan marker + immediate commit (`5064a90a3`) | read |
| **P1 expiry-gated loop** — `relogin.leadDays=7` option, daily `*-*-* 09:11:00` schedule, jq+grep in unit PATH, due rule (`sessionState != fresh` OR `earliestExpiry` within lead) on `cv profile accounts --json`, per-platform journal lines | **ran**: dry-run matrix as `cv` against the rendered script — row 1 no-store → exit 30 "sealed store missing"; row 2 empty store → 3 unseeded WARNs → exit 10; row 3 corrupt db → exit 30 "could not read" (all rc-captured, output in session) |
| **P2 outcome-aware exits** — contract 0/10/20/30, `SuccessExitStatus=[10]` (unseeded = green, never pages), `ErrNoStoredLogin` output-grepped to WARN-class, 2FA/drift → 20 with runbook pointer | ran: matrix asserts codes; the F2.2 sentinel is the verbatim upstream error text (CV relogin.go:23) |
| **P3 eval guards** — `checks.cv-relogin-specs` (per configured platform: spec file exists + ANCHORED `login_url:`/`session_cookie:` greps), `checks.cv-relogin-env` (SuccessExitStatus=[10], TimeoutStartSec=1200, MemoryMax=3G, User=cv, EnvironmentFile≠[], NODE_PATH resolves `playwright/index.js`, store-enabled env), `checks.cv-relogin-playwright-pin` (major-drift hard fail, minor-drift loud note — currently prints the CV `^1.65.0` vs nixpkgs `1.64.1` drift) | **ran**: built green pre-float; **negative-proven**: the FIRST draft's un-anchored grep PASSED on a stripped spec (rc=0, want 1) — caught and fixed to colon-anchored, re-proven rc=1 |
| **P4 visible signal** — `cv-credentials-metrics` collector (6-hourly oneshot, runs AS `cv`, reads the 0700 store natively, mktemp+atomic-mv into the sticky textfile dir): `cv_stored_logins{platform,kind}`, `cv_relogin_last_result{platform}` (0/10/20 mirror), `_age_seconds`, `cv_credentials_scrape_errors` fail-closed; status source `data/relogin-status.tsv` written by the relogin script (mktemp+mv); 2 SigNoz draft rules (`CV Relogin Loop Unseeded` with `or vector(0)` absent-series handling, `CV Credentials Scrape Broken`); post-deploy-check textfile leg (first-window WARN-aware) | **probed**: hand-run as `cv` published a valid `.prom` — which surfaced the owner's evening seeding (`cv_stored_logins{freelance-de,password}=1`) |
| **P6 key-scoping code + drills** — new scoped sops template `cv-store-key-env` (cv:cv 0400, restartUnits cv-server+cv-relogin), `CREDENTIALS_MASTER_KEY_V1` REMOVED from `cv-env` (cv-scan/cv-agent lose it automatically), cv-server EnvironmentFile = [cv-env, oidc, key] / [cv-env, key] both branches, cv-relogin = key template ONLY; VM test mock added | **ran**: wrong-key drill via `systemd-run -p EnvironmentFile` (no secret on any command line) fails CLOSED — typed fatal error under `CV_CREDENTIALS_STORE_ENABLED=1` |
| **P7 backup restorability** — cv-backup artifacts now chmod 600; full drill: fresh backup (22:19) parity 2=2 events + `integrity_check ok`; decryptability proof = store booted against the restored copy (StoreOn fatal) returned the TYPED `ErrNoStoredLogin` for ateam — i.e. restored db decrypted + read-model readable; runbook documents the drill incl. the cv-ownership/-shm trap and the rotated-key-after-backup failure mode | ran (all rc-captured) |
| **P8 owner-gate prep** — freelance-de finding rowed `[blocked:push]` (spec lacks `session_cookie` — the seeded credential cannot loop); ateam `auth_marker` row already `[blocked:user]`; both linked from TODO_LIST | read |
| **P9 docs/process** — runbook v2 (daily expiry-gated semantics, exit-code table, metrics paragraph, seeding walkthrough with exact clicks, restore drill, lost-key+rotated-key mode); grading rubric `docs/audits/credential-session-grading-rubric.md` (D1–D6, weights, evidence classes read/ran/probed/pinned, baseline + after-tables); systemd.md NODE_PATH/browser-automation pattern; CONTRIBUTING.md `flake check ≠ host eval` + float-diagnosis lessons; deploy.sh io_uring phantom-class hint (D-state≤1 + idle disks branch); post-deploy-check CV metrics leg | read (scripts syntax-checked `bash -n`) |
| **P10 decision pack + specs** — plan §10 owner pack (A blob-canonical / B file-canonical / C staggered, cost+risk each, recommendation **C now → A when upstream lands**); `docs/upstream/cv-credentials-write-api.md` full spec: `cv credentials set-password` (flags/prompt/exit codes/no-secret-in-argv), post-relogin `session_blob` rotation flow (WARN unless stale-blob-under-active-store → fail), `cv credentials status` JSON shape; upstream rows updated with links | read |
| **P11 fleet triage** — cv-server memory verdict: ladder COHERENT (GOMEMLIMIT 768MiB < MemoryHigh ~819MiB < MemoryMax 1GiB; live ~686MiB; `memory.events high`=38 930 absorb-events, `max`/`oom`=0) → `[watch]` row, not a bug; the 5 pre-existing smoke baseline FAILs named in a services.md row (forgejo-runner INACTIVE, Health Hub 503, Offsite Borg tripwire, CPU sanity crm 197%/tq 203%, node-exporter journal rate) — with the note that the baseline FILE is rewritten each run so the names live in the row; quarterly re-audit `[watch]` row linked to the rubric | probed (cgroup/journal reads) |
| **Todo-system discipline** — every closed item ticked in BOTH TODO_LIST.md and its domain library (services.md/upstream.md) with DONE + evidence; new rows added to both surfaces; the 22:40 draft report self-harvests §f follow-ups via those rows | read |

## b) Partially done (code complete, final proof blocked)

1. **P3 VM-test RUN** — legs 11–14 written into `tests/test-cv.nix` (unit
   shape; seed-gate skip → ExecMainStatus=10 + stub NOT called; invoke
   matrix via stub cv — ateam stale → refresh, gun.io fresh+2d → refresh,
   freelancermap fresh+far → skip-not-due; corrupt → ExecMainStatus=30)
   with a boot-failure diagnostic dump. **Blocked twice**: first run failed
   at `cv-server.service` inactive-no-jobs (cause NOT yet diagnosed — see
   d.1); rebuild then blocked by the parallel float (cv@2a8ec62's templ FOD
   is unbuildable, and the VM closure builds the locked cv package).
2. **P5 deploy + live battery** — battery script ready
   (`~/.cache/cv-p5-battery.sh`: anchor, timer cadence, gated hand-run,
   collector start, key-split EnvironmentFiles proof, cv-env keyless proof,
   cv-server store-boot journal). **Blocked**: host eval/deploy is held by
   the parallel float ceremony (below).
3. **P6 live verification** (F6.6/F6.7) — rides the same deploy.

## c) Not started (deliberately)

1. **The deploy itself** — two deploys ran tonight, both by OTHER sessions
   (21:15→gen-994 exit 3 pre-existing flake; 23:37→mid-gate RED proof). Mine
   was never fired: blocked first by IO PSI, then by the float gate.
2. **C19 close-out tail** — final report numbering (this report serves it),
   `scripts/check-todo-system.sh` re-run, push to origin. Push NOT done
   (deliberate: mid-flight parallel deploy + your instruction to wait).

## d) What went wrong / got fucked up (honest accounting)

1. **First VM test failed undiagnosed** — `cv-server.service` inactive with
   no pending jobs at boot (driver built from the pre-P6 tree). Root cause
   NOT found yet; I added a status+journal dump to the failing wait and
   parked the rerun behind the float. Suspicion (unproven): an
   EnvironmentFile list-concatenation interaction between the test's
   `mkForce` mock and the module's mkForce entries pointing at a mock path
   that does not exist in the VM.
2. **Two pre-commit hook rejections on my own drafts** — (i) nullglob audit
   class B (`$( $var )` indirection — fixed with a `run_cv()` function);
   (ii) textfile-tmp audit (fixed-name `.tmp` redirect — fixed with
   mktemp). Both were the audits WORKING; both fixes landed before any
   deploy. Zero wasted deploys tonight.
3. **Two of my own bugs caught by my own gates before deploy** — a
   literal-string capture (`accounts="$cv_bin …"` missing `$( )`) and a
   Nix-interpolation escape bug (`${status_file}` needed `''${…}`). Both
   found by parse/matrix, fixed immediately.
4. **Daemon committed my broken intermediates** — heuristic commits
   `6ca8e7945`, `021430283` carry pre-fix states; healed forward, never
   amended across foreign files. The commit trail tonight is
   daemon-heavy (my 4 clean commits: `5064a90a3` tombstone, `21faaac57`
   P1+P2, and two more eaten by races into daemon batches).
5. **The negative test beat my first draft** — my spec guard initially used
   un-anchored greps and PASSED on a stripped spec; only the F3.11 negative
   leg caught it. Lesson recorded in the report and rubric: first-draft
   guards are worth exactly one negative test.
6. **Parallel-session blockade (flagged, NOT touched)** — timeline: 21:15 a
   session starts a deploy (78 min, activates gen-994 at 22:23, exits 3 on
   a pre-existing `systemd-timer-monitor` baseline regression); 22:15 a
   session floats flake.lock 24+ inputs (cv fab9306→40c1feb→2a8ec62) and
   its 22:14 deploy attempt is refused exit 13 (lock held); 23:37 a new
   deploy runs the float ceremony — registry regenerated + committed, proof
   **RED** (`templ-0.3.1070` source FOD `specified: sha256-AAAA…` = upstream
   placeholder at cv@2a8ec62 — unbuildable by construction). That deploy is
   mid-gate at report time. My morning-revert precedent was NOT applied to
   their live float per multi-agent discipline.
7. **My one process call to flag**: I wrote the P5 battery script under
   `~/.cache/` (durable, not /tmp — correct) but have NOT executed any of
   it, correctly, while another deploy is mid-flight.

## e) What got BETTER because of this run (improvements shipped)

1. Sessions stop dying on the calendar → the loop is now condition-driven
   (the actual customer outcome; the 19:30 audit's D2 grade 0 → 9 pending
   the deploy proof).
2. "Unseeded" is now a SIGNAL, not a journal line: metric + SigNoz draft +
   post-deploy leg (D4).
3. Every loop claim now has a pin that can fail: VM legs, 2.5 eval checks,
   negative-proven guard semantics (D5).
4. The store master key's blast radius shrank from 4 consuming units to 2
   (D1).
5. The credentials backup is now PROVEN restorable (not just "a file
   exists") and artifacts are 0600.
6. The next audit is comparable: rubric + quarterly cadence row (D3/D6
   decisions documented with a recommendation).
7. Two durable process lessons entered the canon (`flake check ≠ host
   eval`, float-diagnosis-is-a-registry-diff) + the io_uring phantom hint
   in deploy.sh.
8. CV upstream work is now unblocked-by-spec: the write API is specced to
   implementable detail, linked from the blocked:push rows.

## f) Next things (ordered, up to 50 — ready unless marked)

1. Wait for the 23:37 parallel deploy to conclude (RED proof ⇒ it must
   revert lock+registry together or fix upstream-first).
2. After the tree settles (clean + no eval-relevant mtime < 5 min × 4
   polls): re-run the relogin dry-run matrix against the FINAL script.
3. `nix flake check --no-build --all-systems` (capture to file, grep after).
4. Toplevel `--keep-going` build (capture).
5. `nix run .#deploy` (respect PSI; record util% + D-state if forced).
6. Run the P5/P6 battery script (anchor, timer, hand-run, collector,
   key-split proofs).
7. Diagnose + fix the VM-test cv-server-inactive failure; run the driver
   green (legs 11–14).
8. Hand-run `cv-credentials-metrics` post-deploy; verify the .prom content.
9. Verify `systemctl show cv-scan cv-agent` — no key template in
   EnvironmentFiles.
10. Verify `journalctl -u cv-server` shows store boot after the key split.
11. Post-deploy smoke: CV legs incl. the new textfile metric leg.
12. Update the 22:40 draft report §3 / write the deploy close-out section.
13. Tick TODO rows that said "rides the next deploy" (P6 row, F5 items).
14. `scripts/check-todo-system.sh` (queue/library pairing).
15. `nix run .#pre-reboot-check` only if a reboot is ever planned.
16. Push to origin (after your go-ahead; tree carries 4+ sessions' work).
17. Owner: seed ateam / freelancermap / gun.io passwords (freelance-de
    already done) — activates the loop with NO deploy.
18. Owner Q1: single-source-of-truth pick (plan §10; recommendation C now →
    A later).
19. Owner Q2: refresh aggressiveness (daily gated is live; twice-weekly is
    one timer line if the portals object).
20. Owner Q3: the 24-input float — accept the registry-committed state or
    direct a revert (it's the parallel session's call first).
21. Owner: one logged-in ateam session → auth_marker selector (F8.1–F8.5).
22. CV repo: `freelance-de` `session_cookie` pin ([blocked:push] row).
23. CV repo: write API per `docs/upstream/cv-credentials-write-api.md`
    ([blocked:push]).
24. CV repo: stale "relogin runs operator-side" docs line ([ready] row).
25. After upstream write API lands: adopt `cv credentials status` in the
    collector (drop the sqlite schema dependency).
26. After blob rotation lands: flip decision A (blob canonical) + projector.
27. Watch `cv_relogin_last_result` first REAL seeded run (the [watch] row).
28. Watch cv-server `memory.events high` rate (row added; raise MemoryMax
    if max/oom ever fire).
29. The 5 named baseline FAILs: each deserves its own root-cause dispatch
    (forgejo-runner, Health Hub, Offsite Borg, CPU thresholds, journal
    rate) — none caused by this work.
30. `systemd-timer-monitor` HTTPS new-baseline regression (from the 21:15
    deploy's exit 3) — triage before the next deploy's baseline absorbs it.
31. Reconcile with the OTHER sessions' in-flight work before pushing (the
    float, the check builds).
32. Quarterly re-audit trigger is armed ([watch] row + rubric baseline).
33. Consider `relogin.metrics` collector interval tuning if 6h proves
    too coarse for the unseeded alert's 7d window.
34. Playwright minor drift (1.64 vs ^1.65): watch nixpkgs, or ask CV to
    re-pin; the check names it every flake check until then.
35. VM-test leg for the collector (currently live-proven only) if it grows
    logic.

## g) Questions I cannot answer myself (max 3)

1. **The parallel float (Q3 in the plan):** the 23:37 deploy's proof is RED
   on cv@2a8ec62's templ placeholder hash. Do you want me to (a) let that
   session finish its ceremony (revert-or-fix is its move), (b) take over
   the revert to the last proven graph once its deploy dies, or (c) wait for
   your explicit call? I did not touch it.
2. **Deploy timing:** my P1–P6 work is fully committed but NOT deployed
   (gen-994 predates it). The moment the tree settles and you say go, I run
   the battery and the close-out. Do you want the deploy tonight or in a
   calm morning window?
3. **Q1/Q2 owner gates** (from the plan, still open): single session store
   of record (A/B/C — my recommendation: C now, A when the upstream write
   API lands), and refresh aggressiveness (daily gated is what's coded).

_Standing by. No further actions until your instructions._
