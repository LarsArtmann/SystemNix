# Task Status Report — Zone 6 (IO-PSI emergency guard) — self-review

**Task-Queue-ID:** `000001a09d4250c0865315a05f290879bf54`
**Date:** 2026-09-14 14:57 CEST
**Session scope:** the IO-PSI emergency guard tier task ONLY (module + test + docs + closure). Based on this session's run and what I noticed in it.

---

## a) FULLY DONE

1. **Zone 6 implemented** (`modules/nixos/services/memory-emergency-guard.nix`): trips on sustained io-pressure some avg60 ≥ `ioPsiSomeAvg60ThresholdPercent` (40) ONLY when real disk activity corroborates — max per-disk `/proc/diskstats` io_ticks delta vs the previous guard run ≥ `ioDiskBusyThresholdPercent` (20). Unknown busy (first run / unreadable) = corroborated, fail-safe. Phantom-PSI (D-state on dead automounts, idle disks) does NOT trip.
2. **Churn stops**: `ioChurnUnits` (btrbk-root/data/pool, btrfs-balance-{metadata,data}, all three btrfs-scrub units) stopped on ANY trip, never restarted by the guard (timers resume; btrbk-pool-clean heals interrupted receives). flm cold loads covered by the existing sacrifice/socket mechanism.
3. **Options + metrics**: three new module options; `memory_emergency_guard_{io_psi_some_avg60_percent, io_disk_busy_percent_max, zone6_trips_total}`; zone-counts file extended to 6 fields with backward-compatible read.
4. **VM test scenarios 8 + 8b** (`tests/test-memory-emergency-guard.nix`): real trip (io psi 55% + 40% busy over a seeded interval) trips, stops a dummy `btrfs-balance-data.service`, emits all three metrics; phantom (io psi 90%, zero io_ticks delta) does not trip. `writeFakes` gained io-PSI + diskstats fake sources (env-overridable like the others).
5. **Gatus**: existing "guard TRIPPED/died" check covers Zone 6 via `last_trip_recent`; alert text now names the I/O-stall zone and churn stops.
6. **Docs**: TODO_LIST item closed `[x]` with full DONE narrative; AGENTS.md guard bullet extended with the Zone 6 paragraph; task status report written (`docs/status/2026-09-14_14-52_task-000001a09d4250c0865315a05f290879bf54.md`).
7. **Verification**: `nix build .#checks.x86_64-linux.memory-emergency-guard` green TWICE in a row after the flake fix; `nix flake check --no-build` green (incl. gatus-pattern-lint, module-shape-lint over my files); shellcheck on the guard script passes (SC2086 directive with a plain-comment form).
8. **Commit**: `74f01ec0` carries the Task-Queue-ID footer (pathspec commit, docs-only, `--no-verify` with the pre-existing red `checks.x86_64-linux.cv` reason in the message, per AGENTS.md precedent). Never pushed. Tree clean at close.

## b) PARTIALLY DONE

1. **sev1-escalation interplay untested for Zone 6**: zone-6 trips flow through the existing guard-trip notify path by construction, but `tests/test-sev1-escalation.nix` was NOT re-run with a zone-6 prom fixture (it mocks the guard prom file; my metric additions don't touch keys it reads — reasoned, not executed).
2. **Churn-stop verified against ONE unit only**: the VM test asserts the dummy balance unit stops; the other 7 default `ioChurnUnits` are covered by `systemctl stop` being a no-op on inactive/absent units, not by test.
3. **Gatus alert text change is eval-verified only** (gatus-pattern-lint + flake check); not deployed, so the live Discord text still shows the old wording until the next deploy.
4. **Zone 6 is DORMANT in production** — the deployed guard binary predates it; it activates on the next `nix run .#deploy`.

## c) NOT STARTED

1. **Episodic-IO leaky bucket** (a Zone-5 analogue for io avg10 episodes): crash #3's observed io buildups were sustained over ~18 min, so the avg60 gate matches the incident class; deferred until telemetry shows an episodic-only io shape.
2. **ClickHouse merge churn containment** (named in the TODO item): deliberately excluded — stopping the SigNoz telemetry DB is judged worse than the stall it causes; documented in the TODO_LIST closure as a decision, not an omission.
3. **SigNoz dashboard panels** for the three new metrics.
4. **Deploy + live post-deploy verification** of Zone 6 (pre-deploy §10 will auto-loan the new metrics from the to-be-deployed config; loan retirement afterwards).

## d) TOTALLY FUCKED UP (mine, this session)

1. **The awk zero-delta sentinel bug shipped in my first implementation**: with `m` unset, a 0-delta disk never set it and my `m == ""` check printed `-1` (unknown) — meaning a TRUE idle-disk phantom would report "unknown ⇒ corroborated" and TRIP, defeating the entire phantom filter. The phantom test scenario caught it; fixed with `BEGIN { m = -1 }`. The core safety property of the feature was wrong until the test said so.
2. **Fake diskstats line had 12 stat fields instead of 11**, so `$13` was a filler, not io_ticks — busy delta silently read 0 and the trip behaved "corroborated-unknown", masking bug d.1 behind a fixture bug. Field-layout arithmetic done in my head instead of verified with `awk '{print $13}'` against the fake.
3. **Blob line-number arithmetic wrong twice**: wrote `sed '5p'/'7p'` when the real layout (sourcesBlob already emits its own `full` line) put io-some at 6 and diskstats at 8. Burned ~4 full VM test cycles on failures whose cause was fixture slicing, not logic.
4. **Nondeterministic assert**: `io_disk_busy_percent_max 40.0` depends on integer-second elapsed between seeding and run — it passed once (lucky timing), then failed on a rerun. I wrote a wall-clock-dependent exact-float assert. Fixed to assert known-and-not-minus-one.
5. **Invalid Python in the testScript on my first scenario-8 draft** (`machine.fail(...), ("...")` tuple expression — a silent no-op if it had run). Caught by inspection during a failed old_string match, not by review before writing.
6. **Multiedit partial-apply confusion**: "Applied 9 of 10" — I did not immediately diff which edit failed, then re-applied the missing block from memory and created duplicate/orphan fragments that took a cycle to untangle.
7. **shellcheck directive with an em dash** broke the directive parser (SC1125) — two build cycles burned on comment syntax, and it violated the repo's no-em-dash-in-source doctrine on top.
8. **Debug prints (Z6DEBUG) got snapshotted by the auto-commit daemon** mid-debugging and survived into a daemon commit; had to be re-removed later after I noticed them still present. Debug scaffolding should have been removed in the same logical step it was added.
9. **History-rewrite confusion**: daemon commit hashes vanished from master mid-session; I spent a round theorizing about it before doing the right thing (verify current tree content file-by-file against my expected end-state). Content had survived; the check was cheap and immediate.
10. **Hygiene droppings**: `/tmp/z6dbg`, `/tmp/z6result`, `/tmp/z6final`, `/tmp/z6final2` left behind; one stray `sed -i … /dev/null` in a heredoc (harmless error noise).

## e) WHAT WE SHOULD IMPROVE (systemic, from this session)

1. **Fixture generation should be structural, not positional**: one source-of-truth generator that writes each fake file separately (meminfo/mmstat/psi/iopsi/diskstats) instead of a mega-blob + `sed -n 'Np'` slicing. Both d.2 and d.3 are the same class: hand-maintained positional coupling between producer and consumer.
2. **Never assert exact floats derived from wall-clock elapsed in VM tests** — assert ranges or semantic properties (known, non-sentinel, above/below gate).
3. **When a multiedit reports partial application, run the diff IMMEDIATELY** — it is the cheapest possible moment to see what is missing; reconstructing from memory one step later cost a cycle.
4. **The test caught the one bug that mattered (d.1)** — this is the argument for writing the NEGATIVE scenario (phantom) BEFORE declaring the positive one (real trip) done. Keep that ordering as a habit: safety property first, then the feature path.
5. **Daemon-race protocol**: re-read files immediately before EVERY edit batch (I did reactively after tool rejections; proactive re-reads after each background job wait would have avoided two mid-air collisions).
6. **shellcheck directives are syntax-fragile**: keep them bare (`# shellcheck disable=SC2086`), explanation on its own comment line — and remember the em-dash ban includes comments.

## f) NEXT — candidate work items (impact-ordered, this task's orbit)

1. Deploy evo-x2 (`nix run .#deploy`) to activate Zone 6 + the updated Gatus alert text.
2. Post-deploy: verify the guard unit restarted, the three new metrics appear in `/metrics` (pre-deploy §10 auto-loans them), and the loan retires on the following deploy.
3. Re-run `tests/test-sev1-escalation.nix` with a zone-6-shaped guard prom fixture (extend if it lacks one).
4. Extend the VM test to stop-assert a second churn unit (e.g. dummy `btrbk-root.service`) so the full-list stop path is exercised beyond one unit.
5. Add the io metrics to the sev1 trip-alert context text (currently the bridge appends only trip churn).
6. SigNoz dashboard panel: `memory_emergency_guard_io_psi_some_avg60_percent` + `io_disk_busy_percent_max` next to the existing PSI panels.
7. Watch live telemetry for the io avg10-episodic shape; if it exists, design the episodic-IO bucket (Zone 7 candidate) with calibration from real data — do NOT preemptively build it.
8. Consider `systemctl kill` vs `stop` semantics for btrbk mid-send (stop sends SIGTERM; btrbk handles it — verify once on a real trip).
9. ~~Add a docs/services runbook stub for the guard (zones table incl. 6, restore/capped semantics, phantom filter) — currently the knowledge lives in AGENTS.md + module comments only.~~ done (harvested — TODO_LIST 2026-09-14 18:30 (guard runbook stub row))
10. ~~Clean up `/tmp/z6*` leftovers.~~ done (harvested — TODO_LIST 2026-09-14 18:30 (probe-leftovers row))
11. ~~Fix the pre-existing RED `checks.x86_64-linux.cv` fixture (already in TODO_LIST — it forced `--no-verify` on my docs commit too).~~ done (already tracked — TODO_LIST cv-fixture row)
12. Sweep the guard's `zone-counts` file for the 5-field legacy state on the deployed host (first post-deploy run reads 5 fields, zone6 defaults 0 — benign, but confirm).
13. Consider alert-dedup: zone-6 trip text vs the "I/O Stall Rate" gatus check could double-page on the same incident — check whether the existing dedup covers it.

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **Severity tiering for Zone 6**: memory conditions were demoted to notify-only by the 2026-09-02 movie-night doctrine because the guard CONTAINS them automatically. Zone 6 trips are equally self-contained — but an io-stall freeze kills the whole box (all four freezes). Should a zone-6 trip stay notify-only (consistent with memory doctrine, my current behavior), or earn warn-tier (amber banner, once) as an infra-hardware-adjacent critical?
2. **ClickHouse churn**: the TODO item named clickhouse merges as a churn source to stop. I excluded it on the judgment that killing the telemetry DB mid-incident is worse than its merge IO. Do you accept that tradeoff, or do you want a softer lever explored (e.g. `SETTINGS` merge throttling / ionice on the unit) as a follow-up?
3. **Deploy timing**: Zone 6 sits dormant until the next deploy. Deploy now to arm it, or hold for a quiet window (the box's io-PSI history makes deploys under pressure unwise, and the llama.cpp regression + reboot-owed state may factor in)?
