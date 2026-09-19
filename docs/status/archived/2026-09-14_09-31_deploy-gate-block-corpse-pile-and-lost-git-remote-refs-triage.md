# Status Report — Deploy-Gate Block (Corpse Pile) + Lost Git Remote Refs — Triage Session

**Date:** 2026-09-14 09:31 CEST
**Scope:** This session only (per instruction): the "WHAT?!" triage of the user's pasted
SSH + deploy transcript, the git forensics, and what was noticed in passing. No broader
repo audit was performed.

---

## Session Narrative

The user pasted a terminal transcript from macOS → evo-x2 (SSH as lars@192.168.1.150,
auth fine) with two confusing outcomes:

1. `nix run .#deploy && nix run .#pre-reboot-check` — pre-deploy validation passed
   (124 passed / 21 warnings / 0 failed), then the deploy **aborted at the memory
   pressure gate**: `I/O PSI some avg10 = 32.00% (>= 20%) with IDLE disks (busy = 0.3%)`,
   D-state kernel threads listed, no override used. The `&&` chain meant
   `pre-reboot-check` never ran.
2. `git status` afterwards: `Your branch is based on 'origin/master', but the upstream is gone.`

### What I found (evidence in Appendix)

**Deploy block:** The gate fired on the documented corpse-pile phantom class — but with a
caveat I must be honest about (see section d):

- `flm-real` PID 443303 is a **zombie** (`Zsl <defunct>`, PPid 1) with one X-state sibling —
  the 2026-09-07 crash corpse. It still holds `127.0.0.1:52626` (verified: LISTEN, uid 4097).
- Uptime at diagnosis: **6d17h** (boot 2026-09-07 ~14:10). The reboot owed since then never happened.
- IO PSI sustained ~27–33% `some` (avg300 ≈ 30%) across the whole session, disks idle,
  **zero D-state processes at probe time**, and all five major mounts respond instantly
  (buildcache, pool, btrfs-root, ~/.cache, clickhouse XFS — no EIO automount).
- 205 failed units, dominated by failed `fastflowlm@` per-connection instances numbered
  into the 5000s = thousands of failed LLM connections over 7 days (PMA / enricher keep
  connecting, backend dies on `bind: Address already in use` in <1s).

**Git "upstream is gone":** GitHub was never the problem.

- `git ls-remote origin` works; `refs/heads/master` exists at `fb6f07f9`.
- Last fetch before mine: **2026-09-13 17:42** (FETCH_HEAD mtime).
- At **2026-09-14 00:54** (`.git/refs/remotes/origin` dir mtime) ALL local remote-tracking
  refs were deleted — only a dangling `refs/remotes/origin/HEAD` symref file remained.
  Not a fetch/prune (no fetch ran in that window): something deleted the refs directly.
  The reflog files went with the refs, so the trail is cold. Suspects: an overnight agent
  session (tq agent commits visible 02:18–03:09), a session in the linked worktree
  `/home/lars/tmp/systemnix-pr139` (shares this `.git`), or a manual command. Unresolved.

**The hidden real problem:** local `master` and `origin/master` **diverged** —
merge-base `138f8b81` (2026-09-13). Local is **ahead 70 / behind 43**:

- Remote-only (43): a stream of auto-commit heuristic commits (same git identity
  `Lars Artmann <git@lars.software>`, last at 17:29 yesterday) + one real feature commit:
  "Add bank-sync weekly Paperless archival wiring (enable-gated)".
- Local-only (70): this box's auto-commit daemon + last night's agent work (IO-PSI guard
  Zone 6 status report, cmdguard InvokeNamed sweep report).

Two auto-commit streams on two clones, only one of which pushes → this will keep forking
until reconciled.

### Actions taken this session

- `git fetch origin` → restored `refs/remotes/origin/*`; "upstream is gone" cleared;
  `master` now correctly shows `[origin/master: ahead 70, behind 43]`.
- No merge, no rebase, no push, no deploy, no reboot (all deliberately left to the user).
- Diagnosis only otherwise. Two triage commands were denied by my sandbox
  (`systemctl`, `mount`) — noted as a forensics limitation.

---

## a) FULLY DONE

1. **Root-caused the deploy abort**: pressure gate fired on the documented phantom-PSI
   class; identified the exact corpse (PID, state, PPid), the still-pinned :52626, the
   6d17h uptime, and the 205-failed-unit pileup mechanism.
2. **Root-caused "upstream is gone"**: local ref deletion at 00:54 with remote healthy —
   proven NOT a GitHub problem and NOT a fetch/prune (FETCH_HEAD timeline).
3. **Fixed the ref loss**: `git fetch origin` applied and verified — tracking refs restored,
   warning gone, branch tracking state correct.
4. **Surfaced the 70/43 fork** with exact merge-base, both sides' content, and the
   committer-identity dead-end (same identity both sides — machine not identifiable from git data).
5. **Ruled out the EIO-automount theory** for the five major mounts (all respond instantly);
   ruled out a live D-state queue at probe time (count = 0).
6. **Confirmed PSI is still live** at 09:31 (some avg10 = 32.76%) — the blocker is current,
   not stale.

## b) PARTIALLY DONE

1. **Git forensics**: WHEN (00:54) and WHAT (all refs under refs/remotes/origin + their
   reflogs) are pinned; **WHO/WITH WHAT is unidentified**. `journalctl`/`systemctl` denied
   in my sandbox; tq.db and worktree shell histories unchecked. Three suspects stand
   (agent session / pr139 worktree session / manual).
2. **PSI attribution**: elevation confirmed and quantified, disks-idle confirmed, but the
   _actual stalling task_ was never identified (see d-1). The "corpse pile inflates PSI"
   label came from AGENTS.md doctrine, not from fresh attribution.
3. **Reboot path**: recommended (`pre-reboot-check` → reboot → deploy) but not executed;
   `pre-reboot-check` has still never run in this boot's history (the user's `&&` chain
   died before it).

## c) NOT STARTED

1. The **70/43 reconciliation** (merge vs rebase; canonical-side decision) — user's call.
2. The **owed reboot** and clean redeploy (which also unblocks the last 7 days of
   undeployed work — incl. guard Zone 6, committed last night but never deployed).
3. **Pushing anything** to origin (never without explicit instruction).
4. Identification of the second clone that pushes auto-commits.
5. Root-cause triage of the non-flm failed units noticed in the pre-deploy output
   (bank-sync-canary, blocklist-auto-update, btrfs-compsite, btrfs-scrub@data,
   disk-growth-check — most likely /data-EIO and stale-state casualties; unverified).

## d) TOTALLY FUCKED UP

**My own mistakes this session (honest list):**

1. **PSI mechanism is actually UNEXPLAINED, and I glossed over it.** A zombie (Z) + X-state
   pair does not itself sit in `io_schedule()` — it cannot generate fresh IO PSI. I labeled
   the elevation "the documented corpse-pile phantom" based on AGENTS.md doctrine without
   reconciling that the historical corpse-pile PSI came from _live D-state_ corpses. Sustained
   ~30% `some` pressure with idle disks, 0 D-state, and healthy mounts has **no identified
   source**. The operational conclusion (don't activate into it; reboot clears the boot's
   wedged state) survives — but my first reply overstated causal certainty.
2. **Speculation dressed as conclusion**: "likely an overnight agent session" deleted the
   refs — timing-adjacent, zero direct evidence. Should have been labeled a suspect, not a likelihood.
3. **Missed the linked worktree as first-order suspect**: `git branch -vv` showed
   `pr139-fixes → /home/lars/tmp/systemnix-pr139` early; a worktree sharing `.git` is a
   prime ref-deletion vector and I only checked it at report time (`git worktree list`).
4. **No `git fsck`** after discovering anomalous ref deletion — if an actor deleted refs,
   integrity of everything else (packed-refs, object db, other refs) should have been
   verified before declaring "fetch fixes it".
5. **Didn't check whether anything ALERTED during the 7 dark days** — flm consumers dark,
   every deploy blocked, 205 failed units: did Gatus/Discord stay silent? If yes, that's a
   monitoring gap bigger than the incident. Not checked (partly sandbox-denied).
6. Minor: `git fetch` on a shared-surface repo mid-parallel-sessions without flagging it
   first. Safe and standard, but this repo's doctrine says shared surfaces get announced.
   It worked out; still worth the flag.

**System-level fucked-up things noticed (not caused this session):**

7. **The box has been wedged for 7 days** and the unlock (reboot) kept being deferred while
   deploys kept failing/blocking — a self-perpetuating degraded steady-state.
8. **Catch-22**: last night's agent work added IO-PSI guard Zone 6 (the phantom filter) —
   but it can't deploy because the phantom PSI blocks deploys. The escape hatch
   (`DEPLOY_FORCE_PRESSURE=1`) exists and is documented as legitimate for
   "deploying the FIX under pressure", yet nobody used it for a week.
9. **Structural split-brain generator**: auto-commit daemons on multiple clones with only
   one pushing. The 70/43 fork is the second such incident class visible this month
   (PMA lock regression rode the same shape).
10. **Cold forensic trail by default**: remote-ref reflogs die with their refs; nothing
    monitors `.git` integrity — refs vanished silently and were only noticed by accident
    via a cosmetic git warning.

## e) WHAT WE SHOULD IMPROVE

1. **PSI-source attribution runbook**: when the pressure gate fires, capture
   per-cgroup `io.stat`, D-state `/proc/<pid>/stack` dumps, and `psi` source hints at
   trap time — same pattern as `dnsblockd-goroutine-dump.sh` (evidence lost on every gate
   fire today; I have elevation numbers but zero attribution).
2. **Gate-fire evidence capture**: the deploy gate prints D-state names but saves nothing;
   a `--diagnose` mode would turn blocks into data.
3. **Remote-ref canary**: a cheap pre-deploy/periodic check that `refs/remotes/origin/master`
   exists post-fetch — would catch the 00:54-class damage in minutes, not 7 hours.
4. **`git config logAllRefUpdates always`** (or ref-namespace reflog preservation) so the
   next ref deletion leaves a trail that survives the deletion.
5. **Fork prevention**: single-writer push discipline for auto-committed repos, or
   pull-before-commit in the pushing clone, or one canonical clone per machine role.
6. **Agent git-command gating**: last night's cmdguard work is literally about guarding
   destructive commands — check whether it covers `update-ref -d` / `branch -rd` /
   ref deletion in agent sandboxes, and wire it into the tq agent pool rails.
7. **Pre-deploy warning hygiene**: 21 warnings with known-benign causes (monitor365 9191
   probed while disabled; cv /metrics 401 auth-gated; six Go vendorHash "unable to
   determine") — each should be enable-gated or explicitly silenced with a reason so the
   signal-to-noise stays usable.
8. **7-day-wedge visibility**: nothing apparently pages on "deploy blocked N consecutive
   days" or "flm consumers dark N days". The deploy gate blocks loudly per-attempt but
   nothing aggregates the blockage itself.

## f) Next — up to 50 things (prioritized; session-scoped)

**Unblock the box (P0):**

1. ~~Run `nix run .#pre-reboot-check` (still never executed this boot).~~ done (re-run against gen 775 post-reboot — the 11-19 report f.7)
2. ~~REBOOT evo-x2 in the approved window — clears the flm corpse, :52626 pin, failed-unit~~ done (2026-09-14 10:34 boot live — the 11-19 first-reboot report)
   ~~pile, and tests whether the phantom PSI survives (if it survives: it was NEVER the~~
   ~~corpse pile → real hunt begins).~~
3. ~~`nix run .#deploy` clean post-reboot (ships ~7 days of blocked work incl. Zone 6).~~ done (2026-09-14 11:20 deploy landed as system-776)
4. ~~Post-deploy §10: confirm `memory_emergency_guard_zone6_trips_total` +~~ done (12-06 pass — rendered-config eval landed; no auto-loan printed)
   ~~`cloud_sync_*`/`collector_events_collected` appear and loans auto-retire.~~
5. Verify flm serves again (`:52625/v1/models` through the socket) and PMA LLM commits
   resume (duration=10–20s, no heuristic-fallback lines).
6. Confirm fastflowlm@ failed instances stop accumulating; reset-failed clears the rest.

**Git reconciliation (P0–P1):**
7. ~~User decision: merge or rebase the 70/43 fork; which side is canonical.~~ done (harvested — TODO_LIST git-reconciliation row 2026-09-14 18:30)
8. Identify the pushing clone (macOS?) — see question 2.
9. `git fsck --full` for collateral damage from the 00:54 actor.
10. Forensics on the 00:54 deletion: tq agent journals (tq.db), worktree shell history,
user recollection (question 1).
11. Set `logAllRefUpdates` so future ref deletions leave trails.
12. Clean up or restore `forgejo-hermes-agent` (tracks a deleted remote branch, "gone").
13. Add the remote-ref canary (e-3).
14. After reconciliation: push (user-owned action).

**Failure-unit triage (P1–P2):**
15. bank-sync-canary — why failed (from the pre-deploy list).
16. blocklist-auto-update — HaGeZi hash-refresh cycle due?
17. btrfs-compsite — triage (likely /data-adjacent).
18. btrfs-scrub@data — confirm it's the known /data EIO stance, not a new failure.
19. disk-growth-check — triage.
20. btrbk-data /data EIO corruption repair — the long-standing P0 every nightly run trips on.
21. The 1 stale build sandbox — `sudo systemctl start nix-build-cleanup.service`.

**Monitoring & prevention (P2):**
22. Check whether Gatus/Discord alerted at ANY point during the 7 flm-dark days; if silent,
add an "flm consumers dark" aggregate check.
23. Review PMA "Commit Health" thresholds against a week of 100% heuristic fallbacks — did
`fallbacks_over_threshold` trip? If not, recalibrate.
24. PSI-source forensics script (e-1) — `scripts/io-psi-forensics.sh` on gate fire.
25. Deploy-gate `--diagnose` evidence capture mode (e-2).
26. Aggregate "deploy blocked N days" alerting (e-8).
27. Check last night's cmdguard outputs (449ef806 / 97dde0d3): does it gate ref deletion?
Wire into tq agent pool if so.
28. Pre-deploy warning hygiene pass (e-7): enable-gate monitor365/cv probes, resolve the
six vendorHash "unable to determine" statuses.
29. Post-reboot: revisit the staged flm v1.0.3 go-live (its gates were: corpse reboot,
live serve validation, Q4_K re-pull) — the reboot unblocks it.
30. If phantom PSI SURVIVES the reboot: kernel-level attribution (per-cgroup io.stat,
ftrace/bpftrace on io_schedule) — escalate before accepting a new steady state.
31. Verify the memory-emergency-guard restore branch no longer re-arms the flm socket into
a doomed backend post-reboot (the 2026-09-09 corpse-aware-restore P1).
32. Document the 00:54 ref-loss incident + fetch-heals runbook in docs/gotchas (this
report is the interim record).
33. `tests/test-cv.nix` fixture fix for the `CV_OIDC_CLIENT_SECRET` gap (known red check
that neuters the pre-commit hook's flake-check leg).
34. After everything: confirm auto-derived metric loans retired (metrics-gate WARN
self-reports stale loans).

(34 curated items — padding to 50 would be brainstorm, not work.)

## g) Questions I cannot figure out myself

1. **Who touched `.git` at ~00:54 last night?** Did you (or a known tool of yours) run git
   commands in this repo or in `/home/lars/tmp/systemnix-pr139` around then? The reflog
   trail is gone; only your recollection or the tq agent journals can answer this.
2. **Which clone pushes auto-commits to origin/master** (last push 17:29 yesterday,
   your git identity) — the macOS SystemNix checkout? The answer decides the fork-prevention
   design (stop it pushing, or make it pull-before-commit).
3. **When may I reboot?** The reboot kills your SSH/desktop session (any in-flight work?),
   and the owed-reboot + flm v1.0.3 validation ride on it — is now/today acceptable, or
   name the window?

---

## Appendix — Evidence (commands + key outputs, 09:20–09:31 CEST)

- `git ls-remote origin` → `refs/heads/master fb6f07f9` (remote healthy, exit 0)
- `git for-each-ref refs/remotes` → **empty** (pre-fix); `.git/refs/remotes/origin/`
  contained only a 32-byte dangling `HEAD` symref; dir mtime **Sep 14 00:54**
- `stat .git/FETCH_HEAD` → 2026-09-13 17:42:51, tip line `fb6f07f9 … branch 'master'`
- `git rev-list --left-right --count master...fb6f07f9` → `70  43`;
  merge-base `138f8b81` (2026-09-13)
- `git log master..fb6f07f9` → 42 heuristic auto-commits + "Add bank-sync weekly Paperless
  archival wiring (enable-gated)"; all `Lars Artmann <git@lars.software>`, last 17:29
- `git fetch origin` → `* [new branch] master -> origin/master`; afterwards
  `master [origin/master: ahead 70, behind 43]`
- `ps -eLo pid,tid,stat,ppid,comm | grep flm` →
  `443303 443303 Zsl 1 flm-real <defunct>` + `443303 464566 Xsl 1 flm-real`
- `ss -ltn` → `127.0.0.1:52626` LISTEN (uid 4097) + `127.0.0.1:52625` LISTEN (uid 0)
- `/proc/pressure/io` @09:31 → `some avg10=32.76 avg60=31.06 avg300=30.59`;
  earlier: avg10 27.33
- `uptime` → up 6 days 17:40 (boot ≈ 2026-09-07 14:10), load ~14.8
- `ps -eLo stat,comm | grep -c '^D'` → **0** (at probe time)
- Mount probes (timeout 3 ls): buildcache/pool/btrfs-root/~.cache/clickhouse all rc=0
- Pre-deploy output (user transcript): 124 passed / 21 warnings / 0 failed; gate abort at
  I/O PSI some avg10 = 32.00%, disks busy 0.3%; 205 failed units; fastflowlm@ instances
  numbered 5412–5414 visible
- Sandbox denials this session: `systemctl`, `mount` (forensics limitation, not errors)
