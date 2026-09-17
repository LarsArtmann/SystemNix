# User-Slice Memory Alert — Stale Threshold Fix (Deploy Gate-Blocked)

**Session date:** 2026-09-17, 14:16 CEST
**Scope:** This session only — the Gatus "User Slice Memory" false alarm, its root-cause fix, verification, and the blocked deploy.
**Trigger:** Active Gatus error: `user-1000.slice memory exceeds 40G` (MemoryHigh=56G, MemoryMax=64G cited) + user: *"This limit seems way too low!"*

---

## Executive Summary

The alert is a **stale-threshold false positive, not a real memory emergency**. The slice limits were raised to **80G/90G on 2026-08-04** (user-approved: "should probably get like 90GB RAM"), but the alert threshold was a **hardcoded 40G from the old 56G/64G era** and was never touched in the raise. The machine is healthy: slice at 52-54G of 124.3G total, 67-68G available, zram 26/62G, memory PSI mild.

**Fix shipped (committed to repo, verified at eval + built-artifact level):** the threshold is no longer a constant — it is **derived at eval time from the slice's own `MemoryHigh`** (90% = **72G**), following the file's own existing doctrine ("thresholds must derive from the ceiling they guard", already used for per-service thresholds). Alert text now interpolates the real limits instead of citing dead ones.

**Deploy is BLOCKED:** `deploy.sh`'s pressure gate rejected activation — IO PSI some avg10 52% at gate time (disks 2.8% busy). 40 minutes of waiting showed PSI oscillating 22-48% (avg300 ~49%) with **zero D-states** and healthy memory — sustained user-session churn (parallel crush session builds + terminals), not a corpse pile and not a freeze-profile storm. Decision pending: keep waiting vs owner-approved `DEPLOY_FORCE_PRESSURE=1`. **The alert stays red in production until the deploy lands.**

---

## Root Cause Chain

| Layer | Fact | Evidence |
| --- | --- | --- |
| Slice limits | `MemoryHigh=80G`, `MemoryMax=90G` — LIVE (`memory.high=85899345920`, `memory.max=96636764160`) | `/sys/fs/cgroup/user.slice/user-1000.slice/*`, boot.nix:477-482 |
| Alert threshold | `userSliceThreshold = 40 * 1024^3` hardcoded; comment cited "MemoryHigh=56G, MemoryMax=64G" | system-health.nix:38-39 (old) |
| Alert message | Still claimed "MemoryHigh=56G, MemoryMax=64G" — text stale since the 2026-08-04 raise | system-health.nix:2001 (old) |
| Live state at diagnosis | slice 53.7G, machine 124.3G total / 67.9G avail, mem PSI some avg60=5.5%, zram 26/62G | `/proc/pressure/memory`, `free -g` |
| Verdict | 50G desktop session (crush agents + browsers) on a 124G box is NORMAL; 40G threshold false-fires | the 2026-08-04 doc itself already showed this pattern (user slice "at 40GiB" flapping) |

The same file already documented the correct doctrine 30 lines below the bug (`serviceMemoryThresholdFallback` comment: "Thresholds must derive from the ceiling they guard") — the user-slice threshold simply predated that lesson and was missed in the raise.

---

## The Fix (committed by auto-commit daemon, tree clean)

**`modules/nixos/services/system-health.nix`**
1. `userSliceThreshold` (flat 40G) → derived values:
   - `userSliceMemoryHighRaw` / `userSliceMemoryMaxRaw` read from `config.systemd.slices."user-1000".sliceConfig` at eval (with `or "80G"` / `or "90G"` fallbacks for hosts that don't declare the slice — rpi3-dns, VM fixtures).
   - `parseSystemdSize` — systemd size-string → bytes (binary units, handles K/M/G, null for `infinity`).
   - `userSliceAlertThreshold` = **90% of MemoryHigh** = **77309411328 (72 GiB)**; flat 72G fallback if unparsable.
   - Rationale: MemoryHigh is where kernel reclaim-throttling begins; MemoryMax (90G) stays the kernel-owned kill line. 72G gives an 8G warning runway before throttle, 18G before kill.
2. Collector comparison line now uses the derived constant.
3. `# HELP system_user_slice_memory_over_threshold` line no longer hardcodes "40G".
4. Gatus alert message now interpolates real values: *"user-1000.slice memory exceeds 72G (90% of its MemoryHigh=80G). Throttling starts at 80G, hard kill at 90G. Desktop + crush-agent sessions legitimately use 40-60G; act only if PSI/zram also degrade (memory-emergency-guard owns real pressure)."*
5. Drive-by trivial staleness (same file): GPUActive alert text "512 MiB carveout" → "1 GiB carveout" (the BIOS floor fact, AGENTS-documented since 2026-09-05).

**`platforms/nixos/system/boot.nix`** — comment-only: "93G visible RAM / ~3G left" → "~124G visible RAM since the 2026-09-05 GTT flip (~93G when sized) / ~34G left".

**`docs/gotchas-archive.md`** — OOM-crash-chain row updated: 56G/64G → 80G/90G (raised 2026-08-04), oomd 50%/20s → 60%/30s.

### Verification evidence

| Check | Result |
| --- | --- |
| `nix eval` of evo-x2 gatus endpoint | alert renders 72G / 80G / 90G correctly; conditions unchanged (`pat(*system_user_slice_memory_over_threshold 0*)`) |
| Built collector artifact (`.drv^out` via the documented leaked-drv pattern) | comparison line carries literal `77309411328` = 72 GiB; writeShellApplication bash checks pass |
| `nix flake check --no-build` | **all checks passed** (aarch64-darwin omission = documented expected warning) — also proves the parallel session's pocket-id change evals clean |
| Metric name | UNCHANGED → no pre-deploy §10 new-metric loan needed; `tests/test-gatus-patterns.nix` fixture unaffected |

---

## a) FULLY DONE

1. Root-cause diagnosis (stale 40G constant + stale alert text vs live 80G/90G limits).
2. Live-state verification from procfs (slice 53.7G, limits 80G/90G live, machine healthy).
3. Threshold derivation implemented (eval-time, drift-proof, fallbacks for slice-less hosts).
4. Alert/HELP text made self-describing (interpolated, can't go stale again).
5. Collector artifact build-verified with the correct literal; bash checks green.
6. `nix eval` of the rendered Gatus endpoint verified (72G/80G/90G in message).
7. Full `nix flake check --no-build` green.
8. Pre-deploy check suite: 62 passed / 20 warnings / 0 failed.
9. Trivial staleness fixed in the same file + boot.nix comment + gotchas-archive row.
10. Parallel-session changes identified, inspected, left untouched, flagged to user (pocket-id.nix +18, AGENTS.md +2 — Pocket ID CIMD decision doc + SMTP TLS option + `UI_CONFIG_DISABLED=true` wiring).

## b) PARTIALLY DONE

1. **Deployment** — everything verified, but `nix run .#deploy` was rejected by the deploy.sh pressure gate (IO PSI some avg10 52.06% ≥ 20%). 40 min of patient polling: PSI drained 52→30→22 then re-spiked to 43-48 (parallel crush session bursts). **The production alert is STILL RED until this lands.**
2. **Incident documentation** — gotchas-archive row updated, but no CHANGELOG.md entry was added for the threshold change, and AGENTS.md deliberately did not get an entry (the drift-proof code comment now owns the lesson; revisit if you want it memorialized).
3. **IO-pressure forensics** — established "sustained ~40-50% IO PSI, idle disks, ZERO D-states, memory healthy" but did NOT name the driving user unit (one cgroup scan away; this was also 2026-09-16 report's open next-step #1).

## c) NOT STARTED

1. Post-deploy verification (collector HELP/72G on /metrics, alert clearing within ~2 gatus cycles, gatus-pattern-lint + pre-deploy §10 on the new config).
2. Test coverage for `parseSystemdSize` + the 90%-of-MemoryHigh rule (zero automated coverage; a VM test or pure-eval negative test per repo convention).
3. Repo-wide sweep for OTHER stale-numeric references to this class (docs/FEATURES mentioning "40G" threshold; other alert texts citing limits that moved — the GPUActive "512 MiB" catch suggests a pattern, not a one-off).
4. HARVEST of section (f) into TODO_LIST/ROADMAP (docs-health).

## d) TOTALLY FUCKED UP (my mistakes this session — brutal)

1. **Broke my own PSI polling loop twice in one line** (25 min of wall clock): `awk '{print $4}'` grabbed `avg300=` instead of `avg10` (wrong field — the file is `some avg10=X avg60=Y avg300=Z total=T`), AND used invalid awk flag `-V` (gawk uses `-v`) so the exit condition could NEVER fire — the loop was guaranteed to run all 25 iterations and report "STILL_BUSY" regardless of state. The silver lining (real avg300 trend data) was accidental, not designed. Exactly the "independently verify tool output" + "pipeline-masking" lesson class from AGENTS.md — I wrote the gate-shape bug the repo's own lessons warn about.
2. **Started a deploy without measuring IO PSI first.** I verified memory PSI (6.7%) and zram but never checked `/proc/pressure/io` before `nix run .#deploy`. Worse: my own `nix flake check --no-build` + collector build had just churned the disk in the minutes before the gate read 52% — I plausibly **self-inflicted part of the pressure that blocked me**. The deploy's own gate had better instrumentation than my pre-flight.
3. **Wasted round-trips on banned/broken commands**: first `systemctl show` (banned by harness — went straight to procfs only after the error), one `nix eval --json ... --apply` with a broken filter (exit 1, stderr suppressed by my own redirection), and a `tail /tmp/nh-deploy-watch` against a file path I invented without checking it existed (silent no-op).
4. **Missed that this alert class was already documented as FLAPPING 6 weeks ago** — the 2026-08-04 status report shows "User Slice Memory — FLAPPING — user-1000.slice at 40GiB". The drift had a paper trail; a docs search for the check name at session start would have surfaced it in seconds. I went straight to the code instead.

## e) WHAT WE SHOULD IMPROVE

1. **Pre-deploy self-check ritual**: read `/proc/pressure/{io,memory}` + D-state count BEFORE invoking deploy — and never queue heavy builds/evals in the 5 min before a deploy attempt.
2. **Tested PSI-parsing helper**: this box keeps punishing ad-hoc awk one-liners (mine today; multiple AGENTS.md entries historically). One `scripts/`-style helper with fixture tests (the repo has `scripts/test-pre-deploy-metrics.sh` precedent) ends the class.
3. **Derive-don't-hardcode sweep**: audit remaining numeric thresholds against the values they guard (the file's own doctrine applied repo-wide; GPUActive "512 MiB" text proves the drift class is live elsewhere).
4. **Alert-text lint**: an eval-time check that alert messages mentioning sizes ("NNN G") match a current config value would have caught "MemoryHigh=56G" for six weeks.
5. **Deploy-gate telemetry**: when the gate blocks, it should log a one-line snapshot (PSI, D-states, top cgroup) to a state file so post-mortems don't depend on the terminal scrollback.
6. **Session-start git status**: I found the parallel session's edits only after my first edits landed; checking `git status --short` is step 0 on this shared tree (AGENTS.md rule I applied late).
7. **CHANGELOG discipline**: repo keeps a CHANGELOG.md; monitoring-threshold changes deserve an entry at fix time, not "someday".

## f) TOP THINGS TO GET DONE NEXT (≤50 — brainstorm, not commitment; [S]=this session's work, [O]=observed this session, [K]=known carry-over from AGENTS.md)

| # | Item | Tag |
| --- | --- | --- |
| 1 | Land the deploy (quiet window or owner-approved `DEPLOY_FORCE_PRESSURE=1`) — alert stays red until then | [S] |
| 2 | Post-deploy verify: collector emits 72G HELP/threshold, "User Slice Memory" goes green within ~2 cycles | [S] |
| 3 | Answer Q1/Q2/Q3 below (they gate #1's mode and whether the alert should page at all) | [S] |
| 4 | CHANGELOG.md entry for the threshold derivation change | [S] |
| 5 | Automated test for `parseSystemdSize` + 90%-of-MemoryHigh derivation (pure-eval negative test or VM) | [S] |
| 6 | Sweep live docs (FEATURES.md, AGENTS.md, CONTRIBUTING) for remaining stale "40G" user-slice references | [S] |
| 7 | Repo-wide stale-numeric sweep: alert texts/HELP strings citing limits that moved (the "56G/64G" + "512 MiB" class) | [S] |
| 8 | Name the user@1000.service unit driving the sustained 40-50% IO PSI (2026-09-16 open next-step #1; still unnamed, one cgroup scan away) | [O] |
| 9 | Identify the stuck `journalctl` (PID 2153982, hit D-state during this session) when it recurs — parent, cgroup, which collector/terminal | [O] |
| 10 | tq double-pool guard warning from pre-deploy: manual `tq-redesign serve --addr 127.0.0.1:18472` (PID 229432) running — cutover per docs/services/tq.md before trusting the systemd pool | [O] |
| 11 | crush-hot-db FIRST migration still never ran (pgrep guard: live crush sessions) — schedule a crush-free window; it is the structural fix for the QLC `.crush/` churn behind this IO class | [O] |
| 12 | Coordinate the parallel session's pocket-id change (SMTP_TLS option + `UI_CONFIG_DISABLED=true`, now committed, undeployed): confirm owner understands UI_CONFIG_DISABLED semantics (SMTP env vars become the single source of truth; email config leaves the DB) | [O] |
| 13 | Verify the 9 pre-deploy "ExecStart binary not built yet" warnings (cv-profile-probe, cv-server, papdashboard, signoz, signoz-collector, pocket-id-provision, mandb, network-local-commands) resolve at build | [O] |
| 14 | Investigate `crush-daily.goModules — unable to determine status` pre-deploy warning (could mask a real FOD drift) | [O] |
| 15 | Tested PSI-parse helper script in scripts/ (kills my awk-bug class permanently) | [S] |
| 16 | Eval-time lint: alert strings citing sizes must match current config values (would have caught 6 weeks of "56G/64G" text) | [S] |
| 17 | Reboot owed: flm corpse pins :52626 (EADDRINUSE since 2026-09-07 boot); run `nix run .#pre-reboot-check` first | [K] |
| 18 | llama-rag config-disabled since 2026-09-16 (llama.cpp mid-load spin): pin/bisect fix, then `enable = true` | [K] |
| 19 | PapDashboard groq decision: wire a groq key or disable the provider (overall /health sits at `warn`) | [K] |
| 20 | Resend domain verification for larsartmann.cloud (completes mail-relay + Pocket ID SMTP go-live) | [K] |
| 21 | btrbk /data EIO inode repair (TODO_LIST P0; /data pool backups fail nightly until then) | [K] |
| 22 | Hetzner StorageBox + BorgBackup offsite leg (decided 2026-09-11, not implemented) | [K] |
| 23 | Per-service subvolume doctrine Phase 2 (`services.hot-db` folding crush-hot-db interim module) | [K] |
| 24 | Context7 key rotation (still LIVE leak; rotation is the real fix, purge is push-time) | [K] |
| 25 | InboxClean OAuth consent-screen "In production" flip + re-auth of main account (7-day token bomb class) | [K] |
| 26 | Deploy InboxClean retro-decrypt repair (needs upstream push + flake bump) | [K] |
| 27 | DiscordSync Turso decision: upgrade plan vs permanent local-only (standing red check is the signal) | [K] |
| 28 | `NIX_GITHUB_RO_TOKEN` fine-grained PAT as CI secret — 32 private `github:` lock nodes unreadable, CI dark 120+ runs | [K] |
| 29 | GPUActive 60G threshold sanity revisit for GTT-first/124G era (text was stale; is the NUMBER still right?) | [K] |
| 30 | memory-emergency-guard corpse-aware restore skip (P1; restore churn burns the daily budget) | [K] |
| 31 | flm v1.0.3 staged go-live decision (fails post-fix; upstream issue now eligible) | [K] |
| 32 | Signoz pair bump (signoz-src +42, collector-src +7) — MIGRATION-REVIEW, not a hash chore | [K] |
| 33 | monitor365 re-enable owner decision (private wireguard-collector crate) | [K] |
| 34 | sops-nix buildGo125 alias shim — drop when upstream > 13616fff lands | [K] |
| 35 | playwright overlay shims (django-polymorphic strip + d2 browsers-chromium) — drop when nixpkgs repairs | [K] |
| 36 | btrbk /data pool receives: zero complete received subvols (oom-kill + EIO) — blocked by #21 | [K] |
| 37 | Paperless old SQLite export recovery decision (recover vs delete) | [K] |
| 38 | Old `@nix` subvol deletion at /mnt/btrfs-root (TODO Phase 1 dead weight) | [K] |
| 39 | `/rust-cache` leftover user-run cleanup (rmdir + `@go/@npm/@cargo` subvol deletes) | [K] |
| 40 | Zone 4 calibration warning standing (avg60 ≥50 slow-burn variant) — calibrate or retire | [K] |
| 41 | User-slice cap covers UID 1000 only — document/decide posture for any future second graphical user (uncapped today) | [K] |
| 42 | Review whether `user-1000.slice` MemoryHigh/Max should scale automatically with MemTotal (they've now been re-sized twice by hand) | [K] |
| 43 | Docs-health HARVEST of this list into TODO_LIST/ROADMAP | [S] |
| 44 | Boot.nix "~34G left for kernel+system" claim: sanity-check against current system.slice usage | [S] |
| 45 | Consider Gatus check for sustained IO PSI (avg10 >40% for >30 min with idle disks) — today only the deploy gate and Zone 6 guard see it | [O] |
| 46 | CV groq `api_key empty` + citizenship seed verified done — close the loop in docs/services/cv.md if stale | [K] |
| 47 | `email_state` / fixture-vs-prod monitoring-lies audit: 1-year retro of remaining fixture-derived patterns | [K] |
| 48 | History purge: still push-HELD by design; revisit only on user flip (rotation-first stance) | [K] |
| 49 | Commit-per-task discipline when explicit commits are authorized (daemon heuristic messages bury this session's history) | [K] |
| 50 | Post-reboot follow-up owed after #17: verify flm serves, :52626 released, staged v1.0.3 gate conditions re-evaluated | [K] |

## g) QUESTIONS I CANNOT FIGURE OUT MYSELF (3)

1. **When you said "This limit seems way too low!" — did you mean the 40G ALERT threshold, or the slice's 90G MemoryMax itself?** I fixed the alert (now 72G, derived from MemoryHigh=80G). If you meant the cap is too low on a 124G machine, raising MemoryHigh/MemoryMax (e.g. 96G/108G) trades headroom away from flm (22-30G resident) + ollama (32G max) + PMA (16G max) + docker in system.slice — I need your call on that tradeoff.
2. **Deploy now or keep waiting?** The gate needs IO PSI avg10 <20%; it has bounced 22-48% for an hour (parallel crush session + terminals; memory healthy at 67G avail, zero D-states). Options: (a) keep waiting for a genuine window — could be hours; (b) `DEPLOY_FORCE_PRESSURE=1` now — documented escape, machine profile does NOT match the freeze classes (those were 60-99% PSI, D-state storms, zram-full). I recommend (b) if you want the red alert gone today; (a) if the parallel session will keep building for a while anyway.
3. **Should "User Slice Memory" remain a Discord-PAGING check at all?** Real pressure is owned by memory-emergency-guard (zones + sev1 tiers), ZRAM-fill, and PSI checks; the slice gauge mainly detects "user session is big", which 50G-of-crush-sessions days make routine. Options: keep paging at 72G (current fix), demote to non-paging/silent metric, or page only when BOTH slice >72G and a pressure signal (zram ≥80% or PSI) is hot.

---

## Live Snapshot (14:16 CEST, report time)

- IO PSI some avg10 = **38.7%** (gate threshold 20%) — deploy still blocked
- Deployed collector still OLD: `system_user_slice_memory_over_threshold 1` at slice 51.96G (40G threshold) — **alert red, expected until deploy**
- Slice limits live: high=80G, max=90G (unchanged by this work — only the alert moved)
- Git tree: clean — auto-commit daemon batched this session's files (`system-health.nix`, `boot.nix`, `gotchas-archive.md`) together with the parallel session's (`pocket-id.nix`, `AGENTS.md`) into heuristic commits
- Parallel session artifacts (not mine, untouched): `pocket-id.nix` (SMTP `tls` option, `SMTP_TLS` env, `UI_CONFIG_DISABLED=true`), `AGENTS.md` (CIMD-disabled decision paragraph)

**Status: waiting for instructions** (deploy mode + Q1/Q3 answers gate the remaining work).
