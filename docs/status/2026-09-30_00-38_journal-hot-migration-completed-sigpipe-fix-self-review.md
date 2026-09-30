# Status: journal-hot migration COMPLETED (runtime path) — runbook premise failure + finalize SIGPIPE — self-review

**Date:** 2026-09-30 00:38 CEST · **Host:** evo-x2 · **Session:** continuation of the autofs-deadlock recovery arc
**Scope:** this session's run only (PSI-gate raise → migration completion → verification → cache/forgejo triage). Prior legs: see `2026-09-29_23-14_*`, `2026-09-29_20-21_*`.

## TL;DR

The journal-hot migration is **functionally complete on the runtime path**: subvol copied exact, mount live on the Samsung, journald persistently writing it, volatile window flushed with zero loss, marker roundtrip green, nodatacow set. Two real failures this session, both caught and fixed same-session: (1) I handed the user a runbook step that failed on arrival because I trusted the prior report's triage line instead of reading `/etc/fstab`; (2) the parallel session's finalize died silently to a `pipefail`+`head` SIGPIPE bug that I had failed to spot while editing that exact file. The boot-ordering path is still UNVERIFIED until a reboot. Zero journal data lost at any point.

## a) FULLY DONE

1. **PSI gate raised 20% → 80%** in `scripts/migrate-journal-hot.sh` (user-ordered, storm was not draining); moot quiet-window watcher job 052 killed.
2. **Root-caused "Unit var-log-journal.mount not found"**: active `/etc/fstab` had NO journal entry; LoadState `not-found`; journal proved the unit DID attempt mounts at 21:36×3 + 21:54 (ENOENT = subvol pre-migration). Root cause: the journal-hot import was **containment-disabled** in `platforms/nixos/system/configuration.nix:50-58` (by the parallel session, after the 21:36 deploy rode it un-migrated) with an explicit re-arm instruction.
3. **Re-armed the import exactly per the documented re-arm condition** (prepare had completed); stale containment comment replaced with the factual re-arm note.
4. **Eval-verified the wiring** before build: `fileSystems."/var/log/journal"` (tlc, `subvol=journal`, nofail, 5s device-timeout) + journald `after/wants = var-log-journal.mount`.
5. **Audited deploy riders** (unaudited-tree lesson applied): snapshots.nix `SuccessExitStatus=1` = parallel session's documented scrub-abort fix (verified live 00:22, commit bd615524); docs rows only otherwise.
6. **Toplevel pre-flight build green** (deploy-readiness gate honored; the FOD-mismatch class from last night cannot recur silently).
7. **User deploy f52i5gyv succeeded**: `var-log-journal.mount` mounted `nvme1n1p2[/journal]` (subvolid=259), journald restarted onto it.
8. **Finalize silent death root-caused and PROVEN**: `ls -t | head -1` under `set -euo pipefail` → SIGPIPE(141) → script killed right after a successful flush (reproduced: `EXIT=141`). Fixed both hazards: `sed -n '1p'` and `grep … >/dev/null` (the `grep -q` twin would have reported spurious VERIFY FAILED). Fix tested green + `bash -n` clean.
9. **Full migration verification executed manually** (everything the dead finalize tail was supposed to check): mount active; journald persistently writing the mount (live mtimes); /run window (23:36→flush) entries readable post-flush; active journal file resolves onto the mount; write→read marker roundtrip green; `lsattr` shows `C` (nodatacow, doctrine C); 100 files preserved. **MIGRATION COMPLETE, zero data loss.**
10. **AGENTS.md gotcha filed**: new "Journal on the Samsung Hot Tier (`journal-hot`, migrated 2026-09-29)" section — the migration-before-import doctrine (with the containment/re-arm pattern that worked) and the pipefail SIGPIPE shell class.
11. **`nix.pre-tlc` backup trashed** per its own documented lifecycle (`configuration.nix:452-454`: "copy back, then trash it"); zero open fds verified; 210MB back on the 92%-full QLC root.
12. **Cache census + forgejo health check delivered**: trash ~13.5G stale (fio benchmark leftover, .bun, go-*-p0, helium, .pnpm-store, go-smoke-wave) / move ~16G hot to tlc via crush-hot-db symlink pattern (uv, overview, qmd, go-build-httputil/demo, gopls, buildflow, chromium-headless, puppeteer, comgr, golangci-lint) / leave (nix already automounted, fontconfig). Forgejo: active/running, mirror+backup timer family alive, only 4 benign warnings since 21:00 (2 stale commit-graph locks, 2 storm-window slow API calls), data on QLC root, `dedicated` subvol design correctly INERT (mkIf-gated, migrate-script-gated).
13. All edits swept by the auto-commit daemon (verified: 3dce80b8 00:28 and successors).

## b) PARTIALLY DONE

1. **Official finalize record**: the script's own `finalize marker` + `finalize OK` line never landed (script died pre-marker). Functionally superseded by my manual verification; a 5s optional re-run (now fixed) would make the script's own record true.
2. **Migration-gate policy**: gate sits at the storm-time 80% (user-ordered); designed value was 20%. Also asymmetric: finalize's flush is ~2s of IO but is held to the same 80% gate (it REFUSED twice at 83-85% before passing).
3. **Documentation of this arc**: AGENTS.md gotcha done; TODO_LIST.md row ("modules with one-time migrations must block deploy until executed") NOT filed — deliberately deferred to avoid colliding with the parallel session's actively-staged edits. Undone, not forgotten.
4. **Cache + forgejo work**: analysis and recommendations complete, execution not started (awaiting direction).

## c) NOT STARTED (carried backlog, highest first)

- Reboot verification: the module's entire boot-ordering path (journald `Before=sysinit.target` race) is untested until a real boot; `nix run .#pre-reboot-check` not run.
- Forgejo doctrine implementation (Q2: disko-declare `hot/forgejo` + migrate + flip `dedicated`, vs keep on QLC).
- Durable GC-eviction fix (docs/todo/pipeline.md:155) — nix-gc ran AGAIN at 00:00 tonight; the eval-flap WILL recur today.
- Real build of the hot-user-caches regression VM test (eval-only so far).
- test-journal-hot.nix: authored by the parallel session, claims to boot both shapes — never built/eval'd by me.
- Everything else from the 23:14 report §f backlog (gatus alerts, pool balance, hermes 0.0.0 anomaly, forensics archival, docs-health HARVEST, etc.).

## d) TOTALLY FUCKED UP (honest ledger)

1. **Runbook handed over on an unverified premise.** I gave the user `systemctl start var-log-journal.mount` as step 2, adapted from the 23:14 report's claim that the unit had "failed". It was actually ABSENT from the generation (import commented out ~22:00). A 2-second world-readable read of `/etc/fstab` (no sudo needed) would have caught it before the user burned a round-trip — and journald sat volatile longer than necessary because of it. Root cause: inherited triage claims treated as ground truth instead of re-verified state.
2. **Reviewed the migration script twice, missed the landmine that then fired.** I read `migrate-journal-hot.sh` in full and edited its PSI gate — and still did not flag `ls | head -1` under `set -euo pipefail` (or the `grep -q` twin). Finalize then died silently mid-verify. Diagnosis after the fact was fast and proven, but the review that should have caught it failed. Both patterns are now fixed AND documented in AGENTS.md so the class has a name.
3. Minor technique misses: `LoadUnit` stub semantics initially misread (it returns a path for not-found units — had to re-check LoadState); killed watcher job 052 without reading its final output (lost the PSI trend record for this report).

Nothing irreversible happened. No data lost, no false "OK" claims to the user, no unowned damage.

## e) WHAT WE SHOULD IMPROVE

1. **Verify inherited claims against live state before emitting runbooks** — fstab/unit state is readable without sudo; "the previous session said X" is not evidence.
2. **Audit any script for shell footguns the moment I touch it** — pipefail + early-exit pipes (`head`, `grep -q`, `sed -n` is safe), `set -e` + command substitution, unquoted globs. Touching a file = reviewing it.
3. **fdstore knowledge**: a journald restart does NOT return it to persistent mode (fdstore continuity keeps it volatile) — empirically learned tonight; encode in the journal-hot AGENTS.md section when next touched (flush is the only reliable lander).
4. **Gate policy**: restore PSI 20% post-migration (or make it an env override, e.g. `MIGRATE_PSI_MAX`), and consider gating finalize more leniently than prepare (flush ≈ 2s of IO vs a full 7.9G rsync).
5. **Parallel-session coordination is reactive**: I audited riders only after noticing symptoms. Cheap default: `git log <last-deployed>..HEAD --oneline` + grep incoming modules for `migrate`/runbook markers before every deploy handoff.
6. **The root disk (92%) is a standing incident** — every gigabyte matters; stale-cache trash list is the cheapest 13.5G available.

## f) NEXT (priority-ordered, brainstorm beyond ~10 is ROADMAP fuel)

1. Reboot decision + `nix run .#pre-reboot-check` + boot-path verification of journal-hot (the one unproven half).
2. Optional: re-run `sudo bash scripts/migrate-journal-hot.sh finalize` (fixed) for the official marker record.
3. Restore PSI gate to 20 / make it env-overridable.
4. Trash the stale cache list (~13.5G off the 92% QLC root).
5. Implement the cache mover (generic `hot-user-caches.dirs` module or one-shot script; symlink pattern, skip-live, `chattr +C` for sqlite-heavy targets).
6. Investigate `/mnt/hot/nix` root-level dir (Aug 17) — likely cruft from the first cache-migration attempt; trash after a peek.
7. Verify the `~/.cache/go-build → /nix/store/…` symlink (home-manager artifact) is intended; store targets are read-only.
8. Forgejo doctrine per Q3 answer (disko-declare + `migrate-forgejo-subvol.sh` + flip `dedicated`, or keep-on-QLC and delete the inert bootstrap design).
9. File the TODO_LIST row: one-time-migration modules gate (deferred from tonight).
10. Durable GC-eviction fix (gcroot the checks / keep-outputs / rescope nightly nix-gc) — recurs daily until done.
11. Real-build the hot-user-caches VM regression test.
12. Eval/build `tests/test-journal-hot.nix` (verify it exists and matches the shipped module).
13. Audit the daemon commits that rode tonight's deploys (777fa972, 31392dbf, 3c1b7fc1, dae3ee0a + the 00:2x-00:3x batch).
14. Read the parallel session's `2026-09-29_11-34_gatus-panic-notification-storm-incident.md`.
15. hermes-agent closure-version anomaly (0.21.4 → 0.0.0).
16. User: `inboxclean auth` (expired OAuth — last red unit).
17. Gatus alerts: stuck-systemd-jobs + boot-completion.
18. Fleet audit: `before=*.mount` orderings; mount-timeout on every automount fstab entry.
19. gatus-config.nix:673 rule fix.
20. Pool btrfs metadata balance (97.9% full metadata).
21. Root-disk cleanup plan beyond caches (QLC 92%).
22. docs-health HARVEST: the three 09-29/09-30 status reports.
23. Archive `/var/tmp` forensics (78M journal capture, PID 10158 stack) into docs/ before tmp cleanup.
24. Post-reboot: verify boot-ordering, then schedule the eventual QLC shadow-dir cleanup after a soak period.
25. Check `/run/log/journal` residual (dir re-created post-flush, 40B — verify empty, benign expected).
26. SigNoz GCP receiver go-live deploy (single remaining step per AGENTS.md) + dnsblockd post-deploy probe.
27. Run buildflow + `nix flake check --no-build` once the tree settles (GC-flap heal protocol if it bites).
28. Consider a "deploy gate" hook: refuse switch if any imported module matches `migrate-*.sh` unreferenced in its header (codify the doctrine).
29. `/mnt/hot` capacity watch once caches land there (790G free now; set a gatus threshold).
30. Revisit forgejo's stale `commit-graph.lock` files if the warnings persist across sync cycles.

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **Reboot tonight** (after `pre-reboot-check`) to prove the journal-hot boot path — or defer to a chosen window?
2. **Cache execution mode**: green-light the trash list + mover now — generic `hot-user-caches.dirs` module, or a one-shot script tonight (no new module)?
3. **Forgejo**: flip to the Samsung now (disko-declare + migrate + enable `dedicated`), later, or keep it on QLC permanently and delete the inert subvol design?

---

_Written as `.md` per explicit user instruction (canonical status-report format is HTML; override noted). Auto-commit daemon will sweep this file._
