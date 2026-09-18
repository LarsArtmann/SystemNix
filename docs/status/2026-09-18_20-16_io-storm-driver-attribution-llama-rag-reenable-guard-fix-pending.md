# Session Status Report — 2026-09-18 20:16

**Scope:** This session only (resumed from the 2026-09-17 handoff summary). Two directives received mid-session: "Review again!" → re-verification + forensics reading + driver attribution; then "READ, UNDERSTAND, RESEARCH, REFLECT / break into steps / execute" → a 7-step plan was announced and its FIRST TWO tool calls were interrupted by this status request. Zero code changes landed this session.

**Headline:** The 2-day IO storm's driver is now NAMED with rate evidence: the llama-rag stack — which a parallel session RE-ENABLED on 2026-09-18 despite the 2026-09-16 config-disable — was running the known-regressed build at 93.9% CPU ×2 plus ~17 MB/s of block IO into the QLC root. At 20:16 the llama-servers are GONE from `ps` and IO PSI has drained to 33% (below the 40% Zone-6 trip line): the attribution is corroborated by the storm dying when they died. Backups: missed TWO consecutive nights (Sep 16 + Sep 17 23:00 runs both guard-killed mid-send); pool receives still stop at `@.20260915T2300`; `@home-hermes` has ZERO receives ever. The guard fix (4 items) is still NOT STARTED.

**Observation timestamps:** deep evidence gathered 13:44–13:57 CEST; freshness probe 20:16 CEST.

---

## a) FULLY DONE (this session)

1. **Live state re-verified** (13:57): guard trip #456, 100% Zone 6, io PSI some avg10=57/avg60=58.6 sustained, MemAvailable ~53%, memory PSI ~8% — the crash-#3 episodic class, exactly as on 09-17. Storm age: 2+ days continuous.
2. **The io-psi-forensics bundles were finally READ** (358 exist in `/var/tmp`; the thing left undone across two prior sessions — the storm driver's name was already captured, one `cat` away). Read in depth: the two newest bundles (meta, psi, dstate, top-io-procs, cgroup-io, diskstats).
3. **Rate attribution via 10-min cgroup io.stat deltas** (bundles 13:44→13:54): `llama-reranker.service` **15.8 MB/s**, `discordsync.service` **9.0 MB/s**, `llama-embeddings.service` 1.1 MB/s, `clickhouse.service` 1.0 MB/s, everything else <1 MB/s. **Hermes user slice (user-975): ~0.01 GB/10min — EXONERATED.**
4. **Discovered the llama-rag re-enable:** `llama-rag.enable = true` at `platforms/nixos/system/configuration.nix:613`; both llama-servers running since 11:28 (Sep 18) at **93.9% CPU each** (141 min CPU over ~2.5 h wall), D/R state, `llama-cpp-0.3.0` store path `sj4rpa8y…` (the byte-identical pin-back build). New units present: `llama-rag-leak-metrics.service/.timer` + a module comment about "the re-enabled reranker unit bind-failed" — this is a PARALLEL SESSION's deliberate work (leak-metrics + portGuard + rev-pinned `nixpkgs-llama-rag` input, matching the 2026-09-18 evening AGENTS.md notes), NOT drift. The re-enable rode heuristic auto-commit daemon commits (`076836fe`, `56400267`) — no attributed commit exists.
5. **Coredump evidence:** `llama-server` **SIGSEGV at 10:24 Sep 18 from a `llama-cpp-0.4.0` build** (561 MB coredump written to QLC root `@`) — a build DISCREPANCY vs the 0.3.0 instances started at 11:28 (see d)4). Bonus finding: quickshell SIGABRT crashes every ~2 h (4+ coredumps today; the known ScriptModel UAF).
6. **Confirmed the SECOND missed backup night:** Sep 17 23:00 `btrbk-root` SIGTERM'd by the guard at 23:04:36 mid-send (unit stats: 5.4G read, 1.2G written, 3.5G mem peak). Pool receives still end at `@.20260915T2300`. `@home-hermes` receives: **0**.
7. **D-state snapshot:** `amdgpu_amdkdk_restore_userptr_worker` in D — GPU-driver churn corroborating the llama/ROCm spin (`kfd_wait_on_events` class).
8. **Gatus cross-check:** "llama.cpp Embeddings" check FAILING at 11:25 while Reranker was green — endpoint-level confirmation the re-enabled stack was unhealthy.
9. **Freshness probe (20:16):** guard at **trip #484**; **llama-servers GONE from `ps`**; io PSI some avg10=36.5 / **avg60=33.2 — below the 40% trip threshold for the first time in days**; tonight's 23:00 btrbk pending. Storm waning exactly as the attribution predicts.
10. Todos re-established (4 items) per the handoff instruction.

## b) PARTIALLY DONE

1. **Storm-driver attribution** — strong but not airtight: (i) the live 60-second rate measurement was interrupted, so the headline 15.8 MB/s figure carries a caveat (cgroup io.stat RESETS on unit restart — the 11:28 restart means bundle-delta math may mix restart artifacts in); (ii) the storm ALSO raged Sep 16–17 while llama-rag was nominally disabled — the driver of THAT window (trips #299–#337; crush sessions? discordsync?) has NOT been attributed from the older bundles yet.
2. **Diskstats analysis** — direction correct (QLC root `nvme0n1p6` saturated with reads; Samsung `nvme1n1p2` at 21% busy; DAS disks idle; `/data` model partition ~0 reads — so the spin does NOT re-read model files), but my parse produced **impossible busy percentages (5950%)** — field misalignment vs the bundle format; needs a live re-parse before any number from it is cited.
3. **Prior session's working-tree changes** still present, still undeployed, still carrying the known exit-4 hazard: `snapshots.nix` verify-gate fix (eval-verified, +7/−1), `AGENTS.md` gotcha bullet, the two 09-17 status reports.

## c) NOT STARTED (this session)

1. **The guard fix — all four items**: staged catch-up re-arm for `btrbk-*`, backup-starvation escalation metric + alerting, restore-capped log dedup, top-IO-offender line in trip messages. The guard module (~800 lines) is STILL not read in full — mandatory before editing.
2. **Backup seed handoff** — and while the storm ran, a manual `btrbk-root` start would have been guard-killed anyway (correctly).
3. **Mount options fix** — `/nix` + `/mnt/hot` still lack `commit=300` + `nodiscard` (doctrine violation found 09-17).
4. **oomd attribution** for the Sep 17 04:01 hermes SIGKILL (one journalctl command, still not run).
5. **The three owed answers** (now owed 3+ turns): `/mnt/hot` naming, DiscordSync-first per-service migration design, disk-layout "what you're missing" synthesis. Evidence gathered across sessions; no answer delivered.
6. **Generation check** — which generation deployed the llama-rag re-enable; `/run/current-system` anchoring state (interrupted before running).
7. Post-receive steps: verify-posture decision, hermes subvol finalize.

## d) TOTALLY FUCKED UP!

1. **Two interrupted tool calls with zero results:** I announced a 7-step plan and fired the first two probes; they died to the interrupt. Announce-then-dangle — the calls should have been fired-and-completed in one breath.
2. **Published impossible derived metrics:** my diskstats delta math output 5950% disk-busy and I reported it without the obvious sanity bound (busy% >100% = parse bug BY DEFINITION). Derived metric → validate → then trust. Same discipline class as the phantom-green checks this repo keeps documenting.
3. **Carried from last session (on record, restated for completeness):** the false "guard has no attribution" claim — io-psi-forensics was wired on every trip since ~09-14. Corrected, but it cost a day and trust.
4. **The build-discrepancy was flagged, not chased:** a `llama-cpp-0.4.0` llama-server crashed at 10:24 while `0.3.0` instances (started 11:28) are what `ps` showed. Is the rev-pinned `nixpkgs-llama-rag` input actually feeding the units, or did a generation mismatch run the WRONG build half the day? Interrupted before resolving — unresolved and load-bearing for the llama-rag decision.
5. **Process failure across sessions:** 300+ forensic bundles sat unread for ~4 days while I theorized about the storm. The evidence was captured, on disk, and one `cat` away — twice told before I read it. (Mitigation landed: none yet — see e)1.)
6. **Near-miss (held correctly, worth recording):** I nearly classified the llama-rag re-enable as config drift to revert. It is a parallel session's deliberate work; the heuristic auto-commit log initially made it LOOK like drift. Only mid-analysis reading of the 09-18 AGENTS.md notes prevented a stomp.

## e) WHAT WE SHOULD IMPROVE

1. **Evidence-first ordering:** when forensics/tripwire data is already captured, READ IT before proposing or building anything. This one habit would have named the driver two sessions and ~460 guard trips ago.
2. **Sanity-bound every derived metric** (busy% ∈ [0,100]; rates ≤ device spec). Impossible output = parse bug, stop and re-derive from `/proc` live.
3. **Live-rate measurement before bundle-delta trust:** cgroup io.stat resets on unit restart — always pair bundle deltas with a live 60 s `/proc/<pid>/io` + `io.stat` sample, and note restart artifacts.
4. **Check deployed-generation state** (`readlink /run/current-system`, `/nix/var/nix/profiles/system`) before attributing working-tree config to running units — the re-enable proves tree and runtime can diverge silently for hours.
5. **Fire-and-complete:** never end a message with announced-but-unexecuted tool calls; the interrupt window is exactly where context is lost.
6. **Add a "resurrection detector":** the 2026-09-16 llama-rag config-disable was silently reverted and NOTHING alerted on "a unit I deliberately disabled is running again." A drift tripwire (declarative-disable vs running-state) would have caught it in minutes. Candidate task below.
7. **The guard's trip lines still don't name offenders** even though forensics captures them — the fix is item 4 of the guard work; this session proved the value (manual bundle-reading took 4 commands; the guard could have said it every trip).

## f) Things to get done next (ranked, not all P0)

**P0 — unblock backups + storm closure:**
1. Owner decision on llama-rag (question g)1): re-disable until the ROCm/kernel root-cause lands, or keep the parallel session's experiment running. Highest-leverage storm control; last night proved the cost of inaction (2nd missed backup).
2. Guard fix 1/4: staged catch-up re-arm — resume `btrbk-*` churn units on a sustained quiet streak (e.g. io avg60 < 25% for 3 consecutive runs) while balances/scrubs keep the strict <40% full-drain gate; tonight's 23:00 timer is the first live test candidate.
3. Guard fix 2/4: `memory_emergency_guard_backup_starved` metric (churn window open > 6 h with btrbk units stopped) + Gatus check + sev1 notify consumer — makes the silent +24 h backup slip class page.
4. Guard fix 3/4: restore-capped log dedup (log once per state change, not every 30 s run).
5. Guard fix 4/4: top-IO-offender line in trip journal messages (per-cgroup io.stat delta tracking in the guard state dir).
6. Read `memory-emergency-guard.nix` IN FULL before any of the above (still pending).
7. Deploy the guard fix (user-run `nix run .#deploy`) and verify the catch-up path fires on the first quiet streak.
8. Backup seed once quiet holds: `sudo systemctl start btrbk-root.service` (user-run); verify `@home-hermes` + `@.20260916T2300`+ receives land in `/mnt/pool/backups/root/`.
9. Verify tonight's (Sep 18) 23:00 btrbk outcome tomorrow — with PSI already at 33% and llama gone, it has its first real chance in three nights.
10. snapshots.nix verify-gate posture: implement WARN-until-first-receive (self-resolving: fatal only once a `@home-hermes` receive has ever landed) — removes the exit-4 deploy hazard AND the open question in one shape.
11. Finish the interrupted live-rate measurement (60 s `/proc` deltas) to lock the attribution beyond the restart-artifact caveat.
12. Attribute the Sep 16–17 window (trips #299–#337) from older bundles — llama-rag was disabled then; if discordsync/crush dominated, they need their own containment.
13. `journalctl -u systemd-oomd --since "2026-09-17 03:50"` — attribute the 04:01 hermes SIGKILL.
14. Generation check: which generation deployed the re-enable; is `/run/current-system` anchored (reboot-revert risk).

**P1 — owed answers + hardening:**
15. Deliver the disk-layout "what you're missing" synthesis (mount-opts gap; Samsung single-device + zero SMART/monitoring; root 77% + 118 G dead `@nix`; subvolid=5 toplevel can't snapshot; offsite leg absent; reboot owed).
16. Deliver the `/mnt/hot` naming proposal (candidates `/mnt/fast`, `/mnt/state`, `/mnt/tlc`; interacts with Phase-2 `hot/<svc>` subvol naming — decide ONCE).
17. Deliver the per-service migration design (DiscordSync first as Set C; fsync measurement first; Samsung tier).
18. Resolve the 0.4.0-vs-0.3.0 build discrepancy (d)4) — was the rev pin bypassed?
19. Mount options: add `commit=300` + `nodiscard` to `/nix` and `/mnt/hot` declarations; note remount/reboot implications.
20. discordsync at 9 MB/s sustained — journal peek (reconcile/backfill?); if chronic, its Samsung migration becomes urgent.
21. Coredump hygiene: 561 MB llama core + 207 GB cumulative coredump-slice IO — check size limits/rotation.
22. quickshell SIGABRT every ~2 h (ScriptModel UAF) — raise restart resilience or fix.
23. Extend/add the guard VM test for all four new behaviors (check `tests/` for the existing Zone-5-era guard test first).
24. Resurrection detector: eval- or runtime-tripwire when a config-disabled service's unit runs.
25. Crush-hot-db migration NEVER ran (276 `.crush` dirs, ~42 GiB on QLC) — run it in a quiet window; it is the structural storm fix for the session-DB class.
26. hermes subvol finalize after first receive + deploy (`migrate-hermes-subvol.sh status` → root-diff shadowed dirs → finalize).
27. Delete the dead `@nix` subvol (118 G) — user action, queued since 09-12; root at 77%.
28. Pool growth check after the first `@home-hermes` receive lands (~92 G full receive; pool at 12%, fine — but btrbk retention math should acknowledge it).

**P2 — background:**
29. Offsite leg (Hetzner StorageBox + Borg) — decided 09-11, not deployed.
30. Samsung SMART/health monitoring — none today.
31. Document guard threshold calibration (leave 40/20 as endorsed by TODO #515 verdict).
32. llama-rag upstream root-cause (ROCm/kernel/GPU-state bisect upstream of llama.cpp) — parked on the g)1 decision.
33. Confirm the parallel session's `llama-rag-leak-metrics` Gatus check is actually wired (coverage exists on paper).
34. VM-test the catch-up-re-arm/Zone-6 relapse loop (a resumed btrbk re-tripping within 30 s must converge, not oscillate).
35. TODO_LIST HARVEST of this report's (f) list (docs-health).

## g) Questions I cannot answer myself

1. **llama-rag fate:** the re-enable is a parallel session's deliberate, in-flight experiment (leak metrics + portGuard + rev-pinned input). It ran the regressed build all day, drove the storm alongside discordsync, and crashed twice (SIGSEGV coredumps). Do I treat it as **to-be-re-disabled now** (storm control; backups get their window) or **hands-off active work by another session**? I cannot know that session's intent or ownership — the heuristic auto-commits hide attribution entirely.
2. **Backup sequencing:** while any storm runs, manual `btrbk-root` starts get guard-killed (correctly, per the freeze-#3 doctrine). Sequence = guard fix deployed first → automatic catch-up on first quiet streak? Or do you want to force a seed window now that PSI is at 33% (llama gone), accepting the risk that a resumed send re-trips Zone 6?
3. **Reboot window:** `/nix` remount (for `commit=300`), the llama corpse/port cleanup, and the recovery-reader reset all want a reboot — and freeze #5/#6 forensics recommend one. When is your window? (`nix run .#pre-reboot-check` will run first; I cannot schedule your downtime.)

---

*Report format: Markdown at the user's explicit instruction (overrides the status-report skill's HTML default — flagged). Not committed: the auto-commit daemon owns commits in this repo. WAITING FOR INSTRUCTIONS.*
