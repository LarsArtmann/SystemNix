# Status Report: Git compression config audit & cleanup

**Date:** 2026-08-11 12:27 CEST
**Session focus:** Audit git compression/gc configuration in `platforms/common/programs/git.nix`, identify overly aggressive settings, fix them, verify.
**Working tree:** `platforms/common/programs/git.nix` (10 deletions), `FEATURES.md` (1 edit). Formatter also reformatted `flake.nix` (unrelated).
**Head commit:** `3f488ccf` — `docs(status): add 2026-08-11 project-meta follows cleanup self-review`

---

## a) FULLY DONE

1. **Comprehensive search of git compression/gc config across the entire codebase.**
   - Used sub-agent to search all `.nix`, `.sh`, `.yml`, `.md` files for: `compression`, `gc.auto`, `packedGitLimit`, `packedGitWindowSize`, `core.compression`, `pack.compression`, `gc.aggressive`, `git config`, `.gitconfig`.
   - Found ALL git config lives in a single file: `platforms/common/programs/git.nix` (Home Manager managed, 100% declarative — confirmed by `docs/status/archive/2026-01-14_04-13_GIT-CONFIG-MIGRATION-COMPLETE.md`).
   - No standalone `.gitconfig` files, no imperative git config, no systemd git-gc timers.

2. **Identified and removed `core.compression = 9`** (git.nix:23).
   - Level 9 is max zlib compression, applied to EVERY loose object write (`git add`, `git commit`, `git stash`, `git write-tree`).
   - 3-10x CPU overhead for ~5% smaller objects that are temporary (repacked by `git gc` anyway).
   - Removed → reverts to git default (-1, which is zlib level 6 — good speed/size balance).

3. **Identified and removed `packedGitLimit = "512m"` and `packedGitWindowSize = "512m"`** (git.nix:24-25).
   - These are NOT compression settings — they control mmap window size for reading pack files.
   - `packedGitWindowSize = "512m"` is **512x the default** (1 MiB). No measured benefit; cargo-cult tuning.
   - `packedGitLimit = "512m"` is **16x the default** (32 MiB).
   - Removed → reverts to git defaults (32m / 1m).

4. **Identified and removed dead `gc` block** (git.nix:72-77).
   - All four values were git's **exact built-in defaults**: `auto = 6700`, `autopacklimit = 50`, `autodetach = true`, `pruneexpire = "2 weeks ago"`.
   - Dead config = false confidence. Removed entirely.

5. **Updated FEATURES.md** — removed "max compression" from the Git feature description (line 143).

6. **Verified with `nix flake check --no-build`** → `all checks passed!`

7. **Ran `nix fmt`** — formatted correctly (formatter also reformatted `flake.nix` as a side effect — see section d).

---

## b) PARTIALLY DONE

1. **Communicating the full scope of `core.compression` removal.**
   - **What I did:** Said "every interactive git operation will be faster."
   - **What I should have said:** `core.compression` is the default for BOTH loose objects AND pack files (when `pack.compression` is not separately set). Removing it changes pack compression from level 9 to zlib default (6) too. This affects `git gc`, `git repack`, `git push`, and `git fetch`. The impact is broader than just loose objects.
   - **Why it matters:** The user should know that push/fetch/gc behavior also changed, not just local commits.
   - **Blocker:** None — just a communication gap.

2. **Explaining what happens to existing repositories.**
   - **What works:** New objects written after deploy use zlib level 6.
   - **What remains:** Existing packs compressed at level 9 stay at level 9 until `git gc` or `git repack` runs. Old packs take slightly more CPU to decompress on `git log`, `git diff`, `git cat-file` until repacked.
   - **Blocker:** None. `gc.auto = 6700` (now relying on git default) will eventually repack naturally.
   - **Estimated effort:** Zero — automatic. But user could force it with `git repack -a -d` in large repos if they want immediate read-time improvement.

---

## c) NOT STARTED

1. **Add a comment in `git.nix` explaining WHY compression settings were removed.**
   - Without context, a future maintainer (or AI) may re-add `core.compression = 9` thinking it's an optimization. A comment like `# Deliberately NOT setting core.compression — git default (zlib 6) is the right speed/size tradeoff` would prevent regression.

2. **Consider `pack.compression` explicitly.**
   - If the user wants max compression on packs (long-term storage / network transfer) but fast loose objects, they could set `pack.compression = 9` separately while leaving `core.compression` at default. Not discussed.

3. **Check per-repo `.git/config` overrides.**
   - If any repo has local `core.compression = 9`, removing the global HM setting won't help there. Not checked.

4. **Consider `git maintenance` scheduling.**
   - Git 2.55 has `git maintenance start` / `git maintenance run --scheduled` which is more modern than `gc.auto`. Could register repos for background maintenance. Not evaluated.

5. **Evaluate `gc.bigPackThreshold` / `gc.bitmapPrefix`.**
   - Other gc tuning knobs exist that might be more impactful than what was removed. Not evaluated.

6. **Revert or keep formatter-introduced `flake.nix` reformat.**
   - `nix fmt` reformatted `flake.nix` (554-line reindentation — `inputs @ {` → `inputs@{`, etc.). This is unrelated to the git compression task. User should decide whether to keep or revert.

---

## d) TOTALLY FUCKED UP!

1. **Running `nix fmt` reformatted `flake.nix` (554 lines) — an unrelated change.**
   - Severity: Low-medium. The formatting change is legitimate (alejandra style normalization), but it's **unrelated to the git compression task** and pollutes the working tree.
   - Root cause: `nix fmt` runs treefmt across the entire repo. It found pre-existing formatting drift in `flake.nix` and corrected it. I ran it as a "verify formatting" step without anticipating side effects on unrelated files.
   - **What I should have done:** Either (a) not run `nix fmt` at all (the edits were clean), or (b) run it and immediately noted the side effect, or (c) staged only my files (`git add platforms/common/programs/git.nix FEATURES.md`) before formatting.
   - Mitigation: The `flake.nix` change is harmless formatting. But it should be a separate commit, not mixed with the git config change.

2. **I was slightly hyperbolic about the memory settings being "dangerous."**
   - `packedGitLimit` controls mmap window size for pack files, NOT heap allocation. On a 128GB RAM machine (evo-x2), 512 MiB mmap window is not "dangerous" — it's just unnecessary. On the Mac (24GB), it's still fine because mmap is lazy.
   - I said "can cause memory pressure and swapping" which is technically possible but unlikely at these values. The real critique is: **no measured benefit, cargo-cult config**.
   - Lesson: Be precise about what settings actually do before characterizing them.

3. **I didn't mention `core.compression` also affects pack compression.**
   - My analysis said "every loose object write" but `core.compression` is also the default for `pack.compression` when the latter isn't set. So removing it affects `git gc` / `git push` / `git fetch` compression too. I under-communicated the scope.
   - This isn't a bug — the change is still correct — but the user deserved the full picture.

---

## e) WHAT WE SHOULD IMPROVE!

1. **Add explanatory comments when removing "optimization" settings.** Future maintainers will re-add them without understanding why they were removed. Comments are the only defense against configuration regression.

2. **Run `nix fmt` on specific files, not the whole repo, during focused tasks.** Or stage intended files first. Running treefmt across 1534 files during a 2-file task is asking for unrelated diff pollution.

3. **Be precise about what git settings actually do before characterizing them.** "Dangerous" implies risk of harm; "unnecessary" is the accurate characterization for `packedGitLimit`/`packedGitWindowSize`.

4. **Always explain the full blast radius of a setting.** `core.compression` affects both loose objects AND packs. Saying "loose objects" was incomplete.

5. **Consider `pack.compression` as a separate knob from `core.compression`.** They serve different purposes: loose objects are ephemeral (want speed), packs are persistent/transferred (can afford compression). The right config might be: default loose compression + explicit pack compression.

6. **Check the git version before recommending defaults.** Git 2.55 may have different default behavior than the git version when these settings were originally added. (Verified: git 2.55.0 on this system.)

---

## f) Up to 50 things we should get done next

### Direct follow-ups from this session
1. Add a comment in `git.nix` explaining why compression was removed (prevent regression)
2. Decide whether to keep or revert the `flake.nix` formatter reformat (554-line change)
3. Check per-repo `.git/config` files for local `compression = 9` overrides
4. Consider explicitly setting `pack.compression` if max pack compression is desired
5. Run `git repack -a -d` on large repos (SystemNix, DiscordSync) to decompress old level-9 packs

### Git config improvements
6. Evaluate `git maintenance` (git 2.55) as a replacement for `gc.auto` heuristics
7. Consider `core.preloadIndex = true` (parallel index operations — big speedup on SSDs)
8. Consider `core.fsync.objectFiles = true` (crash safety for important repos — costs speed)
9. Consider `index.threads = true` (multi-threaded index operations)
10. Consider `feature.manyFiles = true` for repos with 100k+ files
11. Consider `fetch.writeCommitGraph = true` (faster `git log --graph` after fetch)
12. Consider `gc.writeCommitGraph = true` (faster commit graph traversal)
13. Evaluate `core.untrackedCache = true` (speeds up `git status` on large repos)
14. Consider `pack.threads` setting (default is CPU count — verify it's optimal)
15. Consider `protocol.version = 2` (default in 2.55, but verify)

### Config hygiene across the codebase
16. Audit other Home Manager config files for dead defaults (settings that match upstream defaults)
17. Run a "dead config" sweep on all `platforms/common/programs/*.nix` files
18. Audit `http.postBuffer = 524288000` (500MB — is this still needed? Was for large pushes)
19. Audit `submodule.fetchJobs = 8` (is 8 optimal for the hardware?)
20. Check if `credential.helper` libsecret works correctly on NixOS (known to be flaky)

### Process improvements
21. Add a pre-commit or CI check that flags git config settings matching git defaults (dead config detection)
22. Create a "config audit" script that diffs HM-managed config against upstream defaults
23. Add `nix fmt` as a targeted step in the deploy script (not whole-repo)

### Documentation
24. Update AGENTS.md if it references git compression (checked — it does not, but worth confirming)
25. Document the git config philosophy in a `docs/` page (why defaults are preferred over tuning)
26. Update `docs/status/archive/2026-07-30_15-53_git-insteadOf-restore.md` which incorrectly says `gc.auto = 6700` is "slightly lower than the default 6700" — it IS the default

### Broader SystemNix improvements (noticed during this session)
27. The `signoz.nix` file has uncommitted changes (`background_pool_size`, `max_threads`) — these need to be committed or investigated
28. The `security-hardening.nix` file has pre-existing uncommitted changes — investigate
29. `flake.nix` formatting drift suggests `nix fmt` hasn't been run recently on the full repo — consider a CI formatting check
30. Consider adding `alejandra` to pre-commit hooks (if not already) to catch formatting drift before commit
31. The `docs/status/archive/` vs `docs/status/archived/` directory split is confusing — consider consolidating

---

## g) Questions I CANNOT figure out myself

1. **Do you want to keep the `flake.nix` formatter reformat (554-line style normalization) or revert it?** It's unrelated to the git compression task. I caused it by running `nix fmt` on the whole repo. Keeping it is harmless but pollutes the git diff for this task.

2. **Do you want `pack.compression` set explicitly?** Removing `core.compression = 9` means BOTH loose objects and packs revert to zlib level 6. If you want to keep aggressive pack compression (for smaller network transfers and long-term storage) while letting loose objects be fast, I should add `pack.compression = 9` as a separate setting.

3. **Should I add a comment in `git.nix` documenting why these settings were removed?** Without a comment, a future session may re-add `core.compression = 9` as an "optimization." I recommend adding `# Deliberately NOT set — git default (zlib 6) is optimal for speed/size tradeoff` but didn't want to add comments without your approval.
