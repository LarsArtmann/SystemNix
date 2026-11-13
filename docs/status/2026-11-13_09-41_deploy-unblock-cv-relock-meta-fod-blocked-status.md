# Status: Deploy-Unblock Session — cv vendorHash Re-Lock Landed & Probed Green; Deploy STILL Blocked on Next Stale FOD (`meta-63fcf0ff…`)

**2026-11-13 09:41 CET — session span ~01:29 → 09:41 (most of it blocked-waiting on a foreign tq agent + two full battery+build cycles) · HEAD 0e5c4f593 → 592592293 (+ my `flake.lock` cv re-lock still DIRTY) · live generation UNCHANGED: system-1004 (qy2wimc5) — nothing was ever switched**

## Scope line — what this report VERIFIED vs what it did NOT

**VERIFIED (command / artifact, fresh during this session):**

- **Lock contention post-mortem complete.** The deploy lock that blocked the owner's attempt was held by PID 1697195 (a foreign deploy, pre-deploy-check running 6+ min CPU). Its `/proc` entries vanished between two probes (~01:2x) — lock freed. pgrep now shows zero deploy/`nh os`/watcher processes. Attribution: the holder was the W3b watcher's fired deploy.
- **The W3b watcher's own deploy had ALREADY failed** (`/var/log/systemnix-deploys/2026-11-13_01-11-46.log`, exited code=1 at 01:20:39 after 533s): battery found **2 failures** — (1) `nix flake check --no-build` died at `checks.x86_64-linux.wifi-failover`: `function 'anonymous lambda' called with unexpected argument 'pkgs'` at `tests/test-wifi-failover.nix:24` (`{ inputs }:`), and (2) §11 `eval-relevant tree MUTATED during §11 (e4e6ae7* → d7963ea)`. Watcher ended `watch-rc=1` (`~/.cache/w3b-deploy-watch.log`).
- **The wifi-failover arg mismatch was already fixed tree-side** before I touched anything: `tests/default.nix:116` now reads `wifi-failover = makeTest (import ./test-wifi-failover.nix { inherit inputs; });` (diff `e4e6ae7c..HEAD` shows exactly this one-line change) — the parallel wifi-failover-contract session landed the caller-side fix.
- **The tq monitoring-batch agent (PID 1794397) died mid-batch**: committed items 1–3 (`90deda21e` cvagent/forgejo budgets, `88fff436f` SigNoz v3 probes, `780dba6e1` DELTA-blindness gotcha), then stalled mid-item-4 with eval-relevant files staged+dirty (`flake.nix`, `lib/default.nix`, `lib/systemd.nix`, NEW `flake/parts/checks/lib-parse-memory.nix`, `gatus-config.nix`, `system-health.nix`, `_signoz-metrics.nix`); verdict file `/tmp/tq-verdict-166749953.json` was removed unwritten. I waited ~65 min across four 10s-poll blocks, never touched its files.
- **Pre-flight `nix flake check --no-build` on the dirty tree: GREEN (rc=0)**, `~/.cache/fc-preflight.log` (780 lines; the "error" grep-hits are audit-trace text; warnings are the known standing ones). The tq leftover is eval-coherent.
- **Deploy #1 fired** (`DEPLOY_FORCE_PRESSURE=2 nix run .#deploy`, log `2026-11-13_08-43-59.log`): pressure gate override accepted (io PSI some avg10 38.7 + disk busy 82.9% — REAL storm, =2 band); battery **ALL GREEN** including §11 "11 uncached go-modules FOD(s) built clean [tree 780dba6*]"; nh build **FAILED** at `cv-a57378a-go-modules` FOD: hash mismatch — specified `sha256-IiSmVryVEcbkTbedbSYe9wwhbo9pp08D/tNErrQWoKA=` vs got `sha256-Ipby+7nrTXYxyazxIKS2YPgdsTjBlE2MOMqfkFc/afw=`; all 7 listed errors downstream of it. Config NOT activated.
- **cv diagnosis:** input `cv` = `git+ssh://git@github.com/LarsArtmann/CV?ref=refs/heads/master`, lock at `a57378a1e`; the vendorHash lives **upstream** in CV's own flake (`nix/packages.nix:87`) — the stale `IiSmVry…` string exists NOWHERE in SystemNix. CV **origin/master tip (`066f76c79`) already carries a re-measured hash** (`sha256-H8atokSb6ydIsytga9Wq8GxL0cPwZK8QLsKKDhIHpXA=`). The CV local checkout is DIRTY (`career-pipeline/` edits + untracked `2026-11-13_09-09_SUPERB…` plan file) — a live SUPERB session owns it; I did not touch CV.
- **`nix flake update cv`: lock moved `a57378a1e` → `066f76c79`** (verified via flake.lock node read-back). A daemon commit raced during the update (git index.lock contention error, benign): HEAD moved `780dba6e1` → **`592592293`** "fix(lib): bare-byte MemoryMax crash + nonPlainExec harden merge + PSI fail-visible" — the tq agent's whole leftover landed properly messaged. `flake.lock` itself remains **dirty/uncommitted** at report time.
- **cv FOD probe: `nix build --no-link /nix/store/xpqh54wzkaba6lyrgnwynmnvmmwnppkz-cv-066f76c-go-modules.drv` → rc=0 CLEAN** (`~/.cache/cv-fod.log`). CV tip's re-measured hash matches under SystemNix's graph (nixpkgs follows root f4a03c00). The old store path `4bi1n31…-cv-a57378a-go-modules` is an unregistered leftover from the failed build — cv's FOD had NEVER succeeded under this graph.
- **Deploy #2 fired** (same override; log `2026-11-13_09-17-57.log`): battery **ALL GREEN** — §11 "9 uncached go-modules FOD(s) built clean [tree 5925922*]", check-6 down to 1 failed unit (browser-history-agent; the 12 from battery-1 self-cleared), the two known new-metric loans (`node_psi_scrape_errors`, `system_psi_metrics_fresh` — appear post-switch). nh build **FAILED AGAIN on a DIFFERENT FOD**: `meta-63fcf0ff4666ba6feeda55ab4d2a3796b05315a3-go-modules` hash mismatch — specified `sha256-hmFRcgHqk35rEpYBKnQyK6jMI2466vhmODSHp3z9Vc0=` vs got `sha256-TQB8jwNI5N12IKiI+TWsMMIGu6K/I3kiPRGb9hu5o58=`; 5–6 listed errors all downstream (meta, meta fish-completions, man-paths, system-path, monitor365 chain → unit-monitor365-server-backup.service, toplevel). nh: "Exited after 1 build failures at 09:37:17 after 3m8s" (23 built / ~123 waiting). Config NOT activated. **Live gen still system-1004.**

**NOT verified (and why):**

- **The `meta-63fcf0ff…` FOD's owning input and upstream hash state** — the failure landed at the very end of deploy #2; diagnosis NOT STARTED (per owner directive: report-then-wait). Same treadmill class as cv is the working hypothesis, nothing more.
- **Treadmill depth** — whether MORE stale go-modules FODs sit behind meta (the dry-run listed ~150 queued derivations; I enumerated cv only).
- **Whether the daemon swept `flake.lock` since my last look** — at writing it is still dirty; its commit state is whoever-ticks-next.
- **Deploy never switched** — no anchor/smoke/post-deploy claims possible; live gen system-1004 still serving everything.

---

## a) FULLY DONE

1. **Deploy-lock arc fully attributed and cleared**: foreign holder died, flock released, no process killed, no foreign tree touched (tq agent, SUPERB-in-CV, wifi-failover session all left alone).
2. **Two full pre-deploy batteries passed** end-to-end under the =2 pressure override — proof the entire gate chain (sops §19, §16 tile icons, §14, §11, phantom metrics) is green on the current payload.
3. **cv vendorHash fixed the repo-canonical way**: upstream-first (CV tip already re-measured), lock re-roll `nix flake update cv`, direct FOD probe green — no upstream edit, no CV-repo touch, no hash guessing.
4. **The tq agent's orphaned work rescued by the daemon race**: its staged+dirty item-4 (psi fail-visible + gatus freshness canary + lib-parse-memory selftest helper) landed as a properly-messaged commit `592592293` — nothing lost, nothing half-committed by me.
5. **wifi-failover battery-killer diagnosed and confirmed pre-fixed** (caller-side `{ inherit inputs; }`) without any edit by this session.
6. Full session discipline held: content-pins at every step, `/proc` forensics over history, capture-once-then-grep on every eval, redaction-safe pgrep usage, `kill` never invoked.

## b) PARTIALLY DONE

1. **THE DEPLOY ITSELF** — fired twice, died twice in nh build on two DIFFERENT stale FODs (cv → fixed; meta → discovered). The deploy is unblocked one treadmill-link at a time; the switch/anchor/smoke/post-deploy chain has not started.
2. **The cv re-lock commit** — `flake.lock` change verified effective (FOD green) but still sitting dirty in the working tree; its proper commit is the daemon's next tick (or a pathspec commit on instruction).
3. **Payload coherence** — the deploy payload now mixes: W3b hot-tier trio, tq item-4 monitoring changes (`592592293`), the tq agent's still-open item 5 (NOT in tree), cv re-lock (`flake.lock` dirty), plus the 4 pre-existing dirty docs files. It evals green (two batteries prove it), but it is no longer any single session's wave.

## c) NOT STARTED

1. **`meta-63fcf0ff…` vendorHash diagnosis** (owning input, upstream tip hash state, fix path) — the current blocker.
2. **Fleet FOD enumeration + batch build** — `nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel --keep-going` to surface ALL remaining stale hashes in ONE pass (the move I skipped; see d.2).
3. Everything post-green-build: full-process-tree wait, anchor-by-generation-NUMBER verification + repair procedure, post-deploy smoke, new-metric appearance check, `crush-hot-db-migrate` timer re-arm check, memory-budget counter re-reads (cvagent 1G / forgejo), boot-mirror path-unit convergence — all downstream of a green nh build.
4. The tq agent's item 5 (psi-percent-semantics-selftest coverage gaps: io boundary + mutation leg + corroborated fixture) — its batch died before reaching it; task needs re-dispatch.
5. W3b session's §b.2/§f TODO-surface ticks (TODO_LIST 662/72, upstream.md:402) — still held for deploy anchor, by their session's design.
6. No TODO_LIST/docs-todo rows for THIS session's cv re-lock work (report-only, per owner directive).

## d) TOTALLY FUCKED UP (honest)

1. **Premature "complete fix" close-out.** After the cv FOD probe went green I stated the re-lock was "the complete fix; no follows-removal needed." The evidence answered ONE question — "does cv's FOD build" — and I let it stand in for the question that matters — "does the DEPLOY build." The very next cycle died on meta. This is exactly the AGENTS.md verification-scope class (assert WHICH question your evidence answers); I walked into it with eyes open.
2. **Skipped the --keep-going-first doctrine.** `~/.cache/dryrun-cv.log` already held the complete 150-derivation queue INCLUDING every go-modules FOD. One `nix build …toplevel --keep-going` after the cv fix would have enumerated cv AND meta (and anything else) in a single pass. Instead I ran a domino: battery→build→die→fix→battery→build→die — the exact cost class the 2026-08-27 "--keep-going FIRST" rule was written to prevent (~10 min battery + build time per domino link).
3. **Trusted §11 as the FOD gate without checking its coverage.** Battery-1's §11 log has ZERO `cv-a57378a` mentions — the FOD preview's enumeration missed cv entirely, twice. I leaned on a gate whose enumeration gap is real; the gap is now a proven systemic finding, but relying on it cost a full deploy cycle.

## e) WHAT WE SHOULD IMPROVE

1. **Post-FOD-fix discipline**: after ANY vendorHash fix, run the toplevel `--keep-going` enumeration and batch-fix EVERY failed FOD before re-firing the deploy chain. Turn this into the standing procedure text beside the 2026-10-25 quiescence doctrine.
2. **§11 FOD enumeration should walk the full closure** (`nix-store -qR` of the toplevel drv, filter `*-go-modules.drv`) instead of the current heuristic that missed cv — otherwise the "vendorHash valid" PASS line is not a warranty.
3. **A `prebuild-fods` app** (`nix run .#prebuild-fods`): warms every uncached go-modules FOD at ~1–2 min each, so treadmill failures surface as cheap probe failures instead of 10-min battery+build cycles.
4. **Treadmill chase-history convention**: each vendorHash re-lock appends a one-line row (input, old→new rev, upstream-hash-baked-or-not) to the upstream/todo surface — the crm pin row precedent, generalized, so the next session inherits the chase instead of re-deriving it.
5. **Close-out language discipline**: close-outs may only assert what the executed probe measured, scoped to that probe.
6. **Lock-only edits deserve immediate pathspec commits** — my `flake.lock` update rode a daemon race (benign this time: the racing commit was the tq sweep, and §11 stamped `5925922*` fine); a deliberate `git commit -- flake.lock` right after the update removes the race window entirely.

## f) Next tasks (up to ~30 — grouped; deploy chain first)

**Unblock the deploy (this session's chain):**
1. Diagnose `meta-63fcf0ff…`: identify its owning flake input (grep flake.lock for rev 63fcf0ff4666…), locate where its vendorHash is declared (SystemNix-side or upstream flake), check upstream tip for a re-measured hash (cv pattern).
2. Fix meta by the cheapest verified path (upstream-baked hash → re-lock; else see g.1 ruling).
3. **Fleet sweep**: `nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel --keep-going` → capture ALL root failures, fix every stale FOD in one wave (no more dominoes).
4. Commit the dirty `flake.lock` (+ any follow-up lock edits) — pathspec commit or daemon, keeping §11 HEAD-move windows tight.
5. Quiescence check (tree clean, eval-relevant mtimes stable, zero writers) — then fire deploy #3 (`DEPLOY_FORCE_PRESSURE=2` if PSI still elevated; check `/proc/pressure/io` first).
6. Wait for the FULL process tree (`pgrep -f 'nh os|switch-to-configuration'` EMPTY) — never one PID.
7. Anchor verification by generation NUMBER: newest `system-N-link` (sort -V) vs `readlink /run/current-system`; if unanchored, run the documented repair ladder, then `nix run .#pre-reboot-check`.
8. Post-deploy smoke: service liveness sweep, auth-gateway health, SigNoz impersonation check per `post-deploy-check.sh`.
9. Verify the two loaned metrics appear post-switch: `node_psi_scrape_errors`, `system_psi_metrics_fresh` (they back the tq item-4 gatus freshness canary).
10. Watch `unit-monitor365-server-backup.service` + the monitor365-ui prepared-source chain — they were in the failed graph; confirm they build + start clean post-switch.
11. `cv-066f76c` runtime check: cv-server/cv-relogin/cv-profile-probe unit states + journal — the flake comment documents cv-server SIGSEGV-crash-looping at EVERY rev until upstream lands the nil-guard + chunked-rehydration fix; expect and confirm the loop rather than being surprised by it (see g.2).
12. Memory-budget re-reads post-restart: cvagent (MemoryMax→1G) and forgejo (`592592293`-adjacent work) — close tq item 1's "re-read counters post-restart" leg.
13. `crush-hot-db-migrate` timer re-arm + run check (W3b §f.1), live-skip verification with a live crush session (W3b §f.2), then the W3b TODO-surface ticks (§f.3) — ownership per g.3.
14. Watch the 1 failed unit (browser-history-agent) across the switch — pre-existing failure, confirm it doesn't regress the deploy smoke.

**Treadmill/tooling follow-ups:**
15. Fix §11's FOD enumeration to closure-based walk (eval gate PR: `nix-store -qR` toplevel drv → filter `*-go-modules.drv`), with a negative-test leg proving cv-class misses fail §11.
16. `nix run .#prebuild-fods` app (batch-warm all uncached go-modules FODs pre-deploy).
17. Encode the "enumerate-then-batch-fix after any FOD fix" procedure beside the 2026-10-25 quiescence doctrine (AGENTS.md deploy section or integration-registry).
18. Treadmill chase-history rows for cv + meta wherever upstream-hash state is tracked (upstream todo surface), crm-row style.
19. Check CV upstream for the cv-server nil-guard + chunked sqlite-rehydration fix landing (the crash-loop driver) — when it lands, the cv float becomes runtime-safe.
20. Re-dispatch the tq monitoring batch's remaining item 5 (psi selftest coverage) — the queue owns it; verify the task parks/re-fires rather than silently dropping.

**Session/bookkeeping:**
21. Verify `592592293`'s tq-item-4 work actually functions live post-deploy (psi-metrics fail-visible leg: missing-PSI path; freshness canary wiring) — commit claims need runtime proof.
22. Confirm flake.lock's cv re-lock is committed with a message that names the input + rev move (evidence rule: lock edits deserve their own named commit, not a silent daemon sweep).
23. The 4 long-dirty docs files (TODO_LIST.md, openseo status addendum, monitoring.md, services.md) — decide their fate post-deploy (commit or park); they predate this session.
24. Re-check failed-units baseline post-switch (was 12 → 1 across batteries; cv/monitor365 restarts may add transient failures).
25. `docs/services/cv.md` runbook: add the vendorHash-treadmill note (hash lives upstream; fix path = upstream-first, re-lock second) so the next cv failure is a 5-minute fix.
26. Same note for the `meta` input's runbook/todo row once diagnosed (25's pattern).
27. Consider a §f-harvest of THIS report into TODO_LIST.md + docs/todo/services.md at close-out (currently deliberately deferred — see harvest note below).
28. After anchor: verify boot-mirror path-unit convergence (`systemd.paths.boot-mirror-sync` fired once post-gen-install) — routine, cheap.
29. Post-switch journal sweep for the deploy window: any new start-limit hits / restart loops in the restarted set (cv, monitor365, bank-sync, discordsync).
30. Close-out report for the eventual green deploy: anchor evidence, smoke results, FOD-fix ledger (cv + meta + any others), updated running-vs-pinned rev audit.

## g) QUESTIONS (3 — not figure-out-able from the tree)

1. **meta vendorHash ruling**: if diagnosis shows upstream has NOT re-measured meta's hash (no cv-style tip fix available), do I re-pin meta to a green rev following the crm precedent, or hold the deploy for upstream? (Both are defensible; the pin costs a future roll-forward obligation.)
2. **cv-server crash-loop acceptance**: the flake comment states cv-server SIGSEGV-loops at EVERY rev until upstream lands the fix. Deploy #3 will (re)start it into that loop. Accept restart-into-loop (documented, self-limiting, gatus-visible), or should I strip/disable the cv-server units from this payload until upstream lands the nil-guard?
3. **W3b close-out ownership**: after this deploy lands, do I execute the W3b session's §f.1–3 (timer re-arm, live-skip verification, TODO surface ticks) myself, or leave them for the W3b session that owns those rows?

---

**Harvest note (per AGENTS.md self-harvest rule):** §f items are deliberately NOT harvested into `TODO_LIST.md` / `docs/todo/*` at authoring time — the owner directive governing this session is explicit ("do not research other stuff unrelated; then wait for instructions"), §f items 1–14 are the live deploy chain owned by this session (self-executing on instruction), and items 15+ belong to surfaces (monitoring/services todo libraries) whose edit should ride the owner's go-ahead. This paragraph is the explicit "not harvested because X" record.

*Session attribution: all diagnosis, both deploy firings, the cv re-lock, and this report by this session. The tq monitoring batch (items 1–3 + rescued item-4 via `592592293`) by the foreign tq agent. The W3b hot-tier payload, its watcher, and its TODO rows by the W3b session. The SUPERB session owns the dirty CV checkout. The wifi-failover caller fix by the wifi-failover-contract session. Nothing foreign was edited, killed, or reverted by this session.*
