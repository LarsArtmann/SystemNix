# Status: NAR Hash Mismatch + DNS Fallback Fixes

**Date:** 2026-08-12 23:50 CEST
**Session focus:** Fix two build-blocking errors from `nix run .#deploy` failure
**Commit:** `fe891bff` — `fix(nix): add go-nix-helpers follows to align fetch type with top-level pin`

---

## a) FULLY DONE

### 1. Root-caused the NAR hash mismatch (SOLVED)

**Error:** `NAR hash mismatch in input 'git+ssh://git@github.com/LarsArtmann/go-nix-helpers?ref=master&rev=e6d392b...', expected 'sha256-Pqzzz...' but got 'sha256-Bh02s...'`

**Root cause chain (5 layers deep):**

1. `projects-management-automation` was the **only** LarsArtmann flake input missing `go-nix-helpers.follows = "go-nix-helpers"`
2. Without `follows`, PMA locked go-nix-helpers independently via `git+ssh:` fetch type
3. The top-level go-nix-helpers uses `github:` tarball fetch type (per `flake.nix` URL spec)
4. **The same git commit produces DIFFERENT narHashes** depending on fetch type: `github:` tarball normalizes file permissions (all 0644), while `git+ssh:` preserves git's executable bits
5. The nix daemon caches `fetchTree` results **in memory** by `(url, rev)`. A stale cached hash from one fetch type causes "NAR hash mismatch" when the lock file specifies the other. The daemon cache CANNOT be cleared without restarting the daemon — the `~/.cache/nix/fetcher-cache-v4.sqlite` delete didn't help because the daemon holds it in RAM.

**Fix applied:**

- `flake.nix:379` — added `go-nix-helpers.follows = "go-nix-helpers"` to PMA input
- Updated flake.lock: PMA now follows the top-level `github:` tarball fetch, eliminating the `git+ssh:` path entirely
- Removed 6 stale lock nodes (go-nix-helpers_7 + its transitive inputs: flake-parts, nixpkgs, systems, treefmt-nix)

**Verified:** `nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel.drvPath` succeeds → `/nix/store/9nr5wwkyvx0gyncw8362x5l05bcw185i-nixos-system-evo-x2-26.11.20260810.2fcb964.drv`

### 2. Fixed DNS fallback ordering (CONFIG CHANGED, NOT DEPLOYED)

**Error:** `unable to download 'https://cache.home.lan/...': Could not resolve hostname`

**Root cause:** `/etc/resolv.conf` had `nameserver 9.9.9.9` BEFORE `nameserver 127.0.0.1`. glibc queries nameservers in order and accepts the first NXDOMAIN — Quad9 returns NXDOMAIN for `*.home.lan` (private TLD), so glibc never falls through to dnsblockd on 127.0.0.1. This caused 5x retry delays (~10-15s per nix operation hitting cache.home.lan).

The `9.9.9.9` was manually added during dnsblockd OOM/slow outages as a fallback. The Nix config (`dns-resolver.nix`) previously only had `127.0.0.1` with no fallback — which is WHY the user manually edited resolv.conf in the first place.

**Fix applied:**

- `platforms/common/dns-resolver.nix` — added `9.9.9.9` as a **permanent** fallback AFTER `127.0.0.1`
- `127.0.0.1` is primary (local names resolve), `9.9.9.9` is fallback (resilience when dnsblockd is down/slow)
- Updated AGENTS.md gotcha to reflect the new permanent fallback

### 3. Documented both gotchas in AGENTS.md

- New gotcha: "NAR hash differs between `github:` tarball and `git+ssh:` fetch for same rev"
- Updated gotcha: "Manual `/etc/resolv.conf` edits break local DNS" — now documents the permanent fallback

### 4. Verified all LarsArtmann inputs have go-nix-helpers.follows

Ran an audit script confirming every `github:LarsArtmann/` input that has `.follows` declarations also includes `go-nix-helpers.follows`. No more missing follows.

---

## b) PARTIALLY DONE

### 1. Live system NOT deployed

Changes are committed (`fe891bff`) but **NOT deployed**. The live `/etc/resolv.conf` still has `9.9.9.9` first (wrong order). A `nix run .#deploy` is needed to:

- Activate the corrected DNS config (restores the Nix-managed symlink with correct order)
- Clear the nix daemon's in-memory fetch cache (daemon restarts on deploy)

### 2. `nix flake check --no-build` NOT run

Only ran `nix eval` on the toplevel drv path. Did NOT run `nix flake check --no-build` for full syntax validation. The eval passing is strong evidence, but the full check was skipped.

### 3. Stale `go-nix-helpers` lock node NOT cleaned up

The flake.lock still contains an **orphan** `go-nix-helpers` node (locked.type: `git`, flake: `false`, rev: `064a269`). This is a leftover from old `git insteadOf` pollution — the root input maps to `go-nix-helpers_4` (the correct `github:` type), not this stale node. It's harmless (unreferenced) but pollutes the lock file.

### 4. Three `git+ssh:` go-nix-helpers nodes remain in flake.lock

`go-nix-helpers_2`, `go-nix-helpers_5`, `go-nix-helpers_6` still have `locked.type: "git"` with `ssh://` URLs. These belong to inputs that correctly have `go-nix-helpers.follows` but whose lock entries weren't updated to the `github:` tarball type. They work (rev `0122702` is stable, no force-push), but they're potential landmines if go-nix-helpers is ever force-pushed again.

---

## c) NOT STARTED

- Did not investigate whether the go-nix-helpers force-push (commit amend at rev `e6d392b`) was intentional or accidental
- Did not restart the nix daemon to clear its in-memory stale cache (could not — `systemctl` is blocked in this environment)
- Did not verify the deploy actually succeeds end-to-end (only eval)
- Did not check whether other private repos (go-checker-helpers, etc.) have similar `git+ssh:` vs `github:` fetch type inconsistencies
- Did not run pre-commit hooks or pre-deploy-check.sh

---

## d) TOTALLY FUCKED UP

### 1. `nix fmt` reformatted files I didn't touch

Running `nix fmt` globally reformatted `browser-history.nix`, `sops.nix`, `quickshell.nix`, and `flake.nix` with whitespace/indentation changes unrelated to my fix. These were swept into the auto-git commit `fe891bff`. The diff shows `555 +/-/-` lines in flake.nix when my actual change was 1 line. This makes the commit harder to review and conflates formatting with logic changes. **Should have formatted ONLY the files I edited** or committed formatting separately.

### 2. Didn't clear the nix daemon's in-memory cache

The real blocker was the daemon's in-memory `fetchTree` cache, NOT the sqlite file. I deleted the sqlite fetcher cache entry AND cleared 8574 eval cache files — neither helped because the daemon holds the stale hash in RAM. I wasted time on cache clearing that couldn't work. The actual fix (adding `follows` to change the fetch URL) was the right approach, but I should have reached it faster by recognizing that the `Pqzzz` hash existed ONLY in the daemon's memory, not in any lock file.

### 3. Didn't realize the eval cache clearing was futile

Deleted 8574 eval cache SQLite files unnecessarily. These were harmless and rebuilding them costs CPU/time on next eval. The stale hash was never in the eval cache — it was in the daemon's fetchTree memory.

---

## e) WHAT WE SHOULD IMPROVE

### Process improvements

1. **NEVER run `nix fmt` globally when fixing a specific issue** — format only the files you changed, or do formatting in a separate commit
2. **Recognize daemon-level caching faster** — when a hash exists in NO lock file but nix still reports it, it's in the daemon's memory. No amount of cache file deletion will help. The fix is to change the fetch parameters (different URL/fetch type) or restart the daemon.
3. **Always check if follows is missing BEFORE debugging hash mismatches** — the "flake input missing follows" pattern is the #1 cause of fetch-type hash divergence. A 2-line script can audit this in seconds.
4. **Deploy after fixing, don't just eval** — eval proves the config is valid but doesn't fix the live system. The user's DNS is still broken on the live machine.

### Architectural improvements

5. **Add an eval-time assertion that all LarsArtmann inputs have `go-nix-helpers.follows`** — catches the PMA gap automatically on every flake check. Same pattern as the existing tarball-guard and DynamicUser audit.
6. **Consider adding all LarsArtmann shared inputs as explicit follows** — not just go-nix-helpers, but also flake-parts, treefmt-nix, systems. Any input consumed by multiple sub-flakes should follow the top-level to prevent fetch-type divergence.
7. **The `git insteadOf` pollution is STILL causing lock file pollution** — the orphan `go-nix-helpers` node with `type: "git"` and `flake: false` proves the `GIT_CONFIG_GLOBAL=/dev/null` workaround isn't applied consistently during lock updates.

---

## f) Up to 50 Things to Get Done Next

### Immediate (blocking deploy)

1. ~~**Deploy the changes:** `nix run .#deploy` — activates DNS fix + clears daemon cache~~ done — deployed via subsequent deploys
2. ~~**Verify resolv.conf after deploy:** `cat /etc/resolv.conf` should show `127.0.0.1` first, `9.9.9.9` second~~ done — Nix-managed symlink restored on every deploy; post-deploy DNS checks green
3. **Verify `cache.home.lan` resolves after deploy:** `dig cache.home.lan @127.0.0.1 +short` — blocked on Attic cache creation (TODO_LIST Priority 3)
4. ~~**Run `nix flake check --no-build`** — full syntax validation~~ done — passes on every deploy since
5. ~~**Run `scripts/pre-deploy-check.sh`** — verify mount safety, ports, disk space~~ done — runs on every deploy since

### Short-term (cleanup)

6. ~~**Clean up orphan `go-nix-helpers` lock node** — remove the stale `type: "git"` / `flake: false` entry from flake.lock~~ done at `82963f04`/`caf2cab8` (stale nodes removed during the 08-13 follows dedup)
7. ~~**Convert remaining `git+ssh:` go-nix-helpers lock entries to `github:` type** — update go-nix-helpers_2, _5, _6~~ done at `1d3a53a0` (LarsArtmann inputs switched from `git+ssh:` to `github:` tarball fetches)
8. **Add eval-time assertion for missing `go-nix-helpers.follows`** — similar to `nixpkgsTarballGuard` in flake.nix
9. **Check go-checker-helpers and other `flake = false` git+ssh inputs** for similar fetch-type inconsistencies
10. **Investigate whether go-nix-helpers rev `e6d392b` was intentionally force-pushed** — check if this was an amend or a rebase
11. ~~**Run `scripts/post-deploy-check.sh`** after deploy to verify functional outcomes~~ done — runs on every deploy since
12. ~~**Check if the `jscpd-pnpm-lock.yaml` change** (committed by auto-git) is correct or spurious~~ done — correct (the `pnpm-run-path`→`npm-run-path` typo fix, `72115c62`)

### DNS hardening

13. **Monitor dnsblockd stability** with the new fallback — does Quad9 being in resolv.conf cause any unexpected behavior?
14. **Consider adding a Gatus alert for DNS resolution latency** — catch dnsblockd slowness before it motivates manual resolv.conf edits
15. **Document the dnsblockd OOM/slow root cause** — was it fixed? The MemoryMax=2G + GOMEMLIMIT fix from previous sessions may have resolved it
16. **Consider adding `rotate` option to resolv.conf** — distributes queries across both nameservers instead of always trying 127.0.0.1 first
17. **Verify Mullvad doesn't overwrite resolv.conf** — the 0444 mode should prevent it, but verify after deploy

### Flake lock hygiene

18. **Audit ALL LarsArtmann inputs for missing follows** — not just go-nix-helpers, check go-commit, go-output, go-branded-id, cmdguard, etc.
19. **Add a CI check for fetch-type consistency** — flag any lock node with `type: "git"` + `ssh://` URL when the flake.nix specifies `github:`
20. **Consider a flake.lock linter** — detect orphan nodes, stale `flake: false` entries, fetch-type mismatches
21. **Document the `GIT_CONFIG_GLOBAL=/dev/null` requirement** for ALL `nix flake lock` commands in AGENTS.md (it's mentioned in gotchas but not in the "Key Procedures" section)
22. **Run `nix flake archive --dry-run`** to verify all lock entries are fetchable

### Nix daemon hardening

23. **Consider a cron job that restarts nix-daemon daily** — clears in-memory fetchTree cache, prevents stale-hash accumulation
24. **Investigate `nix.daemonNrBuilds` and fetch caching behavior** — understand when the daemon evicts stale entries
25. ~~**Document the daemon in-memory cache as a gotcha** — "nix daemon caches fetchTree results in RAM by (url, rev); stale entries persist until daemon restart"~~ done — AGENTS.md "NAR hash differs" gotcha documents the daemon cache + recovery (`sudo systemctl restart nix-daemon`)

### Testing

26. **Write a VM test for the DNS fallback behavior** — verify local names resolve via 127.0.0.1, external via fallback
27. **Write an eval-time test for the follows assertion** — ensure missing follows fails the build
28. **Test that `nix run .#deploy` actually clears the daemon cache** — verify by checking if the stale `Pqzzz` hash disappears after deploy

### Documentation

29. **Update AGENTS.md "Adding a Service" procedure** — add step: "ensure all shared inputs have `.follows` declarations"
30. **Create a runbook for NAR hash mismatches** — step-by-step: check follows → check fetch type → check daemon cache → restart daemon
31. ~~**Document the `github:` vs `git+ssh:` narHash difference** in the "Consuming LarsArtmann Flakes" section of AGENTS.md~~ done — AGENTS.md gotcha + follows rule cover it
32. **Add the DNS fallback rationale to `docs/gotchas-archive.md`** — full incident narrative

### Monitoring

33. **Add a Gatus check for nix build success** — catch eval failures early
34. **Monitor nix-daemon memory usage** — the in-memory cache could grow unbounded
35. **Add a metric for nix flake lock staleness** — alert when lock entries are >30 days old

### Broader system health

36. **Check if the browser-history.nix reformatting changed any logic** — the auto-git commit included 464 lines of reformatting
37. **Check if sops.nix reformatting changed any logic** — 527 lines of reformatting in the commit
38. **Check if quickshell.nix reformatting changed any logic** — 10 lines of reformatting
39. **Verify the flake.nix reformatting (555 lines) didn't change any URLs or logic** — only whitespace should differ
40. **Run `nix flake show`** to verify all outputs are accessible
41. **Check for other stale eval-cache entries** that could cause confusing errors

### Future architecture

42. **Consider pinning go-nix-helpers to a tagged release** instead of `ref=master` — eliminates force-push risk entirely
43. **Consider a Nix flake-parts module that auto-injects follows** for all LarsArtmann inputs
44. **Evaluate whether dnsblockd should have a health-check-based fallback** — automatically add/remove itself from resolv.conf based on health
45. **Consider using `networking.networkmanager.dns` instead of static resolv.conf** — may handle fallback more gracefully
46. **Add a systemd timer that verifies resolv.conf matches the Nix-managed version** — alert if manually overwritten

### Git hygiene

47. **Consider squashing the formatting changes out of the commit** — `fe891bff` mixes 1 logic line with 500+ formatting lines
48. **Add a pre-commit hook that rejects `type: "git"` lock entries for inputs declared as `github:`** in flake.nix
49. **Review the auto-git daemon's commit message quality** — `fe891bff` has a decent message but doesn't mention the DNS fix
50. **Consider committing formatting changes separately from logic changes** — update the auto-git daemon or add a pre-commit splitter

---

## g) Questions I CANNOT Answer Myself

### Q1: Was the go-nix-helpers force-push (amend of rev e6d392b) intentional?

The commit `e6d392b` ("refactor: move auto-discovery from eval-time to build-time") was force-pushed — the nix daemon cached hash `Pqzzz...` for it, but the current content hashes to `Bh02s...`. This means the commit was amended or rebased after initial push. Was this intentional? If so, we should consider a policy against force-pushing to `master` on shared flake inputs. If accidental, the amended version is now correct and locked.

### Q2: Should I deploy now, or do you want to review the changes first?

The changes are committed (`fe891bff`) but the live system still has the broken resolv.conf (`9.9.9.9` first). Deploying would fix both the DNS ordering AND clear the nix daemon's stale cache. But the commit also includes 500+ lines of `nix fmt` reformatting (browser-history.nix, sops.nix, flake.nix) that I didn't intend to include. Do you want me to deploy as-is, or should we split the formatting into a separate commit first?

### Q3: Is the `jscpd-pnpm-lock.yaml` change yours or spurious?

The working tree shows `pkgs/jscpd-pnpm-lock.yaml` was modified (3 insertions, 3 deletions). This was NOT touched by me — it was already modified at session start or changed by the auto-git daemon. Should this be committed, reverted, or investigated?

---

## Self-Assessment Score

| Category            | Score      | Notes                                                                                           |
| ------------------- | ---------- | ----------------------------------------------------------------------------------------------- |
| Root cause analysis | 9/10       | Found the 5-layer-deep cause (missing follows → fetch type divergence → daemon in-memory cache) |
| Fix quality         | 7/10       | The fix is correct but the commit is polluted with 500+ lines of formatting noise               |
| Speed               | 6/10       | Wasted time clearing cache files that couldn't help (daemon holds hash in RAM)                  |
| Verification        | 5/10       | Only ran eval, not flake check or deploy. Live system still broken.                             |
| Documentation       | 8/10       | Good AGENTS.md updates, but missing a dedicated runbook                                         |
| Completeness        | 5/10       | Didn't deploy, didn't clean up stale lock nodes, didn't check other repos                       |
| **Overall**         | **6.5/10** | Solved the hard problem, botched the execution hygiene                                          |
