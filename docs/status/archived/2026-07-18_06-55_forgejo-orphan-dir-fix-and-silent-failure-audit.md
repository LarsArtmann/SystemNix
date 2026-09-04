# Forgejo Orphan-Dir Fix + Silent-Failure Audit — Status Report

**Date:** 2026-07-18 06:55 CEST
**Session window:** ~03:00 – 06:55
**Branch:** master
**Commits this session:** `2d12a613` (fix), plus `3ca1ad69` from prior session (already in tree)
**Host:** evo-x2 (NixOS, 95%→93% disk after cleanup)

---

## TL;DR

The prior session's `CHANGE_ME` token fix was **deployed but only mirrored 7 of 113 repos**. The other 106 were silently failing with HTTP 409 "Files already exist for this repository" because **orphan git directories** (from past OOM/crash-interrupted migrates) existed on disk without DB records. The script printed `✓ Created mirror` anyway because bare `curl` exits 0 on HTTP errors. I fixed the orphan cleanup + honest error reporting, deployed, and verified the fix is live. **End-to-end mirror verification is still blocked** — the sync timer fires in ~4h and I cannot trigger it manually (no sudo, forgejo-owned token file).

**CRITICAL SIDE FINDING:** BTRFS device-unallocated was **1 MiB** — the exact condition that caused the documented 2026-06-26 metadata-ENOSPC crash + WDT reset. I freed 69 GB (go-build cache) but the structural risk remains.

---

## a) FULLY DONE

1. **Root cause diagnosed** — 106/113 repos failing with HTTP 409 "Files already exist for this repository. Adopt them or delete them" due to orphan git dirs with no DB record
2. **API ground truth confirmed** — `GET /api/v1/repos/search?limit=200` returns 7 repos, all `mirror:true`, all created at 01:58-01:59 (after the CHANGE_ME fix), all `mirror_updated: 02:28` (Forgejo scheduler actively pulling)
3. **Adopt endpoint discovered & verified** — `DELETE /api/v1/admin/unadopted/{owner}/{repo}` (401 on unauth probe = endpoint exists; 404 on `/repos/.../adopt` = doesn't exist)
4. **`mirrorGithubScript` rewritten** (`forgejo.nix`):
   - Orphan cleanup before every migrate
   - HTTP-status-based success detection (200/201) instead of `curl &&`
   - Honest push-mirror error reporting (HTTP code logged)
   - `FAILED` counter + `exit 1` on failures → `onFailure` alerts fire
5. **`ensureReposScript` rewritten** (`forgejo-repos.nix`) — same orphan-cleanup pattern + failure tracking
6. **AGENTS.md gotcha updated** — appended "Orphan git dirs (FIXED)" to the existing Forgejo token-trap row with the DELETE-endpoint pattern and the "never trust `curl &&`" rule
7. **Pre-commit hooks all passed** — gitleaks, deadnix, statix, alejandra, flake check
8. **Committed cleanly** — `2d12a613`, 3 files, 44 insertions, 8 deletions (isolated from 641 files of unrelated formatter damage)
9. **Deployed successfully** — `nix run .#deploy` activated config; orphan-cleanup logic confirmed in deployed store path `/nix/store/7wp6s4dvr0assijafsiavvb93a55m2mk-forgejo-mirror-github`
10. **Disk freed** — `go clean -cache` removed 69 GB, `/` went 95% → 93% (55 GB free), unblocking the deploy
11. **ShellCheck-safe** — no SC1090 (no dynamic `source`), all `curl -w "%{http_code}"` patterns
12. **Em-dash purged** from my added comment (critical rule compliance)

---

## b) PARTIALLY DONE

1. **End-to-end mirror verification** — Fix is deployed and logic-verified, but **no confirmation that all 113 repos actually mirror**. The sync timer fires in ~4h (last 01:58, next ~07:58). Cannot trigger manually (see blockers).
2. **`forgejo-ensure-repos.service` verification** — Same fix applied but the declarative repos (`dnsblockd`, `BuildFlow`) haven't been confirmed to mirror either.
3. **Push mirror setup** — The "target not found" errors in logs are now explained (they ran against unregistered repos), but I did **not** verify the push-mirror setup actually works after the orphan cleanup. The code path now only runs after a successful migrate (HTTP 200/201), which should fix it, but unverified.
4. **Disk health** — Freed 69 GB but BTRFS device-unallocated is still 1 MiB (lazy chunk reclamation). The structural ENOSPC risk is **not** resolved, only deferred.

---

## c) NOT STARTED

1. **Orphaned sops secret deletion** — `forgejo_token:` still exists encrypted in `platforms/nixos/secrets/secrets.yaml` but is now fully unused (the prior session removed it from `mkSecrets` + template). Requires sops/age key access.
2. **641 files of formatter damage cleanup** — treefmt/prettier reformatted docs, AGENTS.md tables, dashboards, lock files. I restored AGENTS.md and committed only my 3 files, but the rest sits uncommitted in the working tree. Separate cleanup decision.
3. **Push-mirror functionality audit** — Are push mirrors (Forgejo→GitHub sync-back) even desired? They were in the original script but never worked (target-not-found). Now they _should_ work but nobody has confirmed the user wants two-way sync vs. one-way mirror.
4. **`forgejo-mirror-starred` script** — Has the same `curl &&` pattern as the github-sync script had. Likely has the same silent-failure bug. Not touched this session.
5. **Monitor365 Overview failure investigation** — Deploy smoke test shows `overview.service` failing (HTTP 000 local, 502 HTTPS). Unrelated to my work but flagged.

---

## d) TOTALLY FUCKED UP

### d.1 — I almost made the silent-failure bug WORSE before making it better

**What I did:** My first fix attempt (in my head, before writing) was going to add `|| echo "failed"` to the curl chain. That would have **preserved** the exit-0-on-failure pattern. I caught this only when re-reading the diff and realizing `curl && { ... } || echo "✗"` still exits 0.

**Lesson:** `curl &&` / `||` patterns are seductive but wrong for HTTP APIs. The ONLY correct pattern is `-w "%{http_code}"` + explicit status comparison. I should have recognized this class immediately from the prior session's "sync scripts that exit 0 on partial failure are invisible" note in the handoff.

### d.2 — I deployed with BTRFS at 1 MiB device-unallocated without realizing the risk until AFTER

**What I did:** The deploy was blocked by the 95% disk check. I cleaned go-build cache, saw `df` drop to 93%, and immediately deployed. **Only after the deploy succeeded** did I check `btrfs filesystem usage` and discover device-unallocated was 1 MiB — the exact crash condition documented in AGENTS.md.

**What I should have done:** Checked `btrfs filesystem usage` BEFORE deploying. The 95% `df` check is a proxy; the real metric is device-unallocated. The deploy itself (building a new system generation) creates metadata transactions that could have triggered the I/O deadlock.

**Mitigating factor:** The deploy succeeded and the system is stable. But I gambled with documented crash risk by not checking the right metric first.

### d.3 — I trusted the handoff's "4 files modified, uncommitted" claim without verifying

**What I did:** The handoff said "4 files modified, all uncommitted." I started planning edits to files that were **already committed** (commit `3ca1ad69`). I wasted a tool call on `git status` before discovering the truth.

**Lesson:** Always `git status` + `git log` FIRST, before reading any handoff claims as ground truth. Handoffs describe a past state that may have moved.

### d.4 — I didn't check whether the push-mirror feature is even wanted

**What I did:** Faithfully fixed the push-mirror setup error reporting. But I never asked: does the user want Forgejo→GitHub push-back? The original script tried to set this up for every repo. If the user only wants one-way GitHub→Forgejo mirror, the entire push-mirror code block is dead weight that I polished instead of questioning.

---

## e) WHAT WE SHOULD IMPROVE

### e.1 — Systemic: `curl &&` is banned for HTTP APIs in this codebase

Every shell script doing HTTP API calls should use `-w "%{http_code}"` + status comparison. There should be a ShellCheck custom rule or a grep-based pre-commit check that rejects `curl.*&&` patterns in `.nix` files. The bug class has now bitten: CHANGE_ME silent failure, orphan-dir silent failure. Third time will happen unless we mechanize the prevention.

### e.2 — Systemic: Forgejo sync scripts have no integration test

The sync logic is complex (pagination, existence check, orphan cleanup, migrate, push mirror) and has failed silently twice in two sessions. A NixOS VM test that:

1. Stands up a Forgejo instance
2. Mocks the GitHub API (or uses a fixture)
3. Runs the sync script
4. Asserts repo count + no-orphan state

…would have caught both bugs at PR time. The `tests/` directory exists but has no Forgejo coverage.

### e.3 — Systemic: BTRFS device-unallocated is a load-bearing metric that `df` hides

AGENTS.md documents this, `btrfs-health.nix` monitors it, Gatus alerts on it — yet **I** (the agent with the full context loaded) still defaulted to `df` for the deploy decision. The pre-deploy-check should **fail** (not warn) when device-unallocated < 5%, independent of `df` percentage. The current check uses `df`-based 95% threshold, which is the wrong metric for BTRFS metadata ENOSPC.

### e.4 — Systemic: The `forgejo_token` sops secret is orphaned and should be deleted

It's dead code in `secrets.yaml`. Every agent reading the secrets file will wonder what it's for. Either delete it (requires sops access) or add a comment `# DEPRECATED: unused, kept for rollback safety until YYYY-MM-DD`.

### e.5 — Process: Agent handoffs should include `git log --oneline -5` output

The handoff said "uncommitted" but the work was committed. A 1-line git log in the handoff would have prevented my d.3 mistake. This is a handoff-template improvement.

### e.6 — Process: I should have a "verify deployed binary matches my commit" step as standard

I did this reactively (checking `/run/current-system/sw/bin/forgejo-mirror-github` for the orphan-cleanup string). It should be a standard post-deploy verification: `grep <signature> $(readlink -f /run/current-system/sw/bin/<tool>)`.

### e.7 — Design: `forgejo-mirror-starred` has the same bug

Same `curl &&` pattern. Same silent-failure class. Not fixed. Should be fixed in the same commit or at least ticketed.

### e.8 — Design: The sync runs as `lars` but touches forgejo-owned state

The `EnvironmentFile` loads `/var/lib/forgejo/.admin-token.env` (owned `forgejo:forgejo`, 0600). systemd reads EnvironmentFiles as root before dropping privileges, so this works — but it's fragile and undocumented. If someone refactors the service to `User=forgejo`, the token file becomes unreadable in a different way. A comment on the `EnvironmentFile` line explaining the root-read semantics would prevent confusion.

### e.9 — Design: Push mirrors need a product Decision, not a Fix

Are they wanted? If yes, verify they work end-to-end. If no, delete the code block. Polishing error messages for an unwanted feature is waste.

### e.10 — Observability: `onFailure` was wired but never fired (exit-0-on-failure)

The `onFailure` referral is useless if the script exits 0 on failure. This is now fixed for the two scripts I touched, but the pattern likely exists elsewhere. A repo-wide audit for `oneshot` services with `onFailure` where the script might exit 0 on partial failure would surface more silent bugs.

---

## f) Up to 50 things to do next (ranked by impact)

### Priority 0 — Verify / Unblock

1. **Run `sudo systemctl start forgejo-github-sync.service`** and confirm all 113 repos mirror via `curl -sf https://forgejo.home.lan/api/v1/repos/search?limit=200 | jq '.data | length'`
2. **Run `sudo systemctl start forgejo-ensure-repos.service`** and confirm `dnsblockd` + `BuildFlow` mirror
3. **Check `journalctl -u forgejo-github-sync.service -n 100`** for any remaining `✗ Failed` lines or HTTP errors
4. **Verify push mirrors work** (if wanted): `curl -sf -H "Authorization: token $FORGEJO_TOKEN" https://forgejo.home.lan/api/v1/repos/lars/go-appkit/push_mirrors | jq`
5. **Grow the BTRFS partition** (`sfdisk` → `partx` → `btrfs filesystem resize max /`) — device-unallocated is 1 MiB, this is the #1 crash risk. See `docs/troubleshooting/btrfs-metadata-enospc-recovery.md`
6. **Investigate `overview.service` failure** (502 on HTTPS, 000 local) — unrelated but broken in the last deploy

### Priority 1 — Correctness / Debt

7. **Delete orphaned `forgejo_token:` from `secrets.yaml`** (requires sops access)
8. **Fix `forgejo-mirror-starred` script** — same `curl &&` silent-failure bug
9. **Add pre-commit check** rejecting `curl.*&&` in `.nix` files (grep-based)
10. **Add pre-deploy-check** for BTRFS device-unallocated < 5% (fail, not warn)
11. **Audit all oneshot services with `onFailure`** for exit-0-on-partial-failure scripts
12. **Add comment to `EnvironmentFile` lines** explaining root-read semantics for forgejo-owned token files
13. **Decide: are push mirrors wanted?** If no, delete the code block. If yes, verify end-to-end
14. **Add `restartTriggers` to `forgejo-github-sync`** referencing the script package path, so the service restarts when the script changes (pattern used elsewhere in the codebase)

### Priority 2 — Testing / Observability

15. **Write NixOS VM test** for Forgejo sync logic (mock GitHub API, assert repo count + no orphans)
16. **Add Gatus health check** for Forgejo mirror freshness (alert if `mirror_updated` > 24h ago on any repo)
17. **Add Prometheus metric** for Forgejo repo count (detect silent mirror loss)
18. **Add Gatus alert** if Forgejo API `/repos/search?limit=1` returns non-200

### Priority 3 — Cleanup

19. **Decide on 641 files of formatter damage** in working tree — revert all, selectively commit, or ignore
20. **Audit `forgejo.nix` for other silent-failure patterns** (the runner token scripts, OIDC setup, etc.)
21. **Document the Forgejo sync architecture** in a runbook (`docs/runbooks/forgejo-sync.md`) — token source, orphan cleanup, push mirrors, failure modes
22. **Add `forgejo_token` removal** to a "sops secrets audit" task — scan for other unused secrets
23. **Consolidate `forgejo.nix` and `forgejo-repos.nix`** — they share ~80% of the migrate logic (DRY violation)

### Priority 4 — Hardening / Polish

24. **Make sync scripts idempotent** — re-running should be safe and fast (currently re-probes every repo every 6h)
25. **Add rate limiting** to GitHub API calls (avoid hitting 60/h unauthenticated or 5000/h authenticated limits)
26. **Handle GitHub pagination edge case** — if exactly N*100 repos, the loop makes one extra empty call (minor)
27. **Add `--fail-with-body` to curl calls** for better error messages (curl 7.76+)
28. **Log sync duration** as a metric (detect slow syncs indicating API throttling)
29. **Add a `--dry-run` flag** to sync scripts for safer debugging
30. **Pin the Forgejo API version** in scripts (currently `/api/v1/` — if v2 ships, scripts break silently)

### Priority 5 — Strategic

31. **Evaluate Forgejo Actions CI** — is the runner (`forgejo-runner`) actually being used? If not, remove it
32. **Evaluate mirror interval** — 8h default + 6h sync timer. Are they aligned? Should the sync trigger a mirror update immediately after migrate?
33. **Consider Forgejo backup strategy** — all repos are mirrors of GitHub, so Forgejo data loss is recoverable. But the Forgejo config (users, OIDC, tokens) is not mirrored. Document recovery procedure
34. **Evaluate moving sync logic to Forgejo's native "migration" feature** — Forgejo can mirror repos without the API script, using the UI or config. Why are we scripting it?
35. **Document why `uid: 1` is hardcoded** in the migrate payload — fragile if the admin user isn't uid 1

### Priority 6 — Nice to have

36. **Add repo descriptions** from GitHub to Forgejo mirrors (currently passed but verify they're set)
37. **Mirror GitHub organizations** (not just personal repos) — the script only fetches `/users/$USER/repos`
38. **Mirror GitHub gists** — if desired
39. **Add a Forgejo dashboard tile** to Homepage showing mirror sync status
40. **Sync GitHub stars/likes** to Forgejo (if supported)
41. **Handle renamed/moved GitHub repos** — the mirror would break; detect and re-create
42. **Handle deleted GitHub repos** — the mirror becomes stale; detect and archive/delete in Forgejo
43. **Add Forgejo webhook** to trigger sync on GitHub push (event-driven instead of polling)
44. **Evaluate `gh` CLI vs raw API calls** — the script uses both inconsistently
45. **Add ShellCheck CI** for all `writeShellApplication` scripts (beyond the build-time check)
46. **Document the `forgejo-generate-token` → sync-service dependency chain** in a diagram
47. **Evaluate using Forgejo's `forgejo admin user create` for the admin user** declaratively instead of the current imperative script
48. **Add a `forgejo-doctor` script** that checks: token valid, admin user exists, OIDC source configured, repos mirror count > 0
49. **Migrate sync scripts from bash to Go** — they're complex enough that the lack of types is a liability
50. **Evaluate Forgejo federation** — if the instance is ever public, federation (ActivityPub) changes the mirror strategy entirely

---

## g) Questions I CANNOT figure out myself

### g.1 — Do you want push mirrors (Forgejo→GitHub sync-back) at all?

The original script tried to set up push mirrors for every repo (`sync_on_commit: true`). They never worked (target-not-found, because the repo wasn't registered). My fix means they'll now _try_ to work. But I don't know if you want two-way sync or one-way GitHub→Forgejo mirror.

**Why I can't figure this out:** The original script's intent is ambiguous — it could be aspirational (never worked, never noticed) or deliberate (wanted, broken, never reported). The AGENTS.md doesn't mention push mirrors. The migrate payload includes `mirror: true` (one-way pull) AND sets up push mirrors (two-way), which is contradictory unless you want Forgejo commits to flow back to GitHub.

**Impact:** If unwanted, I should delete the push-mirror code block (simplifies the script, removes a failure mode). If wanted, I need to verify it works end-to-end after the orphan cleanup.

### g.2 — Can you trigger the sync so I can verify the fix end-to-end?

The sync timer fires in ~4h (next ~07:58). I cannot trigger it manually:

- `sudo systemctl start forgejo-github-sync.service` — sudo unavailable to me
- `busctl call ... StartUnit` — Access denied (requires interactive auth)
- Running the script directly — `FORGEJO_TOKEN` is in `/var/lib/forgejo/.admin-token.env` (0600, forgejo-owned, unreadable by lars)

**Why I can't figure this out:** The permission split (sync service runs as `lars`, token file owned by `forgejo`) works via systemd's root-time EnvironmentFile read, but I have no way to replicate that outside systemd.

**Impact:** Without triggering, I can only verify the fix at the logic level (deployed script contains orphan-cleanup, API shows 7 repos, error pattern matches diagnosis). The actual "113 repos mirror" claim is unverified.

### g.3 — Should I clean up the 641 files of formatter damage in the working tree, and if so, how?

The working tree has 641 modified files — almost entirely formatter damage (treefmt/prettier reformatted markdown tables, docs, dashboards, `flake.lock`, `pkgs/jscpd-pnpm-lock.yaml`). Not mine. I restored AGENTS.md and committed only my 3 files.

**Why I can't figure this out:** I don't know if:

- (a) You want these reformatted (commit them all)
- (b) You want them reverted (`git checkout .` on the non-mine files)
- (c) They're from a `nix fmt` run you intended to review selectively
- (d) They're from a prior agent session you haven't reviewed yet

**Impact:** The working tree is noisy. Any future `git add -A` will sweep up 638 unrelated files. The `flake.lock` change in particular may be intentional or accidental.

---

## Session metrics

- **Tool calls:** ~25
- **Files modified:** 3 (committed), 0 (left dirty)
- **Commits:** 1 (`2d12a613`)
- **Deploys:** 1 (successful)
- **Disk freed:** 69 GB (go-build cache)
- **Repos fixed:** 113 (claimed, 7 verified, 106 pending verification)
- **Time:** ~4h

---

## Commit

```
2d12a613 fix(forgejo): clear orphan git dirs so all GitHub repos mirror, not just 7
3ca1ad69 fix: eliminate CHANGE_ME placeholder from Forgejo GitHub-sync and prevent silent auth failures  (prior session)
```

---

> **RESOLVED — Resolved. Work captured in CHANGELOG.md.**
> All forward-looking items in this report were completed in subsequent sessions.
