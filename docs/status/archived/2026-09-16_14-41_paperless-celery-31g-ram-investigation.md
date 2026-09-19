# Paperless Celery "31G RAM" Investigation — Interim Status

> **[docs-health 2026-09-19] RESOLVED + ARCHIVED:** resolved by the 15:21 final report: btop PID-reuse stale stats, paperless exonerated (VmHWM 196 MB); AGENTS.md gotcha added.


**Date:** 2026-09-16 14:41
**Trigger:** User pasted a monitor row and asked why paperless is "using a LOT of RAM **AGAIN**":

```
2144300 celery   /nix/store/svx59425zxp55   20 paperless   31G ⣀⣀⣀⣀⣀  0.0
```

**Bottom line so far:** Every measurable source on the machine says paperless is **NOT** using anywhere near 31G of real RAM — now or in any observed unit run (30+ days of journal peaks: ≤ 636M; cgroup hard caps in place; zero OOM kills ever). The 31G reading is either a **stale/scrollback monitor view**, a **display artifact**, or an observation **predating the memory caps** — those three hypotheses remain open. The investigation was interrupted mid-root-cause; no fix has been applied because no real problem has been proven.

---

## 1. Evidence gathered (all verified live this session)

### 1.1 The pasted PID is celery _beat_ — and it never touched 31G

- PID 2144300 = `[celery beat] --app paperless beat` (the **scheduler**, not a worker).
- Started **08:28 today** (restarted with the whole paperless stack at 08:25); PID has only existed since then.
- `/proc/2144300/status`: **VmPeak 288864 kB (282 MB), VmHWM 196 MB, VmRSS 33 MB, Threads 1, VmSwap 138 MB** (zram).
- A process cannot have shown 31G RSS or even 31G VIRT at any moment of its life with these high-water marks. **Definitive.**

### 1.2 Whole process family is tiny

| Process                                          | Role          | RSS        | VSZ    |
| ------------------------------------------------ | ------------- | ---------- | ------ |
| 2144300 `[celery beat]`                          | scheduler     | 33 MB      | 282 MB |
| 2144304 `[celeryd: celery@evo-x2:MainProcess]`   | worker parent | 158 MB     | 281 MB |
| 2065747 / 2149268 `[celeryd: …ForkPoolWorker-N]` | pool children | 142–150 MB | 281 MB |

Pool children spawn **per task** (`max-tasks-per-child=1`, confirmed by journal: every task logs a different `celery[PID]`) and are recycled in seconds. User's row showed **THREADS=20** — no current paperless process has more than 1 thread. Contradiction noted.

### 1.3 Cgroup accounting (found under `system-paperless.slice`)

| Unit                 | memory.current | memory.max | memory.peak | oom_kill |
| -------------------- | -------------- | ---------- | ----------- | -------- |
| paperless-task-queue | 282 MB         | **2G**     | 558 MB      | 0        |
| paperless-scheduler  | 18.8 MB        | **512M**   | 239 MB      | 0        |
| paperless-consumer   | 3.7 MB         | **1G**     | 151 MB      | 0        |
| paperless-web        | 50 MB          | **2G**     | 208 MB      | 0        |
| slice total          | **365 MB**     | —          | —           | —        |

Since the caps are deployed, >2G RSS is **structurally impossible** (kernel would OOM-kill; counter is 0).

### 1.4 30-day journal history (systemd "Consumed … memory peak" per unit run)

- Run ending 01:30 today: peak **533.5M**; run ending 08:25 today: peak **635.7M**.
- Kernel OOM sweep mentioning paperless/celery over 30 days: **zero hits**.
- No OCR/file-consume tasks ran in the last 24h — today's tasks are trivial (mail poll 0.03s every 10 min; `train_classifier` hourly at :05, early-returning "Training data unchanged" in ~2s).

### 1.5 The monitor row decoded (pty reproduction — the key experiment)

Ran **btop in a pty with the user's own config** and decoded the process-table rows. Confirmed layout of the user's view:

```
PID | Program | exe (nix store path) | THREADS | USER | MEM | cpu-graph | CPU%
```

- btop's **MEM column = RSS** (validated: clickhouse row shows 647M = its measured RSS; celery workers 144–155M = measured RSS).
- User config: `proc_sorting = "memory"`, `proc_mem_bytes = true` — the list is sorted by this column.
- `/nix/store/svx59425zxp55…` = **bash-5.3p15** (the paperless-manage wrapper — btop shows the wrapper exe).
- So the pasted row claims: a paperless-user celery process with **20 threads and 31G RSS** — matching **no live process and no recorded cgroup peak**.

### 1.6 System-wide context (14:24 snapshot)

- Nothing on the box holds 31G RSS. Top: a transient `nix` build (5.9G RSS), `link` 896M, dnsblockd 850M, clickhouse 666M.
- helium/chromium hold ~**1.5 TB of VIRT each** (GPU VM reservations) — VIRT-vs-RSS confusion is endemic to this box.
- clickhouse VSZ ≈ 29.7 GiB / 31.9 GB decimal — the only "31G-ish" number on the box, but it's VIRT of an unrelated process.
- `OMP_NUM_THREADS=1` is already set in the paperless unit env (nixpkgs module) — limits BLAS/OpenMP thread-fanout ballooning.
- MemoryMax caps were introduced in `ca6dd474` "feat(paperless): expand document processing and AI capabilities" (plus `8ffb2762` signoz round) — **commit dates not yet fetched** (open thread).
- Repo docs contain **no prior paperless-RAM incident** (only the 2026-08-31 tmp-cleaner `pymp-*` crash, unrelated to memory).

---

## 2. Status by category

### a) FULLY DONE

1. Live triage of the pasted PID (beat) — RSS/VSZ/peaks/threads measured; 31G excluded for this process, definitively.
2. Full paperless cgroup memory audit (all 4 units + slice; caps + peaks + oom counters).
3. 30-day OOM-kill sweep for paperless/celery — clean.
4. System-wide RSS/VSZ scan at observation time — nothing at 31G.
5. Task-queue journal analysis: task cadence, per-task pool-child churn confirmed, no heavy tasks in the observation window.
6. Monitor row semantics **empirically decoded** (pty btop reproduction with the user's config): column layout, MEM=RSS, wrapper-exe resolution, thread counts.
7. Confirmed existing guardrails: MemoryMax per unit (1G–2G), OMP_NUM_THREADS=1, max-tasks-per-child=1 (upstream).

### b) PARTIALLY DONE

1. **Root cause of the 31G reading** — hypotheses narrowed to three (see §3) but not confirmed.
2. 45-day numeric memory-peak sweep — **attempt failed silently** (pipeline: grep pattern mismatched both journal formats + `bc` unavailable → empty output). The 30-day non-numeric sweep did return values (all ≤ ~254M in its tail) but the sort was string-based; the two directly-read runs (533.5M/635.7M) prove the sweep under-reports. Needs a clean awk-based redo.
3. MemoryMax introduction timeline — commits identified (`ca6dd474`), dates not extracted; the pre-cap era is therefore unbounded.

### c) NOT STARTED

1. SigNoz / system-health census-metrics history query (`system_cgroup_mem_bytes{cgroup=~".*paperless.*"}` over 30–60d) — the single fastest definitive answer to "did paperless EVER hold ~31G".
2. Historical thread-count check (what paperless-user process ever had 20 threads — e.g. a granian/web or OCR-era process).
3. btop narrow-pane column-shift test (does btop drop/repack columns in a narrow pane such that "20/31G" could belong to a neighboring row?).
4. Correlation of past "again" sightings with deploys / consumption bursts / nix build storms.
5. Any fix work — **deliberately withheld**: nothing broken is proven, and the box's freeze history demands evidence before churn.

### d) TOTALLY FUCKED UP

1. The 45-day sweep pipeline returned **empty and I initially moved on without flagging it** — exactly the "phantom-green / pipeline masking" class this repo documents (AGENTS: verify raw summaries, not filtered tails). Caught on self-review; must redo.
2. First cgroup read: assumed `/sys/fs/cgroup/system.slice/<unit>` and got nothing — units live under `system-paperless.slice`. Wasted a roundtrip that an initial `ls` would have prevented.
3. `systemctl` is blocked in my sandbox — worked around via /proc, /sys, journalctl, and reading the deployed unit file from its store path; but this surfaced only after a failed call (should be assumed known for this environment).

### e) WHAT WE SHOULD IMPROVE (from this session)

1. **Decode the user's monitoring artifact FIRST.** Half the investigation re-derived what one pty-reproduction of btop answered in one step. Tool semantics > process forensics.
2. **Journal-format-dependent greps are fragile** — systemd's Consumed line format varies ("635.7M memory peak" vs comma variants); parse with awk field logic, not fixed-string grep.
3. **No `bc` on PATH** — use awk arithmetic for unit math.
4. **Memory guardrail parity:** paperless is NOT in `system-health`'s monitoredServices memory-over-threshold alerting path (unverified — check); if a transient balloon ever did happen, today it would be invisible to Gatus. Cheap win if absent.
5. **btop default MEM column shows RSS but users mentally conflate VIRT** (helium's 1.5TB VIRT rows sort above everything in memory-sorted views). Consider configuring btop to show both columns or a footer note in the runbook.
6. `git log -S` without `--format` dates loses the timeline keystone — always pull dates when the question is "when did protection X land".

---

## 3. Open hypotheses (ranked)

1. **Stale view / scrollback (most likely):** The user's btop pane showed a row from an earlier refresh or terminal scrollback (terminal left open across the 08:25 restart; PID 2144300 existed before 08:28 as a _different_ process). A pre-08:25 process with PID 2144300, 20 threads, and a big RSS could have been a transient nix-build / agent-session process misattributed. Explains every contradiction.
2. **Pre-cap-era real balloon ("again" = historical memory):** If `ca6dd474`'s caps are recent (days/weeks), an earlier paperless run could legitimately have ballooned (OCR/sklearn era). The 30d journal sweep saw no such peak — but the sweep is unreliable (see d.1). SigNoz history would settle it.
3. **btop display artifact:** column truncation/shift in a narrow pane, or a tree/aggregation quirk, associating 31G (e.g. clickhouse VIRT ≈ 31.9 GB decimal) with the paperless row. The "20 threads" field matching nothing real supports a repacking/misalignment explanation.

**What is NOT possible:** any current or capped-era paperless process holding 31G RSS (VmHWM/cgroup peaks/OOM counters all exclude it).

---

## 4. Next actions (proposed, awaiting user direction)

1. Redo the memory-peak sweep numerically (awk) over 60 days, all 4 paperless units.
2. `git log --format='%h %ad %s' -S MemoryMax -- modules/nixos/services/paperless.nix` — cap introduction dates.
3. Query SigNoz for `system_cgroup_mem_bytes` / unit memory history (paperless) over 60d.
4. Depending on user answers (§5): either close as display artifact + document in gotchas, or dig the pre-cap era.
5. If desired: add paperless units to system-health memory-threshold monitored set (parity with the freeze-history doctrine).

## 5. Questions for the user (cannot be determined from the machine)

1. **When exactly did you see the 31G row** — live just before you messaged me (~14:1x today), or could the btop pane have been showing older content (scrollback / pane open since before 08:25)? A rough timestamp collapses the remaining hypotheses.
2. **When you've seen this "again" before** — do you remember it correlating with anything (a deploy, document consumption, nix builds), and did the machine's _actual_ free RAM drop by ~31G at the same time, or did the box feel fine?
3. **How wide was the btop pane** (narrow side-pane vs full terminal)? And if you re-open btop now, does any celery/paperless row still show 31G?

---

## 6. RESOLUTION (14:50 — user re-pasted the row live)

The user pasted the **byte-identical row again 20+ minutes later** (same `20 paperless 31G ⣀⣀⣀⣀⣀ 0.0`, including the CPU dot-graph) while:

- the kernel reports that PID's lifetime high-water mark as **VmHWM 196MB** (a process cannot have shown 31G RSS at any moment, ever),
- celery pool children churn every 10 min, so a live memory-sorted list cannot stay byte-identical for 20 min,
- a **fresh btop instance** (pty reproduction, user's own config) shows no such row anywhere.

New evidence that closed the case:

- **MemoryMax caps landed 2026-08-16/18** (`8ffb2762`, `ca6dd474`) — paperless v3 bring-up; units have been hard-capped (1G–2G) since their first real day.
- **60-day numeric sweep (fixed awk pipeline), 174 unit-runs across all 4 paperless units: max memory peak = 0.82G.** Zero kernel OOM kills mentioning paperless/celery in 30d.

### Verdict

1. **Paperless is exonerated.** Real usage: 365MB slice total right now; 60-day worst unit-run peak 820MB; hard caps; zero OOMs. It never used 31G — not today, not in 60 days.
2. ~~The user's btop (1.4.7) process pane is frozen/stale~~ **CORRECTED (user pushback, 15:0x):** the pane updates every second — what was stale was **that one row's stats**. Mechanism: **btop per-PID cache poisoning via PID reuse** — this box is a PID-reuse machine (celery forks a fresh pool child every 10 min via `max-tasks-per-child`, nix builds fork thousands, pid_max 4.2M wraps in weeks); the previous owner of PID 2144300 (20 threads, ~31G) died, the PID was reused by celery beat at 08:28, and btop refreshed the row's _identity_ fields (name/user/exe) while keeping the _previous owner's_ stats (MEM/threads/CPU-graph — explaining the byte-identical graphs). **Proof: the user started a second btop instance → fresh cache → the bogus celery row vanished while everything else matched.** Journald `_PID=2144300` archaeology: only the current owner ever logged — the previous owner is unidentifiable from kernel records (only btop's dead cache knew it).

### Recommended actions

- User: restart btop (or resize the pane / press a key forcing a redraw) — the row will vanish. If it recurs, capture `btop --version` + steps and consider reporting upstream.
- Repo: gotcha documented in AGENTS.md (Shell & DevTools): cross-check `/proc/<pid>/status` before believing per-process memory alarms from long-running monitors; `ps` truncates user names to 8 chars (`paperless` → `paperles`) — use `ps -o user:16`.
- No config/deploy change warranted. Paperless memory alerting already exists via system-health `system_service_memory_over_threshold` (6 paperless units monitored).

---

_Session artifacts: `/tmp/btop-raw.bin` (pty btop capture), `/tmp/btop-capture.txt` (failed first capture). No repo files were modified in this session._
