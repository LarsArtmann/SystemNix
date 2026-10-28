# Stability-extinction executor — ratification execution round

**Session:** 2026-10-28 03:05–11:09 CET (continuation of the stability-extinction executor; interrupted ~7 h mid-eval by a session suspension — resumed 10:36) · plan: [SUPERB stability](../planning/2026-10-28_01-25_SUPERB-stability-crash-extinction-pareto-plan.md) §10 execution log · prior report: [03:02](./2026-10-28_03-02_stability-extinction-executor-session-status.md)
**Trigger:** owner answered the §7 gates (~03:05) — **§7.1 all three RATIFIED** (Zone-6 split GO, hard-fail admission gate, census latch ≥2/h × 2 h + ≥20/boot), storm containment "let it run", **§7.3 both accepted** (BIOS fans/PPT + write the M25 brief). §7.2 (io.max values) SKIPPED/unanswered.
**Live at report time (11:09):** io PSI some avg10 22.8 / avg60 22.8 / avg300 24.0 — the storm is finally draining toward the <20 calm bar; boot 0 survived the night (no freeze #38: 10 h storm, 30+ zone-6 trips, old wrong-tool action each time — now the split's ratification evidence); the paused battery (PGID 1931684, session-12) still T-stopped awaiting calm; parallel sessions active (dnsblockd executor mid-rename in the tree).

---

## a) FULLY DONE (this round)

| Item | Evidence |
| --- | --- |
| **M2 Zone-6 action split — IMPLEMENTED + ENABLED** | `memory-emergency-guard.nix`: `ioPause` options (cgroupPatterns/maxPauseGroups/calmSeconds/maxPausedSeconds) + `ioActionCooldownSeconds` 150; trip-branch zone-class dispatch (zones 1–5 byte-identical legacy; zone 6 SKIPS socket+sacrifice entirely); attribution-driven tree selection (top io.stat cgroups ∩ patterns → cgroup.procs → PGIDs); **HARD never-PTY invariant** (one /proc pass, tty_nr==0 for every member; skips logged); pause-state file (epoch+pgids, merge-safe); calm-resume in the 30 s loop (avg60 < restore bar sustained `calmSeconds`, epoch-tracked, broken-stretch resets) + `maxPausedSeconds` hard cap; ≥3-trip-in-pause escalation to churn stop (never the socket); `ioPause.enable = true` on evo-x2 (configuration.nix) — **live with the next deploy** |
| **M3 admission gate — IMPLEMENTED + WIRED** | `scripts/nix-admission-gate.sh`: devshell-only `nix` wrapper, gates build/shell/develop/run/flake-check on trip-recent (guard metric OR last-trip epoch <30 min) OR PSI some avg10 ≥20 (deploy.sh doctrine at the typing layer); `ADMISSION_GATE_FORCE=1` audit-logged escape (subcommand only — argv can carry secrets); fail-closed on unresolvable real nix; fail-open on dead guard inputs; wired via devshells.nix shellHook PATH prefix (owner login shells unaffected BY CONSTRUCTION, F16) |
| **Selftests landed + registered** | `test-nix-admission-gate.sh` (10 assertions: both trip sources, both PSI axes, flake-check unit-gating, eval/fmt passthrough, force+audit, argv-free log, fail-closed) — PASS live; registered `checks.nix-admission-gate-selftest` (bash/coreutils/ripgrep nativeBuildInputs) |
| **M20 sustained-storm latch — IMPLEMENTED** | guard: `stormSustainedTripsPerHour` (2) / `stormSustainedSeconds` (7200) / `stormBootTripFallback` (20) options + epoch-file latch (unbroken-stretch semantics: set on first qualifying run, cleared the first run under the bar) + `memory_emergency_guard_sustained_storm` + `storm_latch_epoch_seconds` metrics; dedicated Gatus "Memory Guard Sustained Storm" check (system-health.nix) whose alert names the CURRENT tools (io-writer-attribution, crash-triage, ioPause-deployed-yet) |
| **M15** | mr-sync-dashboard `IOSchedulingClass = mkForce "idle"` (+priority 0) — the ~19 MB/s forever-read only consumes IO nobody wants |
| **M25 role-split brief** | `docs/planning/2026-10-28_10-45_role-split-decision-brief.md` — crash-cost table (37 freezes, 5 resets/76 h, 28-trip live boot), what-moves/stays sketch, 4 priced options, recommendation **Option A** (used mini-PC for the battery/tq-pool farm), 3 owner inputs |
| **F13 runbook** | `docs/services/memory-emergency-guard.md`: action table (zones 1–5 vs zone-6 pause vs escalation) + never-PTY + state files + latch metrics |
| **TODO close-out (both surfaces)** | 6 rows ticked: Z6 split (stability.md:162), admission leg (stability.md:140), mr-sync idle (stability.md:100), sustained latch (TODO_LIST:150), merge-decision ×2 (TODO_LIST:266 + stability.md:233 — done-by-implementation, memcg question moot for zone 6); checker **rc=0** |
| **Verification** | toplevel drvPath eval **green ×2** (M2+M3 batch, then M20 batch); two `bash scripts/test-*.sh` runs PASS; all content verified present in HEAD after THREE daemon races + one parallel-session amend-merge (`e5cddf26f` — file-by-file verified) |
| Plan execution log updated + committed (`5a874cdea`) | progress note incl. the SIGCONT handoff instruction |

## b) PARTIALLY DONE

| Item | State | Remaining |
| --- |---|---|
| **VM-test legs for the new guard behavior (F11/F12 + M20 6a-ext)** | NOT AUTHORED — the discipline says assertion+legs one unit; I wrote module+design but did not add the Z6-pause / mem-regression / latch scenarios to `tests/test-memory-emergency-guard.nix` | author the scenarios (fake CGROUP_IO_SRC + a real sleeper process for the pause target), run in the M5 quiescence battery — **the biggest honesty item of this round** |
| SEV1 leg 9d + sev1-escalation VM test | code+fixture landed (prior round), never EXECUTED (storm-banned; row 147 tracks it) | first calm window or next push's CI |
| Battery resume | instruction logged twice (plan §10 + handoff) | execute `kill -CONT -1931684` when avg60 <20 sustained ~10 min (bar: 22.8 and falling at report time) |
| M4 reader-pause automation | ungated all along (dep on M2's action shape — now satisfied) | F18–F21 not started; natural next agent leg |

## c) NOT STARTED

M11 (journal-census + crash-autopsy scripts), M13/M14 (model placement + cold-load serialization), M16 (io.max caps — owner §7.2 unanswered), M17/M18 (inboxclean/nsfw hardening — nsfw wrote 46 MB/s during the 02:15 storm leg), M21–M23 (bless armor, flush-lag review, zram recalibration — post-wave deps), M24 (library prune), M26/M27, M5/M6/M7 deploy/reboot/thermal legs (owner-window-gated).

## d) TOTALLY FUCKED UP

| Item | Honest account |
|---|---|
| **7-hour dangling background eval** | The session suspended mid-`nix eval` (job 091, started ~03:15) and I found it still "running" at 10:36 — never killed on resume-probe, dead weight for hours. Rule born: on ANY session-gap resume, first act = inventory background jobs. |
| **Commit thrash ×4 on the M3/M20 batches** | rc=1 (SC2034 — my unused var, caught by pre-commit, daemon then bypassed it), rc=128 index.lock ×2 (parallel session's legit commit + amend held it), rc=128 HEAD-moved-under-me (the amend-merge). All resolved without data loss, but ~4 wasted cycles; root pattern: staging .nix + scripts in one pathspec commit makes the slow nix legs ALWAYS race the 10-min daemon timer. |
| **VM legs not authored with the module** | The parallel boot-contract session self-flagged this exact class ("armor ships with the fix in one batch") and I repeated it: M2/M20 shipped module code whose firing proof exists only as a plan note. Mitigated by: bash-level selftests for M3, eval ×2, and the M5 battery gate — but the honest label is assertion-ahead-of-proof until the VM legs land. |
| **Big-block edit fragility** | The 26-line single multiedit on the guard failed on a 1-line mismatch (never isolated which); splitting into 4 small edits worked. On this file, under concurrent touching, small anchored edits only. |
| **Edit-staleness refusals ×3** (stability.md/TODO_LIST) | daemon mtime-touches without content changes; each refusal cost a re-read. Noted pattern; no fix available beyond re-read-before-edit. |
| **trips_this_boot metric reads 0 with 28 real trips** — NOT FIXED, NOT QUEUED | Noticed live (10:37): fresh prom, journal shows #4508→#4535. Suspected boot-epoch baseline drift (`now - uptime` recomputed per run vs stored epoch — a 1 s drift re-snapshots the baseline every run). The 2026-10-25 "loadBearing landed" close-out claim is therefore suspect on THIS boot. Queued in §f. |

## e) WHAT WE SHOULD IMPROVE

1. **Split code and docs into separate pathspec commits** — docs-only diffs skip the nix legs (instant), code gets the slow legs alone; the daemon race window shrinks by minutes.
2. **Author the VM/test legs in the SAME batch as the module change**, even when execution is storm-banned — the M5 battery then only RUNS them instead of waiting for authoring.
3. **Session-gap resume checklist:** kill/inventory background jobs → `git log` + status (expect daemon sweeps) → verify your last known content in HEAD → only then continue.
4. **The trips_this_boot drift bug** needs a row + fix (compare with tolerance, or derive boot epoch from /proc/stat btime once).
5. **On this tree, edit shared files (stability.md, guard module) in small anchored chunks** — big-block replacements are one mismatch away from failure under concurrent mtime churn.
6. Owner-facing: the §7.2 io.max question was SKIPPED in the gates round — tq-agent-pool ran +162 GB windows all night; re-ask with a concrete default proposal (§g below).

## f) NEXT (session-derived, routed)

1. [now] SIGCONT the battery at the calm bar + verify drain holds 10 min (instruction in plan §10).
2. [ready] Author the VM scenarios (Z6-pause pause/resume + never-PTY skip, mem-zone regression, latch 6a-ext) into `tests/test-memory-emergency-guard.nix`.
3. [ready] Queue + fix the `trips_this_boot` baseline-drift bug (metric reads 0 at 28 trips).
4. [ready] M4 reader-pause automation (F18–F21) — ungated, shape from plan §10.
5. [ready] M11: `journal-census.sh` + `crash-autopsy.sh` + selftests.
6. [owner-window] M5 deploy wave at quiescence (boot-chain 5 + M2+M3+M4+M15+M20 + stability batch + train-B) → anchor verify → §11/§16.
7. [owner-window] M6 reboot battery (2–3 reboots, five stacked verifications).
8. [owner+agent] M7: owner BIOS fans-100%/PPT (§7.3 accepted); agent k10temp maxima pull + fan-telemetry probe + before/after delta.
9. [owner] Read + rule on the role-split brief (recommendation: Option A).
10. [owner] §7.2 io.max values (re-ask with default proposal, §g).
11. [watch] If boot 0 dies before deploy: evidence pull FIRST (7.9/8 G vacuum edge), `crash-triage.sh` is step 0.
12. [watch] Foreign: bootcontract negative-leg red in tree (their §f.1–f.3) — nightly negative-tests would page falsely.
13. [later] M13/M14 (models → Samsung, cold-load serialization), M16 (after §7.2), M17/M18, M21–M27 per plan §1 ordering.

## g) QUESTIONS I CANNOT FIGURE OUT MYSELF

1. **M5 deploy window:** avg60 is ~23 and falling — if the calm bar holds this afternoon, do you want the wave deployed TODAY (you run `nix run .#deploy` + the 2–3 reboots), or a later scheduled window? (Everything in the wave is eval-green; only quiescence + your hands gate it.)
2. **§7.2 io.max (skipped in the gates round):** proposed default — tq-agent-pool read cap **100 MB/s** + nix build slices **150 MB/s** write, flm exempt — accept, or name different ceilings? (tq-pool ran +162 GB/10-min windows all night; M16 is blocked only on this number.)
3. **The frozen battery (session-12 `bump-dep.sh go-retry v0.9.0`, T-stopped ~9.5 h):** SIGCONT when calm (default — the owning session's build resumes mid-lint), or kill it and let that session re-dispatch cleanly?

---

**Harvest routing:** items 1–5 are this round's completions-in-flight (tracked here + the plan log; item 3 born this round and NOT yet a row — it is hereby the report's self-harvest, routed to docs/todo/stability.md on next dispatch); 6–10 owner-gated; 11–12 [watch] foreign; 13 plan-ordered. Report written at interruption per instruction; **waiting for instructions**.
