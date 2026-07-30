# Session Review: SearXNG Build Failure Fix (SC2034 Shellcheck)

**Date:** 2026-07-29 21:30
**Session Duration:** ~5 minutes
**Outcome:** Build unblocked, fix verified, NOT committed, NOT deployed

---

## What Happened

A `nix run .#deploy` failed with a cascading build error originating from a single derivation: `searxng-wait-dns`. The `writeShellApplication` wrapper runs shellcheck, which flagged SC2034 (variable `i` appears unused) on the loop `for i in $(seq 1 60); do`. Shellcheck warnings are treated as errors by `writeShellApplication`, failing the derivation. This cascaded: `searxng-wait-dns` → `unit-searx.service` → `system-units` → `etc` → `activate` → `nixos-system-evo-x2` — the ENTIRE system build died from one unused loop variable.

## The Fix

`modules/nixos/services/searxng.nix:62`: changed `for i in $(seq 1 60)` → `for _ in $(seq 1 60)`. The underscore is the repo-wide convention for throwaway loop variables (used in 7 other files: `dns-blocker.nix`, `twenty.nix`, `_forgejo-scripts.nix`, `niri-wrapped.nix`, `dnsblockd-cert-trust.nix`).

---

## a) FULLY DONE

1. **Root cause identified** — SC2034 shellcheck failure in `searxng-wait-dns` `writeShellApplication`
2. **Fix applied** — `i` → `_` matching repo convention
3. **Fix verified** — individual derivation builds (`nix build` exit 0), `nix flake check --no-build` passes
4. **Codebase scanned** — grep confirmed NO other `for [a-z] in $(seq` patterns exist (all 7 other loops already use `_`)

## b) PARTIALLY DONE

1. **Build verification** — ran `nix flake check --no-build` (syntax/eval only). Did NOT run a full `nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel` to confirm the ENTIRE system compiles end-to-end. The flake check passing is strong evidence, but not a full build proof.

## c) NOT STARTED

1. **Commit** — the fix is uncommitted (`git status` shows `M modules/nixos/services/searxng.nix`)
2. **Deploy** — `nix run .#deploy` was NOT run after the fix
3. **AGENTS.md update** — the SC2034 / `writeShellApplication` shellcheck lesson is NOT documented in the gotchas table
4. **Post-deploy smoke test** — `nix run .#post-deploy-check` not run (deploy didn't happen)

## d) TOTALLY FUCKED UP

Nothing. The fix is correct and minimal. But there are process failures worth calling out (see below).

---

## e) WHAT WE SHOULD IMPROVE — Brutal Self-Review

### Process Failures This Session

1. **DID NOT check `git status` / `git log` FIRST.** I jumped straight to `grep` for the error string. Had I checked git history first, I would have immediately seen that `searxng.nix` was modified 5 hours ago (commit `9ad073d6`, 2026-07-29 16:48) — the DNS gate was freshly added and NEVER build-tested before committing. This is the real story: **code was committed without `nix flake check --no-build`**. The auto-git daemon strikes again — it committed code that doesn't build.

2. **DID NOT run a full system build after the fix.** I built the individual derivation and ran `flake check --no-build`. The user's original error was a full system build failure. I should have at least attempted `nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel` to prove the ENTIRE chain builds, not just the leaf derivation.

3. **DID NOT update AGENTS.md.** The AGENTS.md gotcha table has a "SearXNG engine init DNS race (FIXED 2026-07-29)" entry that describes the `searxng-wait-dns` ExecStartPre gate. It does NOT mention that `writeShellApplication` enforces shellcheck and that unused loop variables must use `_`. This is a general Nix lesson worth adding: **`pkgs.writeShellApplication` runs shellcheck with warnings-as-errors — ALL unused variables, not just loop variables, will break the build.**

4. **DID NOT proactively scan ALL `writeShellApplication` blocks.** I scanned for `for [a-z] in $(seq` patterns (the specific failure), but I did NOT scan for other common shellcheck failures in `writeShellApplication` text blocks across the repo (unused variables, unquoted variables, `echo $(...)` subshells, etc.). There could be latent time bombs in other `writeShellApplication` blocks that haven't been triggered yet because those code paths weren't exercised.

5. **Root cause of the root cause not addressed.** The REAL problem isn't `i` vs `_` — it's that **the auto-git daemon commits code without build verification**. This is at least the Nth time a committed change broke the build (the AGENTS.md documents dozens of similar incidents). The fix should be a **pre-commit hook that runs `nix flake check --no-build`** (or at minimum `nix eval` on changed modules). There IS a pre-commit hook for statix/alejandra (documented in gotchas), but NOT for `nix flake check`. This would have caught the SC2034 before it ever reached `master`.

### Architectural Observations

6. **`writeShellApplication` is a footgun.** It silently enforces shellcheck with `-E all` (all warnings as errors). This is GOOD for code quality but BAD for developer experience when the error only surfaces at build time (which can be minutes into a deploy). The alternative — `writeShellScriptBin` or `writeBashApplication` — skips shellcheck entirely but loses the safety. The right answer is probably: keep `writeShellApplication` but add `excludeShellChecks` for known-safe warnings, OR ensure CI/pre-commit catches it before deploy.

7. **The DNS gate pattern is duplicated.** The `waitDnsReady` pattern (loop + `getent hosts` + sleep) appears in `dns-blocker.nix`, `twenty.nix`, `_forgejo-scripts.nix`, `dnsblockd-cert-trust.nix`, and now `searxng.nix`. Each is a slightly different implementation. This should be a **shared helper in `lib/`** — e.g., `mkDnsGate { hostname = "wikidata.org"; timeout = 120; }` — that produces the `writeShellApplication` consistently, with `_` by construction.

---

## f) NEXT 50 THINGS TO GET DONE

### Immediate (this fix)
1. **Commit the searxng.nix fix** (`i` → `_`)
2. **Deploy** (`nix run .#deploy`)
3. **Run post-deploy smoke test** (`nix run .#post-deploy-check`)
4. **Verify SearXNG engines init correctly** — check `searx.service` logs for "DNS resolution ready", confirm wikidata/radio-browser engines are NOT disabled

### Short-term (shellcheck / build safety)
5. **Add `nix flake check --no-build` pre-commit hook** — catches eval-time + shellcheck failures before commit
6. **Scan ALL `writeShellApplication` blocks in the repo** for shellcheck issues (`grep -rn 'writeShellApplication' modules/ platforms/ pkgs/ lib/`)
7. **Extract `mkDnsGate` helper** into `lib/default.nix` — DRY the 5+ duplicated DNS-wait patterns
8. **Add AGENTS.md gotcha entry** for `writeShellApplication` + shellcheck SC2034
9. **Audit the auto-git daemon** — does it run ANY validation before committing? If not, add at minimum `nix flake check --no-build`
10. **Add `nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel`** to CI or pre-deploy-check — `flake check --no-build` catches eval errors but NOT all build-time failures

### SearXNG module health
11. **Verify SearXNG is actually running** post-deploy (the DNS gate was just added; the service may have other issues)
12. **Check SearXNG Gatus health check** — is `searxng` showing green?
13. **Verify SearXNG search actually works** — not just `/healthz`, but an actual search query returns results
14. **Confirm the Brave 429 issue** — AGENTS.md notes "Brave 429 too many requests" as transient; verify it self-resolves
15. **Test SearXNG from a browser** via `searxng.home.lan` — DNS resolution, Caddy vHost, forward-auth, actual search

### Build system robustness
16. **Run a full system build** (`nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel`) to confirm zero other build failures
17. **Check flake.lock** — it's modified (`M flake.lock`); verify the lock update is intentional and doesn't introduce other issues
18. **Review the auto-git daemon's commit `717edcdb`** — "chore(flake): update flake.lock" — did this lock update introduce the searxng changes or are they independent?

### Documentation
19. **Update the "SearXNG engine init DNS race" gotcha** to mention the shellcheck SC2034 build failure
20. **Document the `writeShellApplication` shellcheck enforcement** as a general gotcha (not SearXNG-specific)
21. **Consider a "Common Nix Build Failures" doc** — SC2034, vendorHash, FOD purity, etc. are all recurring patterns

### Technical debt (from AGENTS.md observations)
22. **Extract `mkHttpCheck` and `discordAlert` patterns** into a Gatus helper module (partially done?)
23. **Add `CPUQuota` to ALL `writeShellApplication`-based services** — these run shell scripts that could loop
24. **Audit all `writeShellApplication` blocks for `RuntimeInputs` completeness** — missing runtime deps cause `status=127`
25. **Consider `writeShellScriptBin` for simple gate scripts** where shellcheck strictness isn't worth the overhead

### Broader SystemNix improvements (noticed during this session)
26. **The AGENTS.md gotcha table is ENORMOUS** (~100+ entries) — consider splitting into `docs/gotchas/` by category (Caddy, systemd, Nix, SearXNG, etc.)
27. **No automated test for "does the system build?"** — `nix flake check --no-build` catches eval, but `nix run .#deploy` is the only full build test, and it's manual
28. **The deploy script (`deploy.sh`) runs `reset-failed` + `nh os switch` but doesn't pre-validate the build** — `pre-deploy-check` catches boot issues but not shellcheck failures
29. **Consider adding shellcheck to treefmt/pre-commit** for `.sh` files AND `writeShellApplication` text blocks
30. **The `restartTriggers` pattern** (package path changes → service restarts) should be audited across ALL services — some may be missing it (silent stale-process bugs)

### Process improvements
31. **Add a "build gate" to the auto-git daemon** — never commit without `nix flake check --no-build` passing
32. **Add a "deploy gate" to `deploy.sh`** — `nix build` the toplevel BEFORE `nh os switch`, fail fast on build errors
33. **Consider `nix flake check --build`** (full build) in CI — expensive but catches everything
34. **Add `shellcheck` to `devShell`** — so developers can `shellcheck script.sh` locally before wrapping in `writeShellApplication`
35. **Template for DNS-gate scripts** — standardize the pattern across all services

### Monitoring gaps noticed
36. **No Gatus check for "is the system buildable?"** — a daily CI job that builds the toplevel would catch regressions early
37. **No alert when auto-git commits a broken build** — the daemon commits silently; a broken build can sit on master for hours
38. **Post-deploy-check doesn't validate SearXNG search** — only checks `/healthz` (HTTP 200), not actual search functionality
39. **Gatus SearXNG check** — verify it includes `[RESPONSE_TIME]` condition per AGENTS.md rule 9
40. **Monitor auto-git daemon health** — is it logging? committing at expected intervals?

### Future considerations
41. **Migrate DNS-gate scripts to a NixOS `ExecStartPre` with `pkgs.writeShellScriptBin`** — less strict than `writeShellApplication` but avoids shellcheck false positives on intentional patterns
42. **Consider `systemd` `ExecStartPre=` with inline scripts** — no shellcheck at all, but loses type safety
43. **Add `bash` LSP to devShell** — `bash-language-server` provides inline shellcheck feedback in editors
44. **Audit all `text = ''...''` blocks in the repo** for potential shellcheck issues (not just `writeShellApplication`)
45. **Add a `nix-shell -p shellcheck --run 'shellcheck ...'` devShell command** for quick local checks
46. **Consider `nix develop .#shellcheck`** devShell with shellcheck pre-installed
47. **Document the `writeShellApplication` vs `writeShellScriptBin` decision tree** — when to use which
48. **Add `# shellcheck disable=SC2034` as an escape hatch pattern** in AGENTS.md for cases where `_` isn't appropriate
49. **Review if `enableLocalIcons = true` for homepage-dashboard** is still needed or if the icon situation has improved upstream
50. **Celebrate** — the fix was correct, fast, and minimal. The process gaps are the real lesson.

---

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **Should I commit and deploy this fix now, or do you want to review the `flake.lock` changes first?** — `flake.lock` is modified (`M flake.lock`, 68 lines changed from commit `717edcdb`). I don't know if those lock changes are related to the SearXNG work or independent. Deploying with an unreviewed lock update could pull in unintended dependency changes.

2. **Does the auto-git daemon have any build-validation step before committing?** — If yes, why did it commit a broken `searxng.nix`? If no, should we add `nix flake check --no-build` as a pre-commit gate? (I can check the daemon config, but I don't know where it lives or if it's your personal tool vs a project tool.)

3. **Is the `searxng-wait-dns` DNS gate even the right approach?** — The AGENTS.md documents that `dnsblockd.service` is `Type=simple` and `After=`/`Wants=` alone don't guarantee DNS readiness. But `systemd` has `Type=notify` + `sd_notify(READY=1)` for proper readiness signaling. Should `dnsblockd` be patched to send `READY=1` instead of every consumer running its own `getent` poll loop? This would eliminate ALL the duplicated DNS-gate scripts at once.

---

## Summary

| Category | Status |
|----------|--------|
| Build error | FIXED (`i` → `_`) |
| Verified | `nix flake check --no-build` passes, individual derivation builds |
| Full system build | NOT verified (only eval check) |
| Committed | NO |
| Deployed | NO |
| AGENTS.md updated | NO |
| Root cause (auto-git commits broken code) | NOT addressed |
| Root cause (no build gate) | NOT addressed |

**One-character fix, correct and minimal. But I skipped the full-build verification, didn't update docs, and didn't address the systemic issue (auto-git daemon commits without build checks). The fix is done; the process that created the bug is not.**

---

## Resolution (2026-07-30)

The one-character fix (`i` -> `_`) was committed (`d09f6693`) and deployed in a subsequent deploy. SearXNG builds cleanly with the DNS boot-race fix active. The `searxng-wait-dns` ExecStartPre runs successfully on boot.
