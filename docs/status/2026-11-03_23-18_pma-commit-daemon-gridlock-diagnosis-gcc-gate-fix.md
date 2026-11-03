# PMA Commit-Daemon Gridlock — Diagnosis, GCC Gate Fix, Honest Retraction

**Session:** 2026-11-03 evening (~22:00–23:25) · **Author:** Crush agent session (single instance)
**Trigger:** owner question + pasted fleet-wide `mr status` (264 repos, 5 chdir-fail): "What is wrong with our git commit daemon?"
**Tree pin:** SystemNix HEAD `9ef607479` at edit time (daemon auto-commits continued during session; `9f0bf8e9e` was HEAD when the session started). Parallel session active — its files are attributed in the attribution note (§11).
**As-of:** 23:18 CET (live probes re-run at report-writing time).

---

## §0 TL;DR

The commit daemon (PMA, `projects-management-automation.service`) is **alive and `active/running`** — it did not die. It is **gridlocked by four stacked causes**, which is exactly why `mr status` shows mass staged-but-uncommitted work across the fleet:

1. **FastFlowLM is crash-looping** (the dominant cause): restart counter **10 by 23:16**, crash signature **escalating from SIGABRT to SEGV** — every PMA message-generation burns a 30s timeout, then falls back to heuristic commits (`ratio=1` alert at 22:10:11).
2. **The build gate had no C compiler**: 1148 of 1426 gate holds since 18:00 are `cgo: C compiler "gcc" not found` — a **gate-environment defect**, chronic since 2026-11-02 14:34. **Fixed this session** (in-tree, eval-verified, inert until next deploy).
3. **Batch-queue saturation**: 2 committer workers × (30s LLM timeouts + 20–200s gate builds) cannot drain a 260-repo evening event flood → `batch queue full, will retry on next stale sweep` loop (215×/4h).
4. **`go.work → go.work.pdg-bak` debris**: a daemon-side backup-restore cycle stages the rename, restores the disk, but leaves the **index** dirty (`AD`/`RD` states) in ~12 repos; one release commit (project-discovery-sdk `f95a37d`) was corrupted by it and repaired same-day by that session.

Plus one **retraction**: the `chore: stage pending work before dependency update` commits are **NOT PMA's** (see §6) — the writer is unattributed as of this report.

---

## §1 The four causes, with evidence

### Cause 1 — FastFlowLM demand-driven crash-loop (dominant)

| Time | Event |
| --- | --- |
| 22:10:11 | PMA WARN `heuristic fallback ratio crossed alert threshold ratio=1` |
| 22:10:47 | flm `double free or corruption (!prev)` → `code=dumped, status=6/ABRT`, **restart counter 4** |
| 22:21:16 | same double-free, post-reload, while serving |
| 22:59:55 | `status=6/ABRT` again |
| 23:16:12 | **`status=11/SEGV`** — signature escalated |
| 23:16:48 | restart counter **10**, model reloading |

This is the known class (`docs/todo/upstream.md` row "go-commit: release OPENAI_TIMEOUT + PMA re-vendor", still `[blocked:push]`): PMA's vendored go-commit hardcodes a 30s HTTP timeout, shorter than flm's 2–5 min cold load (worse tonight: `NPU busy, request queued (4/10)` backlog); the mid-prefill client-disconnect trips flm v1.0.2's heap corruption. SystemNix wires `OPENAI_TIMEOUT=10m` (module `extraEnvironment`), but the vendored go-commit predates the env knob — **inert until the re-vendor lands**. Every commit attempt therefore pays a 30s `context deadline exceeded` before falling back.

### Cause 2 — the build gate's missing compiler (FIXED this session)

`busctl get-property …Service Environment` → unit PATH carries go-1.27.2, PMA, git, go-1.26.8, coreutils, findutils, gnugrep, gnused, systemd — **no `gcc`/`cc`**. The gate (`requireCleanBuild/requireCleanVet`, live since 2026-10-31) runs `go build ./...` with that PATH, so every CGO-containing tree failed with `cgo: C compiler "gcc" not found: exec: "gcc": executable file not found in $PATH`.

Tally (journal 18:00–22:14): **1426** `build-gate: tree does not build` WARNs, of which **1148 = gcc-not-found** (false holds, ~110 distinct repos, first hit 2026-11-02 14:34), ~97 = legit `go mod tidy` needs, rest = missing go.sum entries (the dependency wave's in-flight state — legit holds, hold-not-discard working as designed on those).

**Fix:** `modules/nixos/services/projects-management-automation.nix` — `pkgs.gcc` added beside `pkgs.go_1_27` in the `path` mkBefore. **Verified:** scoped `nix eval --json .#nixosConfigurations.evo-x2.config.systemd.services.projects-management-automation.path` returns `gcc-wrapper-16.2.0` in the list; `nix fmt --` scoped run clean (0 changed). **Inert until the next NixOS switch** (gate config is written at activation, not hot-reloaded).

### Cause 3 — queue saturation

Journal WARN tally 18:00–22:14: `batch queue full, will retry on next stale sweep` **×215**; `deletion guard` ×38; `conflicts detected` ×11 + `conflicts remain` ×2; `committed via heuristic fallback` ×125. Still saturating at 23:18 (live tail: Domination, ChastityAPI, quotaboard, bank-sync, nsfw-classifier, journal all deferred). This is a throughput collapse downstream of causes 1–2, not an independent bug — it self-drains once they are fixed (gate fix needs the deploy; flm needs the crash loop to end).

### Cause 4 — `go.work.pdg-bak` staged debris

Daemon-side backup-restore cycle: renames `go.work` → `go.work.pdg-bak` **and stages the rename**, later restores the disk file but not the index → `RD` (rename staged, backup deleted in worktree) and `AD` (added staged, deleted in worktree) states. Live-observed in ~12 repos tonight (BuildFlow, cmdguard, InboxClean, Kernovia, Standup-Killer, Zlota44, universal-workflow, project-meta, smart-configs, go-structure-linter, browser-history; templ-components has its own `AD` case tracked as §21 of its 20-05 report). project-discovery-sdk's release commit `f95a37d` carried the phantom rename and was repaired (`2fba043`, `5e4b24a`) — per that repo's 19:19 report §a5/§b4, which names "the daemon's backup-restore cycle" as the writer.

**Writer attribution status:** the literal `pdg-bak` appears in NO source tree in `~/projects` (fleet-wide grep: only the two status reports) and is pickaxe-clean across `project-discovery-daemon@a6dd6a3` full history and PMA@deployed `a257580d` — the suffix is runtime-assembled (e.g. `fmt.Sprintf("%s.pdg-bak", …)`) from code not present in any current checkout.

---

## §2 Evidence ledger

| Claim | Command (verbatim probes this session) | Result |
| --- | --- | --- |
| PMA alive | `pgrep -af` + `busctl …Unit ActiveState SubState` | PID 2302, `active/running` |
| Unit PATH lacks gcc | `busctl get-property … org.freedesktop.systemd1.Service Environment` | PATH dump, no gcc/cc |
| gcc false-holds chronic | `journalctl -u projects-management-automation --since 2026-10-31 \| rg 'gcc.*not found' -m1` | first hit 2026-11-02 14:34 |
| Gate failure mix | journal 18:00–22:14 piped through `uniq -c` tallies | 1148 gcc / ~97 tidy / rest go.sum |
| flm crash-loop | `journalctl -u fastflowlm` tails at 22:11/22:14/23:18 | counters 4 → 10, ABRT → SEGV |
| Gate fix verified | `nix eval --json .#nixosConfigurations.evo-x2.config.systemd.services.projects-management-automation.path` | contains `gcc-wrapper-16.2.0` |
| "stage pending work" ≠ PMA | `journalctl -u projects-management-automation --since 00:00 \| rg 'stage pending work'` → **empty**; `git show -s` on two such commits → **no `Daemon: true` trailer** (heuristic commits carry it); pickaxe across 7 candidate automation repos → **clean** | writer unattributed |

---

## §3 a) FULLY DONE

1. **Root-cause diagnosis delivered** — all four causes identified with live evidence, symptom→cause mapping for everything visible in the pasted `mr status` (mass staged files → queue saturation + gate holds + dependency-actor staging; heuristic commit flood → flm crash loop; `go.work.pdg-bak` → backup-restore cycle).
2. **GCC gate hole fixed in-tree** — `modules/nixos/services/projects-management-automation.nix`: `pkgs.gcc` added to the gate PATH with evidence comment (1148/4h, first-hit date, parity rationale). Eval-verified (`gcc-wrapper-16.2.0` in unit path), treefmt-clean (0 changed).
3. **Runbook updated** (`docs/services/projects-management-automation.md`) — gcc-hole bullet on the gate entry + a full "2026-11-03 fleet-wide commit gridlock" incident bullet with per-cause signatures and counts.
4. **pdg-bak debris class queued** — full `[ready]` row in `docs/todo/upstream.md` (per-state cleanup commands: `RD` → `git restore --staged go.work go.work.pdg-bak`; `AD` → `git rm --cached go.work.pdg-bak`; writer-locating steps) + `[ready]` one-liner in `TODO_LIST.md` under `### services`.
5. **"stage pending work" attribution correction** — the unproven claim I shipped mid-session was tested and REFUTED (journal-silent, no daemon trailer, pickaxe-clean); correction recorded here and in §6.

## §4 b) PARTIALLY DONE

1. **The gridlock itself** — diagnosed and two of the legs fixed (gcc in-tree; flm understood) but the daemon is STILL saturated as of 23:18; the backlog drains only after (a) the deploy carries the gcc fix and (b) the flm crash loop ends.
2. **flm stabilization** — diagnosed (demand-driven, escalation to SEGV), durable fix exists but sits in the `[blocked:push]` OPENAI_TIMEOUT chain; no mitigation executed this session (deliberate: stopping a production LLM service mid-evening was not my call).
3. **pdg-bak** — class documented, cleanup commands written, affected-repo list compiled; **no repo's index was actually cleaned** (deliberate: foreign repos with possibly-active sessions; concurrent-session discipline).
4. **Runbook gridlock bullet** — written pre-escalation ("counter 4"); the 23:16 SEGV/counter-10 escalation is only in this report (runbook line updated at harvest time).

## §5 c) NOT STARTED

1. Deploying the gcc gate fix (`nix run .#deploy`) — left to the next deploy window by design.
2. Executing the pdg-bak cleanup across the ~12 repos (queued `[ready]`).
3. Locating the pdg-bak writer code path (queued, step 1 of the upstream row).
4. Verifying whether tonight's alerting legs (PMA Commit Health Gatus, `system_flm_coredumps_24h`, crash-trigger-pair composite) actually fired — the monitor leg of this incident is UNVERIFIED (queued at harvest time).
5. The go-commit `OPENAI_TIMEOUT` push + PMA re-vendor (existing row 43, `[blocked:push]` — needs owner push).
6. Attributing the "stage pending work" writer (new open question, §6).

## §6 d) TOTALLY FUCKED UP

1. **I shipped an unverified attribution claim in my first answer** — I asserted the `chore: stage pending work before dependency update` commits were "benign, earlier LLM-authored PMA commits" **without running a single verification probe**. The retraction evidence: (a) the PMA journal since 00:00 contains ZERO occurrences of that message (the journal echoes every commit message — 125 heuristic commits are all visible); (b) both sampled commits (`GmbH 534fe78`, `AI-von-Art-Bench 82cf648`) carry **no `Daemon: true` trailer**, which even the heuristic fallback path stamps; (c) pickaxe across projects-management-automation, gomend, dependabot-auto-configure, go-auto-upgrade, mr-sync, BuildFlow, project-dependency-graph (all history) finds no such string. **The writer is unknown.** Best current hypothesis: an external dependency-update automation that (i) commits pending work as a prep snapshot, (ii) stages go.mod/go.sum updates, and (iii) died or is still mid-flight — which would also make the fleet's staged dependency waves ITS leftovers, not PMA's. This violates the house rule "a claim requires an ACTUAL RUN" and "assert WHICH entity served it"; it is exactly the 2026-09-13 gitleaks-claim class. Corrected the same session via journal + git evidence.
2. **`rg -rn` typed twice, hook-blocked twice** — the `--replace`-not-recursive trap is documented in AGENTS.md verbatim, and the hook counts these as "third strike of this exact trap on this host". I repeated a documented banned form twice in one session. No damage (hook blocked both), pure round-trip waste.
3. **Minor:** templ-components was omitted from the affected-repo list in the queued upstream row (its `AD` case is self-tracked in its §21, but the omission wasn't recorded as deliberate at queueing time). Recording it here as deliberate: their session owns that repo's state tonight.

Nothing destructive: no production state mutated, no service restarted, no foreign repo touched, no `rm`/`reset`/`checkout`.

## §7 e) WHAT WE SHOULD IMPROVE

1. **Verify-before-asserting, even for "benign" claims** — the retraction in §6 cost nothing but could have; a 10-second journal grep at claim time would have prevented it. Rule now personal: any "this came from X" sentence in an answer needs its probe run BEFORE the sentence.
2. **Check the monitor leg as part of diagnosis, not after** — I diagnosed the incident but never asked "did the alarms we built for exactly this class fire tonight?" until writing this report. The PMA Commit Health metrics (2026-10-23 work) exist precisely for this; a diagnosis should open with the monitors, not close with them.
3. **Gate-environment defects need a canary** — the gcc hole shipped 2026-10-31 and false-held ~110 repos for ~33 hours before anyone looked. An eval-time assertion ("gate PATH must contain a cc wrapper") or one canary CGO repo in the selftests would have caught it day one. Cheap, structural, worth doing.
4. **Attribution-first for fleet-wide anomalies** — the staged go.mod/go.sum waves and the "stage pending work" commits appeared in my very first input; attributing their writer should have been step 2 (after pre-read), because their in-flight state is what PMA is gating on. I treated symptoms as causes.
5. **Report-time freshness** — my final answer quoted counter 4; by report time it was counter 10 with SEGV. Live incident numbers in a live session should carry "as-of HH:MM" stamps and be re-probed at every surface they're written to.
6. **Don't type banned forms** — the rg `-r` trap is in AGENTS.md word-for-word; reading it once before a long grep-heavy session would have saved two blocked calls.

---

## §8 f) UP TO 50 THINGS WE SHOULD GET DONE NEXT

Grouped; ✱ = harvested into TODO/domain libraries during this session; (o) = owner decision required; (d) = needs the next deploy; (u) = upstream/push-gated.

### Deploy & drain (the gridlock)
1. (d) Deploy the gcc gate fix and verify the ~110 held-CGO repos drain (watch `build-gate` WARN rate → 0 gcc lines).
2. (d) After deploy: confirm gate PATH on the LIVE unit carries `gcc-wrapper` (busctl probe, not just eval).
3. (d) After deploy: confirm one real LLM commit lands (`duration=10-20s`, no heuristic tag) once flm stabilizes.
4. (o) Decide tonight's flm stance: leave the crash-loop cycling, stop `fastflowlm` until the go-commit fix lands, or pause PMA (pauses auto-commits entirely).
5. (u) Push go-commit `OPENAI_TIMEOUT` → PMA re-vendor → verify a cold load survives (existing upstream.md row 43).
6. Execute the queued pdg-bak per-state cleanup across the ~12 repos (dry-run one repo first).
7. Locate the `go.work.pdg-bak` writer (crush DB + reflog timing + widen pickaxe to non-`~/projects` checkouts).
8. Fix the cycle upstream: restore must clear the INDEX and never race its own commit.
9. Triage the 11 `conflicts detected` repos — identify them from the journal and resolve or re-queue.
10. Review the 38 deletion-guard deferrals (e.g. go-atomic-write `package.json`) — do they ever drain or rot forever?
11. (o) Attribution pass on the "stage pending work" writer AND the fleet's staged go.mod/go.sum waves (crush DB + journals + commit timing).
12. (o) After attribution: either finish or roll back the half-done dependency-update wave (repos with `go mod tidy`-needed staged state).

### Monitor legs (verify what we built actually fired)
13. ✱ Verify tonight's PMA Commit Health alert path: `heuristic_fallbacks_24h ≥ 20` must have gone RED — probe the textfile metrics + Gatus history; fix a dead leg if green.
14. Verify `system_flm_coredumps_24h` and `system_flm_crash_trigger_pair_24h` caught tonight (counter 10, ABRT→SEGV).
15. Add a queue-saturation signal: metric + threshold on the `batch queue full` WARN rate (215/4h was invisible to alarms).
16. Add a gate-env false-hold signal: alert on `C compiler "gcc" not found` appearing in gate output tails (class: gate broken, not tree broken).
17. Add a held-commits gauge (per-repo hold streak + oldest held age) to the textfile collector.
18. Confirm the flm Gatus smoke check is RED right now and that alert delivery actually pages.

### Gate hardening
19. Eval-time assertion: PMA unit PATH must contain a cc wrapper (kills the gcc class forever, ~10 lines in the module).
20. (o) Decide gcc-parity vs `CGO_ENABLED=0` policy with measured gate durations (parity is current; speed alternative documented).
21. Study gate GOCACHE persistence across runs (20–200s builds × 1426 holds = real CPU; a warm cache halves it).
22. Document the gate cooldown ladder in the runbook (observed 5m → 10m → 20m → 40m at streaks 1–4; find the cap).
23. Upstream PMA: classify GATE-ENV errors (missing compiler) separately from TREE errors in gate output.
24. Post-deploy: run one known-CGO repo's `go vet` under the gate env to confirm the vet leg passes too.
25. Add one canary CGO repo to the PMA selftest surface (would have caught the gcc hole on 2026-10-31).

### flm
26. Check flm upstream for a v1.0.2 heap-corruption fix/bump (verify-before-filing; the bug is now SEGV, not just ABRT).
27. flm crash-loop guard: refuse/queue-limit client requests after N coredumps per window (corpse-guard analogue to deploy.sh's).
28. Post-fix: verify `OPENAI_TIMEOUT=10m` covers cold load + an NPU queue backlog like tonight's 4/10.
29. (o) Consider a small fast model tier for commit messages when the 35B is unhealthy (quality tradeoff is owner's call).

### PMA tuning
30. Post-drain: measure queue drain time; consider `PMA_COMMITTER_WORKERS 2→3` only with numbers (the 2026-08-09 pressure history constrains this).
31. Upstream PMA: bound the batch queue + shed with a WARN summary counter (tonight's retry loop had no backpressure signal).
32. Live-verify the "OPENAI_TIMEOUT inert" doc claim on the deployed binary (`go version -m` probe) instead of trusting docs.
33. Update upstream.md row 43 with tonight's re-fire evidence (giant-line edit, full-line-match discipline).

### Fleet hygiene (noticed during the session)
34. mr: prune the 5 dead chdir targets (Castle, bewerbungen, hierarchical-errors, payment-automation, template-SECURITY).
35. (o) Git Town WIP stash clutter across repos (`stash@{N}: Git Town WIP` seen in ≥6 repos) — keep or drop policy.
36. templ-components `AD go.work.pdg-bak` — coordinate with that repo's §21 owner to avoid double-cleanup races.
37. Watch tomorrow's CI: 125 heuristic commits tonight mean message quality is down fleet-wide; any red waves trace here.
38. (o) The vendorHash treadmill watch row (4 re-stales in 9 days) — pick release-discipline nudge vs deliberate rev-pin.

### Process/docs
39. ✱ Runbook escalation note: flm crash signature escalated to SEGV, counter 10 by 23:16 (harvested into the gridlock bullet).
40. Add "as-of" timestamps to every live number in diagnosis answers (this session's counter-4-vs-10 gap).
41. Extend the "commit-message evidence rule" habit to ANSWERS, not just commit messages (§6 lesson, encode in AGENTS.md if owner agrees).
42. Pre-commit-canary idea (19) doubles as the negative-test harness case: add to `scripts/negative-test-lints.sh` groups.

### Deferred deliberately (not queued — reasons recorded in §9)
43–50. Remaining candidates from brainstorming (alert-noise budget review, gomend/mr-sync consolidation, stash-hygiene scripting, heuristic-message quality study, PMA release cadence, discovery-daemon socket-mode audit) are NOT minted as rows: they are either duplicates of existing watch rows, lack a concrete ask, or need an owner ruling first. Recorded here so the drift-WARN recount after the next prune includes them.

---

## §9 Self-harvest record (TODO-system discipline)

Harvested at authoring time (all direct follow-ups of THIS report):
- `docs/todo/upstream.md` — pdg-bak locate+index-clean row — **landed during the session** (before this report).
- `TODO_LIST.md` `### services` — pdg-bak cleanup one-liner — **landed during the session**.
- `docs/services/projects-management-automation.md` — gridlock + gcc bullets — **landed during the session**; SEGV escalation appended at harvest time.
- `docs/todo/services.md` + `TODO_LIST.md` — **new at harvest time:** "Verify tonight's alerting legs caught the gridlock" `[ready]` row (item 13/14 above).

Deliberately NOT harvested: §8 items marked (o)/(d)/(u) are decision-, deploy-, or push-gated (queue rules: those live library-side or not at all until actionable); items 43–50 are recorded as non-asks in §8 itself. The gcc fix needs no row — it is DONE in-tree and rides the next deploy.

---

## §10 g) QUESTIONS ONLY THE OWNER CAN ANSWER

Asked via the structured prompt immediately after this report; answered there, not here.

---

## §11 Attribution note (shared tree)

Parallel session(s) were active tonight. Files dirty in the working tree that I did NOT touch: `docs/services/architecture-catalog.md`, `docs/services/dnsblockd.md`, `docs/todo/services.md` (pre-existing + my one harvest row), `docs/todo/storage.md`, `docs/status/2026-10-26_08-56_caddy-edge-live-battery-full-status.md`, `modules/nixos/services/discordsync.nix`, `scripts/negative-test-lints.sh`, `TODO_LIST.md` (their 4 rows + my 1–2). I verified my anchored edits against the current on-disk state before each write (content-pin at `9ef607479`) and co-verified none of their content. The auto-commit daemon will sweep the mixture — a pathspec commit split at next review would attribute cleanly.
