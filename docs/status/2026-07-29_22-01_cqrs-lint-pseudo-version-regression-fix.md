# Status Report: cqrs-lint Pseudo-Version Regression Fix — 2026-07-29 22:01

> **Scope:** Fixed a regression where go-cqrs-lite commit `b0d76b68` re-broke
> the cqrs-lint Nix build by reverting `go-finding` back to a zero pseudo-version.
> This session re-applied the correct fix (v1.4.1), pushed upstream, updated
> SystemNix flake.lock, and verified the build end-to-end.

---

## Timeline — What Actually Happened Across Both Sessions

| Time      | Commit      | Action                                                                    | Correct? |
| --------- | ----------- | ------------------------------------------------------------------------- | -------- |
| 21:10     | `8a34163d`  | Bumped go-finding to v1.4.1 (fix from first session)                      | YES      |
| ~21:33    | `b0d76b68`  | **Reverted** to pseudo-version, claiming "v1.4.1 not published"           | **NO**   |
| ~21:33    | `d0792702`  | Status report written documenting the (now wrong) pseudo-version fix      | Stale    |
| 22:01     | `649bcd5f`  | Re-applied v1.4.1 (this session)                                          | YES      |

**Critical insight:** The previous session already diagnosed and fixed this
exact problem. A subsequent commit (`b0d76b68`) **reverted the fix** based on a
false assumption that `v1.4.1` was not published. `v1.4.1` IS tagged and
available on `github.com/larsartmann/go-finding`. This was a regression, not a
new bug.

---

## a) FULLY DONE

| Item                                                       | Status  | Evidence                                              |
| ---------------------------------------------------------- | ------- | ----------------------------------------------------- |
| Root-caused the Nix build failure                          | Done    | Traced to pseudo-version in go.mod + `go mod tidy`    |
| Verified `v1.4.1` IS published                             | Done    | `git tag -l 'v*'` on go-finding shows `v1.4.1`        |
| Fixed go.mod in go-cqrs-lite (pseudo-version -> v1.4.1)    | Done    | Commit `649bcd5f`                                     |
| Ran `go mod tidy` to ensure go.sum consistency             | Done    | Clean exit, only go.mod line changed                  |
| Built cqrs-lint from go-cqrs-lite via Nix                  | Done    | 3 derivations built successfully                      |
| Pushed fix to go-cqrs-lite remote                          | Done    | `b0d76b68..649bcd5f master -> master`                 |
| Updated SystemNix `flake.lock` for go-cqrs-lite            | Done    | Lock updated to `649bcd5fec26338...`                  |
| Built cqrs-lint from SystemNix                             | Done    | 3 derivations built successfully                      |
| Verified binary runs                                       | Done    | `cqrs-lint version 0.2.2`                             |
| Cleaned up debug artifacts (/tmp/cqrs-lint-debug)          | Done    | `rm -rf` executed                                     |

---

## b) PARTIALLY DONE

1. **SystemNix flake.lock commit** — The lock file is updated and the build
   passes, but the change is **UNCOMMITTED** (` M flake.lock`). It needs to be
   committed to take effect on deploy.

2. **SystemNix AGENTS.md gotcha documentation** — I identified that the
   pseudo-version trap should be documented but did NOT add it. The existing
   gotcha table already has a `cqrs-lint samber-do-auditlog version drift`
   entry; a new entry for the pseudo-version regression class is needed.

3. **Stale status report annotation** — The go-cqrs-lite repo has
   `docs/status/2026-07-29_21-10_cqrs-lint-nix-build-fix.md` which documents
   the fix as "bump to v1.4.1". Then commit `b0d76b68` reverted that fix with a
   status report claiming the opposite. Neither report reflects the final state.
   These should be annotated with the resolution.

---

## c) NOT STARTED

1. **`nix flake check --no-build`** on SystemNix to verify no eval errors from
   the flake.lock change.
2. **Functional test** of cqrs-lint beyond `--version` (e.g. `cqrs-lint doctor`
   or running it against a real project).
3. **Checking other consumers** of the go-cqrs-lite flake input to see if any
   are affected by the commit change.
4. **Preventive CI check** for zero pseudo-versions in committed go.mod files.

---

## d) TOTALLY FUCKED UP

1. **The regression itself (commit `b0d76b68`)** — A commit explicitly reverted
   a correct fix based on a FALSE claim ("v1.4.1 has not been published as a git
   tag yet"). `v1.4.1` was tagged. The commit message was detailed and confident
   but factually wrong. This wasted an entire session re-diagnosing and
   re-fixing the same problem.

2. **The stale status report (`d0792702`)** — Written alongside the regression
   commit, it documents the pseudo-version as the fix, creating a misleading
   historical record. Anyone reading the repo history would see two conflicting
   "fixes" for the same issue within 30 minutes.

---

## e) WHAT WE SHOULD IMPROVE

### Process Failures

1. **Verify assumptions before acting.** The commit `b0d76b68` claimed v1.4.1
   wasn't published. A 2-second `git tag -l 'v1.4.1'` would have disproven this.
   The commit was made with confidence but without verification. **Always verify
   factual claims before committing, especially when reverting another fix.**

2. **Status reports should be written AFTER verification, not alongside the
   commit.** The stale report `d0792702` was committed simultaneously with the
   wrong fix, creating a permanent misleading record. Write the report only after
   the build is green.

3. **I should have checked the git history of the file BEFORE fixing.** If I had
   run `git log --oneline cmd/cqrs-lint/go.mod` first, I would have immediately
   seen that v1.4.1 was ALREADY the version before `b0d76b68` reverted it. This
   would have saved diagnostic time.

### Technical Improvements

4. **Add a pre-commit/CI guard for zero pseudo-versions.** The string
   `v0.0.0-00010101000000-000000000000` should NEVER appear in a committed
   go.mod (except as a `replace` source target in workspace setups, which
   mkPreparedSource handles). A simple grep check would catch this class of bug
   before it breaks a Nix build.

5. **mkPreparedSource should warn or error on main-dep pseudo-versions.**
   Currently it normalizes sub-module pseudo-versions but silently passes
   through main-dep ones. At minimum, a warning during the prepared-source
   phase would surface this earlier.

6. **The go-cqrs-lite AGENTS.md is 944 lines** (BuildFlow flagged it, max 377).
   This is the go-cqrs-lite repo's issue, not SystemNix's, but it was visible
   during the session.

### What I Did Well

7. I correctly diagnosed the root cause by examining the Nix build log, the
   prepared source go.mod, and running `go mod tidy` on the prepared source.
8. I verified `v1.4.1` was actually tagged before committing.
9. I verified the build from BOTH repos (go-cqrs-lite and SystemNix).
10. I committed upstream with a detailed commit message explaining the
    root cause and why the revert was wrong.

---

## f) Up to 50 Things We Should Get Done Next

### Immediate (blocks deploy)

1. **Commit the SystemNix flake.lock change** — `flake.lock` is modified but
   uncommitted. This is the #1 blocker.
2. **Run `nix flake check --no-build`** on SystemNix to confirm no eval errors.
3. **Run `nix build .#cqrs-lint` one more time** from a clean state to confirm
   reproducibility.

### Documentation

4. **Add SystemNix AGENTS.md gotcha entry** for the pseudo-version regression:
   "go-cqrs-lite cqrs-lint pseudo-version regression — zero pseudo-versions in
   main deps break mkPreparedSource builds."
5. **Annotate the stale status report** in go-cqrs-lite
   (`docs/status/2026-07-29_21-10_cqrs-lint-nix-build-fix.md`) with a resolution
   note pointing to commit `649bcd5f`.
6. **Add a CONTRIBUTING note** in go-cqrs-lite: "Never commit
   `v0.0.0-00010101000000` to any go.mod require line."

### CI / Pre-commit Hardening

7. **Add a grep guard to go-cqrs-lite's pre-commit** that rejects commits with
   `v0.0.0-00010101000000` in go.mod require lines.
8. **Add the same guard to SystemNix's pre-commit** for any vendored go.mod.
9. **Consider a `check-modules` enhancement** in go-cqrs-lite that validates
   no pseudo-versions exist.
10. **Add cqrs-lint Nix build to go-cqrs-lite CI** (`ci.yml`) if not already
    there — the regression was caught only when SystemNix tried to build.

### mkPreparedSource Improvements (upstream go-nix-helpers)

11. **Add a warning in mkPreparedSource** when a main dep has a zero
    pseudo-version in go.mod.
12. **Consider normalizing main-dep pseudo-versions** the same way sub-modules
    are handled (more complex but eliminates the asymmetry).
13. **Add a test in go-nix-helpers** that verifies mkPreparedSource handles
    both pseudo-version and real-version main deps correctly.

### Verification

14. **Run `cqrs-lint doctor`** to verify the binary works functionally.
15. **Run cqrs-lint against a real consumer project** (e.g. discordsync) to
    confirm the linting functionality works.
16. **Run `nix run .#deploy` (dry-run or eval-only)** to confirm SystemNix
    config still evaluates with the updated flake.lock.
17. **Check if any other SystemNix packages consume go-cqrs-lite** and verify
    they still build.

### Stale Report Cleanup

18. **Audit ALL go-cqrs-lite status reports from 2026-07-29** — there are two
    conflicting reports about the same issue; reconcile them.
19. **Add a "Resolution" section** to the `21-10` report pointing to `649bcd5f`.
20. **Add a "Resolution" section** to the `b0d76b68` commit's report explaining
    the revert was wrong.

### Broader go-cqrs-lite Health (spotted during session)

21. **39 GitHub vulnerabilities** were flagged on push (21 critical, 6 high,
     12 moderate). These are likely Dependabot alerts — review and address.
22. **govalid-generate failed** on 6 modules during BuildFlow (catalog, schema,
     dispatcher, example/getting-started). Investigate.
23. **gomod-check flagged 74 findings** — direct/indirect requires mixed in
     74 go.mod files. This is a formatting issue across the monorepo.
24. **go-cqrs-lite AGENTS.md is 944 lines** — should be trimmed to <377 per
     go-structure-linter.

### Build Infrastructure

25. **Verify `vendorHash` in go-cqrs-lite flake.nix** (line 343) is stable after
    the go.mod change — the hash didn't change this time but confirm.
26. **Check if `proxyVendor = true`** is still needed now that go-finding is
    properly versioned.
27. **Audit all cmd/* go.mod files** in go-cqrs-lite for the same pseudo-version
    bug class (cqrs-gen, cqrs-bench, api-stability, doc-check).
28. **Run `go work sync`** in go-cqrs-lite to ensure workspace versions are
    aligned after the fix.

### SystemNix Integration

29. **Verify cqrs-lint is actually used in SystemNix** — check
     `lib/lars-packages.nix` and any modules that reference it.
30. **Check if cqrs-lint is in any devShell** or pre-commit config in SystemNix.
31. **Run the SystemNix pre-deploy-check** to confirm nothing else broke.
32. **Verify the SystemNix post-deploy-check** still passes with the new binary.

### Future Prevention

33. **Add a `verify-nix` target to go-cqrs-lite** that builds all Nix packages
     (`cqrs-lint`, `default`) as part of CI.
34. **Consider pinning go-cqrs-lite to tags** instead of `ref=master` in
     SystemNix flake inputs to prevent regressions from unreviewed commits.
35. **Add a `CODEOWNERS` rule** for go.mod files in go-cqrs-lite requiring
     review before changes.
36. **Document the daemon's interaction with go.mod** — if an auto-commit daemon
     runs `go mod tidy`, it can introduce pseudo-versions when local replaces
     are active.
37. **Add a regression test** that builds cqrs-lint from a clean Nix store to
     catch mkPreparedSource issues.

### Lower Priority

38. **Review go-finding's release process** — ensure tags are pushed BEFORE
     consumers reference them.
39. **Consider versioning go-finding/pipeline** separately if it diverges.
40. **Audit go-cqrs-lite's `deps` map** in mkCqrsLintSource for completeness.
41. **Check if cqrs-lint's `vendorHash` needs a comment** explaining how to
     update it when deps change.
42. **Review whether the `-config` naming convention** applies to cqrs-lint
     in SystemNix.
43. **Verify cqrs-lint overlay** (`overlays.cqrs-lint`) works with the new
     version.
44. **Check if any SystemNix service depends on cqrs-lint at runtime** (unlikely
     but worth confirming).
45-50. _(Reserved for items discovered during follow-up work.)_

---

## g) Questions I CANNOT Figure Out Myself

1. **Who/what created commit `b0d76b68`?** The commit reverts a correct fix
   with a detailed but wrong justification. Was this an AI agent, the auto-commit
   daemon, or a manual commit? Understanding the source would help prevent
   recurrence. The commit says "Generated with Crush" — was this a previous
   Crush session that made an incorrect diagnosis?

2. **Should SystemNix pin go-cqrs-lite to a specific tag/commit instead of
   `ref=master`?** This regression was introduced by a bad commit on master.
   Pinning to tags (or specific commits verified by CI) would prevent unreviewed
   upstream changes from breaking SystemNix builds. But it adds maintenance
   overhead (manual bumps). This is a policy decision.

3. **Should the auto-commit daemon in go-cqrs-lite be allowed to modify go.mod
   files?** If the daemon runs `go mod tidy` with local `replace` directives
   active, it can introduce zero pseudo-versions. Should go.mod files be
   excluded from daemon auto-commits, or should the daemon run in a mode that
   strips local replaces before tidying?

---

## Verification Commands Run This Session

```bash
# Diagnosis
nix log /nix/store/1gbv3rvaf93...cqrs-lint-b0d76b68...drv          # "go mod tidy needed"
cat /nix/store/r0dxz8mds7n4.../go.mod                               # pseudo-version confirmed
cd /tmp/cqrs-lint-debug && go mod tidy                              # wants v1.4.1
cd /home/lars/projects/go-finding && git tag -l 'v*'               # v1.4.1 EXISTS

# Fix
# (edit cmd/cqrs-lint/go.mod: pseudo-version -> v1.4.1)
cd cmd/cqrs-lint && go mod tidy                                     # clean

# Upstream verification
cd /home/lars/projects/go-cqrs-lite && nix build .#cqrs-lint       # PASS

# Push
git push origin master                                              # b0d76b68..649bcd5f

# SystemNix verification
cd /home/lars/projects/SystemNix
nix flake lock --update-input go-cqrs-lite                          # lock updated
nix build .#cqrs-lint                                               # PASS
./result/bin/cqrs-lint --version                                    # 0.2.2
```

---

**Bottom line:** The build is fixed and verified from both repos. The
SystemNix `flake.lock` change is uncommitted (blocking deploy). The root cause
was a regression — a commit that incorrectly reverted a correct fix. The #1
prevention is a CI guard against zero pseudo-versions in committed go.mod files.
