# Offsite-Borg Tripwire Session — Full Status + Self-Review

**Date:** 2026-11-15 13:46 CET
**Scope:** the owner-pasted post-deploy §16 FAIL (`Offsite Borg - tripwire binary not executable/missing`) triaged, root-caused, fixed, verified, documented; deploy attempted three ways (own watcher, two foreign attempts) and still NOT landed — blocked by PSI storm + a foreign storage-collector FOD breakage.
**HEAD at writing:** 91d701c4b (working tree clean; every session artifact daemon-swept into git: 4f687f460 fix, e12b96fbb queue rows, 91d701c4b report edits + row annotations).
**Companion report:** docs/status/2026-11-15_12-55_offsite-borg-tripwire-203-nine-night-outage-fix.md (evidence chain, fix surfaces, class audit).

## Self-review first: what I forgot, what I did wrong

1. **Probe order was backwards.** The live unit file + `journalctl -u borgbackup-job-hetzner` would have settled the whole question in ONE command ("the unit carries a dead path; the job 203s nightly"). Instead I spent three tool calls on queue rows and the smoke lib before touching ground truth.
2. **I saw the smoke fixtures carrying the broken shape and did nothing.** `scripts/test-offsite-borg-smoke.sh:103-127` feed `ob_pre_deploy` fixtures whose ExecStartPre is the BROKEN `<file>/bin/<name>` form. Grep-based, so they pass either way — but the fixtures teach the wrong canonical unit shape to the next editor. Queued only now (row added at this report's authoring).
3. **I never built `offsite-borg-smoke-selftest`** (the flake-check twin of the bash fixture I ran). Only the bash fixture (21/21) and `offsite-borg-positive-render` got built. Queued now.
4. **Nine nights of `Triggering OnFailure= dependencies` in the journal and I never asked "did anyone get PAGED."** Delivery receipt (Discord leg) unverified; possibly a second silent layer on the only offsite copy. Queued now.
5. **Same class: no check that a SigNoz rule exists on `backup_healthy{offsite-borg}=0` / `backup_age_hours=999`.** That metric sat at dead-values for 9+ days with (apparently) no page — if no rule exists, staleness alerting for the offsite leg is missing entirely. Queued now.
6. **I saw `backup_ever_succeeded{backup="audiblesync"} 0` alongside `{backup="audible-sync"} 1` in the backups.prom grep and flagged it NOWHERE** — a duplicate/stale registry row pair, real finding, dropped on the floor during the evidence pull. Recorded here + in §f.
7. **The hygiene-bundle queue row cites docs/todo/services.md but has NO twin there** (rg for pipewire/mainProgram/ghost-subdomains over docs/todo/ = empty). I noticed the empty result, flagged nowhere. Pre-existing queue/library drift; queued now.
8. **My verification-green basis predates the two newest foreign commits.** My evals + check build ran ~12:50-12:52; d1eed8cd9 (cv+monitor365 input refresh) landed after. I did not re-prove `nix flake check` on the current tree (it currently CANNOT pass — see §b) — so "my files still render the flat path on HEAD" is argued from file-disjointness, not re-proven by eval.
9. **I hand-rolled a PSI watcher instead of using `scripts/deploy-when-quiescent.sh`** — productized literally TODAY (c99ad93bb) with rc-classified firing and lock-retry logic. Mine worked (validated the parse on one known value first, never forced) but duplicated repo tooling.
10. **Three sloppy probes shipped no wrong data but wasted cycles:** `test -x … 2>&1 | head -1` (test prints nothing — pointless pipe), a diskstats awk with wrong field offsets (printed all-zeros — caught as implausible, NOT quoted anywhere, per quote-scrutiny), and a malformed `find -o` cgroup sweep that returned empty after one attempt with no remediation retry.
11. **Two edit-tool failures** (read-before-edit via bash sed doesn't count; long-line transcription mismatch) — the exact traps AGENTS.md documents. Recovered correctly via line-number replacement with anchor assertions, but they were avoidable.

## a) FULLY DONE

| Item | Evidence |
| --- | --- |
| Root cause identified + proven at three layers | deployed unit line 24 (`/bin/` form); tree eval rendered the same `/bin/` form (current tree was broken too); journal 203/EXEC `Unable to locate executable …: Not a directory` every nightly 06:30 fire Nov 07 → Nov 15 (9 fires, incl. the post-boot Nov 15 fire) |
| Root fix landed | `backup.nix:316` → `ExecStartPre = "${goliveCheck}";` (writeShellScript single-file drv interpolated directly; getExe AND getExe' both append `/bin/` — the 2026-11-07 "fix" was a no-op). Commit 4f687f460 (daemon-swept, contents verified: exactly the 3 fix files) |
| Eval-time class guard | `offsite-borg-positive-render` gained `assert !lib.hasInfix "/bin/" …` on ExecStartPre; check BUILT green post-edit |
| Regression proofs | tree eval post-fix = flat path, `test -x` YES; `meta.mainProgram` eval warning GONE (grep 0 on eval stderr); smoke fixture selftest 21/21; `nix fmt --` 0 changed; statix clean |
| Repo-wide class audit (closed) | every other `getExe`/`getExe'` call site targets writeShellApplication (bin/ layout) or real packages: monitor365 ×5, all forgejo scripts, system-health ×2, memory-emergency-guard ×2, crm ×2, pim-sync, gatus-config (mkSecretCheck + oidc env), bank-sync, immich (mkImmichApiKeyProvision), snapshots scrubGuard. backup.nix was the ONLY writeShellScript+getExe misuse |
| Wrong-premise queue rows corrected on both surfaces | TODO_LIST tripwire row + docs/todo/pipeline.md:1124 ticked and rewritten (smoke was RIGHT; the unit was dead; their proposed "-x the manifest path" would have MASKED the dead job) — commits 4f687f460/e12b96fbb |
| Hygiene bundle leg resolved | `meta.mainProgram` leg marked RESOLVED in the TODO_LIST bundle row (warning was getExe's fallback on this call site; gone from eval) |
| Runbook trap documented | docs/services/offsite-borg.md TRIPWIRE PATH SHAPE paragraph (writeShellScript → interpolate; getExe/getExe' append; guard name) |
| Status report with full evidence chain | docs/status/2026-11-15_12-55_offsite-borg-tripwire-203-nine-night-outage-fix.md (§a evidence table incl. backups.prom dead-values + missing marker, §b root cause incl. the inverted-premise correction, §d verification, §e audit, §f deploy arc) |
| Watch rows queued + kept premise-accurate | storage.md + TODO_LIST first-success rows, annotated DEPLOY PENDING (blocked by foreign FOD arc; nightly fires keep 203-ing until a deploy lands) |
| Impact framing | no offsite backup has EVER succeeded (backup_ever_succeeded 0 since the registry row exists, marker never created); the 203 was accidentally fail-closing the owner-signed-off ~646 G seed (2026-11-04 triple-answer) |
| Deploy discipline held under pressure | 45-min PSI watcher (12:52-13:36, avg10 41-79%) never forced; flock-holder + §0.5-style quiescence + eval-relevant-mtime checks before every attempt; anchor pre-checked (system-1012 == running system) |

## b) PARTIALLY DONE

1. **The deploy — the only step that makes the fix REAL — has not landed.** Three attempts in the window, none mine landing: 10:13 foreign deploy exit 3 (battery carried the same tripwire FAIL + 5 other new FAILs); 12:08 code-12 pressure-gate refusal (real IO storm, sdb 87%); my 45-min watcher never saw avg10 <20; 13:06 foreign deploy aborted code 1 at flake check on THEIR OWN `storage-collector-prepared-source` FOD failure (`sed: Permission denied` inside the prepared-source builder; their commit d1eed8cd9 "storage-collector 0.2 re-vendored" is the arc mid-repair). The live unit is STILL broken; the next 06:30 fires keep failing 203 until any session lands a successful deploy.
2. **Flake-check re-proof on current HEAD not done** (currently unprovable while their FOD fails; my green basis predates d1eed8cd9 — file-disjointness argues my fix is unaffected, not proven).
3. **§f follow-ups of the 12:55 report:** only the watch row was queued at authoring time; the fixture/OnFailure/SigNoz/selftest-build follow-ups existed only in my head until THIS report (queued now — harvest discipline met late, not at authoring time as the rule demands).
4. **First-seed verification chain** (backup_ever_succeeded flips 1, marker appears, journal create+prune+compact, first-run --stats sizing) — queued as [watch], blocked behind the deploy.

## c) NOT STARTED (deliberately, with owner-visible reasons)

1. **The 10:13 battery's other FAILs** — forgejo-runner-evo-x2 INACTIVE (ordering-cycle start-job drop), tq-agent-pool not active, Health Hub /readyz 503, Kith CRM 303, crm-server 201% CPU. Foreign session's arc (their deploy, their baseline); recorded as not-harvested in the 12:55 report. NOT researched further per scope.
2. **The storage-collector FOD repair itself** — foreign arc, actively owned; my touching it would violate concurrent-session discipline.
3. **Hygiene legs pipewire.jack deprecation + caddy ghost subdomains** — queued (bundle row), untouched this session.
4. **Restore drill real-mode** — pre-existing [watch] row (storage.md), blocked behind first success.
5. **BX11 → BX21 decision** — pre-existing sizing row, needs the first-run --stats measurement that needs the deploy.

## d) TOTALLY FUCKED UP

Blunt ranking of this session's failures:

1. **The owner-facing outcome is still "offsite backup dead."** Nine nights of failures before this session, and the session ends with the fix committed but NOT live. External blockers (storm + foreign FOD breakage) are real and documented — but from the "did it work" seat, the deliverable isn't delivered.
2. **The 11-07 session shipped the no-op "fix" and the 11-13 session shipped the inverted-premise row — and the 11-13 row's premise survived NINE more nights of nightly failures unchallenged** (the deploy smoke even failed with it at 10:13 today and still read as "smoke bug"). My share: I initially planned around the row's premise for two tool calls before the live-unit probe killed it. Two sessions' worth of missed ground-truth probes is the actual fuck-up pattern here; my early calls repeated a soft version of it.
3. **Nothing I shipped is wrong** — but three of my probes were malformed (§ self-review item 10) and one finding (audiblesync duplicate rows) sat unnoticed in my own grep output for the whole session until this self-review. Sloppy, even when harmless.
4. **Harvest discipline met LATE** (§b item 3) — the rule says self-harvest at report-authoring time; I did it only when writing this second report.

## e) WHAT WE SHOULD IMPROVE

1. **Ground truth first, documents second:** for ANY pasted FAIL, the first two probes are (1) the live unit file line, (2) the unit's journal since the failure window. Docs/todo rows are hypotheses, not facts — the 11-13 row cost 9 nights because nobody ran probe (1) for 9 days.
2. **"False-FAIL" claims need the checker's input path printed:** the smoke echoes `_borg_pre` VERBATIM from the unit — the 11-13 session misread that echo as the smoke's own appended path. Rule candidate: any "the check is wrong" verdict must show the exact line the check READ, not just what it printed.
3. **Use repo tooling that exists:** check `git log --since 1 day` for productized helpers (deploy-when-quiescent.sh landed TODAY) before hand-rolling.
4. **Quote-scrutiny is a VETO power, use it before interpreting:** the diskstats zeros were implausible on sight; the rule is validate-one-known-value BEFORE building any loop/probe pipeline (I did it for the PSI parse — should have done it for diskstats/cgroup too).
5. **Edit-tool hygiene:** View-tool read before ANY edit (bash sed/cat doesn't register); short grep-verified anchors over long transcriptions; line-number+anchor replacement as the documented fallback worked perfectly.
6. **Report-authoring harvest is a checklist, not a vibe:** every §f bullet gets "queued at <file>:<row>" or "deliberately not harvested because X" IN the report, written when the report is written.
7. **Alert-chain completeness belongs in every outage review:** "the job failed N nights" must always be paired with "and here is proof someone was paged" — otherwise you're fixing the job but the silence layer survives.
8. **Daemon-swept commits + foreign sessions:** verify `git show --stat` on every sweep touching your work (done, twice) and record WHEN amend is blocked (later sweep landed on top; behind origin) so the narrative lives in reports, not in rewritten history.

## f) NEXT — what to get done (ordered, session-adjacent first)

**Deploy + verify chain (this fix's tail):**
1. Land the deploy once the storage-collector arc clears AND PSI <20% — use `scripts/deploy-when-quiescent.sh --probe` then `--fire` (not hand-rolled).
2. Post-deploy anchor verify: `readlink /run/current-system` == newest `system-N-link`, full `nh os|switch-to-config` process tree empty.
3. Re-run post-deploy §16 → Offsite Borg all-PASS (tripwire line flat + executable).
4. Before firing: the drv-equality cheap gate (`nix eval …toplevel.drvPath` vs `nix-store -q --deriver $(readlink /run/current-system)`).
5. First-seed watch: post-deploy 06:30 fire → backup_ever_succeeded flips 1, `.last_success` appears, journal create+prune+compact (TimeoutStartSec 2d; multi-hour WAN seed).
6. First-run `borg create --stats` = irreplaceable-set measurement vs ~800 G BX21 trigger; queue BX21 decision if near.
7. WAN/IO-impact watch during the seed (io PSI, LAN/WAN saturation window; the seed runs in the 06:30 slot — confirm the "staggered after the pool dump/restic window" claim live).
8. First-connect validation: port-23 `[host]:23` known-hosts pin + rotated r2 key end-to-end (journal shows any host-key/auth refusal).
9. Verify borg-offsite-dir provisioner ran post-deploy (deploy.sh provisioner loop restarts oneshots; cache dir on /mnt/hot).
10. Restore drill real-mode + timings into offsite-borg-restore.md (existing watch row; needs first success).
11. Build `checks.offsite-borg-smoke-selftest` (flake twin of the bash fixture — never built this session).
12. Update smoke fixtures to the flat shape (test-offsite-borg-smoke.sh:103-127) — QUEUED THIS SESSION.
13. OnFailure delivery audit for the 9 failed fires + SigNoz staleness-rule check (backup_healthy/backup_age_hours offsite-borg) — QUEUED THIS SESSION.

**Alerting/monitoring gaps noticed this session:**
14. Check whether gatus covers borgbackup-job-hetzner unit failure at all (unit-failure coverage, not port probing).
15. Fix the `backup_ever_succeeded{backup="audiblesync"} 0` vs `audible-sync 1` duplicate registry rows (stale second name; noticed in this session's backups.prom grep).
16. Consider a static lint (lint-static/dead-guard-lint family) for `getExe`/`getExe'` applied to writeShellScript results — repo-wide class guard at grep level [decision].

**Documentation drift found this session:**
17. Add the missing docs/todo/services.md twin for the eval-warning hygiene bundle row — QUEUED THIS SESSION.
18. Re-word the 12:55 report title's "Nine-Night" vs the metric-level "never succeeded" framing when it's next annotated (minor wording hazard).

**Hand-offs to the foreign session / owner (NOT mine to execute):**
19. storage-collector-prepared-source FOD: `sed -i` Permission denied inside the prepared-source builder (their d1eed8cd9 arc; blocks ALL deploys until fixed).
20. forgejo-runner-evo-x2 INACTIVE after the 10:13 switch (ordering-cycle start-job drop; 5-min runner-ensure timer convergence check; eval gates: ordering-cycle-audit.nix + buildcache recoveryRestartUnits).
21. tq-agent-pool not active (pool.conf typo class per the smoke's own hint).
22. Health Hub /readyz 503 (cvagent 503 + llama dark chaining).
23. Kith CRM 303 at /login (auto-forward pattern row exists — owner-approved 2026-11-12).
24. crm-server sustained 201% CPU.
25. Who fired the 12:08 `DEPLOY_FORCE_PRESSURE=1` typed attempt (attribution via sudo journal/_COMM per the shell-history caveat) and whether forcing was intended during a real storm.
26. Storm source: sdb at 87.3% with ghostty-scope cgroup stalling (12:08 crosscheck) — /proc forensics per AGENTS (fish history is not evidence).
27. The 10:13 deploy's `activation completed with failed units (exit code 4)` — WHICH units failed at that switch (log line ~2230).
28. Footless daemon commits 4f687f460 / e12b96fbb / 91d701c4b / c147bb8e5: optional properly-messaged squash/reword once the foreign arc stops sweeping and the branch is reconciled (behind origin by 1).

**Pre-existing queued rows adjacent to this session (not started by me):**
29. go-deps-audit runner breakage (audit blind since 2026-11-13).
30. secret-history-scan red on the tracked fixture literal in .gitleaks.toml.
31. negative-tests.yml red (lint-harness selftests).
32. nix-check + VM-test CI cluster (~38 min red runs).
33. Hygiene legs: pipewire.jack.enable deprecation; caddy dns-local ghost subdomains (nsfw, llama).
34. Signoz provisioner v8 full green unit run (landed in-tree 2026-11-13, rides the next deploy — same deploy as mine).
35. cvagent + forgejo memory.watermark post-deploy re-read (rides the next deploy too).
36. Prune retention policy = still an owner decision (prune.keep conservative defaults per module comment).
37. gcs-staging 24 G owner-reclaim decision (storage.md) — moot for the seed since /data left paths, still open reclaim.

(Stop at 37 — items past this would be re-derivation of the dispatch queue, not session work. The tq pool harvests from TODO_LIST; items 12, 13, 17 above are QUEUED as of this report; the rest carry explicit hand-off/observation status here.)

## g) Questions I cannot answer myself

1. **Deploy sequencing:** the storage-collector re-vendoring arc (d1eed8cd9, foreign session) currently blocks EVERY deploy at flake check. Do you want me to wait for that session to finish and then deploy the borg fix in the first calm window — or is that arc abandoned/should I coordinate (or repair the FOD myself) so the tripwire fix can land today?
2. **Seed auto-start reconfirmation:** the 2026-11-04 sign-off says the Persistent timer proceeds without a hold. Once a deploy lands, the next 06:30 fire starts the real ~646 G WAN seed (hours-to-days). Still auto — or do you want an explicit go word now that timing has moved 11 days past the original plan?
3. **Alert receipt:** did you receive Discord pages for the 9 failed 06:30 fires (OnFailure= triggered nightly)? If yes, the delivery layer works and only the smoke caught it late; if no, there is a SECOND silent layer on the only offsite copy that I should audit and fix alongside the tripwire.

_WAITING FOR INSTRUCTIONS._
