# CV Backup Self-Creation — VM Regression Test, Third Bug, Full Self-Review

**Date:** 2026-08-31 17:22 CEST · **Host:** evo-x2 · **Session arc:** user challenge "why does the folder not create itself if needed?! We have nix for a fucking reason!" following the 16:29 pool-recovery report. Continuation of `2026-08-31_16-29_das-pool-recovery-backup-catchup-self-review.md` (read its addendum for the bridge).

---

## What happened this arc, in one paragraph

I owned that leading with `sudo mkdir` was the wrong answer, built the NixOS VM regression test that PROVES the backup dir self-creates (`tests/test-cv.nix` steps 9-10, real `/mnt/pool` disk via `emptyDiskImages`), and the test's **first run went RED** — exposing a **third production bug** the 226 had been masking: `cv-backup` was a **silently green no-op since deployment** (root + `harden {}`'s empty `CapabilityBoundingSet` obeys DAC → cannot stat through cv-server's `0750 cv:cv data/` → `[ ! -f $db ]` true with the DB present → exit 0). Fixed with `CAP_DAC_READ_SEARCH` (backup-health-metrics precedent), test re-ran **GREEN end-to-end**, `nix flake check --no-build` passes, my files formatter-clean, AGENTS.md + prior status report updated, everything staged.

## Verified end state (17:22)

| Thing | State |
| --- | --- |
| `tests/test-cv.nix` steps 9-10 | **GREEN** in VM: dir self-creates at boot, deploy-style restart recreates after `rm -rf`, real `pipeline-*.sqlite` lands on the pool mount, "no pipeline.sqlite" line asserted ABSENT |
| `nix flake check --no-build` | all checks passed |
| cv.nix / paperless.nix / test-cv.nix formatting | clean (scoped `nix fmt`, 0 changed; the repo-wide `--ci` "1 changed" was a mid-run race on the PARALLEL session's `scripts/bench-disk.sh`) |
| `btrbk-data` (started 14:30 boot catch-up) | **FINISHED ~17:02 — FAILED again** (the known /data EIO class); `btrbk-pool-clean` then correctly removed BOTH incomplete receives (`data.20260726T2330` garbled + the old `data.20260721T2330` stray) — `/mnt/pool/backups/data` is now clean-empty awaiting tonight's 23:30 retry (which fails again until the EIO P0 repair; expected/documented) |
| cv / paperless in `backups.prom` | still red (999h / 255h) — exactly the two things the undeployed fixes address |
| Production cv-backup | STILL BROKEN (three stacked defects, all fixed repo-side only): no pool dir → 226 tonight; even with dir → DAC no-op |

---

## a) FULLY DONE

1. **The declarative answer, proven:** `cv-backup-dir` oneshot (atticd-storage-dir pattern) wired three ways — boot (`multi-user.target` + `RequiresMountsFor`), deploy (`deploy.sh` provisioner restart → dir exists the moment the switch completes), timer-fire (cv-backup `wants` it → systemd retries the creator inside the same transaction). No manual `mkdir` ever needed; the only remaining step is the deploy that activates the module. Retraction of the sudo-shortcut as primary answer: done, in writing.
2. **VM regression test** (`tests/test-cv.nix` steps 9-10) with a real auto-formatted `/mnt/pool` disk: boot self-creation, deploy-convergence replay (`rm -rf` + restart), real sqlite seed → real pool-side backup artifact, unit-not-failed assert, plus an explicit **silent-noop journal guard** (`journalctl` must NOT contain "no pipeline.sqlite").
3. **Third bug root-caused and fixed:** `CapabilityBoundingSet = "CAP_DAC_READ_SEARCH"` on cv-backup — root cause chain verified against the DEPLOYED unit file (empty bounding set, no hiding directive) and prod `/var/lib/cv` layout (`0750 cv:cv data/`, actively written — live mtime). The repo's own `backup-health-metrics` module documents the identical class.
4. **Verification stack:** VM test GREEN (41s run), `nix flake check --no-build` all-pass, scoped formatting clean.
5. **Docs:** AGENTS.md recovery bullet extended to "Three bugs" with the DAC lesson + test pointer; addendum appended to the 16:29 status report; all session files staged (`git add`: AGENTS.md, status doc, cv.nix, test-cv.nix).

## b) PARTIALLY DONE

1. **Deploy activation — still THE blocker.** Everything above exists only in the tree; production still has the missing pool dir, the 226, the no-op, and the non-Persistent paperless timer. Tonight 03:17 cv-backup fails 226 again unless deployed first.
2. **btrbk-data observation closed but outcome negative:** the 14:30 full re-send FAILED (~17:02, expected EIO class); the clean pass worked perfectly (both incomplete subvols removed — first live proof the garbled-receive GC handles exactly this). The tier remains the only backup that has NEVER completed pool-side (P0 since Aug 18).
3. **Test fidelity gaps:** the VM seed creates a ROOT-owned `pipeline.sqlite`; prod DB is cv-owned (same cap covers both, but the test proves the weaker case). The cv-server-DOWN edge (03:17 with server stopped: sqlite may need to write `-shm`/`-wal` into the cv-owned dir → EACCES loud failure) is reasoned, not tested.

## c) NOT STARTED

1. Repo-wide sweep for the silent-noop class (hardened root oneshots reading/`-f`-checking paths under foreign-owned dirs — this is the THIRD DAC incident: attic chown EPERM 2026-08-18, backup-health-metrics cap, now cv-backup).
2. Eval-time audit: `ReadWritePaths` under `/mnt/pool` ⇒ `RequiresMountsFor` + a declared creator.
3. Backup-timer `Persistent=true` lint (flake check).
~~4. `TODO_LIST.md` migration of the durable items (still not done across two reports!).~~ done — 2026-08-31 docs-health audit (eval-audit cluster rows)
5. `backup_ever_succeeded` metric (never-worked vs stale distinction — today proved the difference matters: cv rode "all red" outage noise for days while being never-green since birth).
6. paperless `RandomizedDelaySec` (or fix the lying comment in configuration.nix).
7. Prod shadow-dir cleanup under `/mnt/pool` (cv + root/data tmpfiles shadows).
8. `btrbk-root` post-deploy/`--no-block` catch-up trigger.
9. `scripts/backup-catchup-report.sh`.

## d) TOTALLY FUCKED UP (honest ledger)

1. **The module shipped with THREE stacked defects in ~40 lines** — no declared dir creator (226), DAC-blind no-op (exit 0 forever), and outage-masked visibility of both via the root-fs shadow. NONE were caught by eval, pre-commit, CI, flake check, or monitoring — because everything was green-shaped. The monitoring gap is the real fuckup: an exit-0 oneshot whose artifact never existed was indistinguishable from a healthy backup until a human asked "why manual mkdir?".
2. **I had the evidence and explained it away:** the Aug 27-30 journal lines "no pipeline.sqlite yet" were in my terminal at ~15:05; I attributed them to benign absence (ignition pending) instead of asking why the file was invisible to a root unit. The user's challenge — not my analysis — forced the test that found it. My first-round self-review even flagged "no negative test" and I still didn't write one until pushed.
3. **Led with an anti-declarative reflex** (`sudo mkdir`) in the first answer — in a repo whose whole philosophy is converge-by-construction.
4. Minor: my first edit attempt this arc hit the mtime guard twice (daemon commits mid-session) and one AGENTS edit left a "Two bugs"/three-items inconsistency that I caught and fixed only because I re-read the line.

## e) WHAT WE SHOULD IMPROVE

1. **Artifact assertions over unit-state assertions** — a backup is not "healthy" because the unit exited 0; it's healthy when the FILE exists with fresh mtime. Apply everywhere: tests, Gatus, backup-coordination (`ever_succeeded` flag), post-deploy checks.
2. **Test-first reflex for fixes** — the repo doctrine existed (signoz-query-lint, gatus pattern lint lessons); this arc is the proof: the test found in 3 minutes what 4 hours of journal archaeology missed. Rule: any fix for a "silently wrong" bug ships with the test that would have caught the bug.
3. **Canonicalize the root-without-caps DAC gotcha** — currently scattered across three incident notes (attic, backup-coordination, cv). One AGENTS systemd-section entry + optionally a `harden { readForeignPaths = true; }` sugar or lint that flags root units referencing other services' StateDirectory paths.
4. **Consider identity-correct backup units** — `User = "cv"` + cv-owned backup dir would make cv-backup immune to the whole DAC class (at the cost of creator chown); decide deliberately rather than per-incident.

## f) NEXT (ranked; merged with surviving items from the 16:29 report)

1. **Deploy** (`nix run .#deploy`) — activates all three fixes; deploy.sh restarts cv-backup-dir at switch time, so the dir exists the moment the deploy finishes.
2. Post-deploy prod proof: `test -f /mnt/pool/backups/cv/pipeline-*` + `backups.prom` cv healthy + optionally `systemctl start cv-backup` for immediate confirmation.
3. Tomorrow morning: pool `@.20260831T2300` received (23:00 send), paperless export fresh (01:30), cv backup landed (03:17), `backup_all_healthy 1`, `btrfs-verify-pool-backups` green.
4. Repo-wide silent-noop sweep (hardened root oneshots vs foreign-owned paths).
5. Eval-time audit: pool-path ReadWritePaths ⇒ RequiresMountsFor + creator.
6. Backup-timer Persistent lint.
7. `TODO_LIST.md` migration (both reports' durable items).
8. `backup_ever_succeeded` metric.
9. Test-cv fidelity: seed as `cv` user; add cv-server-stopped edge case.
10. Decide cv-backup identity model (root+cap vs User=cv) — follow-up refactor.
11. AGENTS: single canonical DAC gotcha entry in the systemd section, cross-ref the three incidents; split the mega-bullet for readability.
12. /data EIO P0: schedule the repair decision — tonight's 23:30 retry will fail again by design.
13. btrbk-data oom containment (page-cache class, 20.6G).
14. `btrbk-root` post-deploy `--no-block` catch-up trigger.
15. paperless RandomizedDelaySec / comment fix.
16. Prod shadow-dir cleanup under /mnt/pool.
17. `scripts/backup-catchup-report.sh`.
18. btrbk receive-freshness in `backups.prom`; btrbk-pool snapshot freshness check.
19. Local `snapshot_preserve` widening decision (outage rollback-window lesson).
20. google-sync go-live or dormancy note.
21. Confirm CI green on the new cv VM test after push (GitHub Actions builds all checks).
22. Monitor the parallel session's pending edits (lib/default.nix, lib/docker.nix, smart-audio, browser-history, services README) — they ride the next deploy.
23. Investigate the odd `btrfs send -p @.20260816T2231 @.20260814T2300` journal line (curiosity).
24. Consider a paperless-exporter boot-catch-up test (Persistent assertion in a VM).
25. Document the cv-backup server-down `-shm` semantics (loud EACCES acceptable vs gate).

## g) QUESTIONS (cannot resolve myself)

1. **Deploy timing (still the blocker, second time asking):** the parallel session has unstaged edits in `lib/default.nix`, `lib/docker.nix`, `smart-audio.nix`, `browser-history.nix` — deploy now and take their in-flight state onto the switch, or wait for that session to land? Say the word and `nix run .#deploy` is one command away (sudo is blocked for me).
2. **/data EIO repair (P0, third reminder):** today's full re-send failed exactly as every run since July, and the clean pass just wiped the target clean — the tier rebuilds from zero on every attempt. Do you want the maintenance window scheduled (quiesce /data, `btrfs check`, likely rebuild from sends), or keep the documented "let it fail loudly" stance?
3. **cv-backup failure semantics when cv-server is stopped at 03:17:** sqlite may need to write `-shm`/`-wal` into the cv-owned dir → root-without-write-caps fails LOUDLY (onFailure alert) rather than silently — acceptable, or should the unit gate/wait on the server (or run as `User = cv` with a cv-owned backup dir, eliminating the whole DAC class)?

---

**Bottom line:** the folder now creates itself — declaratively, three ways, proven by a VM test that also caught a third, worse bug (silent no-op backup since deployment). Everything is fixed, tested, staged, documented — and sitting behind exactly one command you control: the deploy.
