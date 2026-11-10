# SUPERB plan P5+P6 live close-out — deploy landed, batteries green

**Session:** 2026-11-10 00:02 → 05:33 CET (continuation of the 2026-11-09 SUPERB execution; resumed on the owner's "GET SHIT DONE" directive)
**Plan:** docs/planning/2026-11-09_19-45_SUPERB-cv-credential-session-excellence.md (EXECUTED tombstone added)
**Previous report:** docs/status/2026-11-09_23-48_FULL-status-SUPERB-plan-execution.md

---

## TL;DR

The blocked deploy landed as **gen-995 at 2026-11-10 02:24** (exit 3 on one new smoke failure = Bank-Sync's pending SCA bank challenge, owner-gated, not deploy-related). The P5 live battery ran at 05:22: **every leg green** — daily 09:11 timer, exit-10 unseeded semantics with clean journal lines, credentials textfile collector with live-mirroring metrics, exact key-split per unit file, cv-env keyless, store boot on the scoped key. P6 verified. The rubric "after" column is official (evidence class `probed`). One pre-existing VM-test breakage root-caused (cv-server's late-applications target absent in the VM since 2026-10-26) and fixed (4a1e40967).

## a) DONE this session

1. **Float blockade resolved** — both 23:37 and 00:05 float ceremonies died RED on the same upstream roots (bank-sync@40c1feb6's stale vendorHash.nix → go-modules FOD mismatch, plus the dnsblockd-af8abff cascade; roots files in ~/.cache/lockfloat/). The ceremony's own guidance ("pin that input back") was executed: flake.lock restored to the aeb919bbf pairing (cv=da7f3cbc — the exact gen-994 inputs) + the ceremony's registry revert kept; committed (rode 1242387e8 via daemon sweep; the revert is visible in that commit's diff and attributed here).
2. **The deploy landed via the box's own choreography** — the float session's /tmp/deploy-retry.sh loop (pressure-wait, 5-min cadence) caught the 02:07 window (io avg10 dipped <20 for the first time in 3.5h); validation + build + switch completed 02:24:07–02:24:25; anchor verified: readlink /run/current-system == system-995-link target (a51w2six…, nixpkgs f9a75f4 = same as gen-994, as the restored lock predicted).
3. **P5 battery (05:22, all green)** — see TL;DR. Notables: cv_relogin_last_result{platform}=10 with age_seconds 0–1 proves the collector mirrors the relogin status tsv in the same cycle; the timer shows NEXT 09:11 (daily cadence live); the three loop platforms each journal `state=none expiry=- -> skip (unseeded; seed at https://cv.home.lan/admin/credentials/…)`.
4. **P6 verified live** — cv-credentials-metrics.timer started at switch; hand-start exit 0; .prom contains cv_stored_logins{freelance-de,password}=1 (the only seeded platform, correctly NOT loop-capable), the three result mirrors, scrape_errors 0. Post-deploy smoke leg "CV - credentials metrics publishing" **PASS** in the deploy log. Key-split: cv-server = cv-env + cv-oidc client-secret + cv-store-key-env; cv-relogin = cv-store-key-env ONLY; cv-scan/cv-agent = cv-env only (master key scoped to exactly 2 readers). cv-server journaled `credentials store booted activeKeyID=v1 keys=1` at the switch.
5. **Smoke baseline comparison** — 5 FAILs vs gen-994's 6, 167 passes vs 156: forgejo-runner and timers.home.lan HTTPS **recovered**; retained known items (Health Hub 503, borg tripwire binary, sanity CPU crm/tq, sanity journal node-exporter). The ONE new failure triaged: **Bank-Sync `sync_errors_total > 0` = the Wise SCA challenge is pending** ("statements paused pending SCA approval — Run 'bank-sync sca approve'"): owner-gated bank-side auth, same bank-sync rev as gen-994, unrelated to the deploy. Rowed below.
6. **VM-test root cause + fix** — cv-server's `wantedBy = mkForce [ "late-applications.target" ]` (2026-10-26 ordering-cycle trim) references a target that exists only in host config; the VM test imports the flake module alone → nothing ever pulled the unit ("inactive, no pending jobs" — exactly the observed signature). Broken since 10-26 and invisible because checks run `--no-build`. Fixed test-scoped (4a1e40967): pull via multi-user.target. Live driver run blocked by a parallel session's in-flight `timesheets` input lock drift (infra-follows audit) — CI will execute the test on push.
7. **Runaway IO source killed** — a `sudo find / -name key.txt -path *sops*` from 22:30 (2.5h in D-state, full-filesystem scan over the 14.6T pool) was killed by explicit PID; it was NOT the dominant driver (PSI unchanged) but was pure waste.
8. **Rows/rubric/plan updated** — services.md key-scope row LIVE-VERIFIED note; rubric "after" column official (D1/D2/D4 `probed`, D5 `pinned`, D6 `ran`, D3 owner-gated); plan EXECUTED tombstone.

## b) OWN ERRORS (the discipline section)

1. **I raced a live ceremony**: my 00:06 lock restore executed while the 00:05 ceremony was mid-proof — its sha-guard would have discarded the green commit anyway (proof went RED on the roots regardless, so no green proof was lost, but the ceremony's commit path was poisoned by me). The check that would have prevented it: `pgrep` for float-register/deploy immediately before ANY lock write, not only at session start. The pre-commit hook caught my own inconsistent commit 3 minutes later (registry had moved under me) — the guards worked, my sequencing didn't.
2. **Commit subject over the 72-char house limit** (86) — one wasted hook cycle; fixed by shortening.
3. **Two broken ad-hoc IO-attribution one-liners** (cgroup joins with reset counters, a /sys sampler with a path bug) produced garbage MB/s numbers — recognized and discarded, never quoted (the quote-scrutiny rule applied to myself). The deploy gate's own device-truth crosscheck was used instead.

## c) STILL OPEN (owner-gated or by-design)

1. **§10 decision pack** (single-source-of-truth A/B/C + refresh aggressiveness) — owner questions g.3 from the 23:48 report.
2. **Seeding** ateam/freelancermap/gun.io (services.md row 1039) — the loop is inert-safe until then (exit 10 by design). freelance-de seeded but not loop-capable (upstream row).
3. **auth_marker**: one ateam live session for the auth_marker verification (P8 owner leg).
4. **Bank-Sync SCA approval** (`bank-sync sca approve` / wise.sca_approval_token) — clears the only new smoke FAIL; then the deploy exit-3 class disappears.
5. **CV-repo pushes** (spec + freelance-de session_cookie) + the write-seam spec (docs/upstream/cv-credentials-write-api.md) — upstream work.
6. **VM-test live run** — blocked on the parallel timesheets lock settle; fix committed, CI will run it.
7. **Push to origin** — owner-gated per house rules (tree carries 5+ sessions' work; never push without explicit instruction).

## d) Evidence anchors

Deploy log /var/log/systemnix-deploys/2026-11-10_02-07-39.log (switch summary names cv-credentials-metrics.timer among new units; smoke PASS lines incl. the CV textfile leg; exit 3 footer names Bank-Sync); anchor probe readlink pair (a51w2six…); battery transcript in session (05:22); cv-server journal 02:24:12 `credentials store booted activeKeyID=v1 keys=1`; bank-sync journal 02:36:57 SCA WARN; roots files ~/.cache/lockfloat/float-roots-20261109-235034.md + float-roots-20261110-001627.md; commits: pairing (rode 1242387e8), VM fix 4a1e40967, rubric/services/plan updates (this session, docs).
