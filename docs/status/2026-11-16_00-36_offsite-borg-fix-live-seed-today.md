# Offsite-Borg Tripwire Fix LIVE — First Real Seed Fires 06:30 TODAY

**Date:** 2026-11-16 00:36 CET
**Session span:** 2026-11-15 ~13:30 → 2026-11-16 00:36 (tripwire triage/fix 13:30-13:46 per the two earlier reports; landing watch 13:52-15:15; this wrap-up 00:36).
**HEADLINE: the 203/EXEC fix is LIVE.** The 13:52 foreign deploy holder ran 5028s, switched, and the live unit now carries the flat executable tripwire path. **The first real offsite backup attempt (~646 G WAN seed, owner-signed-off 2026-11-04, default = proceed) fires TODAY 06:30 CET.** Only an explicit owner HOLD word before ~06:25 stops it.
**Companion reports:** docs/status/2026-11-15_12-55 (evidence + fix), docs/status/2026-11-15_13-46 (full status + self-review round 1).

## Landing evidence (all probed 00:3x, live)

| Probe | Result |
| --- | --- |
| `/etc/systemd/system/borgbackup-job-hetzner.service` ExecStartPre | `/nix/store/bvvc483…-borg-offsite-golive-check` — FLAT, `test -x` YES (the `/bin/` corpse is gone) |
| §16 legs on the live unit | marker wired ✓, `EnvironmentFile=/run/secrets/rendered/borg-env` ✓, `IOSchedulingClass=best-effort` + `Priority=6` ✓, backups.prom coordination row present ✓ |
| Smoke battery of the landing deploy | `tripwire binary not executable` occurrences: **0** (was present in every battery since 11-07); PASS 172 / FAIL 6 / SKIP 3 / WARN 17 |
| Anchor | system-1012-link == `readlink /run/current-system` == `vqi67vah5…-nixos-system-evo-x2-26.11.20261107.f4a03c0` (deploy.sh self-repaired the profile to the running system, standard arc) |
| Timer | NextElapseUSecRealtime = **2026-11-16 06:30 CET** (persistent) |
| Journal since 15:00 | no borg entries yet (expected — nothing fires before 06:30) |
| Flake check on the deployed tree | the 13:52 attempt PASSED check 1 (the storage-collector FOD breakage that blocked the 13:06 attempt was fixed by the foreign arc in between — my 13:46 report's open flake-re-proof item is thereby closed: the deployed tree evals+checks green) |

**How it landed (sequencing beat re-firing, exactly per the AGENTS 2026-11-15 doctrine):** I did NOT fire a third deploy. The foreign session's 13:52 holder evaluated the CURRENT tree — which already carried my committed fix (4f687f460) — forced through the entry pressure gate (41% avg10, 102% disk busy, their call), switched, and the battery confirmed the tripwire leg green. My 84-min background watcher caught the exit and verified the landing. Re-firing would have bounced rc=13 on the flock for nothing.

## Self-review round 2: what I forgot / did wrong since the 13:46 report

1. **The "DEPLOY PENDING" annotations I wrote at 14:0x went stale within ~90 minutes** (deploy landed 15:15). Live-surface rows must be re-annotated the moment their premise flips — I only corrected them at 00:36 when THIS wrap-up forced a re-read. Same drift class I flagged in the 11-13 row; I then committed a softer version of it myself.
2. **The seed question became time-critical and sat unanswered for 9 hours.** g.2 of the 13:46 report asked about seed auto-start; the deploy landed hours later and the seed now fires in ~6 h. Lesson: time-sensitive owner questions need an explicit default-with-deadline ("proceeds at 06:30 unless you say HOLD before then"), not an open question.
3. **The landing was verified in batch, not per-leg at the moment it happened** — acceptable (all legs green 9h later, nothing runs in between), but a landed-switch verification should have been: unit line + anchor + battery tripwire count, immediately, then §16 legs.
4. Nothing I shipped this round is wrong; the two NEW battery FAILs (bank-sync sync errors, papdashboard journal storm) are foreign arcs — recorded, not touched.

## a) FULLY DONE (cumulative session, all committed)

| Item | Where |
| --- | --- |
| Root cause proven 3 layers deep (unit line, tree eval, journal 203/EXEC ×9 nights) + `getExe`-on-writeShellScript mechanism named | 12:55 report §a |
| Root fix: `ExecStartPre = "${goliveCheck}"` (flat path) | backup.nix:319, commit 4f687f460 |
| Eval-time class guard: no-`/bin/` ExecStartPre assert | offsite-borg-positive-render, selftests.nix |
| **FIX LIVE ON THE HOST** | deployed unit flat+executable since 15:15 Nov 15; tripwire FAIL count 0 in the landing battery |
| All 5 §16 legs green on the live unit | probed 00:3x (table above) |
| Anchor discipline | system-1012 == current-system (self-repaired by deploy.sh in the standard arc) |
| Repo-wide getExe/writeShellScript audit closed (backup.nix was the only misuse) | 12:55 report §e |
| Wrong-premise queue rows corrected + ticked (both surfaces) | TODO_LIST + pipeline.md (commits 4f687f460/e12b96fbb) |
| meta.mainProgram hygiene leg resolved (was the same getExe fallback warning) | bundle row updated |
| Runbook trap paragraph | offsite-borg.md |
| Three status reports incl. this one | 12:55, 13:46, this file |
| Watch rows queued AND kept premise-accurate | storage.md:348 + TODO_LIST:3654 (now LANDED) |
| Self-harvested follow-up rows (fixtures shape, OnFailure/SigNoz audit, services.md twin drift) | TODO_LIST + pipeline/monitoring/services.md (commit fee55fb7a + the 00:3x row fixes, pending sweep) |
| Verification proofs | tree eval flat, mainProgram warning gone, positive-render build green, smoke fixture 21/21, fmt 0-changed, statix clean |

## b) PARTIALLY DONE

1. **First-seed verification** — the watch row's whole point: runs TODAY 06:30 (backup_ever_succeeded flips 1, `.last_success` appears, journal create+prune+compact, first-run --stats sizing). Everything before it is done; it itself cannot be done until the fire.
2. **OnFailure/Discord delivery audit + SigNoz staleness-rule check** (9 nights of OnFailure triggers, receipt unknown) — queued (monitoring.md), not executed.
3. **Smoke fixture flat-shape sweep + offsite-borg-smoke-selftest build** — queued (pipeline.md), not executed.
4. **services.md twin for the hygiene bundle** — twin row NOW ADDED to services.md (this round), TODO_LIST pointer row queued; the two OPEN legs (pipewire, caddy) untouched.
5. **Battery exit-3 cleanup** — the landing battery still exits 3 on 6 foreign FAILs; my legs are green but the regression-signal gate stays red until the foreign arcs resolve or re-baseline.

## c) NOT STARTED (deliberately)

1. Foreign battery FAILs: forgejo-runner-evo-x2 INACTIVE (ordering-cycle drop, persists across all 3 deploys today), **bank-sync sync cycles failing (NEW this battery)**, Health Hub /readyz 503, Kith CRM 303, crm-server 200% CPU, **papdashboard journal 371 lines/min (NEW this battery)** — foreign sessions' arcs.
2. storage-collector FOD repair — foreign arc, RESOLVED ITSELF between 13:06 and 13:52 (flake check passed) — no action needed, recorded for history.
3. Hygiene legs pipewire.jack + caddy ghost subdomains (queued).
4. Restore drill real-mode (blocked behind first success), BX21 sizing decision (blocked behind first-run stats).

## d) TOTALLY FUCKED UP

1. **Stale premise on live surfaces (mine, this round):** the DEPLOY-PENDING annotations survived the landing by 9 hours until this wrap-up. Small, but it's the exact class that cost 9 nights on the 11-13 row — zero tolerance means zero for my own rows too.
2. **The seed hold-window is ~6 hours and the owner question sat open 9.** If the owner wanted a hold, the default (proceed per 2026-11-04 sign-off) eats the window silently. Default-with-deadline should have been stated at 13:46.
3. Cumulative honest tally across the whole arc: the actual backup outage was 9 nights of 203/EXEC before ANY session probed the live unit — two sessions (11-07's no-op "fix", 11-13's inverted-premise row) each had the evidence in hand and mis-read it. My 13:30 session repeated a softer version (docs-first, host-second) for 3 tool calls. The fix is now live and guarded, but the meta-failure — treating documented premises as ground truth — is the thing to actually fix in ourselves.
4. Nothing shipped broken this round; no data at risk; no secrets touched.

## e) WHAT WE SHOULD IMPROVE

1. **Default-with-deadline for time-sensitive asks:** "X proceeds at TIME unless you say HOLD" — open questions defaulting to inaction (or silently to an old sign-off) are how 6-hour windows vanish overnight.
2. **Premise-flip reflex:** any row I annotate must be re-checked when its blocking condition changes — the landing flipped two rows' premises and nothing reminded me. (A cheap `rg 'DEPLOY PENDING|blocked by' docs/todo TODO_LIST` at every deploy-landing verification would catch these mechanically.)
3. **Watch-the-holder, don't re-fire:** worked perfectly this time (the 13:52 holder deployed my committed wave); keep using a bounded background watcher + post-exit leg verification as the standard pattern under multi-agent deploy contention.
4. **Landed-switch verification checklist stays mechanical:** unit Exec lines + anchor equality + battery tripwire count + journal — 4 probes, one command, every landing.
5. Keep re-running `check-todo-system.sh` before walking away from row edits (did this round: structure clean; the UNHARVESTED WARN about the 13:35 audiblesync report is a FOREIGN session's harvest obligation, not mine).
6. Probe pipelines: validate one known value before trusting output (PSI parse ✓, diskstats ✗ — the lesson repeats until it's reflex).

## f) NEXT — what to get done (session-adjacent, ordered)

**Seed day (TODAY):**
1. **06:30 fire watch:** journal `-u borgbackup-job-hetzner` shows the tripwire EXECUTE (first time ever), borg connect to the StorageBox (port-23 known-hosts pin + r2 key validation), then create start. Expect hours-to-days (TimeoutStartSec 2d).
2. Post-fire: `backup_ever_succeeded{backup="offsite-borg"}` flips 1 only after create+prune+compact — until then it stays 0 (do NOT misread as failure mid-seed; `.last_success` appears at completion).
3. First-run `borg create --stats` = irreplaceable-set measurement vs ~800 G BX21 trigger (BX11 is 1 TB; seed ~646 G raw, dedup+compress lands lower).
4. WAN/IO-impact watch during the seed: io PSI, BE/6 tier keeps interactive IO responsive; the 06:30 slot was chosen to trail the pool dump/restic window — verify that staggering claim live.
5. OnFailure audit (queued): did the 9 nightly Discord pages deliver? + SigNoz rule existence for backup_healthy/backup_age_hours offsite-borg (both silent-layer candidates).
6. After first success: restore drill real-mode + timings (existing watch row).
7. gatus coverage check: is borgbackup-job-hetzner unit failure monitored at all?

**Left over from this session (queued, not executed):**
8. Smoke fixtures → flat shape (test-offsite-borg-smoke.sh:103-127) + build checks offsite-borg-smoke-selftest.
9. services.md hygiene-bundle twin legs: pipewire.jack deprecation + caddy ghost subdomains (twin row now exists; the fixes are one-liners).
10. Duplicate backups.prom registry rows: `backup_ever_succeeded{backup="audiblesync"} 0` vs `audible-sync 1` — drop/merge the stale name.

**Foreign battery FAILs (hand-offs — mine only if you reassign):**
11. forgejo-runner-evo-x2 INACTIVE since the 10:13 switch (ordering-cycle drop; 5-min runner-ensure timer convergence check; ordering-cycle-audit.nix + buildcache recoveryRestartUnits gates).
12. bank-sync sync cycles failing since restart (bank_sync_sync_errors_total > 0) — NEW in the 13:52 battery.
13. papdashboard journal 371 lines/min sustained — NEW in the 13:52 battery.
14. Health Hub /readyz 503 (cvagent 503 + llama dark chain).
15. Kith CRM 303 at /login (auto-forward row exists, owner-approved 2026-11-12).
16. crm-server sustained ~200% CPU.
17. The repeated `activation completed with failed units (exit code 4)` on every nh switch today — WHICH units (the log names the FAILEDhunt list only indirectly); worth one `systemctl --failed` snapshot post-battery.
18. Footless daemon commits (4f687f460, e12b96fbb, 91d701c4b, c147bb8e5, fee55fb7a, + the pending sweep): optional properly-messaged reword once the branch reconciles (ahead 13+/behind 1 at last check).

**Pre-existing queued rows adjacent to the deployed tree (ride future deploys):**
19. Signoz provisioner v8 full green unit run (in-tree since 2026-11-13 — NOTE: the 13:52 deploy carried it; check whether the provisioner ran green in the switch window).
20. cvagent + forgejo memory.watermark post-deploy re-read (the 13:52 deploy carried those bumps — the re-read is NOW DUE).
21. go-deps-audit runner breakage (nightly audit blind since 2026-11-13).
22. secret-history-scan red on the tracked fixture literal.
23. negative-tests.yml red.
24. nix-check + VM-test CI cluster.
25. Retention policy = owner decision (prune.keep conservative defaults).
26. gcs-staging 24 G owner-reclaim decision.

(37→26: items from the 13:46 list that resolved themselves — flake re-proof via the passing 13:52 check, storage-collector FOD — are dropped, not carried.)

## g) Questions I cannot answer myself

1. **SEED GO/HOLD — needs an answer before ~06:25 TODAY:** the first real ~646 G WAN seed fires 06:30 per the 2026-11-04 sign-off (default = proceed, no hold requested then). Say HOLD if you want to pick the window (e.g. not while you're using the WAN), otherwise I let it run and watch.
2. **The 6 battery FAILs are all foreign-arc** (forgejo-runner, bank-sync NEW, Health Hub, CRM, crm CPU, papdashboard NEW). Do you want me to pick up any of them (bank-sync + papdashboard are the two NEW today), or do their sessions own them and I stay off?
3. **Did the 9 nightly backup-failure Discord pages arrive?** (OnFailure= triggered daily per journal; delivery receipt unknown.) If they did NOT arrive, the staleness-alert layer for the only offsite copy has a second silent break I should fix alongside the alert audit row.

_WAITING FOR INSTRUCTIONS._
