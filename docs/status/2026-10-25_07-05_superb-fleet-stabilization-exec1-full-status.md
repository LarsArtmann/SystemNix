# SUPERB Fleet-Stabilization exec-1 — Wave 0 Gates Landed, Deploy Still Storm-Gated

**Date:** 2026-10-25 07:05 CEST · **Ask:** "READ, UNDERSTAND, RESEARCH, REFLECT. Break this down… Execute and Verify them one step at a time. Repeat until done." (SUPERB plan execution dispatch) · **Boot:** post-freeze-#33 recovery boot (gen 939-era, 06:0x still up) · **HEAD at start:** `ddc0ef3e8` · **Plan:** [docs/planning/2026-10-25_05-10_SUPERB-fleet-stabilization-truth-and-deploy-throughput.md](../planning/2026-10-25_05-10_SUPERB-fleet-stabilization-truth-and-deploy-throughput.md) (tombstoned EXECUTING `1c8961cd2`)
**Parallel sessions live throughout:** freeze-#31–33 autopsy (04:57/05:48 reports), monitor365 trust-proxy fix (`6b45b2876`), nsfw-classifier crash-loop fix (06:21 report), integration-tiles/forgejo wave (daemon-swept `644fb7e43`/`a51bc1f6a`), auto-commit daemon. All commits pathspec-scoped; no foreign files touched.

---

## a) FULLY DONE (each verified this session)

1. **Tombstone first** (`1c8961cd2`): EXECUTING marker written + committed before any task — the twin-executor guard held (no competing marker found via `docs/status/` + git-log sweep).
2. **F01/F02 — windowed IO-PSI sampler** (`scripts/io-psi-sampler.sh`, daemon-swept `fa660aa7d`): per-cgroup io.pressure (some/full avg10) + io.stat wbytes deltas over a window, top-20 by peak full-PSI and by peak write-rate, persisted under `~/.cache/psi-storm/`. Fixture selftest (storm-vs-idle ranking in both blocks) green; shellcheck clean; arg-rejection verified (rc=1). **Live 5-min capture during the storm** (first real data, persisted `~/.cache/psi-storm/summary-*.tsv`): top writers = nix-daemon **152 MB/s** peak (a parallel session's `nix build .#checks.…`, PID 3165494), user-1000.slice 42 MB/s (owner Gradle/Kotlin `webphoneandroid` battery + session scopes), **nsfw-classifier 32.7 MB/s** (its crash-loop restart churn), dnsblockd 20 MB/s; most-STALL victims = tq-agent-pool (full avg10 ≈ 60) + user@1000.service (≈ 63). monitor365 agent: IO-IDLE at probe time (0 wbytes/10s, io.pressure 0.00 — its 79.5% CPU is breaker-retry churn, not IO).
3. **T5 premise correction (live-falsified):** the plan's "Ghostty interactive-scope IO storm" is NOT tonight's storm — ghostty scopes absent from the sampler's top-20 in every probe (06:0x–06:4x). The deploy-gate-blocking storm is agent/owner build load + nsfw churn. The 10-23 ghostty attribution (three `app-niri-ghostty-*` scopes at ~70–77 full) remains valid for THAT window — two different drivers, same gate.
4. **F07–F10 — lock-float eval gate** (daemon-swept `644fb7e43`, contents verified green pre-sweep): `lib/lock-float-audit.nix` + `flake/expected-locks.nix` (registry seeded from the live lock: 93 rev-carrying root inputs; regenerate command in its header = the deliberate-float mechanism) wired into `allEvalGuards` after `lockAuditGuard`. A blanket `nix flake update` now fails eval naming every drifted input until the registry is re-stamped after a green `toplevel --keep-going` build — the 2026-10-23 four-float DOA-deploy class is structurally closed. Verified: live lock → `[]`; unit negatives (floated rev, unregistered input) throw naming the input; `checks.lock-float-selftest` (4 fixture legs: clean incl. follows+path skip, float, unregistered, stale-registry) **built green**.
5. **F11–F13 — FEATURES enable-drift standing gate** (implements the 03-42 plan's W1 1%; that executor idle since 03:43, no W1 commits, check absent — non-collision held): `lib/features-drift.nix` (pure parser+mapper; standalone-cell backticked-`.nix` file cells + ✅/🔧/🚫 status cells) + `flake/parts/checks/features-drift.nix` (eval-derived `enabledMap` from evo-x2 options+config; mapping = exact stem==ns (93/131 modules) + unique-prefix, e.g. `monitor365`→`monitor365-server`; ambiguous prefixes (attic→2, audio→2, …) and audit modules skipped by design) + `checks.features-drift-selftest` (5 fixture legs, **built green**). **Live verdict: 45 rows guarded, 0 violations** (4 ambiguous + 3 unmapped skipped) — U2's manual sweep result is now eval-pinned. Anti-blind-skip: `minGuarded = 40` throws if row anchors rot. Anchor-regex map measured live, not hardcoded.
6. **F25–F29 — watch-the-watcher:** (1) gatus check **"Node Exporter Textfile Health"** (gatus-config.nix): `[STATUS] == 200` + `[BODY] == pat(*node_textfile_scrape_error 0*)` — the 7-day dup-row blindness class now has a named tripwire (the sentinel flips 1 on ANY textfile dup/parse error, and its absence fails too); endpoints 229→230 with README re-stamped in the same change. (2) `checks.system-health-rendered-unique`: reads the REAL rendered collector (evo-x2 `system-health-metrics` ExecStart) and asserts the `for svc in` list is duplicate-free AND count-equal to the option-space deduped union — **built green** against the live tree. The dup regression class now fails at check time, not after 7 blind days.
7. **Doc-counts drift unblocked the repo** (`b0dc09825`): foreign endpoint `e22397e03` (alert relay, T-007) had landed without its stamp — every non-docs commit was failing the eval leg (README 228 vs eval 229). Re-stamped per the gate's own embedded command; commit B above then stamped 229→230 for my own endpoint in the same change that added it (the discipline the drift demonstrated as missing).
8. **F33/F34 disposition (gatus 114 / papdashboard 43 idle conns to :9100):** ACCEPT as by-design Go `http.Transport` pooling — gatus exposes no per-host idle-conn cap (timeout/dialer only), counts are stable per probe and proportional to concurrent check bursts, and the 4,353-conn pile was failing-scrape RETRY churn (the dup-row class), which drains once the fix deploys. The self-health check (a.6) is the tripwire if a pile regrows. Row closed with the post-deploy re-probe folded into the existing deploy-watch verify.
9. **Queue ↔ library surfaces synced:** TODO_LIST features-drift row → [x]; pipeline.md row 631 → [x] + new [x] lock-float row; monitoring.md +1 done row (watch-the-watcher) + conn-cap disposition + F01 tooling noted. All four surfaces edited fresh-read (three are parallel-session files).

## b) PARTIALLY DONE

| # | Item | Done | Missing | Why |
|---|---|---|---|---|
| 1 | T5 storm root-cause | sampler tool + first live attribution (a.2/a.3) | the ghostty-scope window itself was not live during this session; no ghostty-scoped fix/cap decided | the storm never presented; premise for tonight falsified instead — the tool + persisted captures arm the next window |
| 2 | T1 deploy batch | everything in-tree and eval-green (repeated full-flake evals via pre-commit runs + targeted check evals, 06:0x–07:0x) | the deploy itself | see c.1 |
| 3 | Watch-the-watcher gatus leg | check written + stamped | not LIVE (deploys with the batch) | deploy-gated by definition |

## c) NOT DONE (deliberate)

1. **T1/T2 deploy + proofs — blocked on BOTH gates all session:** io PSI cycled avg10 25–45 / avg60 28–52% (never sustained <30%) AND k10temp cycled 80→98.75°C repeatedly (deep-throttle bounce; the freeze-#33 autopsy's live re-arm warning stands — build battery + nsfw churn kept re-heating it). Deploying a toplevel build into that window is freeze-#34 bait per the family precedent and the autopsy's owner ask d)1. The batch (volume cuts + retention + backup memory caps + MONITOR365_SERVER__MEMORY_LIMIT + retention.sh DUCK_SESSION + node_exporter dedupe + trust-proxy + alert-relay + integration/forgejo wave + my two checks) rides the FIRST genuinely calm window — the standing [watch] row in services.md owns the fire procedure (`nix run .#deploy`, anchor-by-NUMBER verify, post-deploy battery, F17–F21 proofs).
2. **T8/T9 hot-tier moves** — sequenced after T1 by the plan's own graph.
3. **T10–T12 upstream wave** — standing owner question 3 (push authorization) unanswered; nothing written upstream.
4. **T13 system-health decompose, T15 eval-red remainder (hermes IFD leg), T16 CHANGELOG retag, T17–T19 drills + /data alarm, W4 triage waves** — not reached this session; all remain [ready]/[decision] in their libraries. The session's Pareto allocation went to the two permanent gates + watch-the-watcher (the plan's own Wave-0/2 ordering under a locked deploy window).

## d) OWNER LEVERS (F22–F24 packet — exact, verified)

**Lever 1 — tenant event-cap 1B → 250k (the drain throttle).** The live value re-arms on EVERY boot: `monitor365-schema-migrate` runs `UPDATE tenants SET max_events_per_day = 1000000000` (monitor365.nix; runbook line "Daily event limit override"). Two ways to restore 250k:
- In-tree (rides the next deploy): change that UPDATE's literal in `modules/nixos/services/monitor365.nix` to `250000`.
- Immediate (sudo, no deploy): `sudo duckdb /var/lib/monitor365-server/*.duckdb "UPDATE tenants SET max_events_per_day = 250000;"` (DB filename per runbook; the server re-reads limits per-request — no restart needed for the cap itself).
Trade-off: at 250k/day the 407.76M backlog drains over ~1,600 days (effectively frozen); unthrottled it drains in days but at the measured 38–40 GB/10-min write class (the freeze-#33 death-hour reader). **Recommendation: 250k BEFORE any pool-capacity improvement (hot-tier move T8 un-leashes the drain otherwise).**

**Lever 2 — agent intent (row 747-adjacent [blocked:user] + the [decision] fork).** The agent IS running (gen-939 restart), SSE connected, watchdog cycling healthy; backlog 407,761,140 held back only by the wedged pool. Options: (a) keep running + Lever 1 = bounded slow drain; (b) stop+mask (`sudo systemctl stop monitor365.service monitor365-agent-watchdog.timer; sudo systemctl mask …`) = backlog frozen on disk, zero risk, monitoring blind spot for desktop telemetry; (c) retire agent + trim buffer after evidence pull (deletes the bomb). If (a): update the stale CHANGELOG owner-gate note ("Inert until the owner restarts the agent").

**Lever 3 — backlog ground truth (sudo, 30s).** `sudo du -s -h /mnt/pool/services/monitor365` (+ `sudo ls -lat /mnt/pool/services/monitor365/diagnostics | head` for the flight-recorder growth row). Gauge cross-check: `cloud_sync_upload_backlog_size` at `:9191/metrics` (no auth needed). These numbers decide whether 30 GiB max-buffer headroom makes the drain bomb a disk risk too.

**Standing escalation (from the autopsy, re-measured this session):** k10temp hit 98.75°C twice more during this session under build load; every precedent says pause-first. Cooling inspection (14 baits) and the sdb fsck remain owner hands.

## e) What worked / cost us time

- Tombstone-before-execution, pathspec commits, fresh-read-before-edit on the three parallel-owned files: zero collisions across FIVE concurrent sessions + daemon.
- **`git commit | grep | head` masks commit failures** — pipeline rc comes from `head`, and `head -4` truncated the failing leg's output; both 09A commits "looked" fine while neither landed (reflog proved it). Retry pattern: full log to a file, rc from git itself. Same class as the freeze session's regex-quit lesson: suspect your own plumbing first.
- The tracked-files trap (new check file must `git add -N` before ANY eval sees it) hit exactly as documented — one eval failure, immediately recognized.
- Statix inherit rules cost three iterations (`x = x` → `inherit`; `toolA = registry.toolA` → `inherit (registry) toolA`; a `//`-override attr firing rule 04 — restructured instead of suppressed).
- Daemon sweeps absorbed the sampler + the whole lock-float gate (contents verified green pre-sweep, `git show --stat` checked each time; attribution recorded here — the amend-forward path was unavailable because the daemon pushes outpaced verification).

## f) NEXT (self-harvested)

1. [ready→watch] **Deploy the batch at the first PSI+thermal calm window** (sustained io avg10 <30% AND k10temp <85°C) — existing services.md [watch] row owns it; then F17–F21 proofs (node_exporter journal zero dup-errors, .prom one-row-per-service, :9100 conns drained, backup MEMORY_LIMIT journal line at next 03:00, retention first-fire, SSE/breaker 30-min window) + `scripts/post-deploy-check.sh`. → stays on the deploy-watch row (deliberately not re-queued: it IS the row).
2. [ready] **T13 system-health decompose phase 1** (`extraCollectors` seam) — unblocked now, pure in-tree work. → docs/todo/monitoring.md.
3. [ready] **T22 tq harvest-gate hardening** + **T15 hermes IFD leg** (row 612 remainder). → pipeline.md rows exist.
4. [watch] **F67 /data 85% alarm + du-vs-df gap** — in-tree gatus/textfile rule rides the next deploy regardless. → storage.md row exists.
5. [ready] **Ghostty-scope window capture** — run `scripts/io-psi-sampler.sh 600 10` during the next interactive-scope storm; only then decide fix vs IOWeight-cap (T5 F03–F06). → monitoring.md ghostty row.

## g) QUESTIONS (owner)

1. The plan's three standing questions (backup gap now vs 03:00-fire; drain intent + agent fate; upstream push authorization) — unchanged, packet in §d.
2. Endorse pause-builds + cooling inspection before any deploy attempt (the autopsy's ask, re-measured live at 98.75°C this session)?
