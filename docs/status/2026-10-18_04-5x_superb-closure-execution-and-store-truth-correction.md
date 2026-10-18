# SUPERB Closure Execution + the Store-Truth Correction

**Session:** 2026-10-18 04:23 → 04:5x CEST · **Instance:** resuming instance 1 (third executor of the wave)
**Trigger:** standing instruction: break the successor plan into steps, execute and verify one at a time.
**Plan:** [docs/planning/2026-10-18_02-36_SUPERB-tile-logos-deploy-and-closure.md](../planning/2026-10-18_02-36_SUPERB-tile-logos-deploy-and-closure.md)

## TL;DR

Epics **E4–E8, E11, E14–E16 executed and verified**; E12/E13 are IO-GATE-BLOCKED (PSI avg10 75, load 305 at decision time — guardrail 3, not skipped); E1/E2/E3/E9/E10 remain owner-gated. The session's headline is the **E4 store-truth sweep REFUTING yesterday's dotted-query "fix"**: the ClickHouse store holds `ai_meter_ttft_seconds_sum` (type Sum, 45 series) and `system_forgejo_mirror_sync_stale_count` (type Gauge, 43 series) LIVE while the dotted forms have ZERO series — dotting applies to histogram FAMILIES only. Both queries reverted; the lint gained a store-verified allowlist + inverted deadMetrics; 19/19 negative-test legs green including two new store-truth legs.

## a) FULLY DONE (evidence per item)

| # | Item | Evidence |
| --- | --- | --- |
| a1 | Tombstone FIRST (guardrail 1): EXECUTING marker in the plan header + twin-progress re-check before any edit | plan header; HEAD moved 987f60451→f9429d360 mid-session (4th session's unblock), re-pinned before every commit-class action |
| a2 | **E4 store-truth sweep (104 metric tokens → CH probe)** | `~/.cache/tilelogos/extract_metrics.py` + sweep.txt; 78 live, 26 zero-series; triage: 2 real phantoms-of-my-own-making (the dotted pair), 4 PRE-EXISTING real phantoms, GCP families expected-absent (receiver containment-disabled), rest label-value/tokenizer noise |
| a3 | **Both dotted queries REVERTED to the live underscore forms**; verified at BOTH layers (CH series + PromQL `count()` → 1 for underscore, ERR for dotted) | `dashboards/ai-meter.json` TTFT panel, `_signoz-alerts.nix` forgejo-mirror-backlog rule; surgical diffs (1 line each) |
| a4 | **Lint root-cause fix, not call-site suppression**: `underscoreLive` allowlist (5 store-verified names) + dotted phantoms INTO `deadMetrics` + dot-escaping in the dead-metric grep | `flake/parts/checks/lint-static.nix`; `signoz-query-lint` builds green |
| a5 | E7 harness hardening: `*)` guards on all three case runners (silent fall-through class), per-case log to `~/.cache/negative-test-lints/cases.log`, two NEW legs (`underscore-allowlisted` stays green; `dotted-phantom-dead` fails with the trap-4-only marker) | `scripts/negative-test-lints.sh`; **CASES=signoz,controls → 19/19 PASS** (first run caught my own `${m//./}` nix-interpolation syntax error across all 19 — fixed with sed form, re-run green) |
| a6 | **E8 §16 coverage arm**: icons < tiles FAILs; `--section-16-only` flag for cheap iteration; body extracted to `pap_section16()` | positive: **40/40 PASS**; negative hand-probe (icon-less tile in a tree copy + subset build): **coverage 39/40 → FAIL, exit 1**; shellcheck clean; AGENTS.md §16 cell + papdashboard.md updated |
| a7 | **E5 tombstone doctrine**: AGENTS.md Session Discipline rule + CONTRIBUTING cross-link + `scripts/plan-marker.sh` (start/done, sed-delimiter bug found by its own functional test, shellcheck clean, idempotence proven on a copy) | the marker convention that would have saved the 3 h twin duplication |
| a8 | **E11 scripts/lib**: `pid_of_port` (live-proven on a throwaway :18991 listener), `kill_pid` (TERM→5s→KILL, coreutils binary), `harness_scratch`; bench scripts refactored to `kill_pid`; THREE /tmp scratch sites migrated to XDG_CACHE (negative-test-lints WORK, crush-rc-test, paperless-stage0 token) | `scripts/lib/process.sh` + 4 migrated scripts, shellcheck ×3 clean |
| a9 | **E14 receiver pin check**: NO `translation_strategy` knob exists — the form behavior is the receiver's inherent family parsing; drift vectors = otel-collector lock bumps or exporter TYPE changes. Tripwires delivered: `scripts/metric-exists.sh` (exit 0/1/2 + type) + the pin-risk paragraph in monitoring.md + signoz.md cheat-sheet line | helper tested 3 ways (live/phantom/pattern) |
| a10 | **E6 docs completion**: monitoring.md "Exporter names vs store names" (type-decides doctrine + regression case study) + icons_ok pat() worked example; FEATURES.md tile-logo row; monitoring todo row REOPENED with the correction (the "emitter correct, only queries needed dots" text was itself wrong); TODO_LIST:1521 + services.md wave rows carry the revert; pack-staleness row dated (next review 2027-01-17); signoz.md + papdashboard.md cross-links | all edited files above |
| a11 | **E15 CI memos**: PapDashboard TODO row 104 (repair-vs-retire decision memo with facts + recommendation: RETIRE, consumer-gate = the CI) + pipeline.md weekly lint-baseline-diff proposal row | both repos |
| a12 | **E16 queue hygiene**: dedupe (wave rows 1+1 = sanctioned mirror pair, no dupes); premise-drift sweep (zero surviving wrong "dotted" claims in queue surfaces); 4 new pre-existing phantoms queued as [ready] (discordsync_immich_lookup_total, io_disk_busy_percent_max, io_psi_some_avg60_percent, reallocated_events — each with its evidence + probe-first note); harvest dispositions appended to the three wave reports (unharvested WARN 67→65; remainder = the deliberate backlog incl. the 04-18 report's own note); `check-todo-system.sh` structure OK | checker output in transcript |
| a13 | Session report (this file) + plan tombstone flipped to EXECUTED | plan header |

## b) PARTIALLY DONE / BLOCKED

| Item | State | Blocker |
| --- | --- | --- |
| E12 papdashboard VM test | not started — skeleton only sketched | **IO gate**: PSI some avg10 75, load 305 at decision time; a VM build under this storm is the exact 3×-freeze context the box is already in |
| E13 shim-fleet sweep (erraudit/crm/golangci) | not started | **IO gate**: per-repo upstream FOD builds are the heavy-build class; also needs upstream pushes (blocked:push by policy without builds) |
| Full `nix flake check --no-build` re-run on the final tree | my delta is covered (signoz-query-lint + gatus-pattern-lint + §16 + toplevel-eval control all green post-change) | final whole-tree re-run deferred to a calm window (evals crawl at load 305); queued in the owner handoff |
| E1.2 full pre-deploy battery on the final tree | 4th session ran 104/6/0 at 03:52; my changes since are eval-lint-covered | same deferral |

## c) CORRECTIONS TO PRIOR REPORTS (surfaces named)

The 02-32 closeout §a "On-sight fix" row, the 02-08 report §g2/§h, the monitoring.md CLOSED row, and the wave rows in TODO_LIST/services.md all asserted the dotted-store story. All now carry explicit corrections naming the refuted premise, the store evidence, and the reverted post-state: correction banner + harvest disposition in 02-32, harvest note in 02-08/02-38, reopened monitoring row, corrected wave rows. The "forgejo rule could never fire since 2026-10-16" premise is marked UNPROVEN (inferred from the lint lesson, never probed; the underscore series was live).

## d) TOTALLY FUCKED UP (all caught)

1. **I executed the predecessor's wrong fix confidently** — yesterday's session (also "me") reverted queries based on a lint lesson + one dashboard precedent, and the closeout even flagged the exact gap (§b5 "did NOT query the store") without acting on it. Today's sweep cost ~15 min and reversed it. Lesson encoded: the doctrine bullet now REQUIRES the store probe before ANY naming decision, and `metric-exists.sh` makes the probe one command.
2. **First lint edit had a nix-interpolation bug** (`${m//./}` inside an indented string): all 19 harness cases failed on a syntax error — the harness's pristine CONTROLS caught it in one run (they exist for exactly this). Fixed, re-run 19/19.
3. **plan-marker.sh shipped with a sed delimiter bug** (`|` inside the marker regex vs `|` delimiter) — caught by its own functional test before any real use; `@` delimiter + full start/done/idempotence test.
4. **Negative-probe first attempt failed on an unbuilt subset** (the copy's PAP_ICONS_DIR store path never built) — misread as a gate failure before noticing the REAL coverage arm hadn't even been reached; built the subset, re-proved 39/40 properly.

## e) IMPROVEMENTS WORTH ADOPTING

1. **Store probe before name, always** — now doctrine + one-liner tooling; the lint's allowlist/deadMetrics entries make the two known-wrong forms machine-checked.
2. **Pristine controls earn their keep** — the all-19 syntax failure would have looked like "lint broken" without the controls distinguishing tree-broken from case-broken.
3. **Plan markers work** — this session ran concurrently with TWO other active sessions (4th session's unblock landed mid-flight; HEAD moved twice) and zero work was duplicated or clobbered: tombstone at start, re-read before every edit, pathspec commits.

## f) NEXT (handoff)

1. ⛔ **Owner: deploy** (`nix run .#deploy`) — now ALSO carries the dotted-query REVERT (the wave as queued at 02:4x would have shipped a dead TTFT panel and an un-fireable backlog rule; this session's revert is part of the wave). Pre-deploy battery last full-green 03:52 (4th session); §16 re-verified 40/40 this session; re-run the full battery at a calm window if the tree moved again.
2. ⛔ **Owner: E9 icon-style decision** (services.md row) — unchanged.
3. ⛔ **Owner: E3 browser pass + E10 phone probe** — unchanged.
4. **E12/E13 at IO calm** (PSI some avg10 < 30 sustained): VM test skeleton per plan §3 E12; shim fleet per §3 E13 (build before any hash paste; never push unbuilt locks).
5. **Post-deploy E2 battery** exactly as the plan's §3 E2 steps (metrics, probes, §16 PASS, SW pap-v10, forgejo rule provisioned with the UNDERSCORE query this time).
6. Weekly lint-baseline-diff CI row (pipeline.md) is harvest-ready for a CI-capable session.

## g) Owner questions (max 3)

1. **Deploy window?** The wave is verified and now includes the correction; IO is storming (avg10 75, load 305, third freeze tonight per the 04-02 report). Recommend waiting for a sustained calm window; the battery re-run takes ~5 min right before.
2. **E9 style call** — accept semantic pack glyphs, or commission the neutral cyan set (~100 min)? Unchanged since queueing.
3. **PapDashboard CI: repair or retire?** The memo (upstream TODO row 104) recommends retiring; the consumer-side gate has caught everything the dead CI would have.
