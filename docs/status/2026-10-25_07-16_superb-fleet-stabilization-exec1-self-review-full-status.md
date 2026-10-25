# SUPERB exec-1 Close-Out — Self-Review + Full Status (Storm-Gated Session)

**Date:** 2026-10-25 07:16 CET · **Ask:** brutal self-review dispatch (3×) + "report then WAIT" · **Session:** ~06:05–07:16 · **Plan:** [2026-10-25_05-10_SUPERB-fleet-stabilization-truth-and-deploy-throughput.md](../planning/2026-10-25_05-10_SUPERB-fleet-stabilization-truth-and-deploy-throughput.md), tombstoned EXECUTING exec-1 (`1c8961cd2`) · **HEAD:** `a51bc1f6a` · **Companion report (delivered mid-session):** [2026-10-25_07-05_superb-fleet-stabilization-exec1-full-status.md](2026-10-25_07-05_superb-fleet-stabilization-exec1-full-status.md) — this file adds the self-review, the honest commit-state table, and the 50-item next list.
**Parallel sessions live throughout:** freeze autopsy (04:57/05:48), monitor365 trust-proxy (`6b45b2876`), nsfw crash-loop fix (06:21), integration-tiles/forgejo wave (daemon `644fb7e43`/`a51bc1f6a`), auto-commit daemon.

---

## a) FULLY DONE (verified this session — commit state explicit)

| # | Deliverable | Verification | Commit state |
|---|---|---|---|
| 1 | Tombstone marker written BEFORE any task (twin-executor guard) | marker on disk + grep sweep for competing executors | `1c8961cd2` ✓ |
| 2 | **F01 sampler** `scripts/io-psi-sampler.sh` — windowed per-cgroup io.pressure + wbytes-delta top-20, persisted `~/.cache/psi-storm/` | fixture selftest green (storm ranked #1 both blocks), shellcheck clean, bad-arg rc=1 | daemon `fa660aa7d` ✓ (whitespace-normalized only, verified) |
| 3 | **F02 live storm capture** (5 min @15s, first real data, persisted) | sampler output (top writers: nix-daemon 152 MB/s, user-1000 42 MB/s, nsfw 33 MB/s; most-stalled: tq-agent-pool ≈60 full, user@1000 ≈63) | data file `~/.cache/psi-storm/summary-*.tsv` (not a repo artifact by design) |
| 4 | **T5 premise live-falsified:** tonight's storm ≠ ghostty (absent from top-20); drivers = agent/owner builds + nsfw churn; monitor365 agent IO-idle at probe (79.5% CPU = retry churn) | `/proc` + cgroup io.stat deltas + sampler | documented in 07-05 §a.3 + this report |
| 5 | **F07–F10 lock-float eval gate**: `lib/lock-float-audit.nix` + `flake/expected-locks.nix` (93 inputs, regenerate cmd in header) + `allEvalGuards` wiring + 4-leg fixture selftest | live lock → `[]`; unit negatives throw naming input; selftest BUILT green; evals green repeatedly | daemon `644fb7e43` ✓ (verified green pre-sweep, `git show --stat` checked) |
| 6 | **F11–F13 FEATURES enable-drift gate**: `lib/features-drift.nix` + `flake/parts/checks/features-drift.nix` + 5-leg selftest | **live verdict 45 guarded / 0 violations / 4+3 skipped**; selftest BUILT green; statix+fmt clean | **WORKING TREE — commit blocked (see d.3)** |
| 7 | **F25–F29 watch-the-watcher**: gatus "Node Exporter Textfile Health" (200 + `node_textfile_scrape_error 0` pat) + `checks.system-health-rendered-unique` (real rendered collector dup-free + count-exact) | rendered check BUILT green against live tree; endpoints 229→230 + README stamped in same change | **WORKING TREE — same block** |
| 8 | **Repo unblock #1:** doc-counts drift (foreign `e22397e03` endpoint, 228 vs 229) — re-stamped per the gate's own command | next non-docs commit attempt passed doc-counts | `b0dc09825` ✓ |
| 9 | **F33/F34 conn-cap disposition:** gatus 114 / papdashboard 43 idle conns = by-design Go transport pooling; no cap exists in gatus client config; storm pile = retry churn, drains post-deploy; self-health check is the tripwire | /proc/net/tcp UID probes (379 mid-churn), option-space reading | row closed in monitoring.md (working tree) |
| 10 | Queue ↔ library sync: TODO_LIST features-drift → [x]; pipeline.md 631 → [x] + new lock-float [x] row; monitoring.md +1 done + 1 disposition + conn row | fresh-read edits on all 3 parallel-owned files | **WORKING TREE** |
| 11 | Close-out report 07-05 (incl. **F22–F24 owner packet** with exact verified commands) | written | **WORKING TREE** |

## b) PARTIALLY DONE

1. **T1 deploy batch** — 100% in-tree + eval-green (repeated full-flake evals), deploy itself NEVER fired: io PSI cycled 25–45% avg10 and k10temp cycled 80→98.75°C all session (deep-throttle bounce; freeze-#34 doctrine). Both gates must be calm simultaneously; never were.
2. **T5 root-cause** — tool + live attribution landed; the ghostty-scope window never presented, so no fix-vs-cap decision (correctly deferred rather than guessed).
3. **Foreign `upholds` test breakage investigation** — root-caused to `tests/test-upholds-convergence.nix:82` (`systemd.units."mnt-uph.mount".upholds` — option absent from pinned nixpkgs fe13242; `upheldBy` exists); the nixpkgs option-semantics lookup was mid-flight when this dispatch arrived. Fix NOT applied (foreign work; semantics unverified).

## c) NOT STARTED (session scope, deliberately)

- T2 post-deploy proofs (F17–F21) — needs T1.
- T8/T9 hot-tier DB moves — sequenced after T1 by the plan graph.
- T10–T12 upstream wave — owner authorization unanswered (standing Q3).
- T13 decompose, T15 eval-red hermes leg, T16 CHANGELOG retag, T17–T19 drills + /data alarm, W4 triage waves (T20–T27), F69+ docs-truth legs (03-42 owner; executor idle 03:43 →, non-collision verified but scope respected).

## d) TOTALLY FUCKED UP (owned)

1. **`git commit | grep | head` masked two failed commits** (09A): pipeline rc came from `head` (always 0), and `head -4` truncated the failing eval-leg output — I read "SUCCESS" lines and assumed commit A landed while BOTH aborted silently. The reflog exposed it only at the next direct probe. Two full pre-commit eval cycles (~6 min) wasted on retry rounds built on the false belief. Lesson: capture git's own rc + full log to a file; never let a display filter own the exit code.
2. **The 07-05 report's §a table implied commits that had not landed** — items 5–7 were described with "daemon-swept ✓" for lock-float (true) but the features-drift/watch-the-watcher rows carried no explicit uncommitted flag; a reader could close the plan rows on phantom commits. Caught by this review before any consumer acted on it (the todo rows in the working tree DO say done — they ride the same uncommitted tree; corrected context here, rows stay accurate ONCE commit lands).
3. **Did not run one upfront `nix flake check --no-build` after my big edits** — every commit attempt instead surfaced tree breakage ONE attr at a time (tileExemptions → doc-counts → statix ×3 → upholds). The repo's own --keep-going doctrine exists for exactly this; I even cited it in the 07-05 report without applying it to myself. Cost: 4 commit cycles.
4. **statix triage was reactive** — three iterations of inherit-rule fixes that one pre-flight `statix check` on ALL staged files (not 2 of 4) would have collapsed into one.
5. **Selftest assert arithmetic** (guarded=3 vs 4) — I wrote expected values without dry-running the verdict first; one build cycle burned on my own arithmetic, then a semantics call (violations count as guarded) was made mid-fix — the right call, but it should have been the design from the start.
6. **Session-local noise:** first cgroup drill used `user@1000.service` (v2 layout is `user-1000.slice`); first sampler draft had the awk-sort quoting monstrosity and a selftest that mutated fixtures before sampling (rewritten before commit); jq absolute-path pure-eval error (needs --impure for getFlake). All caught same-session, none shipped.

## e) WHAT WE SHOULD IMPROVE (durable, beyond this session)

1. **Commit-outcome verification must be structural:** `git commit … > log 2>&1; rc=$?` then `tail log` — add to the session reflexes next to "show --stat before amend". Display filters must never sit between git and the operator.
2. **Pre-commit eval legs domino on shared trees** — when a commit fails on a FOREIGN attr, run the full check once (`nix flake check --no-build --keep-going` semantics: enumerate, don't whack-a-mole) before retrying; each blind retry costs ~3 min of eval on a hot box.
3. **A "tree red at HEAD" fast-probe would pay for itself** — the daemon commits WITHOUT hooks, so committed breakage is routine (tileExemptions, upholds both landed that way). One `nix flake check --no-build` gate in the daemon (or a pre-sweep check) would stop red commits at the source. Candidate row.
4. **Foreign-file fixes need an attribution convention in commit messages** ("unblocks tree; author = parallel session; fix verified by X") — I did this ad hoc twice (doc-counts, statix inherit); make it explicit.
5. **Sampler cadence:** the 5-min window was too short to catch the thermal-bounce periodicity (~10 min); next capture 20+ min. Tool already supports it.
6. **The three report surfaces (plan file, close-out report, todo rows) drifted within ONE session** — the 07-05 report said rows were updated (true) but not that the updates were uncommittable at write time. Future reports: commit-state column on every claimed deliverable (this report's table is the template).

## f) NEXT (up to 50, ordered)

**Unblock + land (this tree, now):**
1. Fix `tests/test-upholds-convergence.nix:82` — map `.upholds` to what pinned nixpkgs offers (`upheldBy` exists; verify direction semantics from nixos/modules source first), unblocking ALL non-docs commits.
2. Commit the features-drift + watch-the-watcher batches (both verified green; messages already drafted).
3. Write the CHANGELOG entry for this session's gates + sampler + checks.
4. Flip the plan tombstone to EXECUTED with scope note (done as part of close-out if not already).
5. Re-run `nix flake check --no-build` once green → confirm no further domino attrs.

**Deploy wave (first calm window: sustained io avg10 <30% AND k10temp <85°C):**
6. `nix run .#deploy` (batch carries: volume cuts, retention, backup caps, MEMORY_LIMIT, retention DUCK_SESSION, dedupe fix, trust-proxy, alert-relay, integration/forgejo wave, my 2 checks).
7. Anchor verify by generation NUMBER (`ls …/profiles | sort -V | tail -1` vs `readlink /run/current-system`), pgrep-empty first.
8. F17: node_exporter journal zero "error gathering metrics" (10-min window).
9. F18: live .prom one-row-per-service + :9100 conns drained to baseline.
10. F19: backup unit green with MEMORY_LIMIT=6G journal line (next 03:00 fire, or owner-approved manual fire).
11. F20: retention first-fire journal lines + DB size delta (VACUUM 25 GB → ~7–10 GB expected).
12. F21: agent SSE reconnect + breaker closed (30-min window).
13. `scripts/post-deploy-check.sh` full battery.
14. Verify the new gatus self-health check goes green in the gatus UI.
15. Verify features-drift + lock-float checks pass in the deployed CI cycle (they're check-time, but confirm `nix flake check` green at the new HEAD).

**Owner levers (packet in 07-05 §d):**
16. Cap restore 1B → 250k (in-tree literal OR immediate sudo UPDATE).
17. Agent intent decision: keep-running+cap vs stop+mask vs retire+trim.
18. `sudo du -s /mnt/pool/services/monitor365` ground truth + diagnostics dir growth.
19. Pause-builds decision + cooling inspection (14 baits; box hit 98.75°C twice this session).
20. sdb buildcache fsck (ext4 journal damage).
21. Upstream push authorization (gen_app migration, SsoConfigRow redaction, bounded queue).

**Monitoring truth (in-tree, low IO):**
22. T13: system-health decompose phase 1 (extraCollectors seam extraction).
23. Crash-loop detection leg ("restarts ≥N/1h for ≥2h" → SEV1 bridge) — monitoring.md row.
24. hermes-db-health boot-admission gate (stability.md row).
25. nsfw-classifier restart gating decision row (storm-aware RestartSec/backoff).
26. /data 85% usage alarm (gatus/textfile rule) + du-vs-df gap measurement (F66–F68).
27. ClickHouse thermal query for the freeze-33 death window (freeze-11 method).
28. wtmp reboot-line extraction + NVRAM reset reason (crash-vs-owner-cycle).
29. btrfs read-time csum movement vs freeze-22 baseline.

**Structural (plan Wave 3):**
30. T8: monitor365 DuckDB → Samsung hot tier (doctrine C checklist; PSI-gated migrate BEFORE mount).
31. T9: discordsync + browser-history hot-tier completions.
32. T15: hermes-python IFD rollback/forward decision (row 612 remainder).
33. T16: CHANGELOG deploy-pending retag with per-entry activation verification.
34. T17: ClickHouse native-BACKUP restore drill.
35. T18: monitor365 backup restore drill (export → fresh DB opens).
36. T22: tq harvest-gate hardening (sudo-skip, stale-snapshot, watch re-fire, log-only, stamp cap).
37. Ghostty-scope window capture (sampler 20+ min during next interactive storm) → fix-vs-IOWeight-cap decision (T5 F03–F06).

**Queue hygiene (Wave 4):**
38. F69 tombstone check on the 03-42 docs-truth plan before any T20 leg.
39. Pipeline 494-row stale-marked triage (5 sprints).
40. Services 504-row triage post-deploy retags.
41. Monitoring 137-row triage (fold T4/T14-covered rows).
42. Desktop 92 + security 16 + ai-stack 26 + pixel6 18 sweeps.
43. Docs-truth stages 2–3 + tasks/ 57 (Q2 owner-gated).

**Upstream (owner-gated):**
44. gen_app migration (new-table vs query-time) + SystemNix lock bump.
45. SsoConfigRow secret redaction + Pocket ID client rotation runbook.
46. Bounded agent offline queue (drop-oldest + dropped-counter).

**Watch items:**
47. dmesg-klogctl SIGSEGV recurrence (monitor365 diagnostic canary).
48. Boot-mirror NVRAM persistence (third reversion re-opens the guard question).
49. nixpkgs pin LIFT condition (aw-core + linux-7.3 keep-going green).
50. features-drift coverage growth: 4 ambiguous + 3 unmapped rows (attic, audio, sops, searxng…) — either give those modules registry namespaces or a mapping table, next time their files are touched.

## g) QUESTIONS (cannot resolve from repo or probes)

1. **May the next calm-window session fire `nix run .#deploy` autonomously**, knowing the batch carries OTHER sessions' undeployed-prod work (forgejo-runner migration with identity carry-over, integration tiles, trust-proxy)? Or do you want to pull that deploy yourself after reviewing the carry list (services.md deploy-watch row)?
2. **Levers 1+2 now?** Cap 1B→250k + agent keep/stop/retire — the drain-bomb decision is yours per standing rows; every pool-capacity improvement (hot-tier T8) un-leashes the 407.76M backlog until the cap is restored.
3. **Upstream push authorization** for monitor365 (and the LarsArtmann fleet): may sessions write+push the queued upstream fixes, or is upstream yours? (Also gates T10–T12 and the [blocked:push] rows across ~15 repos.)
