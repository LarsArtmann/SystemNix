# Window Closeout — Five Tasks: 2 Review-Fixes, Paperless PG Dump, Cache-Fallback Sweep, Restic Dedup Repo

**Date:** 2026-09-22 05:07 CEST
**Window:** 2026-09-21 ~11:30 → 2026-09-22 ~05:00 CEST
**Tasks closed (queue IDs):** `000001a0c10023cde007879240f2d8a3a5ae`, `000001a0c100232043f9f217095d7fe77d2d`, `000001a0c373465b2a59cd41196ec4d45014`, `000001a0c5fdb2dd3166a37c82d89dc5be6c`, `000001a0c618c3adc95abca642eadda2dd3c`
**Report method:** every closeout report read first; every claim below re-verified against git (`git show --stat` on all five footer commits + the underlying daemon implementation commits), the tree (test files, module files), and the tq journal (`tq facts --type task.reprioritized`).

---

## a) FULLY DONE

1. **Review-fix `…cde007879240f2d8a3a5ae` — citation correction landed and verified.** Fix commit `36a7160c` (11:41) corrected one line in `docs/status/2026-09-20_09-46_task-000001a0bbb06602422f206275102f26a74a.md:31`: the deploy-restart-audit config-layer fix is credited to `50f73871` (09:36, `deploy-restart-audit.nix` +27/−20, verified via `git show --stat` before the edit), with the parenthetical that `82d4fa4a` carried only the commit MESSAGE claiming the fix (docs-only diff). Report commit `ce2f01da` carries the footer. Re-verified this pass: the corrected line is live on the tree.
2. **Review-fix `…f9f217095d7fe77d2d` — hot-db shared-unit finding verified ALREADY RESOLVED.** Zero code changes were needed: `modules/nixos/services/hot-db.nix` groups consumer anti-shadow wiring PER UNIT via `lib.zipAttrsWith (_: lib.concatLists)` (landed in daemon commit `9cce5bfd`, 09-21 11:17 — minutes before the fix ticket was cut), and `tests/test-hot-db-assertions.nix` carries the `shared-unit-entries-wire-all-paths` case. The disposition report (commit `ca8ad35a`) verified both `hot-db` checks build green. Correct disposition under the "verify content, not authorship" multi-agent rule.
3. **Paperless PG-level dump (`…d45014`) — implemented, closed, and re-verified.** Implementation: `9546e7a1` (module: `paperless-db-backup.timer` 02:00+10min jitter Persistent, `paperless-db-backup.service` User=postgres peer-auth `pg_dump --format=custom` 14d retention, mount-gated `paperless-db-backup-dir` leaf oneshot; `scripts/deploy.sh` provisioner entry) + docs commit `e9407432` (footer). The deploy-restart-audit eval guard caught the missing provisioner entry on the first flake check — fixed before any deploy attempt, exactly as designed. The re-dispatch run (report `35fafaec`, commit `35fafaec`) added a verification dimension the first run lacked: the DISABLED-host shape (rpi3-dns renders none of the four artifacts — no module auto-discovery leak). `docs/todo/storage.md` row 27 marked `[x]`. The queued VM-test follow-up subsequently LANDED via the parallel 09-22 batch: `tests/test-paperless.nix` steps 8+13 now assert the timer/service/dir-creator + registry fan-out (verified on tree, lines 320-323).
4. **Cache-fallback sweep (`…2dd3c` part 1) — three NVMe-writing stragglers converged onto the buildcache SSD.** `platforms/nixos/users/home.nix`: HM out-of-store symlinks for `~/.cache/pnpm` (68M live), `~/.local/state/pnpm`, `~/.cargo/registry` (134M stale) + `migrate-buildcache-fallback-caches` activation (mount-gated, `entryBefore ["checkLinkTargets"]`, removes real-dir occupants so HM activation cannot abort). `buildcache.nix`: `pnpm` added to the dead-mount reap list (daemon commits `f39e144b`, `87be97e5`). The pre-commit GOTOOLCHAIN guard was narrowed to nix-value assignments after a live FP on home.nix's deliberate interactive fish override (footer commit `b4eda274`) — positive + negative functional verification of the new predicate. Library row 80 `[x]`; the pointer row left honestly open (see b.2).
5. **Restic app-dumps dedup repo (`…eadda2dd3c`) — module landed, eval-verified, and re-dispatch-verified.** `modules/nixos/services/restic-app-dumps.nix` (daemon commit `49cfb914`, +144): nixpkgs `services.restic.backups.app-dumps` over the 10 app-dump dirs, repo `/mnt/pool/backups/restic-app-dumps`, nightly 05:45+10min jitter, `--keep-daily 14 --keep-weekly 8`, `initialize = true`, machine-local password via `restic-app-dumps-setup` (provisioner-restarted, searxng-secret-key pattern — deliberately NOT sops), `.last_success` ExecStartPost marker + integration-registry `backup` row (fail-closed freshness), ioTier.background + 4G MemoryMax + 12h TimeoutStartSec + mount-gated. Docs `36a946d2` (footer) + verification re-dispatch `0c52b922` (repository option eval + `nix flake check --no-build` green). The queued VM test subsequently LANDED via the parallel batch: `tests/test-restic-app-dumps.nix` (real-btrfs-pool VM test, password idempotence, init-on-missing, marker-only-on-success negative, registry fan-out end-to-end) — file verified on tree (36 restic references), registered as check `restic-app-dumps`, eval-verified per CHANGELOG.
6. **Cross-cutting:** all five footer commits verified present with exact `Task-Queue-ID:` footers and unpushed; per-task closeout reports exist and match the git record; `docs/todo/storage.md` rows 27/30/80/90 + TODO_LIST ticks are internally consistent with the commits.

## b) PARTIALLY DONE

1. **Runtime is ZERO across the entire window — everything is eval-true, not runtime-true.** The running generation (`system-792`, `dj5k7ykb`, nixpkgs-20260919 era) predates ALL of this window's work. `paperless-db-backup`, `restic-app-dumps`, the three cache symlinks, the hot-db shared-unit wiring, the crush-hot-db guard upgrades: none exist on the booted host. The deploy was correctly refused by the pressure gate throughout (io PSI some avg10 62→99% for 25+ min stretches; parallel monitor365 DuckDB build identified as one driver). Every "done" in (a) is one `nix run .#deploy` away from being real, and the batch keeps growing (it now also carries the browser-history dbBackup leg, the discordsync ~40G attachments migration, the vendorHash wave, boot-mirror sync).
2. **The pool-quality pointer row (`…2dd3c` as a whole) stays open** — two `[ready]` library items remain: the `hot-db`/`crush-hot-db` VM-test rebuild (PSI-gated, measured 68% avg10 at session time, gate <20%) and the mountPoint-vs-HM-symlink eval guard (deferred to its own run). The queue row carries the honest BLOCKED note.
3. **The review-fix task's own follow-up (the 12-26 report's second `82d4fa4a` misattribution site) was NOT fixed by the session that queued it — and the 2026-09-21 corpus-sweep round 2 then CLAIMED it fixed without the fix existing.** Verified this pass: `git log --follow` shows exactly one commit (`5653e907`, creation) ever touched `docs/status/2026-09-20_12-26_deploy-chain-rescue-….md`, and its line 17 still credits `82d4fa4a` for the config-layer fix. Annotated with the correction in this pass (see d.1).
4. **The restic dedup premise is unproven** — "forgejo zips share ~0 extents" is the motivating claim, but dedup ratio is unmeasurable until ≥3 nightly runs exist (deploy-gated). The re-dispatch report correctly flags that eval-green is the weakest signal for a backup pipeline.
5. **Paperless DR chain is half-built:** dump exists (eval), but no restore drill, no post-deploy smoke entry, no dump-size/pool-growth observation, and dump-integrity is exit-0-trust-based (no `pg_restore --list` gate).

## c) NOT STARTED

1. **The deploy itself** — the single gate everything in this window sits behind (owner/queue authority question, see g.1).
2. **Restore drills** — paperless `pg_restore` into a scratch cluster (nothing analogous exists for paperless), restic one-file restore smoke, the older twenty/manifest drill (pre-existing storage item).
3. **The mountPoint-vs-HM-symlink eval-time guard** (autofs-in-autofs at unit load — the hot-user-caches go-build class) — library row ready, never built.
4. **The SHA-citation verifier script** (`scripts/verify-status-citations.sh`, from review-fix task 1 §f.3) — now doubly motivated by d.1.
5. **The `~/.npm` convergence** (103M stale real-dir fallback found by the sweep, deliberately not acted on in-run) and the `~/tmp/go-lint` (1.8G live) reclamation path — both filed, neither built.
6. **The wide storage backlog** (Borg offsite leg implementation, ClickHouse backup, /data repair chain, SSD-2 tenant, boot-mirror activation) — untouched, correctly out of these five tasks' scope.

## d) TOTALLY FUCKED UP

1. **A docs-health pass recorded a fix it never made.** The 2026-09-21 corpus-sweep round-2 report (§a.8b) and its CHANGELOG entry both state the `82d4fa4a`→`50f73871` misattribution "in the 09-20 deploy-chain report" was fixed. Git proves otherwise: that file has exactly one commit (creation) and the wrong SHA still sat there until this pass's annotation. Most likely mechanism: the sweep agent corrected the ALREADY-corrected 09-46 file (fixed at 11:41 by review-fix task 1) believing it was the deploy-chain report, then recorded the claim without a post-edit `git log -1 -- <file>` check. This is the exact "verification theater" class: the claim was evidence-shaped but never re-verified, and CHANGELOG (append-only) now carries a false historical entry that can only be counter-annotated, not edited. Two same-topic failures in one day says the citation-fix workflow needs the mechanical verifier (c.4), not more care.
2. **Daemon commit topology split EVERY substantive change in this window from its footer.** `9546e7a1` (paperless module), `49cfb914` (restic module), `f39e144b`/`87be97e5` (cache sweep code), `9cce5bfd` (hot-db shared-unit fix) are all heuristic-message daemon commits; the footer commits carry docs-only diffs. Queue tooling keying on footers sees docs-without-code (the 12:57 report's §e.20 notes the still-open `--soft`-fold carve-out question). The inverse also occurred: `b4eda274`'s message describes the whole sweep while its diff carries only the hook fix — message overclaims relative to its own diff. Two amend races were lost to the daemon in-window (restic 01:00 §d.1; pool-quality 00:17 §d.2) — the "verify + amend in ONE atomic command" rule was re-learned twice and is still not encoded as the standard procedure.
3. **`nix fmt --no-update-lock-file -- --ci` is NOT dry-run** — the 12:29 paperless session's tree-wide `--ci` run reformatted three foreign files (the two never-format multi-MB HTML bundles — the exact 2026-09-20 inflation class — plus a parallel session's script); caught from the error output and restored before commit, zero landing, but the AGENTS.md bullet treats `--ci` as check-only and that is wrong for this tree state.
4. **Review-fix task 2 (`…f9f217095d7fe77d2d`) was dispatched against an already-fixed finding** — the second same-day re-dispatch of closed work (paperless `…d45014` was also a re-dispatch of its own earlier run). Both were dispositioned correctly and cheaply, but the queue's done-filter/dedup gap (already a tracked upstream item) burned two paid dispatches.
5. **The GOTOOLCHAIN guard FP fix is unpinned** — second FP incident on that hook (after the dead-guard-lint `$((` class), both fixed in the scanner without a negative-test case; the repo doctrine says hook guards get pinned like flake checks.
6. **Deploy debt is compounding by the storm-day** — every `[x]`/eval-green mark in this window describes unbuilt state until the switch lands; each refused deploy makes the next one bigger (more exit-4 surface: the cv-perms / db-heal / hot-user-caches classes are all expected on this batch).

## e) WHAT WE SHOULD IMPROVE

1. **Post-edit verification is a gate, not a courtesy:** any doc pass that claims a fix must run `git log -1 -- <file>` (or grep the edited content) before recording the claim — one command would have prevented d.1 and the false CHANGELOG entry.
2. **Ship the SHA-citation verifier:** grep `docs/status/*.md` for bare 7/40-hex SHAs, `git show --stat` each, fail on missing SHAs, WARN on docs-only diffs cited as code fixes; CI WARN-grade first (status docs are append-heavy).
3. **VM test in the SAME run as the module:** restic, paperless-db, and hot-db all needed follow-up dispatches for tests that the landing run could have written. House default candidate: "new backup/backup-adjacent module ⇒ committed VM test in the same change."
4. **Batch-inventory line on every `[blocked:deploy]` row** ("rides the deploy with: X, Y, Z") so whoever fires the switch knows the blast radius before stc runs — this window added ~6 surfaces to the pending batch and the knowledge is scattered across five reports.
5. **One quiet-IO window, one batch of the PSI-gated verifications:** hot-db + crush-hot-db + restic + paperless VM tests are all eval-green/never-run; a single scheduled window (heavy-job wrapped) clears the whole backlog instead of each session re-gating.

## f) NEXT THINGS (most valuable, concrete; queue-shaped subset appended to TODO_LIST)

1. Fire the batch deploy in the first calm window (io avg10 <20%, no Zone-6 trip in 60 min) — it carries restic-app-dumps, paperless-db-backup, the discordsync attachments leg, browser-history dbBackup, the cache symlinks, crush-hot-db guards, hot-db shared-unit fix, boot-mirror sync, and the vendorHash wave; expect the known exit-4 classes, fix-forward.
2. Post-deploy verification chain: anchor check (`/run/current-system` == profile), restic first run + `restic check` + one-file restore smoke + dedup-ratio measurement, paperless first 02:00 dump + `backup_all_healthy` green + dump-size note, cache-symlink resolution + activation-journal check, discordsync attachments migration watch to completion.
3. `pg_restore` drill for the paperless dump into a scratch cluster (assert document counts); record as the DR proof in the paperless runbook.
4. Stub/fixture test for the destructive `discordsync-attachments-migrate` oneshot BEFORE the deploy that triggers it (row-25 doctrine; already filed as library row 87).
5. Rebuild `hot-db` + `crush-hot-db` VM tests green on the current tree (PSI-gated, heavy-job) — the unrealized test drvs are the deploy-confidence gap.
6. Eval-time guard: reject `fileSystems` mountPoints resolving through HM out-of-store symlinks into automounted parents.
7. Converge `~/.npm` onto the buildcache (symlink + reap-list entry) — closes the sweep's one leftover real dir.
8. Reclamation path for `~/tmp/go-lint` (1.8G live, zero gc coverage).
9. GOTOOLCHAIN guard selftest (pin the FP + both violation shapes).
10. `scripts/verify-status-citations.sh` (SHA-citation verifier, WARN-grade).
11. Add a `pg_restore --list` integrity gate (or checksum sidecar) inside the paperless-db-backup unit — exit-0 alone is trust-based.
12. Decide smoke-coverage ownership for the new dump freshness (post-deploy-check entry vs backup-coordination) — one owner only, no double-alerting.
13. Audit ALL `createLocally` PG consumers vs pg_dump jobs in one enumeration (browser-history sqlite leg just landed; twenty/manifest drill pending) so no DB silently lacks a dump.
14. After ≥3 restic nightly runs: measure the dedup win (`du`/`compsize` repo vs source dirs) — validates or falsifies the forgejo-zip premise, and feeds the ROADMAP single-source-of-truth question.
15. Sweep the corpus-sweep round-2 claims that involve file edits (spot-verify its other drift fixes the way d.1 was caught) — cheap given the false-positive found.

*(Deliberately stopped at 15: items beyond this are other domains' tracked rows — the queue owns them; padding to 50 would be research, not reporting.)*

## g) QUESTIONS ONLY THE OWNER CAN ANSWER

1. **Deploy authority + timing:** who fires the pending batch deploy, and under what rule — queue auto-deploy whenever the calm gates hold (io avg10 <20%, no Zone-6 trip in 60 min), or owner-triggered only? Every task in this window is runtime-blocked on it, the batch grows daily, and the 04:30/01:16/12:57 reports all independently asked.
2. **Restic repo scope + offsite role:** should the excluded dirs (`forgejo-subvol`, `github-voice-corpus`, `pixel6`) join `services.restic-app-dumps.paths`, and should the restic repo eventually BE the offsite leg (replicated toward Hetzner) or stay a local dedup layer under the future Borg leg? Changes the paths list and the Borg design in the same decision.
3. **DB-dump RPO policy:** is 14d the intended retention for the new pg/sqlite dumps (paperless-db, browser-history-db), and should restore drills be one-time manual runbook entries or automated periodic VM-test assertions? (Originals/media ride pool snapshots + btrbk; the dumps cover only catalogs/DBs — confirm that split is intended.)

## h) BAND DRIFT

`tq facts --type task.reprioritized` over the journal (`/mnt/pool/services/tq/tq.db`, whole journal 2026-09-10 → present): **0 facts.** No priority changes were recorded for any task in this window (or any other). **None recorded.**

---

## In-passing observations (not researched, flagged for the record)

- **VendorHash wave (23:20–01:21, session `2026-09-22_01-21`):** 7 LarsArtmann upstream repos had stale vendorHashes from one nixpkgs-bump wave; all fixed UPSTREAM, pushed, re-locked; toplevel builds green; deploy still refused by the storm. Its §c.3 asks the right systemic question (why one wave broke 7 repos — suspected dep-sweep daemon landing lock+go.mod bumps without hash dances) and its fleet-audit tooling idea (probe ALL inputs' goModules FODs in one pass) is strong harvest material.
- **Parallel 09-22 03:02–04:39 batch** (outside this window's five tasks): landed the restic + paperless VM tests, paperless relay-email assertions, atticd `ReadWritePaths` derivation, tq `startLimit*` verification, Health Hub post-deploy smoke, the browser-history dbBackup + discordsync attachments legs, and the own-tools migration verification closeout (`32ce794b`). Its two "zero test coverage on destructive/new paths" findings (d1/d2 in the 04:30 report) are already filed as library rows.
- The corpus-sweep round 2 (14:20–16:30) is the only prior docs-health pass in this window's span; its archive moves and reference repoints were spot-checked via the dangling-reference scan it ran (no action needed here beyond d.1).

---

*Verification anchors: footer commits `ce2f01da`, `ca8ad35a`, `35fafaec`, `b4eda274`, `0c52b922`; implementation commits `36a7160c`, `9546e7a1`, `e9407432`, `eae85c7b`, `f39e144b`, `87be97e5`, `49cfb914`, `36a946d2`, `9cce5bfd`; test files `tests/test-restic-app-dumps.nix`, `tests/test-paperless.nix:320-323`, `tests/test-hot-db-assertions.nix` (shared-unit case); tq journal query `tq facts --type task.reprioritized` → 0 facts. All commits unpushed per contract.*
