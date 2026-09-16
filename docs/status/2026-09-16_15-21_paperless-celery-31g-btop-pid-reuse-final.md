# Paperless "31G RAM" + btop PID-Reuse Stale Stats — FINAL Status

**Date:** 2026-09-16 15:21
**Supersedes/extends:** `2026-09-16_14-41_paperless-celery-31g-ram-investigation.md` (kept, with inline correction)
**Trigger:** User reported (twice, live) a btop row `2144300 celery … 20 paperless 31G` and demanded to know why paperless uses "a LOT of RAM **AGAIN**".

---

## TL;DR

1. **Paperless never used 31G.** Kernel-proven: that PID's lifetime peak is **VmHWM 196MB**; the whole paperless slice totals **365MB** now; **60 days / 174 unit-runs: worst peak 0.82G**; units hard-capped (1G–2G) since bring-up (2026-08-16/18, commits `8ffb2762`, `ca6dd474`); **zero OOM kills ever**.
2. **The 31G/20-threads numbers were stale stats for a REUSED PID in the user's long-running btop** (1.4.7). The pane is NOT frozen (user corrected me — it updates every second); only that row's stats were. btop refreshed the row's identity (name/user/exe = the new celery beat, PID reused at 08:28) while keeping the PREVIOUS PID owner's MEM/threads/CPU-graph. **Proof: a second btop instance (fresh cache) showed no such row — user-confirmed ("after starting a second, only celery got removed").**
3. The previous owner of PID 2144300 is **unidentifiable from kernel records** (journald `_PID=2144304`→`2144300` has only the current owner; only btop's dead cache knew it). Candidates by shape (20 threads, ~31G): qemu VM test, helium tab storm, flm-adjacent — unknowable now.

---

## a) FULLY DONE

1. Live triage of pasted PID 2144300 (celery **beat**): RSS 33MB / VSZ 282MB / **VmHWM 196MB** / Threads 1 / VmSwap 138M — 31G excluded for its entire life, in one shot.
2. Full cgroup audit (units live under `system-paperless.slice`, not `system.slice/`): current 365MB total; per-unit peaks ≤ 558MB; `memory.max` 1G–2G verified live; **oom_kill=0 everywhere**.
3. 30-day kernel-OOM sweep mentioning paperless/celery: zero hits.
4. Task-queue journal analysis: pool children fork per task (`max-tasks-per-child=1`, new PID every task), tasks trivial in the window (mail 0.03s/10min; `train_classifier` hourly :05, early-return "Training data unchanged" ~2s; no OCR/file tasks in 24h).
5. **Empirical decode of the user's monitor** (pty reproduction with their own btop config): column layout `PID|Program|exe|Threads|User|MEM|graph|CPU%`, **MEM = RSS** (validated against clickhouse/celeryd rows), `proc_sorting="memory"`, `proc_mem_bytes=true`, btop 1.4.7; `/nix/store/svx59425…` = bash-5.3p15 wrapper exe.
6. Cap-introduction dating: `git log -S MemoryMax` → 2026-08-16/18 (paperless v3 bring-up) — no meaningful pre-cap era.
7. **60-day numeric memory-peak sweep** (fixed awk pipeline), 174 unit-runs across all 4 units: **max 0.82G**.
8. Fresh-vs-long-running btop differential (pty instance showed no 31G row) — later user-confirmed via their own second instance.
9. Journald `_PID=2144300` archaeology: previous owner never logged — documented dead end.
10. Verified paperless memory alerting exists: all 4 units in system-health `monitoredServices` list + integration `monitored = true` (×5) in `paperless.nix`.
11. Documentation: gotcha added to AGENTS.md (Shell & DevTools) — written, then **rewritten** after user correction (per-PID stale stats on PID reuse, not pane freeze); status report 14-41 written + resolution corrected inline.

## b) PARTIALLY DONE

1. **Identity of the previous PID 2144300 owner** (the true source of 20-threads/31G) — mechanism proven, identity unrecoverable (no kernel record; btop keeps no history).
2. **btop upstream bug confirmation** — sourcegraph shows the pid-cache reuse path in btop's collector (`current_procs` keyed by pid; entries survive when the pid is found again), but I did NOT pinpoint the exact stale-stats code path in the Linux collector, nor search existing upstream issues. Mechanism claim is black-box-empirical, internals unverified.

## c) NOT STARTED

1. Upstream btop issue research/filing (pid-reuse stale stats, repro: heavy pid-churn host + long-running instance + memory-sorted view).
2. btop version bump evaluation (nixpkgs) once/if an upstream fix exists.
3. SigNoz census-metrics history query (`system_cgroup_mem_bytes` for paperless) — **deliberately dropped**: the journal-based cgroup sweep settled the question with kernel-truth data.
4. Any paperless config change — **deliberately none**: nothing is broken.

## d) TOTALLY FUCKED UP (honest accounting)

1. **My verdict wording "your btop pane is frozen" was WRONG and the user had to correct me.** The evidence (byte-identical row incl. CPU graph across 20 min + kernel contradictions + my fresh-instance differential) was in hand; the correct conclusion (stale per-PID stats, live pane) was derivable from it. I conflated row-staleness with pane-staleness and wrote the wrong mechanism into BOTH the report and AGENTS.md — permanent-record claims demanded one more scrutiny pass before asserting a mechanism.
2. **45-day sweep pipeline silently returned empty** (journal-format grep mismatch + `bc` missing) and I initially moved on — the exact "pipeline masking / phantom-green" class this repo documents. Caught on self-review; redone with awk.
3. Wrong cgroup path on first attempt (`system.slice/<unit>` instead of `system-paperless.slice/`) — should have `ls`'d before catting.
4. `git log -S MemoryMax` first ran without `--format` dates — the timeline keystone (cap era) needed a second roundtrip.
5. Nearly mis-concluded "no processes run as user paperless" from an awk filter — `ps` truncates usernames to 8 chars (`paperles`); caught late, verified with `ps -o user:16`.
6. First btop capture attempt failed (`script` without a pty winsize); the python-pty method should have been first.
7. `systemctl` is blocked in my sandbox — known environment property, still burned a call on it.

## e) WHAT WE SHOULD IMPROVE

1. **Monitor-forensics FIRST**: decode the reporting artifact (tool, column semantics, fresh-vs-long-running differential) before deep process forensics. Half this session re-derived what one pty-reproduction answered.
2. **VmHWM is the one-shot weapon** for "process X uses lots of RAM" claims — it bounds the process's whole life; pair with cgroup `memory.peak` for unit history. Could become a 5-line triage script.
3. **Distinguish pane-level vs row-level staleness** before naming a mechanism; state confidence levels ("proven" vs "consistent with") explicitly in permanent docs.
4. Journal-format-dependent parsing → awk field logic, never fixed-string grep+sort+bc chains (bc absent on PATH).
5. `git log -S … --format='%h %ad %s'` — always pull dates when the question is "when did protection X land".
6. This host's PID-churn profile (celery per-task forks, nix build storms, pid_max 4.2M wrap in weeks) makes PID-reuse artifacts a RECURRING class — any per-PID tool (btop, scripts pinning pids across time) must validate identity (starttime from /proc/<pid>/stat field 22) before trusting continuity.

## f) NEXT (ranked, no padding)

1. User: note which pane lost the row (old pane too, or only absent in the new one) — pins cache-vs-shared-source for the upstream report.
2. User: rough age of the long-running btop pane — brackets the previous PID-owner era (which 20-thread/31G process it was).
3. Research existing btop issues for "pid reuse stale/wrong memory" (1.4.x); if novel, file upstream with this box's repro (heavy churn + memory sort + days-long instance).
4. Evaluate btop bump in nixpkgs when a fix lands.
5. Optional btop config hardening: `proc_sorting = "cpu lazy"` reduces constant re-sorting of a memory-sorted list (cosmetic; may reduce exposure to sort/stats misalignment).
6. Consider `scripts/proc-mem-triage.sh`: given a PID, print VmRSS/VmHWM/VmSwap/threads + cgroup current/peak/max + unit — turns this session's manual chain into one command for the next "why is X using RAM" report.
7. Keep the SigNoz census query as the fallback oracle for future monitor disputes (documented in the 14-41 report).
8. Nothing to change in paperless — caps, `OMP_NUM_THREADS=1`, `max-tasks-per-child=1`, and system-health memory alerting all verified in place.

## g) QUESTIONS (cannot be determined from the machine)

1. When you started the second btop: did the celery row vanish from the **old** pane as well, or was it simply absent in the **new** one? (Both prove staleness, but they point to different internal btop behaviors — shared collector vs per-instance cache — and decide how to phrase an upstream report.)
2. Roughly how many hours/days had that btop pane been open? (Brackets when the previous owner of PID 2144300 died — i.e., which 20-thread/31G process btop was remembering.)
3. Want me to research + draft the upstream btop issue (verify-before-filing first), or drop it here?

---

**Files touched this session:** `docs/status/2026-09-16_14-41_…md` (written + corrected), `docs/status/2026-09-16_15-21_…md` (this file), `AGENTS.md` (gotcha added, then rewritten post-correction). No Nix/config changes, no deploy. Artifacts: `/tmp/btop-raw.bin` (pty capture).
