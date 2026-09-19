# Window Closeout — Five Tasks: Backup-Pipeline Night (2026-09-17 00:00–03:20 CEST)

**When:** 2026-09-17 03:23 CEST
**Window tasks:** `000001a0ac3c6744` (DAS convergence watch), `000001a0ac6105d6` (btrbk-data oom-kill containment), `000001a0ac8110e2` (Zone 6 churn re-arm), `000001a0acaed797` (dnsblockd /health wedge), `000001a0acc5bb0a` (BuildFlow fallback caches).
**Scope:** this window only, plus what was noticed in passing. Every closeout report for these tasks lives beside this file (`docs/status/2026-09-17_00-25_*` … `02-54_*`); this report is the cross-task synthesis and the feed-forward.

---

## a) FULLY DONE

| Task                                            | Verified outcome                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               | Evidence                                                                                                                                                                                   |
| ----------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Zone 6 churn re-arm** (`…8110e2`)             | The memory-emergency-guard now re-`systemctl start`s exactly the churn units it recorded stopping (btrbk-root/data/pool, balances, scrubs) on the first tick where sustained io PSI some avg60 drains under 40%; new persistent `memory_emergency_guard_churn_rearms_total` counter; VM test extended (drain run re-arms the stopped unit, counter advances) and green. This closes the +24h nightly-backup-slip class (trip #299, 2026-09-16 23:00). AGENTS.md Zone 6 bullet + `docs/services/memory-emergency-guard.md` rewritten (stale "NEVER restarts" doctrine removed). | Code in `modules/nixos/services/memory-emergency-guard.nix` (re-arm block verified present this pass); commits `2fc4db64` + `bd0c4a4b` + `118fc50f`, all footer-labeled; TODO row 29 `[x]` |
| **btrbk-data oom-kill containment** (`…6105d6`) | `btrbk-data.service` gained `MemoryHigh = "4G"` (throttles the unit's own page-cache — bounded cgroup, never killed) + `OOMScoreAdjust = -250` (drops out of oomd's victim set; flm at +300 stays the designated sacrifice). `nix eval` of the evo-x2 serviceConfig returns both values; flake check green.                                                                                                                                                                                                                                                                    | `platforms/nixos/system/snapshots.nix:385` verified this pass; commit `c51cb4c1` (footer); TODO row 28 `[x]`                                                                               |
| **BuildFlow fallback caches** (`…c5bb0a`)       | Quarantine decision resolved (reap — content is pure rebuildable Go cache); `gobuild gocache gomod` added to BOTH exact-name reap loops (`buildcache-usb-recovery` step 2.5 at `modules/nixos/services/buildcache.nix:332` and deploy.sh's pre-switch sweep at `scripts/deploy.sh:175`); flake check all-green 02:52.                                                                                                                                                                                                                                                          | Both loops verified present this pass; commits `afcb7161` (code, daemon-swept) + `82e04b55` + `7f0b44fb`; TODO row `[x]`                                                                   |
| **dnsblockd /health wedge** (`…ed797`)          | Verification-only close: the fix was already shipped upstream and deployed. Lock rev `92aeedd0` proven git-ancestor of fix-carrying `94c9cb93` (deployed since 2026-09-06); `internal/server/health.go:98` serves go-health's 1s cached response (lock-free off SQLite) with fast-503 staleness guard; regression tests confirmed in the pushed history. TODO row closed with the full evidence chain; the :9090 root-cause half correctly left to the standing 09-13 rows.                                                                                                    | `docs/status/2026-09-17_02-20_*` evidence appendix; commit `1e5ce035` + `f5b2d54d`                                                                                                         |
| **Post-DAS convergence watch** (`…c6744`)       | Third verification pass: `backup_all_healthy 1` (all 9 dump backups green, 19–23h), bank-sync sync failures 0, guard alive and tripping correctly on the live nix-gc storm, and the Sep 16 miss root-caused from primary evidence (the 23:00:01 `btrfs send` WAS issued; Zone 6 churn-stop killed it 6.5 min in; `btrbk-pool-clean` healed the garbled target 23:50).                                                                                                                                                                                                          | `docs/status/2026-09-17_00-25_*`; TODO row 27 updated (still open, time-gated)                                                                                                             |

**Cross-cutting:** all five tasks are footer-labeled in git (`Task-Queue-ID` trailers verified by the individual runs), TODO_LIST rows closed or updated, `nix flake check --no-build` green at multiple points in the window.

## b) PARTIALLY DONE

1. **Three fixes are stacked UNDEPLOYED** — Zone 6 re-arm (`2fc4db64`), btrbk-data cgroup sizing (`c51cb4c1`), and the buildcache reap-list unit half (`buildcache.nix`; the deploy.sh half is live on next deploy regardless). Production still exhibits the +24h backup slip on every Zone 6 trip today. The Sep 17 23:00 btrbk-root window is the first that could benefit; the Sep 19 00:28 `btrfs-verify-pool-backups` freshness check FAILs if one more storm-eaten send slips through. **Deploy latency is the single biggest live risk this window produced.**
2. **The actual backup-pipeline outcome is unproven**: nothing yet demonstrates a re-armed send LANDS pool-side (the re-arm is proven at unit level only), and tonight's 23:00 receive confirmation is time-gated (~20h away). The DAS-watch task remains open in a structural BLOCKED loop (harvested at midnight twice; its only check completes at 23:00).
3. **BuildFlow debris not yet reaped**: the ~6.6 GB (`gobuild` 468M, `gocache` 2.7G, `gomod` 3.4G, live-measured 02:52) still sits on the QLC root until the next deploy/recovery event.
4. **dnsblockd close is lock/source-level, not runtime**: no live probe of the cached `/health` behavior on the deployed daemon (sandbox-gated; the standing 09-13 post-deploy row remains the right home).
5. **The oom containment is config-verified, not incident-verified** — the real proof (a full-tree send surviving memory pressure) is gated behind the /data EIO repair (P0), which also fast-fails the send today.

## c) NOT STARTED

- **/data corruption repair (T04–T08)** — the P0 that gates both the btrbk-data EIO story and the oom containment's real-world proof; scrub-mechanism fix still deploy-gated; T06a deletions await user sign-off after scrub-delta gate (b).
- **Wise SCA approval** (user dashboard; 260+ challenges counted) — the remaining bank-sync statement gap.
- **The owed reboot** (flm :52626 corpse, D-state pile, 2026-08-31 wedges) and the staged flm v1.0.3 go-live behind it.
- **llama-rag re-enable** (llama.cpp 20260911 mid-load spin — pin-back or bisect pending).
- **Hetzner StorageBox + BorgBackup offsite leg** — decided 2026-09-11, not implemented.
- **crush-hot-db first migration run** — deployed at generation `bbb931a8` but still pending a no-crush-session window.
- Nothing else from the wider backlog was touched this window (by design; the queue paced five narrowly-scoped items).

## d) TOTALLY FUCKED UP

1. **Duplicate dispatch burned two queue slots.** Tasks `…8110e2` (Zone 6) and `…c5bb0a` (BuildFlow) each arrived AFTER a prior session had already fully completed them under the same task ID — the queue re-dispatched `[x]` items whose closing commits carry the matching footer. Damage was one verification pass each (both runs correctly detected completeness first), but the pacing is wasting budget, and one run's first commit attempt even hit the auto-commit daemon race before recovering via a verified-only amend.
2. **The DAS-watch task is in a structural BLOCKED loop** — harvested at ~midnight two nights running for a check that completes at 23:00. Two sessions re-confirmed the same green signals; one run also carried forward two prior-run claims without re-evidencing them (acknowledged in its own report). The queue's pacing, not the work, is failing here.
3. **A USER-decision gate was closed by an agent**: the BuildFlow "keep vs quarantine" decision was recorded as QUARANTINE with a safe-default rationale because no human answered. Almost certainly correct (pure rebuildable cache), but the decision record attributes to the user a call the user never made — ratification owed (see §g).
4. **Nothing in the window's code is broken**: no failed evals, no broken gates, no secret exposure. The one repo-hygiene cost: the BuildFlow code half rode a heuristic auto-commit (`afcb7161`) instead of a footer-carrying explicit commit, so the closing docs commit references an unlabeled commit for its substance.

## e) WHAT WE SHOULD IMPROVE

1. **Deploy-urgency class for guard/backup fixes.** Three fixes shipping inert against a ticking Sep 19 freshness deadline is a pacing failure. Rule candidate: any fix whose verification clock is a dated external deadline gets scheduled (or flagged) for a quiet-window deploy immediately, not left to ride the next routine switch.
2. **Queue: treat `[x]` TODO rows with a matching-footer commit as terminal** — skip dispatch, or demote to a verify-only lane. Both duplicate runs this window did the right thing (completeness check first); the queue should not require them to.
3. **Queue: schedule time-gated tasks at their trigger time** (e.g. "confirm after 23:15"), or better, retire the class by building self-verifying probes so no midnight agent session is needed at all (see §f.9).
4. **Outcome observability for the re-arm**: `churn_rearms_total` proves the re-arm FIRED, not that the send LANDED. A 2-day WARN tier on `btrfs-verify-pool-backups` (today: single 3-day FAIL) and/or a dedicated `root_receive_age_hours` metric would surface the residual risk ~24h earlier.
5. **Reap lists are name-enumerated whack-a-mole** — each DAS outage can mint NEW fallback cache names nobody reaps (this window's fix was itself the second incident of the class). A size-based detector (flag any `~/.cache/*` real dir >1G that is not an HM-managed symlink target) closes the class instead of the instance.
6. **Commit-race sequencing**: task-queue sessions should commit code explicitly with the footer BEFORE touching TODO_LIST (the TODO edit is what gives the daemon its window) — two of five tasks this window split their code and docs across labeled/unlabeled commits.
7. **Verification-only closes should name their evidence class** (runtime vs lock/source vs doc-chain) as a standing convention — the dnsblockd close did this well; codify it in CONTRIBUTING so downstream sessions know whether a runtime re-check remains.

## f) NEXT THINGS (impact-ordered; appended to TODO_LIST.md this pass)

1. Deploy the stacked fixes (Zone 6 re-arm + btrbk-data MemoryHigh/OOMScoreAdjust + buildcache reap unit) in a quiet-IO window BEFORE the Sep 17 23:00 btrbk-root window — the Sep 19 00:28 freshness check is the deadline.
2. After the Sep 17 23:00 window: confirm the root incremental lands pool-side (`@.20260917T2300` in `/mnt/pool/backups/root`) and `backup_all_healthy`/verify stay green — closes the DAS-watch task.
3. Post-deploy: verify the guard `.prom` carries `churn_rearms_total`, the deployed unit carries the re-arm block, and `buildcache-usb-recovery` carries the six-name reap list.
4. Post-deploy: verify `~/.cache/{gobuild,gocache,gomod}` are reaped and the HM symlinks intact.
5. After the first real post-deploy Zone 6 trip: verify the re-arm journal line AND that the resumed send lands; record trip → drain → re-arm → send-complete timing in `docs/services/memory-emergency-guard.md`.
6. Extend the btrbk-root + btrbk-pool services with the same MemoryHigh/OOMScoreAdjust treatment (same full-tree send class; root re-sends are live via the 2026-09-12 snapshot-loss scenario).
7. Add an eval-time assertion that every `btrfs send`-carrying unit declares a MemoryHigh (class guard, harden{}-throw pattern).
8. Add a WARN-tier boundary at 2 days to `btrfs-verify-pool-backups` (today's single 3-day FAIL is too late to act on).
9. Build a post-23:30 self-verifying receive-freshness probe (textfile metric `root_receive_age_hours` + Gatus check) so nightly convergence no longer depends on midnight agent sessions.
10. Consider a second nightly btrbk-root window (e.g. 04:00 retry) so a storm-eaten 23:00 send self-heals independent of the guard.
11. Read the guard's own journal (`memory-emergency-guard-check` syslog id) for trips #298–#300 and correlate each with btrbk-root send attempts — quantify how many of the last N nightly sends were churn-stopped.
12. Wire `churn_rearms_total` into a Gatus check or the SigNoz guard dashboard (forensics-only vs threshold is a user call — see §g).
13. VM tests for the re-arm: drain → relapse → drain (counter increments twice); re-arm against a nonexistent churn unit (the `|| true` path).
14. Add per-unit `churn_units_rearmed{unit=…}` for forensics symmetry with `churn_units_stopped`.
15. Pre-deploy §10: WARN when `memory_emergency_guard_churn_units_stopped` is present at deploy time (active churn window → units currently stopped).
16. Document the "re-arm races a manual stop" caveat (a human `systemctl stop btrbk-root` during a churn window gets undone by the next drain tick).
17. Build the generic displaced-cache detector: textfile collector flagging any non-HM-managed `~/.cache/*` real dir >1G (new-fallback-name class, this window's reap list being instance #2).
18. Add an eval-time/check assertion pinning the reap-list contents (six names) in both loops so drift or removal is loud.
19. Derive the buildcache reap loop and deploy.sh's loop from ONE shared Nix list so they cannot diverge.
20. Root-cause WHY BuildFlow minted `gobuild`/`gocache`/`gomod` instead of Go's standard `go-build`/`go` fallback names (BuildFlow-side path construction suspected); fix upstream if confirmed.
21. Sweep other cache-minting tools (pnpm, cargo, sccache, pip) for dead-mount fallback names and confirm each is symlink- or mount-converged.
22. Live runtime probe of the deployed dnsblockd cached `/health` (cache-hit latency + forced-staleness fast-503) and close the standing 2026-09-13 post-deploy row (sudo/curl-gated).
23. Confirm `GOTRACEBACK=all` is actually set on the deployed dnsblockd unit and `scripts/dnsblockd-goroutine-dump.sh` is reachable; re-scope the :9090 wedge hypothesis list — the inline-DB-probe suspect is GONE post-`94c9cb93`.
24. Cut a dnsblockd release tag carrying the cached-/health + OTLP-scheme fixes; then decide tag-pin vs `?ref=master` for the SystemNix input (the "carries two untagged fixes" rev-pin justification expires when the tag lands).
25. Post-EIO-repair first send: check `btrbk-data` cgroup `memory.peak` ≤ ~4G to prove the oom containment under a real full send.
26. Codify the "verification-only close" evidence-class convention in `docs/CONTRIBUTING.md`.
27. Queue hygiene: auto-skip dispatch of items already `[x]` with a matching-footer commit; schedule time-gated items at their trigger time.
28. Refresh `docs/services/memory-emergency-guard.md` calibration notes ("first 99 real trips" era → current counts) after the re-arm's first live exercise.
29. Fix the AGENTS.md sev1 section `zone1..5_trips_total` vs `zone1..6` inconsistency (trivial, on sight).
30. Annotate the 2026-09-17_01-37 duplicate Zone 6 report and the archived BuildFlow source report (§c2/c3) with their close-out pointers (docs-health ANNOTATE pass).

## g) QUESTIONS FOR THE OWNER

1. **Was QUARANTINE the actual intent for the BuildFlow fallback caches?** The agent closed the "keep vs quarantine" USER gate with a safe default (reap ~6.6 GB of pure rebuildable Go cache). If "keep" was intended, the reap-list extension should be reverted before the next deploy reaps them.
2. **Zone 6 vs the nightly backup window — what is the accepted RPO posture?** With the re-arm landed, a storm during the resumed send can still cost the night (only a grace window — rejected by design — or a second nightly window covers that). Do you want (a) a quiet-window deploy tonight before 23:00, (b) the second 04:00 retry window, and (c) alerting on `churn_rearms_total` (forensics-only, or a notify-tier threshold ≥3/day)?
3. **Queue policy:** should time-gated tasks be scheduled at their trigger time (or replaced by self-verifying probes), should `[x]`-with-footer items auto-skip dispatch, and should sudo/curl-gated verification items (dnsblockd live probe) stop being assigned to sandboxed agents?

## h) BAND DRIFT (ADR-0015 accountability)

`tq facts` for the window (2026-09-17 00:00 → 03:20, facts #~4040–4068) contains **zero `task.reprioritized` records** — no priority changes were made in or around this window. Observed instead (queue mechanics, not drift): five tasks enqueued/claimed/completed per the backlog; two duplicate dispatches of already-completed items (recorded in §d.1); one unrelated task dead-lettered at 03:16 (`…132491`, go-taskqueue repo verify failure, `class=exhausted`) and two LLM-timeout failures at 03:11/03:18 (`…a118f95`, glm stream deadline) before this closeout task claimed at 03:18:44 — none of which altered any task's priority. **None recorded.**

---

_Point-in-time snapshot, 2026-09-17 03:23 CEST. The authoritative queue is TODO_LIST.md; this report feeds it and must not shadow it._
