# Status: Git Object Corruption Repair + Sync Completion

**Date:** 2026-09-15 11:42 CEST
**Scope:** This session only (10:24–11:00 CEST work + observations since). No unrelated research, per instruction.
**Repo state at writing:** `master` == `origin/master` (parity 0/0), `git fsck --full` zero errors, git-town reports "The previous Git Town command (sync) finished successfully."
**Format note:** `.md` written per explicit user instruction — status-report skill's canonical format is HTML; this is a sanctioned one-off override, not a new default.

---

## What this session was

Two chained jobs on `/home/lars/projects/SystemNix`:

1. **"fix"** — the repo was dead: every git command failed (`fatal: bad object HEAD`), git-town panicked (`branchesQuery` index-out-of-range). Root cause: the 09:33 reboot (boot -1 died **09:32:40**, journal-confirmed) tore the PMA auto-commit daemon's in-flight commit — 10 loose object files came back **0-byte** (page-cache data lost) while the loose ref + index metadata survived, because **git does not fsync loose objects by default**.
2. **git sync completion** — the user's `git sync` push was rejected (remote had moved). The remote commit turned out to be `4f0b9081` — the very sha this session had declared "permanently lost" during repair.

---

## a) FULLY DONE

| #  | Item                                        | Evidence                                                                                                                                                                                                                                                                                                                                                         |
| -- | ------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1  | Root cause identified with journal evidence | boot -1 last log 09:32:38 → boot 0 starts 09:36:59; object-file mtimes 09:32:11; PMA journal shows batch processing up to 09:32:38, no clean-shutdown sequence                                                                                                                                                                                                   |
| 2  | Pre-surgery backup taken                    | `/tmp/systemnix-git-backup-20260915-102536.tar.gz` (121 MB, full `.git`)                                                                                                                                                                                                                                                                                         |
| 3  | Repo repaired, zero data loss               | 10 zero-byte objects trashed (after backup); `master` repointed to reflog tip `689e6c10` via `update-ref -m`; lost blobs of the interrupted staging rebuilt **byte-exact** from the working tree (all 3 hashes matched the index shas); `git write-tree` rebuilt the lost root tree **byte-exact** (`0e45a87d…` — the exact sha the index cache-tree pointed at) |
| 4  | Repo health verified                        | `git fsck --full` zero errors; `git multi-pack-index verify` OK; `git stash list` intact (stash@{0} "Git Town WIP" valid); `git status`/`git log` fully functional                                                                                                                                                                                               |
| 5  | git-town panic eliminated                   | `git town branch` (exercises the exact `BranchesSnapshot` code path that panicked) runs clean                                                                                                                                                                                                                                                                    |
| 6  | Divergence resolved + push landed           | `git rebase --autostash origin/master` clean (our 3 commits replayed as `1c905994`, `f6cc888a`, `bd5b1aa6`; the 3 overlapping files were already-applied patches, auto-deduped); push `4f0b9081..cd256ad2` accepted; `git town continue` pushed the trailing daemon commit + tags                                                                                |
| 7  | git-town state machine closed               | `git town status` → "The previous Git Town command (sync) finished successfully."                                                                                                                                                                                                                                                                                |
| 8  | Prevention committed                        | `core.fsync = "loose-object,index"` in `platforms/common/programs/git.nix` (token validity probed via `git -c core.fsync=... status` before writing) — committed `17acfe3d`                                                                                                                                                                                      |
| 9  | Knowledge captured                          | New AGENTS.md section "Git zero-byte object corruption (boot death mid-commit, 2026-09-15)" with the 7-step runbook                                                                                                                                                                                                                                              |
| 10 | Mystery of the "lost" commit solved         | `4f0b9081` was real: parent `689e6c10`, same 3 files/+85/+6/+128 line counts as our reconstruction — the daemon had **pushed it seconds before the power cut**; only the local never-fsync'd copies died. This retroactively validates the fsync fix                                                                                                             |

## b) PARTIALLY DONE

| # | Item                                                       | Done                                                                                                                                                                                                                                                       | Missing                                                                                                                                                                                                                                                                 |
| - | ---------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1 | Torn-write protection (`core.fsync`)                       | Committed to the repo                                                                                                                                                                                                                                      | **NOT LIVE on the machine.** No `nix run .#deploy` has happened since — `~/.config/git/config` still lacks `fsync`, so the box is still exposed to the exact 09:32 failure mode until the next deploy. I failed to state this prominently in my closing message earlier |
| 2 | Pre-existing `checks.x86_64-linux.wifi-failover` red check | Root-caused (fails identically at pinned rev `689e6c10`, so it predates this session and is NOT from my one-line git.nix change); fix identified: `tests/test-wifi-failover.nix` must co-import `integration.nix` per the repo's own documented convention | Fix NOT applied — the area is actively owned by the parallel window-closeout session (integration.nix churn committed today); touching it risks the documented mid-edit race                                                                                            |
| 3 | Post-repair integrity                                      | fsck + midx + parity all verified at rest                                                                                                                                                                                                                  | The repair has never been exercised against a real recurrence — the true verification is the fsync config going live + a future crash surviving                                                                                                                         |
| 4 | Pre-surgery backup                                         | Taken and served its purpose                                                                                                                                                                                                                               | Sits on tmpfs `/tmp` — dies at next reboot; disposition (relocate vs trash) undecided                                                                                                                                                                                   |
| 5 | Repo hygiene                                               | fsck clean (only 4 dangling-object info lines)                                                                                                                                                                                                             | Dangling objects deliberately left (no `git gc` — cause of corruption was unknown at surgery time; prudence over cosmetics)                                                                                                                                             |

## c) NOT STARTED

| #  | Item                                                                                | Why it's on the list                                                                                                                                                                                                                                          |
| -- | ----------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1  | `nix run .#deploy` to land `core.fsync`                                             | The single highest-impact open item from this session                                                                                                                                                                                                         |
| 2  | Post-deploy verification of the rendered `~/.config/git/config`                     | Trust the delivery mechanism, not the intent                                                                                                                                                                                                                  |
| 3  | `tests/test-wifi-failover.nix` integration co-import fix                            | Blocks a fully green `nix flake check`                                                                                                                                                                                                                        |
| 4  | Full `nix flake check --no-build` green run                                         | Last full run stopped at wifi-failover; everything before it passed                                                                                                                                                                                           |
| 5  | HARVEST of section (f) into `TODO_LIST.md`/`ROADMAP.md`                             | Per status-report skill, (f) is the primary HARVEST input                                                                                                                                                                                                     |
| 6  | fsck sweep of OTHER repos under `~/projects`                                        | The 09:32 boot death was machine-wide — any repo with an in-flight git write at 09:32:40 could carry the same zero-byte objects (this repo is likely not the only one the daemon was touching; journal shows go-cqrs-lite + dnsblockd batches at 09:32:21–38) |
| 7  | macOS clone resync                                                                  | The Mac clone needs a sync to pick up the rebased history (user action or a session on that side)                                                                                                                                                             |
| 8  | Confirming whether THIS box's daemon pushed `4f0b9081` at 09:32 (vs. another clone) | Nice-to-have forensics closure; PMA journal + reflog sparseness suggest here, unconfirmed                                                                                                                                                                     |
| 9  | Global crush AGENTS cross-cutting lesson: "fetch first in corruption repairs"       | Currently only in this repo's AGENTS.md; the lesson is universal                                                                                                                                                                                              |
| 10 | This report committed                                                               | Deliberately not self-committed (harness forbids unprompted commits) — auto-commit daemon will sweep it                                                                                                                                                       |

## d) TOTALLY FUCKED UP (my own mistakes, no excuses)

1. **I misvalidated object existence with `git cat-file -e`.** It only stats the loose file — 0-byte files pass. My first check concluded "all index blobs intact" while fsck, in the SAME output window, was telling me 3 blobs were missing. One wasted diagnostic round, and the wrong conclusion briefly shaped my plan. The correct oracle (`git fsck --full`) was already in hand.
2. **I never fetched from origin during the repair.** The commit I reconstructed blob-by-blob and tree-by-tree sat on GitHub the whole time. `git fetch origin` at 10:30 would have restored `4f0b9081` in seconds and immediately revealed it had been pushed pre-death. My first closing message even told you the object was "**permanently lost**" — that claim was wrong, and the follow-up sync session proved it. Not a lie — a premature certainty I didn't hedge enough.
3. **I said "Hardening added" without saying it isn't live.** `core.fsync` is committed but undeployed; until the next `nix run .#deploy`, the machine remains exposed to the exact failure I claimed to have fixed. Understated risk in my own closing summary.
4. **I worked around git-town instead of through it.** Manual rebase + manual push left the town state dangling; clearing it took two extra `git town continue` rounds. The cleaner sequence was fetch → rebase → `git town continue` once.
5. **Small stuff:** backup tar went to volatile tmpfs (survived its purpose, zero durability); my final verification command chain exited 1 (grep -cv with zero matches) presented without comment; the wifi-failover red check cost three full `nix flake check` evaluation runs (~5 min each) before I pinned the blame with the targeted rev-pinned eval — the cheap probe should have been my FIRST move, not my third.

## e) WHAT WE SHOULD IMPROVE

1. **Corruption-repair doctrine: fetch FIRST.** The remote is a free, consistent super-copy of everything ever pushed. Any repair session should fetch before touching anything local. Now in this repo's AGENTS.md runbook implicitly — should be step 0 explicitly.
2. **One validity oracle: `git fsck`, never `cat-file -e`.** Encode it wherever git health is probed.
3. **Config changes need a "is it live?" gate.** The fsync change has no post-deploy verification step yet (grep the rendered git config). Several existing guards in this repo exist precisely because agents claimed victory on intent instead of delivery.
4. **Consider a small eval/check that renders the HM git config and asserts `fsync = loose-object,index`** — protects against silent regression of the fix.
5. **git-town discipline:** when a town command is mid-flight, finish it with town verbs; manual git surgery on a live town state leaves dangling state.
6. **Backup durability convention:** pre-surgery snapshots of `.git` belong on durable scratch (`/mnt/buildcache` or pool), not tmpfs.
7. **Cheap-probe-first triage:** pin-point evals (rev-pinned, single check) before whole-flake checks when triaging one red gate.
8. **Machine-wide blast radius checks:** a boot death mid-write is not a single-repo event; a fleet-wide fsck sweep across `~/projects` after any hard power-off should be reflexive.

## f) Up to 50 things we should get done next

Sorted by impact. Items 1–10 are the real queue; 11+ are brainstorm-grade (ROADMAP fuel, apply HARVEST routing rigor).

1. **Deploy** (`nix run .#deploy`) — lands `core.fsync` + today's committed work; check the deploy pressure gate first (parallel session mentions a 13h IO storm / freeze-5).
2. **Verify fsync landed:** `grep fsync ~/.config/git/config` → `fsync = loose-object,index`.
3. **Fix `tests/test-wifi-failover.nix`** (co-import `integration.nix`) — coordinate with the parallel session first.
4. **Get `nix flake check --no-build` fully green** after 3.
5. **fsck sweep all repos in `~/projects`** for 09:32-era zero-byte objects (same boot death, other victims possible).
6. **HARVEST this report's section (f)** into `TODO_LIST.md` (docs-health skill).
7. **Decide backup-tar disposition:** relocate to durable scratch or trash (local == origin now).
8. **Confirm PMA cooldown-state health** post-reboot (its 09:32:38 `rename failed` WARN predates the death — verify no residue).
9. **Post-deploy, verify one fresh daemon commit writes fsync'd objects** (strace or filesystem-level spot check) — prove the fix end-to-end.
10. **Update AGENTS.md runbook:** make "fetch origin first" explicit step 0; soften "permanently lost" phrasing to "lost locally (check remote)".
11. Mirror the corruption runbook lesson into the GLOBAL crush AGENTS.md cross-cutting lessons.
12. Evaluate extending `core.fsync` to `references` (loose refs) after a quick docs check.
13. Add the HM git-config render assertion check (see e.4).
14. Confirm whether the pre-commit hook chain actually runs `nix flake check` for daemon commits (it committed twice during a red check — bypass? `--no-verify` in go-commit? Verify and document).
15. Decide whether the wifi-failover red check pattern generalizes: audit ALL VM tests against the "mkIf-wrapped integration def" class with a scripted grep.
16. Resync the macOS clone (rebased history + new commits).
17. Forensics closure: determine whether `4f0b9081` was pushed from this box at 09:32 (PMA journal/git reflog of the push moment) or from another clone.
18. Sweep dangling git objects in this repo at a quiet moment (cosmetic).
19. Verify today's pushes didn't trip GitHub push protection / secret scanning on the new docs/status files.
20. Sanity-build the toplevel once after the flake.lock churn (`5741c9e5` added the nix-email input) — eval passed, full build not run this session.
21. When the nix-email session finishes: verify `modules/nixos/services/nix-email.nix` + `tests/test-nix-email.nix` pass their own gates (new module, only eval-coexistence verified here).
22. After next reboot, confirm flm/fastflowlm state is clean (the 09:33 boot was the "owed" reboot; freeze-5 doc suggests trouble since).
23. Check the staged-but-uncommitted freeze-5 doc + test files get swept by the daemon (they were mid-flight at last check).
24. Consider `core.fsyncMethod=batch` research (throughput vs durability tradeoff for the daemon's commit cadence).
25. Add "one validity oracle" + "fetch first" to the repo's CONTRIBUTING eval-guard docs if git-health checks ever get scripted.
26. Post-deploy: open new terminal (house rule for shell changes).
27. Record in docs/gotchas-archive.md the full incident narrative (AGENTS.md has the short runbook; the archive wants the long story).
28. Verify `git town status`/undo window needs nothing further (currently clean; revisit only if another town command starts).
29. Cross-check that no OTHER machine's clone holds refs to objects missing on origin (Mac clone `git fsck` when convenient).
30. Longer-term: consider a machine-level `git config` NixOS/HM assertion suite so global git hygiene (fsync, insteadOf traps, GOTOOLCHAIN guards) is tested, not remembered.

## g) Questions I cannot figure out myself

1. **The wifi-failover test fix — mine or theirs?** Is the window-closeout/parallel session actively owning `tests/` + `integration.nix` right now (its freeze-5 doc and test-nix-email.nix edits suggest yes), or should I apply the one-line co-import fix as soon as the tree is quiet?
2. **Deploy window:** given the parallel session's freeze-5 / 13h IO-storm findings, when is it safe to run `nix run .#deploy` to land the fsync hardening — now, or after the storm situation is understood?
3. **Backup tar:** keep `/tmp/systemnix-git-backup-20260915-102536.tar.gz` by relocating it somewhere durable, or is it disposable now that local and origin are identical?

---

**Waiting for instructions.**
