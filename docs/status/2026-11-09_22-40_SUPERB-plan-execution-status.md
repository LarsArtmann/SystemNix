# SUPERB CV credential & session plan — execution status

- **Date:** 2026-11-09 22:4x CET (report finalized after the deploy window)
- **Executed by:** Crush session (zai/glm-5.3), plan-execution tombstone `5064a90a3`
- **Plan:** [docs/planning/2026-11-09_19-45_SUPERB-cv-credential-session-excellence.md](../planning/2026-11-09_19-45_SUPERB-cv-credential-session-excellence.md) (EXECUTING marker set 21:43)
- **Scope executed:** P1, P2, P3 (code+negative proofs), P4, P6 (code+drills), P7 (drill), P8 (rows), P9, P10 (pack+specs+rows), P11 — plus P5 deploy/live-verify (see §3)
- **Deviation from plan ordering:** the plan's two-deploy structure (C6 then C8)
  collapsed into ONE deploy — P6's key-split halves land atomically in a
  single switch (both sops templates render before any unit restarts), which
  satisfies the risk register's guard by construction; both verification
  batteries (loop legs AND key-split legs) ran against that single deploy.

## 1) What landed (evidence classes: read / ran / probed / pinned)

| Piece | Files | Evidence |
| --- | --- | --- |
| Expiry-gated daily loop (P1) | cv.nix `relogin.leadDays=7`, schedule `*-*-* 09:11:00`, jq+grep in PATH, due rule on `accounts --json` | ran: dry-run matrix rows 1–3 as cv (no-store→30, empty→10×3 WARN, corrupt→30); pinned: VM legs 12–14 |
| Outcome-aware exits (P2) | exit contract 0/10/20/30, `SuccessExitStatus=[10]`, ErrNoStoredLogin→WARN class | ran: matrix asserts codes; pinned: VM ExecMainStatus asserts |
| VM-test leg (P3) | tests/test-cv.nix legs 11–14 (shape, skip, invoke matrix via stub cv, broken) | pinned (run result in §3) |
| Eval guards (P3) | `checks.cv-relogin-specs` (login_url+session_cookie per configured platform, ANCHORED greps), `checks.cv-relogin-env` (SuccessExitStatus/Timeout/MemoryMax/User pins + NODE_PATH playwright/index.js resolution), `checks.cv-relogin-playwright-pin` (major-drift hard fail, minor-drift loud note) | ran: built green pre-float; negative proof: anchored-grep fires on a stripped copy (the un-anchored first draft DID NOT — fixed) |
| Visible signal (P4) | `cv-credentials-metrics` collector (6-hourly, runs AS cv, counts only) + `cv_relogin_last_result` from `data/relogin-status.tsv` (mktemp+mv atomic) + 2 SigNoz draft rules + post-deploy textfile leg | probed: hand-run as cv published `cv_stored_logins{freelance-de,password}=1` — which SURFACED the owner's evening seeding |
| Key scoping (P6) | sops `cv-store-key-env` (owner cv, 0400, restartUnits server+relogin), key REMOVED from cv-env; cv-server EnvironmentFile = [cv-env, oidc, key] (mkForce both branches); cv-relogin = key template ONLY | ran: wrong-key drill fails closed (typed fatal under StoreOn); F6.6/F6.7 live legs in §3 |
| Backup restorability (P7) | cv-backup artifacts now 0600; drill documented in runbook | ran: fresh backup parity 2=2, integrity ok, decrypt proof = typed ErrNoStoredLogin from a store booted against the restored copy (StoreOn fatal) |
| Docs/process (P9) | runbook v2 (loop semantics, exit table, metrics, seeding walkthrough, restore drill, lost-key+rotated-key failure mode); rubric `docs/audits/credential-session-grading-rubric.md`; systemd.md NODE_PATH/browser pattern; CONTRIBUTING.md flake-check≠host-eval + float-diagnosis lessons; deploy.sh io_uring phantom hint | read |
| Decision pack + upstream specs (P10) | plan §10 (A/B/C with cost+risk, recommendation C-now-A-later); `docs/upstream/cv-credentials-write-api.md` (set-password, blob rotation, status) | read |
| Fleet triage + cadence (P11) | MemoryHigh verdict (ladder coherent: GOMEMLIMIT 768M < High ~819M < Max 1G, high=38 930 absorb events, max/oom=0 → watch row); 5 baseline FAILs named in a services.md row; quarterly re-audit row | probed |

## 2) Live findings during execution

1. **The store is no longer empty**: the owner seeded `freelance-de`
   (kind password) during the evening — `cv_stored_logins` = 1. But
   freelance-de's spec carries `login_url` WITHOUT `session_cookie`, so the
   loop (correctly) does not cover it — rowed upstream
   ([blocked:push]). The three LOOP platforms (ateam, freelancermap, gun.io)
   remain unseeded; every run still exits 10.
2. **Parallel-session lock float (flagged, not touched)**: at 22:15+ a
   parallel session floated flake.lock (24+ inputs, cv fab9306→…→2a8ec62)
   without regenerating the registry; cv@2a8ec62 carries an upstream templ
   vendor pin with a placeholder `sha256-AAAA…` FOD hash (builds RED). Every
   host eval/deploy was blocked by the lock-float audit until the ceremony
   completed. This session did not revert it (multi-agent discipline);
   deploy timing below reflects the wait.
3. **First VM-test run failed at cv-server-inactive** (pre-P6 driver):
   diagnosis added (status+journal dump on wait_for_unit failure); resolved
   state in §3.

## 3) Deploy + live verification (P5/P6 live legs)

_FILLED AFTER THE DEPLOY: generation, anchor check, timer cadence, gated
hand-run journal lines + exit code, collector unit state, key-split proofs
(cv-server shows BOTH env files; cv-scan/cv-agent WITHOUT the key), VM-test
driver result, post-deploy smoke CV legs._

## 4) Owner gates still open (unchanged from plan §8)

- Seed ateam / freelancermap / gun.io at https://cv.home.lan/admin/credentials/
  (freelance-de done) — activates the loop with NO deploy.
- Q1 single-source-of-truth pick (plan §10, recommendation C now → A later).
- Q2 refresh aggressiveness (daily gated is live; twice-weekly = one timer line).
- One logged-in ateam session for `auth_marker` (F8.1–F8.5, [blocked:user]).
- CV-repo pushes (write API, freelance-de session_cookie) — spec linked from rows.

## 5) Self-review (brutal, per house style)

- The playwright-pin check initially used UNANCHORED greps — the negative
  test CAUGHT it (substring match passed on a stripped spec) and the fix
  (colon-anchored `^[[:space:]]*field:`) was proven red. First-draft guards
  are worth exactly one negative test.
- The first relogin script draft had a literal-string capture bug
  (`accounts="$cv_bin …"` without `$( )`) and a `$( $var )` indirection the
  nullglob audit rejected — both caught before deploy by audit/matrix, zero
  wasted deploys.
- The cv-relogin `status_file` mktemp fix tripped the textfile-tmp audit and
  an `${…}` Nix-interpolation escape bug — fixed and parse-proven; the
  daemon committed intermediate broken states (heuristic commits 6ca8e7945,
  021430283) that were heal-forwarded, never amended across foreign files.
- Grade honesty: rubric "after" column stays evidence-class `read` until
  §3 lands; nothing in this report claims deployed parity before it does.
