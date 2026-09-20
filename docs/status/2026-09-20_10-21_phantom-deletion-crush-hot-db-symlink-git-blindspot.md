# Status: Phantom Deletion of `.crush/skills/sops-secret-management/SKILL.md`

**Point-in-time:** 2026-09-20 10:21 CEST
**Scope:** This session only (per instruction). One investigation: "Why did the sops skill get deleted?" — plus anomalies noticed on the way.
**Bottom line:** Nothing was deleted from disk. The `crush-hot-db` migration symlinked `.crush` → `/mnt/hot/crush/SystemNix`; git cannot see through symlinks during its worktree scan, so both tracked files under `.crush/` appeared as worktree deletions, and the auto-commit daemon committed the phantom into `f0f9f9f0`. Content is byte-identical on the hot disk. Version control lost the files; disk did not.

---

## The Incident Chain (evidence-backed)

1. `crush-hot-db-migrate` (deployed 2026-09-16, first full pass ran today) executed its designed final step (`crush-hot-db.nix:176`): `mv .crush /mnt/hot/crush/SystemNix && ln -s <target> .crush`. The symlink is `root:root`, timestamps indicate 04:53.
2. Git's worktree scan does NOT follow symlinked directories. strace proof: `newfstatat(AT_FDCWD, ".crush", {st_mode=S_IFLNK|0777, ...}, AT_SYMLINK_NOFOLLOW) = 0` — one syscall, no descent, so every indexed path under `.crush/` is "missing" → ` D` for both tracked files.
3. The auto-commit daemon (or the parallel status-docs session's commit) swept both phantom deletions into `f0f9f9f0` ("docs(status): log geometrikks storm-watch sessions, roadmap DNS-registry item" — the message does not mention them).
4. `cmp` proved both on-disk files (now under `/mnt/hot/crush/SystemNix/`) byte-identical to their pre-deletion HEAD versions. `git ls-files --debug` showed the index still carrying pre-migration stat data (`dev: 36 ino: 2715628232` vs actual `dev: 38 ino: 2425`).
5. Runtime impact: none — crush reads/writes its DB and skills through the symlink fine. The skill still *loads*; it just fell out of version control.

**Design gap:** `crush-hot-db.nix` has no guard for repos that track files under `.crush/` (skip conditions are only: live crush session, lock contention, already-migrated, fresh DB write, target-exists). SystemNix is exactly such a repo. Any git-side restore without the module fix gets re-symlinked at the next run/boot/deploy and re-deleted by the daemon.

---

## a) FULLY DONE

| Item | Evidence |
| --- | --- |
| Root cause diagnosed to syscall level (symlink + git NOFOLLOW worktree scan) | strace: `newfstatat(".crush") → S_IFLNK`; `readlink .crush` → `/mnt/hot/crush/SystemNix` |
| Data-loss ruled out | `git show HEAD:<file> \| cmp - <file>` → IDENTICAL for both files; copies alive at `/mnt/hot/crush/SystemNix/` |
| Carrier commit identified | `git log --stat -- .crush/` → `f0f9f9f0` carries both deletions (129 lines) |
| Module design gap located | `crush-hot-db.nix:176` `mv && ln -s`; no tracked-files skip condition (grep of all skip branches) |
| Fix path proposed, decision requested from owner | Previous message; three design options drafted |
| This report | `docs/status/2026-09-20_10-21_*.md` |

## b) PARTIALLY DONE

| Item | Works | Missing | Blocker | Effort |
| --- | --- | --- | --- | --- |
| Incident handling (overall) | Diagnosis 100% | Remediation 0% (module guard, un-symlink, git restore) | Design decision (Q1/Q2) + quiet window (live crush session writing the 3.4 GB DB through the symlink) | M |
| Class-surface assessment | SystemNix confirmed affected | `~/projects` has dozens of repos; none checked for tracked files under `.crush/`, none checked for phantom-deletion commits | Nothing — pure sweep work | S |
| "Skill still loads at runtime" | Inferred (file present through symlink, crush running) | NOT verified in a fresh crush session (assert-which-entity rule) | None | S |
| Exact migration timeline | Symlink mtime says 04:53; some mid-session reads were internally inconsistent (early `ls` showed `.crush/skills` as a real dir, later `readlink` showed symlink) | Second-level timeline not pinned from `journalctl -u crush-hot-db-migrate`; unclear whether the pgrep guard saw the live session at swap time | None | S |

## c) NOT STARTED

1. Guard in `crush-hot-db.nix` (blocked on Q1 design decision)
2. Un-symlink `.crush` / restore real dir (blocked on Q1 + quiet window)
3. Git restore of `.crush/.gitignore` + `SKILL.md` as a follow-up commit (no history rewrite) (blocked on Q2)
4. Fleet sweep of other repos for the same class
5. AGENTS.md write-back of the incident (should NOT have waited — see d-4/e-2)
6. `corrupt 12` triage on the hot disk (noticed, deliberately not researched per instruction — Q3)
7. Pending first-migration verification from AGENTS.md (symlink sweep + `node_psi_io_some_avg60` vs 40-60% baseline) — now unblocked, still undone
8. Regression test for the guard (`tests/test-crush-hot-db.nix` tracked-file fixture)

## d) TOTALLY FUCKED UP

1. **The sops skill is deleted from git HEAD.** `f0f9f9f0` removed `.crush/.gitignore` + `SKILL.md` (129 lines). Severity: every fresh clone loses the project-level sops skill that project AGENTS.md references; the deletion sits in history wearing an unrelated commit message. Root cause: known (above). Mitigation: byte-identical copies verified on the hot disk; restore is a trivial follow-up commit once the symlink is handled.
2. **The same class is silently armed across the fleet.** Any `~/projects` repo whose `.crush/` was migrated AND which tracks files under `.crush/` will lose them to its auto-commit daemon the same way. No detection exists anywhere (pre-commit, CI, daemon). Severity: potentially widespread silent VCS loss; nothing has fired because nobody looked.
3. **Phantom deletions are indistinguishable from real ones.** `git status` ` D` under a symlinked dir looks exactly like a human deletion to every existing guard. The daemon will re-delete any restore until the module guard exists — git-side-only fixes are booby-trapped.
4. **My process fuckup: no memory write-back.** The aggressive-update protocol says write AGENTS.md at the moment of discovery. I discovered a new durable gotcha class (git worktree scan vs symlinked subtrees; strace `newfstatat … NOFOLLOW` as the one-shot diagnostic) and wrote nothing — a crash before this report would have lost the entire diagnosis. Additionally I asserted "the skill still works at runtime" without verifying it.
5. **My efficiency: theorized for ~5 tool rounds before using strace.** The decisive evidence was one syscall trace taken at round ~7. Earlier signals I under-weighted: the conversation-start env snapshot already showed the deletions; AGENTS.md documents the migration as "deployed but first run not yet done" — the migration should have been suspect #1 the moment I saw `.crush` anomalies. Also misread one `ls` output (symlink shown as dir) and burned a round on the contradiction instead of running `readlink` immediately.

## e) WHAT WE SHOULD IMPROVE

1. **lstat/readlink-first doctrine:** any "file exists but a tool disagrees" anomaly on this box gets `readlink` + `strace -e newfstatat` in the FIRST diagnostic batch, not the last. Cost of not having it: ~5 wasted rounds.
2. **Memory at discovery, not at report time.** Concrete: the AGENTS.md gotcha entry ships in the same commit as the module fix, before anything else.
3. **Deletions must never ride an unrelated commit message.** `f0f9f9f0` deleted 129 tracked lines under a "docs(status)" title (same family as the 2026-08-18 daemon secret-in-message lesson). Concrete: pre-commit guard that rejects staged deletions of tracked paths whose worktree ancestor is a symlink (plus: commit bodies should enumerate deletions).
4. **Migration observability.** The first full migration run happened today and NOTHING noticed — a git anomaly did. Concrete: journal line + textfile metric (`crush_hot_db_migrated_projects_total`, last-run timestamp) + Gatus presence check, same pattern as pool-recovery.
5. **Design principle to encode upstream-able:** never replace a directory containing VCS-tracked files with a symlink over its original path (same class as Jan's path-guard and the wallpaper dangling-pointer lessons). The migration's skip logic should test `git ls-files`, not assume session dirs are untracked.

## f) Top 50 Next Tasks (brainstorm — harvest with rigor; >25 are ROADMAP fuel)

| # | Task | Impact | Effort | Category |
| --- | --- | --- | --- | --- |
| 1 | Decide migration fix design (skip-if-tracked vs symlink-only-untracked vs per-repo exclude) — Q1 | Critical | S | Bug |
| 2 | Implement guard in `crush-hot-db.nix`: skip when `git ls-files <proj>/.crush/` non-empty, journal the skip | Critical | S | Bug |
| 3 | OR: symlink-only-untracked mode — real `.crush` dir for tracked files; symlink `crush.db`/`-wal`/`-shm`/`logs/` individually | Critical | M | Bug |
| 4 | Un-symlink SystemNix `.crush` at a quiet window (pgrep-verified, no live crush) | Critical | S | Bug |
| 5 | Restore `.crush/.gitignore` + `SKILL.md` to git via follow-up commit (no history rewrite) | Critical | S | Bug |
| 6 | Verify restore byte-parity vs the `c1a6fd60`-era blobs (`git diff <rev> -- .crush/` empty) | High | S | Quality |
| 7 | Fresh crush session: verify the sops skill triggers/loads post-restore | High | S | Quality |
| 8 | Sweep all local git repos: `git -C <repo> ls-files .crush/` — build affected-repos list | Critical | S | Bug |
| 9 | For each affected repo: `git log --diff-filter=D -- .crush/` to find phantom-deletion commits | Critical | M | Bug |
| 10 | Restore any phantom-deleted files found in other repos | Critical | M | Bug |
| 11 | Pin the exact migration timeline from `journalctl -u crush-hot-db-migrate`; confirm whether the pgrep guard saw the live session at swap time | Medium | S | Quality |
| 12 | Verify the stale `.git/index.lock` (00:06) is gone and the daemon is healthy post-`f0f9f9f0` | Medium | S | Quality |
| 13 | Audit `f0f9f9f0`'s FULL stat — what else rode that commit besides the deletions + status docs | High | S | Quality |
| 14 | Write the incident into project AGENTS.md (git-symlink worktree-scan gotcha + strace diagnosis) | High | S | Documentation |
| 15 | Add cross-cutting lesson to global AGENTS.md if judged universal | Medium | S | Documentation |
| 16 | Extend `tests/test-crush-hot-db.nix`: fixture repo WITH a tracked `.crush` file, assert the skip | High | M | Quality |
| 17 | Pre-commit guard: reject staged deletions of tracked paths under a symlinked ancestor | Medium | M | Quality |
| 18 | Daily detector across `~/projects`: flag ` D` status entries that resolve under symlinks (early warning) | Medium | M | Quality |
| 19 | Triage `corrupt 12` on `nvme1n1p2`: scrub + static-vs-growing csum discriminator (Q3) | High | M | Bug |
| 20 | Run the pending first-migration verification: `find ~/projects -name .crush` (no `-type d`) + IO-PSI vs 40-60% baseline | High | S | Quality |
| 21 | Confirm btrbk behavior on the new symlink (`@` snapshots carry the link, not 3.4 GB; no EIO) | Medium | S | Quality |
| 22 | Capacity check: total crush.db+WAL across all projects vs Samsung 1TB budget | Medium | S | Quality |
| 23 | Verify ownership/permissions across migrated trees (seen `lars:users`; hunt root-owned stragglers) | Medium | S | Quality |
| 24 | Decide deploy order: hold remaining unmigrated projects until the guard lands? | High | S | Bug |
| 25 | Re-verify deploy.sh provisioner restart semantics for `crush-hot-db-migrate` after the module change (deploy-restart-audit will enforce) | Medium | S | Quality |
| 26 | Add migration observability: journal line + `crush_hot_db_migrated_projects_total` metric + Gatus check | Medium | M | Feature |
| 27 | Document the tracked-files caveat in the crush-hot-db runbook/docs section | Medium | S | Documentation |
| 28 | Grep SystemNix history for EARLIER phantom deletions under `.crush/` (partial migration runs predate today) | Medium | S | Bug |
| 29 | Full narrative into `docs/gotchas-archive.md` with the strace/readlink evidence | Medium | S | Documentation |
| 30 | Check crush upstream: does skill discovery handle a symlinked `.crush`? File issue if not | Medium | M | Bug |
| 31 | Verify the sops skill loads through the symlink in a fresh session even BEFORE restore (runtime parity proof) | Medium | S | Quality |
| 32 | One-off audit: any other tracked paths in this repo resolving under a symlinked ancestor (generic script) | Medium | M | Quality |
| 33 | Review other dir-symlink migrations (e.g. `@home-hermes`) for tracked-file exposure | Low | S | Quality |
| 34 | Confirm `/mnt/hot` mount health post-migration (findmnt + device stats, besides #19) | Medium | S | Quality |
| 35 | Verify no half-migrated leftovers in the repo (`ls -la .crush*`; orphaned partial copies) | Low | S | Cleanup |
| 36 | Decide the fate of `.crush/commands/` + `init` (empty cruft since 2025-04) | Low | S | Cleanup |
| 37 | `git fsck --full` after the restore to confirm a clean object graph | Low | S | Quality |
| 38 | Update TODO_LIST.md via docs-health HARVEST from this report's section (f) | High | S | Documentation |
| 39 | Sync docs/todo/stability.md: first migration has now RUN (freeze-6 follow-up state changed) | Medium | S | Documentation |
| 40 | Post-deploy smoke addition: assert `.crush` resolution state (symlink vs dir) matches module intent | Medium | S | Quality |
| 41 | Watch WAL/checkpoint behavior through the symlink for a day (perf parity proof) | Medium | S | Quality |
| 42 | Check QLC root space delta post-migration (~3.4 GB+ frees as snapshots expire) | Low | S | Quality |
| 43 | Document git-version invariant (worktree scan is NOFOLLOW) with upstream citation | Low | S | Documentation |
| 44 | Batch the quiet-window ops (#4, #5, #24) into one deploy | Medium | S | Process |
| 45 | If design (3) chosen: rename/redocument the unit to reflect symlink-only scope | Low | S | Cleanup |
| 46 | Confirm nothing else in `f0f9f9f0` needs reverting beyond the `.crush` deletions | High | S | Quality |
| 47 | Add the "deletions enumerate in commit body" rule to the repo's commit conventions | Medium | S | Process |
| 48 | Consider making the sops skill location migration-proof regardless (Q2 follow-through) | Medium | S | Feature |
| 49 | Verify skill-file symlinks elsewhere (user-level `~/.config/crush/skills/` fan-out unaffected) | Low | S | Quality |
| 50 | After fix deploys: re-run this session's strace probe as the acceptance test (`.crush` must lstat as dir for git OR guard must skip) | High | S | Quality |

## g) Top 3 Questions I Cannot Answer Myself

1. **Fix design (Q1):** Should the migration (a) skip any repo that tracks files under `.crush/` — which puts SystemNix's 3.4 GB session DB back on the QLC root and re-arms the IO-storm class, (b) symlink ONLY the untracked heavy entries (`crush.db`, `-wal`, `-shm`, `logs/`) while tracked files stay in a real dir — keeps the IO fix and git honest, or (c) something else? I tried inferring from AGENTS.md (it defers to the ratified Phase-2 `services.hot-db` module) but the design call is yours.
2. **Skill location (Q2):** Should `sops-secret-management` stay git-tracked under `.crush/skills/` (I restore it there and we guard the migration), or should it relocate so `.crush/` can be fully untracked? Moving it means updating the project AGENTS.md reference and the skill's declared location — I can't decide the ownership/layout preference.
3. **Hot-disk corruptions (Q3):** The 04:16 boot's kernel log shows `bdev /dev/nvme1n1p2 errs: wr 0, rd 0, flush 0, corrupt 12` on the Samsung hot disk — the disk now hosting every project's session DB. Do you already have triage context on these 12 checksum corruptions (static vs growing), or should I open it as a P0 investigation? (I was instructed not to research unrelated items this session, so I only flagged it.)

---

*Report by this session only, per instruction. No commits made (harness forbids; the daemon will pick this file up).*
