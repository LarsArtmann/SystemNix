# Storage-Crisis Plan S1–S27 Execution — Day-1 Status & Brutal Self-Review

**Date:** 2026-10-27 15:53 CET · **Session:** storage-crisis executor (tombstoned `EXECUTING` at 82bfe056b)
**Plan:** `docs/planning/2026-10-27_11-49_SUPERB-storage-crisis-recovery-pareto-plan.md`
**One-line verdict:** ALL eval-free work is done and committed; **NOTHING IS DEPLOYED** — the deploy train is blocked by a parallel session's daemon-split lock-float (12+ inputs drifted, eval gate red tree-wide) riding on top of an IO storm (their proof builds, PSI 60–86%). The 66G sweep is PSI-gated. Every "committed" below means inert-until-deploy.

---

## 0. Live state at report time

- Root `@`: 680G/723G used, 35G avail, 96% (parallel opencloud session reclaimed +34G by truncating a runaway init log at ~14:00 — their 14-19 report; the 12 GB/h drain is verified over)
- IO PSI some avg10: 60–68% for the last ~1.5h (three ghostty agent-session scopes at ~70% each — the float session's builds)
- flake eval: RED — `flake.lock lock-float audit failed`: 12+ inputs (branching-flow, buildflow, crush-config, cv, dankMaterialShell, dnsblockd, go-cqrs-lite, go-taskqueue, herdr, home-manager, homebrew-cask, journal, …) floated in the lock but not registered in `flake/expected-locks.nix`. Cause: **the auto-commit daemon batched the parallel session's mid-proof flake.lock alone (b9460ef1c, 14:28), splitting the "commit lock + registry TOGETHER" pair.** That session is alive (cv.nix/sops.nix work 14:4x–15:0x) but has not repaired the registry for >1.5h.
- Consequence: `nix eval`/`nix flake check`/`nix run .#deploy`/pre-commit's full-eval leg ALL fail until the float session registers (or reverts) — my deploy, negative-tests, and flake-check legs are queued behind it.

---

## a) FULLY DONE (verified this session)

| Item | Evidence |
| --- | --- |
| **Tombstone** (plan EXECUTING marker) | committed 82bfe056b; no twin executor found |
| **µ1.1 containers verdict: TRASH** | zero repo references to `/var/lib/containers` (4.9G dead since Docker removal) |
| **S11 runner cache wiring** | wiring PROVEN correct: 14G live in `/mnt/buildcache/ci-runner-cache/gocache` (newest write 10-25); the 13G HOME `.cache/go-build` last written 10-16 08:54 = **pre-wiring residue, stale → trashable** (wiring landed 10-16 16:41). Runner unit currently inactive + ci-watchdog failed — owned by the gen-955 parallel session, not touched |
| **S7 root-100% alert — root-caused + fixed (config)** | **PHANTOM-GREEN from birth, proven**: live metric 94, gatus sqlite shows the check HEALTHY with **zero UNHEALTHY events ever**. Mechanism: pattern hardcodes label order `device,mount_point,fstype`; node_exporter exposes textfile series **alphabetically** (`device,fstype,mount_point`) → literal label segment never matches → both negative conditions pass vacuously. The `9[3-9]` char class is VALID (gatus `pat()` = Go `filepath.Match`, verified against upstream `pattern/pattern.go`; `{a,b}` alternation is NOT supported). Order-immune fix (`device`+`mount_point` pinned, label span wildcarded) **A/B-verified against the live /metrics body with fnmatch** (matches 94%, spares 85%, current pattern matches nothing). Committed via daemon a83f88aa0 |
| **S10 btrfs-du physical** | 189.58GiB total / **6.43GiB exclusive** / 83.62GiB set-shared → **backup prunes + corpse-trash reclaim ≈ nothing physical** while the live DB pins extents; KEEP 7→2 is hygiene, the real lever stays S8 |
| **S18 journal cap** | already explicit (boot.nix: SystemMaxUse=8G, RuntimeMaxUse=2G, MaxFileSec=1week, MaxRetentionSec=1month); 7.8G observed = cap working. Row closed, no change |
| **S16 immich cache verdict: ACCEPT** | clip 5.7G + facial-recognition 631M + ocr 206M + huggingface 33M; bounded by model count, write-rare; relocation is the wrong trade while 66G residue + 123G dumps exist |
| **S17 dnsblockd verdict** | correct tier (Samsung hot subvol); journal.db 4.2G + tracking 2.4G both bounded by 30d retention. ONE anomaly kept: **duplicate tracking DBs** (`tracking.db` 2.4G + `dnsblockd_tracking.db` 724M — upstream rename leftover?) → new dnsblockd.md section queued |
| **S26 probe rules** | 4 rules encoded in docs/agents/shell-devtools.md (no error-eating pipes; section manifest; no `2>/dev/null`; **glob-expands-as-lars under sudo** — `sudo du dir/*` globs BEFORE sudo, run pipelines inside `sudo bash -c`; quoted-number sanity check) |
| **S20 E6 quality pair (shell legs)** | `scripts/test-migrate-user-tmp-hot.sh`: **19 legs, ALL PASS on first run** (prepare/finalize/shadow-cleanup, every refusal gate incl. detached-Samsung + archive-verify-fail-leaves-shadow); hot-user-caches⇄disko eval cross-guard assertion added; negative-test group `usertmpguard` added. **BUT: the flake-check leg and the negative-test leg have NOT RUN (eval-blocked) — parse-verified only** |
| **S12 config legs** | tmpfiles `q /var/tmp … 14d` age-clean + boot-evidence-pull.sh scratch retargeted to `~/.cache/boot-evidence/` |
| **S23 config leg** | `resume_missing = false` on the btrbk root instance (forensics: Oct 23 triple-run + Oct 26 23:00/23:08/23:29 @home-hermes burst = resume-after-stray-receive; root-prune-guard's 5-min btrbk invocations while >90% amplify). Verify at next 23:00 fire |
| **TODO dual-surface stamps** | 9 queue rows + 5 library rows stamped; dnsblockd.md section appended; `check-todo-system.sh` → structure OK |

## b) PARTIALLY DONE (built/committed, blocked on deploy or gates)

| Item | State | Blocker |
| --- | --- | --- |
| **S2 drill CAP fix** | CAP_FOWNER+CAP_DAC_READ_SEARCH in drill harden{} (forgejo.nix:1186), committed (daemon b9460ef1c); rendered-unit eval never ran | deploy (float) → forced drill → both legs green |
| **S4 KEEP 7→2** | config + rationale committed | deploy → next 03:00 fire shows 5 prune deletions |
| **S5 pool-interim copy** | full monitor365-pool-copy unit+timer+tmpfiles+freshness entry committed (699e8aaa7); **premise corrected: pool subvol is NOT empty — it hosts the LIVE agent buffer** (backups go to its `backups/` subdir) | deploy → force-run → pool-side ls verify |
| **S24 balance-watch** | new module (5-min kernel-journal scan, persistent ledger, 4 gauges, gatus check via integration registry), git-added immediately, parse OK — **eval never ran** | deploy → `/dev/kmsg` simulation test |
| **S25 storage-collect hardening** | ProtectKernelLogs=mkForce false (the dmesg SIGSYS fix) + RestartSec 30s + start limit + TimeoutStopSec + **freshness sidecar** (storage-collector-freshness unit+timer+gauge+gatus check), parse OK — eval never ran (mkForce-vs-upstream conflict risk unproven) | deploy → fresh-gauge green + storm behavior |
| **S7 fix live-verify** | config committed | deploy → check must go **RED at live 94% and page Discord** (then resolve as frees land). NOTE: whether gatus-alert-relay's sev1-mute list passes this check through is UNVERIFIED — verify must confirm a Discord page, not just gatus red |
| **S1 sweep prep** | pre-flight complete: PSI gate checked, baseline df, all residue paths existence-verified (discordsync ×4, /var/tmp debris, gitea.pre 5G, containers 4.9G, runner 13G, monitor365 corpses+Jul-12 relics), trash tooling present. **The actual sweep script (µ1.2) was NOT written** — deferred when PSI hit 64–86% (three parallel agent terminals; writing it is IO-free and should have happened anyway) | IO PSI < 20% + write the script |

## c) NOT STARTED

- **S3** dump-leg disable + 123G trash (hard-gated on S2 green drill → needs deploy)
- **S6** balance (gated: +3d pin expiry after S1 frees)
- **S8** monitor365 hot-tier migration (gated on S6 headroom + parallel-session coordination)
- **S9** VACUUM verify (gated on S6)
- **S13** forgejo.md backup-leg enumeration (post S3)
- **S14** pinned-rev dump-module verify (needs eval)
- **S15** dump-growth driver (deferred: unzip -l on 27G zip = QLC read during a storm)
- **S19** monitor365 fork ruling + 32G buffer disposition (owner)
- **S21** scrub root+/data (post-frees, quiet window)
- **S22** hermes du (rides S1 window)
- **S27** close-out (tombstone `done`, 10-26 plan annotation, watches — end-of-plan)

## d) TOTALLY FUCKED UP (radical honesty)

1. **`rg -rn` typed THREE times** — the exact trap AGENTS.md documents with a dedicated hook (which caught all three). One probe (dnsblockd) was eaten by it and had to be rewritten. Zero excuse; the correct form is `rg -n`.
2. **monitor365.nix edit mangle** — my old/new string construction deleted the backup unit's closing braces (`ioTier.background ]; };`) and accidentally re-anchored `ioTier.background` inside my new unit's mkMerge (semantically fine, structurally wrong). Caught by `nix-instantiate --parse` + git-diff within one step, repaired. Cause: I constructed the replacement without re-checking the kept prefix against the current view.
3. **Retyped an existing paragraph and introduced two typos** (DuckuckGo, grafica.com) in shell-devtools.md instead of append-only editing. Caught by immediate diff review, fixed. Retyping existing text is a footgun; append or nothing.
4. **Duplicate `services.integration` attribute** in storage-collector.nix (S25) — parse error, caught, merged. Same root cause class as #2: writing Nix without re-checking the surrounding attrset.
5. **S20's flake-parts wiring landed WITHOUT its eval leg**: my pathspec commit was refused by the pre-commit hook (correctly — full eval blocked by the float), and before I could split it, **the daemon swept `fixtures-migrations.nix` (801d8e367) bypassing the hook** — the documented daemon-bypasses-hook-legs gap. The eval leg is now OWED before any deploy trusts it.
6. **Stamps say "BUILT" for never-evaled modules** — btrfs-balance-watch.nix, the S25 hardening, and the S20 cross-guard are parse-verified only. A parse pass is NOT an eval pass (mkForce conflicts, option-shape errors, writeShellApplication escapes are all still possible). The TODO stamps do say deploy-pending, but the honest label is "parse-OK, eval-unproven".
7. **I did not write the S1 sweep script during the storm** — everything about it is IO-free (it was even designed: trash → verify-landed → precise empty → df probe, honoring the "trash on a subvol mount frees nothing" finding). Pure sequencing miss.
8. **shellcheck never ran** on my edited scripts (boot-evidence-pull.sh, negative-test-lints.sh, the new test) — the daemon swept them before my pathspec commits, so the hook's shellcheck legs skipped. Owed.

Nothing irreversible happened; no secret leaked; no parallel session's work was touched or reverted.

## e) WHAT WE SHOULD IMPROVE

1. **The daemon can split atomic float pairs** — it batch-committed a mid-proof `flake.lock` without `expected-locks.nix` and broke eval tree-wide for >1.5h (multiple sessions + CI's push checks are affected). Structural fix: the daemon (or a daemon-mode pre-commit leg) must REFUSE to commit `flake.lock` unless `flake/expected-locks.nix` changes in the same batch (or a `FLOAT-IN-PROGRESS` marker exists).
2. **A PSI-gated window should trigger IO-free completion**, not full deferral — write the gated script, pre-stage harnesses, so the moment the gate opens it's one command.
3. **gatus label-order fragility is a CLASS** — any `pat()` with a multi-label literal segment is one exporter relabel away from phantom-green. Candidate eval-time lint: flag multi-label literal segments in pat() patterns, require the wildcard-bridged form (like the S7 fix).
4. **Parse-verified vs eval-verified needs distinct vocabulary** in stamps/commit messages ("PARSE OK" ≠ "evals green") — this session blurred it on first write.
5. The `alerts`-relay sev1-mute list needs checking whenever a new Monitoring-group check is added — otherwise "gatus red" ≠ "page landed" silently.
6. Retyping text during edits: banned (append-only or exact-copy). The two typo classes this session were both retype bugs.

## f) NEXT (ranked; feeds the resumed executor)

1. **Unblock the eval train** — float session registers 12+ registry rows with proofs, OR the sanctioned revert (lock revs back to registry, together) executes (§g Q1)
2. **Deploy train A** (one deploy): S2 CAP fix + S7 alert fix + S4 KEEP 2 + S5 pool-copy + S12 + S18(no-op) + S23 + S24 + S25 + S20 wiring — then per-item live verifies (drill force-run; gatus RED at 94 + Discord page; 03:00/03:25 windows)
3. **Write `~/.cache/storage-crisis/sweep-sudo-list.sh`** (dry-run-first) — can be done NOW, storm or not
4. **S1 sweep execution** when PSI < 20 (trash → verify → precise empty per opencloud-session finding; includes S22 hermes du + µ27.4 wevisone-spike/@home-subvol look-then-decide)
5. **S3** after green drill: `dump.enable = false` deploy → verify nightly pool leg → trash 123G (Samsung df delta; 3d hot/forgejo pin)
6. shellcheck on the three edited/new scripts (owed from d.8)
7. Run `CASES=usertmpguard bash scripts/negative-test-lints.sh` + `nix flake check` legs for S20/S24/S25 once eval unblocks (owed from d.5/d.6)
8. **S14** pinned-rev dump-module eval (12 min once eval is back)
9. **S15** unzip -l growth-driver analysis (calm window, rides sweep window)
10. **S6** balance at +3d after S1 frees (reserve-rm → quiet gate → `-dusage=10 -dlimit=5` → re-provision reserve → unalloc ≥20G)
11. **S9** VACUUM watch at the first 03:00 after S6 headroom
12. **S8** monitor365 hot-tier migration (coordinate with parallel monitor365 sessions; needs S6 unalloc)
13. **S19** owner ruling → 32G buffer disposition (§g Q2)
14. **S13** forgejo.md Storage-section rewrite (after S3 lands)
15. **S21** scrub root+/data (weekend quiet, post-frees)
16. **S27** close-out: 10-26 plan annotation, storage.md row-183 drain stamp, watches (~/.cache >90G, tmp automount), plan-marker `done`
17. gatus multi-label pat() lint (e.3) as a negative-test group
18. daemon float-split guard (e.1)
19. dnsblockd duplicate-tracking-DB verify (30d-mtime rule) + possible trash
20. Re-check "Root Auto-Prune Floor (90%)" resolves after S1+S6 (it's correctly red since 10-26 18:05)
21. ci-watchdog failed unit + runner inactive → hand to the runner-health session (not mine)
22. Post-deploy: confirm the monitor365-pool-copy timer arms (03:25) and the freshness row appears in backups.prom
23. Confirm resume_missing=false renders into /etc/btrbk/root.conf post-deploy
24. The 12 GB/h opencloud log class: confirm no regrowth (their report says drain over; watch row exists)
25. Merge-verify + push coordination once the float session lands (local has ~15 unpushed daemon batches)

## g) QUESTIONS (cannot figure out myself)

1. **The lock-float split: wait or revert?** The sanctioned remedy ("revert that input's registry row AND its lock rev together") would restore eval for everyone but stomps the parallel session's in-flight sweep (their proofs re-run). They've been mid-flight >1.5h with the tree red. Do you want me to (a) keep waiting for them, (b) execute the sanctioned revert myself now, or (c) ping them / leave a status note and wait a bounded time?
2. **S19 ruling (plan-marked owner):** monitor365 fork — agent back up vs retire (row 558)? The disposition of the 32G frozen buffer (trash vs drain) hangs on it.
3. **Off-schedule monitor365 backup force-fire:** verifying S4 (KEEP 7→2 prune lines) without waiting for 03:00 means force-running `monitor365-server-backup` (stops the server ~3–6 min; parallel monitor365 sessions active). Force-fire once post-deploy, or let the natural 03:00 window verify it?

---

**Session commits of record (all rode daemon batches; none pushed):** 82bfe056b (tombstone), b9460ef1c (S2 forgejo CAP), a83f88aa0 (S7 gatus fix), 608f08cd5 (S12), bbb93fe44 (S4), 699e8aaa7 (S5 + parallel cv/sops), 801d8e367 (S20 wiring), + TODO/doc stamps in later batches. The tree is the durable record; eval-verification of everything in (b) is owed before the deploy train fires.
