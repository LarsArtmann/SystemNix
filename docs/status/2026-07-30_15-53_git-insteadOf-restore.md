# Status Report: `git insteadOf` Restore — AGENTS.md Update

**Date:** 2026-07-30 15:53
**Session Duration:** ~3 minutes
**Trigger:** User request: *"Bring my fucking GitHub/LarsArtmann insteadOf for https to ssh for back!"*

---

## TL;DR

Restored the `url."git@github.com:".insteadOf = "https://github.com/"` rule in `platforms/common/programs/git.nix` that was removed on 2026-07-29, and updated the AGENTS.md gotcha entry to reflect the new state (warned-but-present, not removed). Verified eval succeeds and the rule renders correctly in the Home Manager git config. **No deploy performed** — user did not request one.

---

## Work This Session

### a) FULLY DONE

| # | Item | Status |
|---|------|--------|
| 1 | Added `url."git@github.com:".insteadOf = "https://github.com/"` to `platforms/common/programs/git.nix` (after `credential.helper` block) | ✅ |
| 2 | Documented `"FIXED 2026-07-29"` status in AGENTS.md gotcha → rewrote to `"restored on user demand 2026-07-30"` with `GIT_CONFIG_GLOBAL=/dev/null` workaround | ✅ |
| 3 | Verified `nix flake check --no-build` passes (all NixOS modules) | ✅ |
| 4 | Verified `nix eval .#nixosConfigurations.evo-x2.config.home-manager.users.lars.programs.git.settings` renders the rule at the right nesting (`url."git@github.com:".insteadOf = "https://github.com/"`) | ✅ |
| 5 | Confirmed no Darwin-specific git config exists that would need a parallel update (`platforms/darwin/programs/` only has `chrome.nix` + `shells.nix`) | ✅ |

### b) PARTIALLY DONE

| # | Item | Status |
|---|------|--------|
| 1 | The `git.nix` change is **committed** (commit `502020e7` from auto-commit daemon) but the AGENTS.md rewrite is **NOT yet committed** — `git status` shows `M AGENTS.md` unstaged | ⚠️ |

### c) NOT STARTED

| # | Item | Reason |
|---|------|--------|
| 1 | Deploy to either evo-x2 or Lars-MacBook-Air | User did not request a deploy; only the config change |
| 2 | Test whether any in-flight `nix flake lock` operations are affected | No flake update was run |
| 3 | Audit all LarsArtmann repo `flake.lock` files for SSH URL pollution | Out of scope for this minimal request |

### d) TOTALLY FUCKED UP

**Nothing broken.** The change is an additive restore of a previously-removed config rule. No existing functionality was altered. The 2026-07-29 removal was a clean diff; the 2026-07-30 restore is a clean re-addition.

### e) WHAT WE SHOULD IMPROVE

| # | Improvement |
|---|-------------|
| 1 | **Consider a global `gitConfigScope`** that scopes the `insteadOf` rule to user-remotes only (e.g., `url.git@github.com:.insteadof=https://github.com/LarsArtmann/`). This would rewrite only your own orgs, leaving external `github.com/X` URLs untouched — eliminates the flake.lock pollution entirely. The current rule is too broad. |
| 2 | Add a pre-commit hook (or pre-`flake update` script) that warns when `flake.lock` ends up with `ssh://git@github.com/` URLs and offers to convert to `github:` clean entries. |
| 3 | The AGENTS.md gotcha entry is now ~3 sentences of reasoning crammed into one table cell. Consider extracting the full workaround to a dedicated `docs/troubleshooting/flake-lock-ssh-urls.md` runbook with examples. |
| 4 | The git.nix file has implicit assumptions about user remotes. Document this in the file header (e.g., "Assumes all GitHub remotes are SSH; HTTPS-to-SSH rewrite is a convenience for ad-hoc clones"). |
| 5 | The `nix flake check --no-build` does NOT validate the rendered HM config — only the NixOS module graph. We relied on `nix eval` for the actual config rendering. Add a tiny `nix run .#verify-git-config` check script that builds the actual file and grep-checks for `[url]` + `insteadOf`. |
| 6 | The commit `502020e7` was created by the auto-commit daemon (NOT by me) — it's titled "chore(programs/git): update git configuration and aliases" which is vague. A better commit would be `"feat(programs/git): restore insteadOf rule for GitHub HTTPS→SSH rewrites"`. |
| 7 | AGENTS.md was updated but not committed. Either commit now, or accept the auto-commit daemon will do it with a generic title. |
| 8 | The AGENTS.md gotcha entry goes from "FIXED" → "restored" — but the table is alphabetically organized (chronological-ish). Consider a "Status" column or split into "Active Gotchas" vs "Resolved" sections. |
| 9 | The `git.nix` file structure is a flat `programs.git` attrset with no sub-modules. Consider splitting: `programs.git.{core,signing,aliases,urlRewrites,credentials}` for readability. |
| 10 | No test for this rule. The NixOS test infrastructure could include a minimal test that builds the HM config and grep-checks for `insteadOf`. |

---

## File Diffs

### `platforms/common/programs/git.nix` (+11 lines)

```diff
       credential = {
         helper =
           if pkgs.stdenv.isDarwin then "osxkeychain" else "${pkgs.gitFull}/bin/git-credential-libsecret";
       };

+      # Rewrite HTTPS GitHub URLs to SSH. WARNING: this caused `nix flake lock`
+      # to record `ssh://git@github.com/...` in lock files instead of `github:`
+      # entries (removed 2026-07-29, restored on user demand). Run
+      # `GIT_CONFIG_GLOBAL=/dev/null nix flake update` to refresh locks with
+      # clean `github:` URLs when needed.
+      url = {
+        "git@github.com:" = {
+          insteadOf = "https://github.com/";
+        };
+      };
```

### `AGENTS.md` (1 line changed)

| Line | Before | After |
|------|--------|-------|
| 408 | status: `FIXED 2026-07-29` (rule removed) | status: `restored on user demand 2026-07-30` (rule present, with workaround) |

---

## Verification

```bash
$ nix flake check --no-build
# all checks passed!

$ nix eval --json .#nixosConfigurations.evo-x2.config.home-manager.users.lars.programs.git.settings | jq '.url'
{
  "git@github.com:": {
    "insteadOf": "https://github.com/"
  }
}
```

---

## Up to 50 Things We Should Get Done Next

Sorted by impact (Pareto: 80/20). The first ~10 are the real winners.

### High Impact (P0/P1)

1. **Deploy this change** to evo-x2 (and darwin if needed) — `nix run .#deploy` for NixOS, `darwin-rebuild` for macOS. Then verify `git config --global --list | grep insteadOf` shows the rule.
2. **Commit the AGENTS.md changes** — either manually with a proper message, or let the auto-commit daemon do it.
3. **Audit all 9+ LarsArtmann repo `flake.lock` files** for `ssh://git@github.com/` URLs. Convert to `github:` entries (use `GIT_CONFIG_GLOBAL=/dev/null nix flake update --override-input <input> "github:LarsArtmann/<repo>/<ref>"`).
4. **Scope the `insteadOf` rule** to `https://github.com/LarsArtmann/` only (not all of GitHub). This eliminates the flake.lock pollution entirely while keeping the user-facing convenience.
5. **Run `nix run .#post-deploy-check`** after the deploy to confirm no service broke from the config change.
6. **Investigate the `nix.conf` `access-tokens` setup** — verify the token is still valid and not expired. The 2026-07-29 removal assumed it worked; never actually tested a fresh `nix flake update` after the removal.
7. **Add a recovery runbook** at `docs/troubleshooting/flake-lock-ssh-urls.md` with: how to detect, how to fix, how to prevent.
8. **Review the 7 unpushed commits** ahead of `origin/master` — `git log origin/master..HEAD --oneline` shows 7 commits, none pushed. Consider a PR or batch push.
9. **Test `nix flake update` end-to-end** on SystemNix AFTER the rule is restored. Verify lock entries use `ssh://` URLs (as expected) and that the build succeeds.
10. **Create a `nix run .#flake-lock-cleanup` script** that converts SSH URLs in lock files to `github:` entries. Useful for sharing locks publicly without exposing SSH hostname.

### Medium Impact (P2)

11. **Document the `GIT_CONFIG_GLOBAL=/dev/null` trick** in the deploy runbook (`docs/runbooks/deploy.md`) — it's a useful escape hatch for any git-config-driven Nix flake issue.
12. **Add a `flake.lock` URL linter** as a pre-commit hook: `git diff` against `flake.lock` to detect URL changes.
13. **Move the `programs.git` config to a dedicated module** (`modules/shared/programs/git.nix`) instead of inline in `platforms/common/programs/`. Better organization.
14. **Consider `programs.git` includes** — split the 100+ alias/git-town config into a separate `git-aliases.nix` file for maintainability.
15. **Add a `git-town` config validation** — `git-town config` runs to verify the town aliases resolve. Caught 0 bugs so far, but cheap insurance.
16. **Time-bomb the `insteadOf` rule** — add a `// TODO: 2026-08-30 — evaluate if this rule is still needed` comment. Forces a re-evaluation in 30 days.
17. **Compare `nixpkgs-unstable` vs `nixpkgs`** — check if `pkgs.git` from unstable has different defaults for `credential.helper` (macOS keychain vs libsecret).
18. **The `coderabbit.machineId` value** is a literal in the config. Consider if it should be a build-time secret or a per-user secret.
19. **The `safe.directory` list** allows `~` and `~/projects`. Document what happens when user's `$HOME` is on a non-standard path (e.g., NFS mount).
20. **Review `pager.diff = "bat"`** — works on Linux but `bat` may not be installed on minimal Darwin setups. Add a fallback.

### Low Impact (P3)

21. **Replace `git config --global` with HM-only** — the file says `programs.git` which is HM-managed. Verify there's no `.gitconfig` rogue file overriding.
22. **Document `core.quotePath = false`** — this is helpful for non-ASCII filenames but can cause issues with some tools.
23. **Document `packedGitLimit = "512m"` and `packedGitWindowSize = "512m"`** — both should be equal for best performance. They're set correctly; just no inline comment.
24. **Add `core.untrackedCache = true`** for faster `git status` on large repos.
25. **Add `core.fsmonitor = true`** if using fsevents (macOS) or inotify (Linux). Speeds up `git status` massively.
26. **`http.postBuffer = 524288000` (500MB)** — reasonable for large repos; document why this size.
27. **`gc.auto = 6700`** — slightly lower than the default 6700. Verify this is intentional.
28. **Consider `commit.gpgsign = true` enforcement** — currently `signByDefault = true` does this. Add a `pre-receive` hook test.
29. **The `git-town` config block** — verify `sync-perennial-strategy = "rebase"` is the desired default.
30. **Add `init.templateDir`** for consistent `.git` templates across all new repos.

### Future / Nice-to-Have (P4)

31. **Migrate to `gitoxide`** for the Rust-based git CLI on systems that support it. Faster but newer.
32. **Add `gh` CLI aliases** under `programs.gh.extensions` for repo-specific shortcuts.
33. **Document the `~/.gitconfig` vs `~/.config/git/config` precedence** — HM writes the latter; verify no rogue `~/.gitconfig` exists.
34. **Consider `delta` as the diff pager** instead of `bat` (better for diffs).
35. **Add `merge.conflictStyle = "zdiff3"`** for cleaner conflict markers.
36. **`branch.sort = "-committerdate"`** for nicer `git branch` output.
37. **`log.date = "iso"`** for ISO timestamps in `git log`.
38. **`diff.algorithm = "histogram"`** for better diffs.
39. **`rerere.enabled = true`** for automatic conflict resolution reuse.
40. **`fetch.prune = true`** to auto-delete remote-tracking refs.
41. **`push.followTags = true`** to push tags alongside the current branch.
42. **`rebase.autoStash = true`** for safer rebases with dirty trees.
43. **`tag.sort = "-version:refname"`** for sortable tag lists.
44. **`worktree.guessRemote = true`** for better worktree UX.
45. **Add `core.hooksPath`** to a shared hooks directory.
46. **Add `credential.useHttpPath = true`** for per-host credentials.
47. **Add `color.ui = "auto"`** for proper color detection.
48. **Add `color.branch = "auto"`, `color.diff = "auto"`, `color.status = "auto"`** for explicit colors.
49. **Add `alias.co = "checkout"`**, `alias.br = "branch"`, `alias.st = "status"`, `alias.ci = "commit"` for brevity.
50. **Consider `delta` config** for syntax-highlighted diffs.

---

## Final Self-Assessment

**What I did well:**
- Identified the exact line in the exact file that needed changing (the rule was in `platforms/common/programs/git.nix:79-82` literally the day before).
- Updated the parallel AGENTS.md gotcha entry to reflect the new state (not just the code).
- Verified the eval works and the rule renders correctly.
- Asked nothing — the user request was unambiguous.

**What I could have done better:**
- **Did NOT commit the AGENTS.md change** — left `git status` showing `M AGENTS.md`. The auto-commit daemon will likely commit it with a generic title. Should have committed it explicitly with a meaningful message.
- **Did NOT deploy** — user did not ask, but the change is useless without a deploy. Could have asked "Deploy now?"
- **Did NOT explain the `flake.lock` SSH pollution risk** at the time of the change — just put it in a comment. Should have summarized the trade-off in the response.
- **Did NOT show the AGENTS.md diff** in the response — only the git.nix change.
- **The branch is 7 commits ahead of `origin/master`** — none of those commits are in this session (they're from the auto-commit daemon), but I didn't flag that. Should have surfaced it.
- **Did NOT consider scoping the rule** — could have offered `https://github.com/LarsArtmann/` instead of `https://github.com/`. Better trade-off.
- **Did NOT run `nix run .#pre-deploy-check`** — could've validated the change is deploy-safe before declaring victory.

**What I should improve going forward:**
- Always commit changes in the same turn as the edit (don't leave `git status` dirty).
- Always run `nix run .#pre-deploy-check` after any `platforms/common` change.
- Always surface unpushed commits (current branch is 7 ahead).
- Always think about the "scoped vs. global" trade-off for config rewrites.
- Always offer the deploy step explicitly: "Change is in. Want to deploy now?"

---

## Questions I Cannot Answer Myself

**Q1: Should I also remove the `auto-commit daemon` from your workflow?** It's been making commits overnight that I don't see context for. The current branch is 7 ahead of `origin/master` and I don't know which of those commits are intentional vs. accidental. This is a real operational risk — I can't audit what I can't see.

**Q2: Do you want the `insteadOf` rule scoped to `https://github.com/LarsArtmann/` only?** This would eliminate the `flake.lock` SSH URL pollution entirely while keeping the convenience for your own repos. The current rule is too broad — it rewrites ALL GitHub HTTPS URLs, including those for projects you don't own.

**Q3: Should I push the 7 unpushed commits to `origin/master`?** They're the auto-commit daemon's output. I don't know if you've reviewed them, if they're private, or if they're intended. Pushing them is irreversible.
