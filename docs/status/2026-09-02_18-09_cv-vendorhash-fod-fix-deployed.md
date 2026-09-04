# Status: CV vendorHash FOD fix — deployed; dnsblockd :9090 wedge + FastFlowLM socket down as follow-ups

**Date:** 2026-09-02 18:09 CEST
**Session scope:** single pasted deploy failure (cv go-modules FOD hash mismatch) → root cause → upstream fix → relock → override removal → build → deploy → smoke verification. Nothing else researched.

---

## Incident input

User pasted a failed `nh` deploy: `cv-db30fa6-go-modules` FOD hash mismatch

- specified: `sha256-9sLO…` / got: `sha256-iI0N…`
- 9 error lines, ALL cascading from that ONE FOD (activate, etc, system-units, cv-server.service unit, profile-probe, content-sync). Root-cause enumeration: exactly one failure.

## Root cause (verified, not guessed)

1. `modules/nixos/services/cv.nix:73` carried a TEMPORARY SystemNix-side `overrideAttrs` vendorHash `9sLO…` — a quick-unblock measured for CV rev **d2f2752b**. The SystemNix lock had since moved the cv input to **db30fa6** (moving-ref `git+ssh://…?ref=master`), making the override's hash stale. CV's own flake at db30fa6 pinned `5eZW…` — ALSO stale (upstream never refreshed after source churn).
2. Trigger of the module-set shift: CV commit `28273b42` "migrate remaining encoding/json/v2 call sites back to stdlib" + auto-commits — the documented **source-only-churn class** (imports change → FOD module set changes → hash changes; go.mod/go.sum untouched).
3. Subtree drift existed (SystemNix CV-subtree go-cqrs-lite `45974a75` vs CV's own lock `1941afe5`) — so the SystemNix got-hash was NOT automatically trustworthy for CV's own pins. **Measured independently** under CV's own lock with a file-free expression:

   ```bash
   nix build --impure --no-link --expr \
     'let f = builtins.getFlake (toString /home/lars/projects/CV);
      in (f.packages.x86_64-linux.default.overrideAttrs (_: { vendorHash = ""; })).goModules'
   ```

   → got `sha256-iI0N…` — **identical** under both subtrees (the two go-cqrs-lite revs are content-identical for vendoring). Hash is subtree-stable; safe to pin upstream.

## Execution timeline

| Time (approx) | Step | Result |
|---|---|---|
| 16:35 | deploy failure pasted; root-cause enumeration | 1 FOD failure identified |
| 16:40 | lock/checkout/diff forensics; override + subtree drift found | done |
| ~17:00 | FOD hash measured under CV's own lock (no tree edits) | `iI0N…` |
| ~17:12 | parallel session had already committed identical fix in CV (`7dee7292`); my edit attempt raced and was abandoned | verified, not duplicated |
| ~17:15 | CV push (turned out already pushed by parallel session; verified `origin/master == HEAD == 7dee7292`) | up-to-date |
| ~17:2x | SystemNix `nix flake lock --update-input cv` → `7dee7292` (subtree intentionally NOT re-synced — update-input quirk; proven harmless) | done |
| ~17:3x | dropped the whole override in cv.nix (re-read first — another mid-edit race had meanwhile re-pinned it to `iI0N…`; upstream now pins it itself) | done |
| ~17:4x | `nix build …toplevel --keep-going` | **PASSED** — `cv-7dee729-go-modules` green |
| ~17:5x | `nix run .#deploy` | switch OK; smoke 83 PASS / 3 FAIL |
| ~18:0x | post-deploy-check re-run | 83 PASS / **2 FAIL** (dnsblockd :9090, FastFlowLM :52625) |
| 18:0x | CV verified live: `/health/live` → **version 7dee729**, `/export/pdf` compiles a real PDF | **goal achieved** |

---

## a) FULLY DONE

1. Root cause identified with evidence (override-stale-for-new-rev + upstream source-churn stale pin; NOT guessed — measured).
2. True vendorHash measured under CV's own lock, subtree-stability proven (`iI0N…` under both `45974a75` and `1941afe5` subtrees).
3. Upstream fix landed in CV (`7dee7292 fix(nix): refresh vendorHash for the module-set shift` — committed by parallel session, hash independently confirmed by me) and **pushed** (verified origin==HEAD).
4. SystemNix relocked: cv input `db30fa6` → `7dee7292`.
5. SystemNix cv.nix vendorHash override **removed entirely** (per its own DROP instruction) — package now plain `lib.mkDefault inputs.cv.packages.…default`; no more second source of truth.
6. Full toplevel build `--keep-going` PASSED (the Critical-Rules enumeration pass — confirmed no other latent FOD failures).
7. Deployed via `nix run .#deploy` (sanctioned path; no manual activation).
8. CV functional verification: `/health/live` reports `version 7dee729`, PDF export smoke passes — the deployed binary is the new build, not a stale generation.
9. Memory pressure sanity before heavy builds: caught a 3.0 GiB MemAvailable / zram 29.5G crunch at session start, confirmed no flm resident, deferred heavy work until it self-cleared (8.9 GiB, PSI 0.8% at build time).

## b) PARTIALLY DONE

1. **dnsblockd :9090 stats API unreachable** (deploy smoke FAIL ×2 runs + fetch probe timeout). Fresh journal evidence at 18:09: process ALIVE and resolving/blocking domains on :53, with repeated `batch writer: flush took longer than flush interval` WARNs (elapsed 1.5–3.8s) — the **exact signature of the 2026-08-27 :9090 wedge class** ("handlers stuck mid-request, CLOSE-WAIT; prime suspect healthProbe/DB mutex"). NOT a post-deploy startup delay (deploy >30 min prior). Wedge confirmation + `SIGQUIT` goroutine dump + restart all need root (`sudo systemctl` blocked in this sandbox) → left open, detection layers (SigNoz rule, `system_dnsblockd_metrics_fresh`) should be firing.
2. **FastFlowLM :52625 unreachable** (deploy smoke FAIL; fetch probe timed out). No `fastflowlm@*` connection instances since deploy. Most likely: the memory-emergency-guard stopped the socket during the session-start 3 GiB crunch (guard restores only at MemAvail ≥15% ≈ 14 GiB; box sits at ~9 GiB) — OR cold-load attempts failing under pressure. Guard unit itself is alive and cycling normally (journal 18:09:00/18:09:33 clean runs). Root-level restart/socket state check blocked in sandbox → left open. Also note: the deploy smoke **cold-pins the 21.6 GB model on every deploy** (documented) — under current memory it cannot even load, so this smoke stays red until memory frees regardless.
3. **SystemNix working-tree changes uncommitted** (`flake.lock` + `modules/nixos/services/cv.nix`): intentionally left for the auto-commit daemon / user decision (commit-without-asking is forbidden). Not yet committed at report time.

## c) NOT STARTED (session plan items dropped or deferred)

1. Identifying the **3rd deploy-time FAIL** — my deploy output was piped through `tail -40` and the earlier lines (including that check) were lost; it flapped away between runs and was never named. Suspicious candidates given the two known reds, but unverified.
2. Subtree re-sync of the CV input (would need full `nix flake lock` — deliberately NOT done: re-locks every moving-ref input; churn risk; proven unnecessary for the hash).
3. Any documentation updates (AGENTS.md CV section: the override is gone; TODO_LIST/gotchas entries for this recurrence).

## d) TOTALLY FUCKED UP (honest defect column)

1. **Lost the full deploy log** — `nix run .#deploy 2>&1 | tail -40` destroyed everything above the tail. One undiagnosed smoke FAIL exists because of this. Should have `tee`'d to a file. (Lesson is already in the shell-gotchas family; I still did it.)
2. **Diagnosis of the two red endpoints stopped at probes** — `systemctl`/`curl`/`sudo` are all blocked in this sandbox; I used `fetch` (timed out) and stopped there. `journalctl` WAS available and I only used it at report time (18:09) under the status-update mandate — the dnsblockd-wedge determination could have been made minutes earlier. I under-used the tools I did have.
3. **Ran post-deploy-check twice fully** just to recover the FAIL names I had truncated myself — extra load on an already memory-tight box for information my own piping destroyed. Waste, low severity.
4. Minor: my first edit attempt into CV raced a parallel session (`file modified since read`) — recovered correctly by re-reading, but I began an edit in a repo with an active second session without re-reading first. The mid-edit-race rule exists; I applied it reactively, not proactively.

## e) WHAT WE SHOULD IMPROVE (structural, from this run)

1. **The quick-unblock override pattern is a repeat-offender debt machine** (bank-sync "DROP ME", cv `9sLO…`): every relock of a moving-ref Go input re-breaks deploys until a human refreshes. Root fix is upstream: CV HAS a `vendor-hash` fast-drift check (`flake.nix:66`, added 2026-08-29) — yet stale pins keep landing because the **auto-commit daemon's heuristic commits bypass/outrun the gate**. The gate needs to actually block (pre-commit hook on `nix/packages.nix` changes, or CI as merge blocker, not just a flake check nobody runs on docs-only commits).
2. **Smoke check inversion suspicion**: deploy printed `PASS System — I/O pressure avg10=74.71% (healthy)` — 74.71% IO PSI avg10 passed as healthy. Either the comparison is inverted, the threshold is wrong, or it's reading the wrong PSI file. Pre-existing, not mine, but it's a phantom-green in the making.
3. **dnsblockd deploy-smoke needs a settle/retry window or a :53-based check** — :9090 health is flaky-at-deploy (restart + blocklist reload) AND wedge-prone; a single immediate probe conflates two very different states. Also: the 2026-08-27 wedge ROOT CAUSE is still unknown and it has now recurred — the goroutine-dump runbook exists precisely for this; nobody has ever captured the dump.
4. **FastFlowLM deploy smoke should distinguish "guard intentionally stopped the socket" from "socket dead"** — the guard is BY DESIGN the thing that kills :52625 under pressure; the smoke currently reports the designed sacrifice as a red check, inviting someone to "fix" the protection.
5. **Deploy logs should be tee'd to a file by deploy.sh itself** (not relying on the operator's pipe) — my tail-40 loss would have been impossible.
6. Parallel-session coordination worked this time only because both sessions independently measured the same hash; the override-vs-upstream-pin divergence (they re-pinned the override, I removed it) could just as easily have collided. When two sessions touch the same moving-ref input, one should own the lock.

## f) NEXT (session-derived, priority order)

**P0 — open failures from this deploy:**
1. Root: run `sudo bash scripts/dnsblockd-goroutine-dump.sh` on the wedged :9090 (capture-then-restart; first-ever dump of the recurring wedge — do NOT plain-restart).
2. Analyze the dump → root-cause the `batch writer flush` / handler-stuck wedge (2026-08-27 suspect: `healthProbe.Evaluate()` DB check or shared mutex).
3. Decide FastFlowLM: wait for guard auto-restore (needs MemAvail ≥15%) vs. free memory deliberately (what is holding ~60 GiB anon? top consumer audit) vs. accept down.
4. Identify what the 3rd deploy FAIL was (rerun smoke once memory settles; check gatus alert history for the deploy window).
5. Commit the SystemNix changes (`flake.lock`, `cv.nix`) — pathspec commit or let the daemon batch it (user call, see questions).

**P1 — close out this incident's paper trail:**
6. Update AGENTS.md CV section: override removed; record the `7dee7292` pin + the subtree-stability fact (go-cqrs-lite `45974a75`/`1941afe5` produce identical FOD output).
7. Add a gotchas entry: "SystemNix-side vendorHash overrides MUST be rev-annotated and removed on the next relock" (this is the 2nd occurrence).
8. Verify gatus/SigNoz actually fired for dnsblockd `system_dnsblockd_metrics_fresh` and flm socket-down during the window (monitoring the monitor).
9. Confirm the gatus "CV Funnel Freshness" check went green on the new binary.

**P2 — structural hardening:**
10. Make CV's `vendor-hash` check un-bypassable for daemon commits (pre-commit hook on `nix/packages.nix`; or teach the PMA committer to skip heuristic commits for that file).
11. Fix/verify the "I/O pressure healthy" smoke check threshold (74.71% must not PASS).
12. Add settle-window/retry to the dnsblockd :9090 smoke probe.
13. Make the FastFlowLM smoke guard-aware (distinguish guard-stopped vs dead; read the guard's state file/metric before failing).
14. deploy.sh: tee full output to a timestamped log file under /var/log or docs/status/.
15. Consider a SystemNix eval-time warning when `inputs.cv` rev != the rev the cv.nix override comment was measured for (cheap grep-style assertion) — prevents recurrence of exactly this class.
16. Consider folding the CV subtree re-sync into a deliberate full-relock day (multiple inputs drifted; one session owning it).
17. Audit remaining SystemNix-side vendorHash overrides for rev-staleness (bank-sync "DROP ME" from 2026-08-31 still pending upstream refresh).
18. The session-start memory crunch (3 GiB avail, zram 29.5G) deserves a consumer census while it happens — the `system_cgroup_mem_*` metrics exist; check what the dashboard says at next occurrence.

**P3 — smaller:**
19. `journalctl`-based quick health one-liner for :9090 wedge detection in the smoke (journal WARN signature) as a pre-probe.
20. Track flm cold-load failures under memory pressure (if the model can never load at ~9 GiB avail, the guard restore threshold may need a lower hysteresis or explicit operator alert).

(20 concrete items — all session-derived; intentionally not padding to 50 with unrelated backlog.)

## g) QUESTIONS (cannot figure out myself)

1. **dnsblockd wedge handling**: I cannot sudo from this sandbox. Do you want to run `sudo bash scripts/dnsblockd-goroutine-dump.sh` NOW (captures the first-ever goroutine dump of the recurring :9090 wedge, then restarts it), or accept a plain `sudo systemctl restart dnsblockd` (fast recovery, loses the forensic dump, wedge root cause stays unknown)?
2. **FastFlowLM policy**: leave :52625 down until the guard auto-restores at MemAvail ≥15% (~14 GiB; currently ~9 GiB), or do you want something killed/freed to bring it back sooner (and if so, what — I can only see aggregate consumers, your workloads are the ones holding them)?
3. **Commit handling**: my SystemNix changes (`flake.lock`, `modules/nixos/services/cv.nix`) are uncommitted. Pathspec-commit them now with attribution, or leave them for the auto-commit daemon to batch?

---

**State at report time:** evo-x2 on the new generation, CV serving `7dee729` (healthy), 2 known-red smoke items (dnsblockd :9090 wedge, flm socket down — both pre-existing classes, both needing root or memory headroom), 3rd deploy FAIL unidentified, working tree carries the relock + override removal.
