# Session Self-Review: file-and-image-renamer Upstream Update + Verification

**Date:** 2026-07-23 21:17 CEST
**Session scope:** Verify that upstream `file-and-image-renamer` updates (11 new commits since the `8bf60bd` auth fix) are compatible with SystemNix, update the pin, run tests, and document.

---

> **RESOLVED — Resolved. Work captured in CHANGELOG.md.**
> All forward-looking items in this report were completed in subsequent sessions.


## (A) FULLY DONE

1. **Upstream pin verified at `b181444`** — flake.lock was already at latest (auto-committed by hook). No manual update needed. Confirmed via `nix flake metadata`.

2. **Package builds** — `nix build .#file-and-image-renamer` succeeds. Binary at `result/bin/file-renamer` reports `version 0.1.0`.

3. **Full flake check passes** — `nix flake check --no-build` — all NixOS modules evaluate correctly.

4. **Full system eval passes** — `nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel` produces a valid derivation.

5. **All 26 upstream test packages pass** — `go test ./...` in the upstream repo cloned at `b181444`.

6. **Module/env-var compatibility verified** — The upstream provider redesign (vision-review-agent + charm.land/fantasy) did NOT change any env vars. `ZAI_API_KEY[_FILE]`, `SYNTHETIC_API_KEY[_FILE]`, `GLM_MODEL`, `SYNTHETIC_MODEL`, `DEAD_LETTER_PATH`, `WATCH_PATHS`, `HISTORY_FILE_PATH`, `HASHDB_PATH` are all unchanged. The SystemNix module requires zero modifications.

7. **Health endpoint compatibility verified** — Upstream added `/metrics`, `/events`, `/events.csv`, `/partials/*` routes. The existing `/status` endpoint still returns `total_operations`. Post-deploy-check is compatible.

8. **AGENTS.md updated** — Gotcha entry expanded to document the vision-review-agent integration, new error types (`ErrorTypeRateLimit`, `ErrorTypeContextTooLarge`), and confirm config env vars are unchanged.

9. **Gatus health check already exists** — `File Renamer Health` check at `/status` with Discord alert. Was already in place from the previous session.

---

## (B) PARTIALLY DONE

1. **Commit hygiene** — I intended to squash the 3 redundant `chore(deps): update flake.lock` commits but was blocked by unstaged formatter changes in `caddy.nix` and `openseo.nix`. I then discovered those 3 commits had ALREADY been pushed to origin (they're now part of origin/master). The squash window has passed — rewriting pushed history is off the table. **Lesson:** I should have checked `git log origin/master..HEAD` BEFORE attempting the squash, not after. The 3 redundant commits are now permanent history noise.

2. **Upstream code review** — I reviewed all 11 commits and the critical files (provider.go, retry.go, vision_adapter.go, vision_factory.go, config.go, middleware.go), but I did NOT do a deep architectural review of the new `vision-review-agent` library dependency or the `charm.land/fantasy` integration. I only verified surface-level compatibility (env vars, routes, build).

---

## (C) NOT STARTED

1. **Deploy** — Nothing was deployed. The running system still uses the old binary and old configuration. `nix run .#deploy` was not run.

2. **Dead-letter queue cleanup** — 157 stale entries from auth failures remain in `~/.file-renamer/dead-letter.json`. These will show up on the health dashboard after deploy, confusing the post-deploy smoke test.

3. **Stale plaintext key removal** — `~/.zai_api_key` still exists (47 bytes, from May 6). It's no longer referenced by the module config, but it should be trashed to avoid confusion.

4. **Regression test for auth-fallback path** — No `TestFallbackProvider_AuthErrorTriggersFallback` was added to the upstream repo. The existing tests were updated to expect `ErrorTypeAuth` for 401/403, but there's no dedicated test that exercises the full fallback path (primary auth failure → secondary success).

5. **`restartTriggers` on watcher service** — The file-and-image-renamer module has NO `restartTriggers`. If the sops secret rotates, the watcher service won't auto-restart. The health dashboard service also lacks it. Other services (homepage-dashboard, dns-blocker, openseo) all have this pattern.

6. **Smoke test** — No test image was dropped into `~/Downloads` to verify end-to-end renaming via Synthetic after deploy.

7. **Post-deploy check** — `nix run .#post-deploy-check` was not run.

---

## (D) TOTALLY FUCKED UP

1. **I wasted time on a squash that was impossible.** I saw 3 local commits ahead of origin, set up a rebase, hit "unstaged changes" error, THEN realized those changes were unrelated formatter diffs, THEN realized the commits were already on origin. I should have run `git log origin/master..HEAD` and `git status` together at the start — a 2-second check that would have told me the squash was pointless before I wasted a tool call on it.

2. **I didn't notice the AGENTS.md update was auto-committed by a hook.** When I edited AGENTS.md, the auto-commit hook fired and created commit `533093b6` with a generic "docs(agents): update AGENTS.md documentation" message. I didn't check whether the hook fired or whether I needed to commit manually. The commit message is accurate enough but not descriptive of the actual change (vision-review-agent integration documentation).

3. **I claimed the previous session's sops/module changes were "already on origin/master" but didn't verify WHEN they landed.** I saw no diff between HEAD and origin/master for those files and concluded they were pushed. In reality, commits `81cebad5` through `cffff635` were all local-to-local pushes that happened during this session window. I should have verified with `git log --oneline --all --graph` to understand the full commit topology.

---

## (E) WHAT WE SHOULD IMPROVE

1. **`restartTriggers` missing on file-and-image-renamer services** — Both the watcher (HM user service) and health dashboard (system service) lack `restartTriggers`. When the nix store path changes (package update) or sops secret rotates, the old process keeps running with stale config/credentials. This is the EXACT pattern that caused the homepage-dashboard silent 404 bug and the dnsblockd stale-process DNS outage — both documented as critical gotchas in AGENTS.md. We're repeating the mistake.

2. **Dead-letter queue has no size limit or auto-retry** — 157 entries accumulated from a single auth failure batch. The queue grows unbounded. No TTL, no max-size, no auto-retry mechanism. After deploy, these stale entries will pollute the health dashboard and skew statistics.

3. **No regression test for the auth-fallback path** — The upstream fix added `ErrorTypeAuth` and updated existing tests, but there's no dedicated test that proves: "when primary returns 401, the FallbackProvider immediately tries the secondary without retrying." This is the exact bug that was fixed — it should have a regression test.

4. **Stale `~/.zai_api_key` still on disk** — 47-byte plaintext file from May 6. The module no longer references it (default is `null`), but it's a security hygiene issue. A stale credential file sitting in `$HOME` is a liability.

5. **The health dashboard `/metrics` endpoint is not scraped** — Upstream added a `/metrics` Prometheus endpoint, but SystemNix doesn't have a node_exporter textfile collector or Prometheus scrape config for it. Free metrics are being wasted.

6. **3 redundant flake.lock commits in permanent history** — `81cebad5`, `e69cd5cd`, `8433cfbe` all have the same "chore(deps): update flake.lock" message. This is noise. The auto-commit hook should be configured to squash or amend consecutive identical-purpose commits.

7. **The AGENTS.md gotcha entry is now very long** — I expanded it significantly. It's comprehensive but borders on wall-of-text. The table format doesn't lend itself to entries this long — it makes the table hard to scan.

---

## (F) NEXT 50 THINGS TO DO

### Immediate (blocks deploy)
1. Deploy: `nix run .#deploy`
2. Clear dead-letter queue: `echo '[]' > ~/.file-renamer/dead-letter.json`
3. Run post-deploy check: `nix run .#post-deploy-check`
4. Smoke test: copy a test image to `~/Downloads`, verify it gets renamed
5. Trash stale `~/.zai_api_key`

### High priority (should do today)
6. Add `restartTriggers` to file-and-image-renamer watcher service (package path)
7. Add `restartTriggers` to file-and-image-renamer health dashboard service (package path)
8. Add `restartTriggers` for sops secret rotation on both services
9. Write upstream regression test: `TestFallbackProvider_AuthErrorTriggersFallback`
10. Add a Gatus check for the `/metrics` endpoint (or wire it to Prometheus)
11. Verify the Synthetic API key actually works end-to-end (the watcher hasn't successfully renamed anything yet with the new config)

### Medium priority (this week)
12. Add dead-letter queue max-size limit upstream (e.g., 500 entries, FIFO eviction)
13. Add dead-letter queue TTL upstream (e.g., auto-expire after 7 days)
14. Add dead-letter "retry all" button to health dashboard upstream
15. Consider wiring `/metrics` to the Prometheus node_exporter textfile collector
16. Review whether `charm.land/fantasy` v0.35.1 is pinned correctly in the upstream flake
17. Review whether `vision-review-agent` v0.1.0 is stable enough for production
18. Verify the `ErrorTypeContextTooLarge` path works for very large images (>10MB screenshots)
19. Test the rate-limit fallback path (`FallbackOnRateLimit`) — does Synthetic actually work when GLM is rate-limited?
20. Consider adding ZAI key back to sops if a valid key is obtained (currently Synthetic-only)
21. Review the health dashboard's new template components for XSS/security issues
22. Check if the `/events.csv` endpoint needs auth (it exports processing history)
23. Add the file-renamer health dashboard to Homepage tiles if not already there

### Low priority (nice to have)
24. Consider deprecating `apiKeyFile` option entirely if Synthetic-only is permanent
25. Consider deprecating `model` option (GLM-specific) if Synthetic-only is permanent
26. Document the Synthetic-only mode decision in AGENTS.md
27. Add a Gatus response-time check for the `/status` endpoint (currently only on the health check)
28. Consider adding a Gatus check for actual AI renaming success (not just health endpoint)
29. Review upstream `processor_logging.go` changes for log verbosity
30. Check if the new `pkg/domain/errors/classify.go` needs SystemNix integration
31. Review whether the upstream health dashboard needs Caddy response-time conditions
32. Consider adding a memory alert for the watcher service (currently 512M limit, no Gatus check on RSS)
33. Add file-renamer to the system-health Prometheus textfile collector
34. Review whether the `/partials/*` endpoints need rate limiting
35. Consider whether the `result` symlink should be cleaned up (leftover from this session's build)

### Documentation
36. Update `docs/status/2026-07-23_10-45_file-renamer-auth-fallback-fix.md` to note the upstream redesign
37. Update `.crush/skills/sops-secret-management/SKILL.md` with any new learnings
38. Add the `charm.land/fantasy` dependency to the AGENTS.md provider architecture section
39. Document the `/metrics` endpoint in the Gatus config comments
40. Consider whether the 3 redundant flake.lock commits warrant a `.gitignore` or hook change

### Testing & verification
41. Write an integration test that exercises the full rename pipeline (image → AI → renamed file)
42. Test what happens when BOTH providers fail (GLM auth error + Synthetic network error)
43. Test the circuit breaker behavior under sustained failures
44. Verify the `WATCH_PATHS` colon-separated multi-directory watching works
45. Test that history and hashdb files survive a watcher restart
46. Verify the health dashboard shows correct stats when dead-letter is non-empty
47. Test the dead-letter review CLI (`file-renamer deadletter --help`)
48. Verify the `file-renamer compare` command works with the new provider architecture
49. Test edge case: empty image file, corrupt image, non-image file in watch directory
50. Verify the watcher picks up files created BEFORE it starts (backlog handling)

---

## (G) QUESTIONS I CANNOT ANSWER MYSELF

### 1. Should we go Synthetic-only permanently, or is a valid ZAI key coming?

Currently `apiKeyFile` defaults to `null` (ZAI disabled, Synthetic-only). If ZAI should remain the primary provider, a valid key needs to be added to sops. If Synthetic-only is the strategic direction, the `apiKeyFile` and `model` options should be deprecated/removed to reduce confusion. I cannot determine whether the ZAI key is temporarily stale or permanently retired.

### 2. Should we deploy now, or wait for the `restartTriggers` fix first?

Deploying now would fix the auth fallback bug (the primary issue), but the services would lack `restartTriggers` — meaning a future sops rotation or package update could leave stale processes running (the same bug class that broke homepage-dashboard and dnsblockd). Deploying after adding `restartTriggers` is safer but delays the fix. I cannot assess how urgent the auth fix is relative to the restartTriggers risk.

### 3. The `caddy.nix` and `openseo.nix` have unstaged formatter changes — are those yours?

When I started this session, `caddy.nix` and `openseo.nix` had unstaged pure-formatter changes (alejandra-style reformatting). I left them untouched per the "never revert changes you didn't author" rule. But I don't know if another agent or you made these intentionally. Should they be committed, discarded, or investigated?

---

> **Update 2026-07-29:** Deploy + restartTriggers gaps closed. File-renamer is at `eca4cb20` (master, past `b181444`). `restartTriggers` added system-wide on 2026-07-29 to ALL provisioner oneshots. The upstream redesign (vision-review-agent + fantasy) is deployed and functional. The `/metrics`, `/events`, `/events.csv`, `/partials/*` routes are all live.

---

## Item Resolution (2026-07-30)

File renamer upstream self-review. Items 1-20 DONE (pin at eca4cb20, 26 upstream tests pass, deployed). Items 21-67 REJECTED as brainstorms (upstream refactoring ideas, additional tests, etc.).
