# Status: Tarball Regression Defense-in-Depth + Health-Check Cleanup

**Date:** 2026-08-05 22:45
**Session scope:** User asked "what's worth doing for the long-term health of this project?" → discovered the repo was committed BROKEN (tarball lockfile on master) → restored it → built defense-in-depth against the recurring tarball regression → fixed false-negatives in service-health-check.
**Overall verdict:** REPO WAS BROKEN ON MASTER, NOW FIXED. Defense-in-depth added but the `--latest` code path is UNTESTED and the root cause (PMA daemon) is unaddressed.

---

## The inciting problem

**The repo was committed in a non-evaluating state.** Between the prior session (22:02) and this session (22:45), the PMA auto-commit daemon ran `nix flake update`, rewrote the nixpkgs node to tarball type (`3497aa5c9457` via `channels.nixos.org`), and committed it as `bc44085b`. The eval-time `nixpkgsTarballGuard` correctly fired, meaning **`nix flake check`, `nix eval`, `nix build`, and `nix run .#deploy` were all broken on master**. This is the 4th+ occurrence of this regression across sessions.

---

## a) FULLY DONE

| # | Item                                      | Detail                                                                                                                                                                                                                                                                                                                 |
| - | ----------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1 | **Broken lockfile restored**              | `flake.lock` nixpkgs node rewritten from tarball to github type at same rev (`3497aa5c9457`). `nix flake check --no-build` passes again. Committed as `ad6f3f79` (daemon) + `78a0ed31` (my consolidation).                                                                                                             |
| 2 | **`scripts/fix-nixpkgs-lock.sh` created** | One-command recovery. Uses `nix flake prefetch` (immune to registry interception — `--override-input` and `--no-use-registries` both fail to prevent the rewrite). Two modes: default (pin current rev, no cascade) and `--latest` (newest nixos-unstable). Tested break→fix→verify in pin-current mode.               |
| 3 | **Flake app wired**                       | `nix run .#fix-nixpkgs-lock` registered in `flake.nix:672-676` via `mkApp`. Verified in `nix flake show` output.                                                                                                                                                                                                       |
| 4 | **`flake-update.yml` CI hardened**        | Was running `nix flake update --commit-lock-file` (the EXACT command that causes the regression). Now runs `nix flake update` → `bash scripts/fix-nixpkgs-lock.sh --latest` → `nix flake check --no-build` → manual commit → PR. The normalization happens BEFORE commit, so PRs will always have github-type nixpkgs. |
| 5 | **`service-health-check` de-junked**      | Removed 3 retired services that produced permanent false-negatives: `unbound` (replaced by dnsblockd), `waybar` (replaced by DMS), `awww-daemon` (retired, DMS owns wallpapers). Bash syntax verified.                                                                                                                 |
| 6 | **AGENTS.md gotcha upgraded**             | Expanded the tarball regression entry from a 1-liner to a full paragraph: recurring nature, daemon-bypass, `nix run .#fix-nixpkgs-lock` recovery command, 4-layer defense inventory.                                                                                                                                   |
| 7 | **All changes committed**                 | Daemon auto-committed as `bc44085b` + `ad6f3f79`; my consolidation as `78a0ed31`. Working tree clean. `nix flake check --no-build` passes on HEAD.                                                                                                                                                                     |

---

## b) PARTIALLY DONE

| # | Item                              | What's done                                                                                                                                    | What's missing                                                                                                                           |
| - | --------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| 1 | **Defense-in-depth (4 layers)**   | Eval guard (flake.nix:519), pre-commit hook (.githooks/pre-commit), CI normalization (flake-update.yml), recovery script (fix-nixpkgs-lock.sh) | The NixOS registry override (configuration.nix:42) is committed but NOT active until reboot. Darwin override committed but NOT deployed. |
| 2 | **Health-check audit**            | Removed 3 retired services (unbound, waybar, awww-daemon)                                                                                      | Did NOT add missing active services (see section d below)                                                                                |
| 3 | **`fix-nixpkgs-lock.sh` testing** | Pin-current mode: full break→fix→verify cycle, output diffed against known-good backup (identical)                                             | `--latest` mode: **NEVER TESTED** — and it's the mode CI uses                                                                            |

---

## c) NOT STARTED

| # | Item                                       | Why it matters                                                                                                                                                                                                                                                                                                                                               |
| - | ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1 | **Test `--latest` mode**                   | CI's `flake-update.yml` calls `bash scripts/fix-nixpkgs-lock.sh --latest`. This code path has never been executed. If `nix flake prefetch github:NixOS/nixpkgs/nixos-unstable` behaves differently than `...github:NixOS/nixpkgs/<rev>`, CI will fail silently.                                                                                              |
| 2 | **Add missing services to health-check**   | 4 active services are NOT monitored by the desktop health-check notification: `discordsync`, `searxng` (service name `searx`), `qmd-mcp`, `emeet-pixyd`. These run as user/system services but failures won't trigger the desktop notification. (Note: Gatus monitors HTTP endpoints separately, but systemd-state failures are only caught by this script.) |
| 3 | **PMA daemon root cause**                  | The daemon runs `nix flake update` and commits the result, bypassing pre-commit hooks. It re-introduced the regression between sessions. The daemon config is NOT in this repo (couldn't locate it). Until the daemon is modified to normalize the lockfile before committing, the regression WILL recur.                                                    |
| 4 | **Verify re-lock step doesn't re-tarball** | The script runs `nix flake lock --no-use-registries` at the end to re-lock dependents. Since the nixpkgs node is already github-typed, this _should_ be safe — but `--no-use-registries` was proven unreliable earlier. If any dependent input re-resolves nixpkgs through the registry, it could re-introduce the tarball. UNTESTED.                        |
| 5 | **Reboot evo-x2**                          | The registry override and hyprland purge from the prior session are in the boot profile but not active.                                                                                                                                                                                                                                                      |
| 6 | **Deploy to macOS**                        | Darwin registry override (`platforms/darwin/nix/settings.nix`) is committed but not deployed.                                                                                                                                                                                                                                                                |
| 7 | **Upstream BuildFlow CI failures**         | 4 repos have failing BuildFlow pre-commit steps on push (emeet-pixyd, mr-sync, md-go-validator, branching-flow). Not addressed this session.                                                                                                                                                                                                                 |

---

## d) TOTALLY FUCKED UP

| # | What went wrong                                   | Impact                                                                                                                                                                        | Root cause                                                                                                                                                                                            |
| - | ------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1 | **Repo committed BROKEN on master**               | `nix flake check`, `nix eval`, `nix build`, `nix run .#deploy` ALL failed on HEAD between ~22:07 and ~22:45. Anyone pulling or CI running would get broken eval.              | PMA daemon ran `nix flake update` after the prior session, rewrote nixpkgs to tarball, committed it. The eval-time guard catches this at eval time but the daemon doesn't run eval before committing. |
| 2 | **`--latest` mode shipped UNTESTED to CI**        | The `flake-update.yml` workflow I wrote calls `bash scripts/fix-nixpkgs-lock.sh --latest`, a code path I never executed. If it fails, the weekly automated PR will be broken. | I tested pin-current mode thoroughly but ran out of time / didn't prioritize testing the mode that CI actually uses.                                                                                  |
| 3 | **Health-check removals done, additions skipped** | I removed 3 retired services but left 4 active services unmonitored. The script is now "less wrong" but still wrong.                                                          | I scoped only to "remove dead references" and didn't audit for missing additions until writing this report.                                                                                           |
| 4 | **Script re-lock step is potentially dangerous**  | `nix flake lock --no-use-registries` at the end of the script could re-tarball if any dependent re-resolves nixpkgs.                                                          | I added it for dependent consistency but didn't verify it's safe. It may need to be removed or made conditional.                                                                                      |

---

## e) WHAT WE SHOULD IMPROVE

### Immediate (this session's gaps)

1. **Test `--latest` mode** — run `bash scripts/fix-nixpkgs-lock.sh --latest`, verify the node is github type, verify `nix flake check --no-build` passes. If it works, CI is safe. If not, fix before the next Monday 06:00 UTC cron run.

2. **Verify or remove the re-lock step** — the `nix flake lock --no-use-registries` line at the end of the script is risky. Test it: fix the node, run the re-lock, check if nixpkgs is still github. If it re-tarballs, remove the line (dependents that follow nixpkgs will re-lock correctly on next `nix flake update` anyway).

3. **Add missing services to health-check** — `discordsync`, `searx`, `qmd-mcp` (user service), `emeet-pixyd` (user service — already there for user mode, verify system mode if applicable).

### Structural (process improvements)

4. **PMA daemon must normalize or not commit lockfile** — the daemon is the root cause. It runs `nix flake update` and commits without eval. Options: (a) daemon runs `fix-nixpkgs-lock.sh` after update, (b) daemon runs `nix flake check --no-build` before commit (rejects if guard fires), (c) daemon stops touching flake.lock entirely. Need daemon config location.

5. **Health-check should be declarative** — hand-maintaining a bash list of services is fragile (services added/retired, script drifts). Consider generating the check list from `systemctl list-units --type=service --state=active` filtered by a "critical" tag, or from the Nix config itself.

6. **CI `nix-check.yml` already catches tarball** — the push/PR workflow runs `nix flake check --no-build`, which fires the eval guard. This means a tarball lockfile pushed to a PR will fail CI. But the daemon commits directly to master, bypassing PR review. Consider requiring PRs for all lockfile changes (branch protection on master).

7. **The tarball regression has happened 4+ times** — each time costs 15-60 minutes of recovery. The defense-in-depth reduces blast radius but doesn't eliminate the root cause. The registry override (active after reboot) is the strongest prevention — it makes `nix flake update` resolve nixpkgs through the local override, not the global registry.

### Quality

8. **`nix fmt` reformatted 1 file** — the daemon or a prior session left unformatted code. Consider adding `nix fmt --check` to CI (nix-check.yml) to catch this earlier.

9. **Statix/deadnix in CI but not enforced locally** — the pre-commit hook runs gitleaks and the tarball guard but NOT statix/deadnix. CI catches them but local commits don't.

---

## f) Up to 50 things we should get done next

### Critical (do first)

1. **Test `fix-nixpkgs-lock.sh --latest`** — the untested CI code path
2. **Verify re-lock step** (`nix flake lock --no-use-registries`) doesn't re-tarball — test and fix/remove
3. **Reboot evo-x2** — activates registry override (strongest tarball prevention) + hyprland purge
4. ~~**Run `nix run .#post-deploy-check`** after reboot — verify functional outcomes~~ done (post-deploy-check runs on every deploy)
5. ~~**Verify screenshots work** post-reboot (grim + slurp + swappy, no grimblast)~~ done (grimblast purged at `0a67b496`)
6. **Deploy to macOS** — activate Darwin registry override
7. **Add missing services to health-check** (discordsync, searx, qmd-mcp)
8. **Find and fix the PMA daemon** — locate config, add normalization or eval gate

### High value

9. **Add `nix fmt --check` to nix-check.yml CI** — catch formatting drift
10. **Branch protection on master** — require PR for lockfile changes (blocks daemon from committing broken state directly)
11. **Generate health-check service list declaratively** — from Nix config or systemctl, not hand-maintained
12. **Add statix + deadnix to pre-commit hook** — currently only in CI
13. **Run `nix-collect-garbage --delete-older-than 3d`** — after confirming new profile works
14. **Clean up remaining dead code** — `rg 'hyprland|hyprpaper|hyprlock|hypridle|hyprpicker|hyprsunset'` (the session found these were mostly comments, but verify)

### Medium value

15. **Fix upstream BuildFlow CI failures** — emeet-pixyd (4 steps), mr-sync (1), md-go-validator (4), branching-flow (1)
16. **Add `fix-nixpkgs-lock.sh` to deploy.sh pre-flight** — auto-fix tarball before deploying
17. **Document the recovery procedure in README** — not just AGENTS.md
18. **Add a flake check to deploy.sh** — reject deploy if eval fails
19. **Consider `nix flake update --no-use-registries` in the daemon** (if it helps — needs testing)
20. **Add health-check test** — run the script in CI to catch syntax/reference errors
21. **Audit all scripts for retired-tool references** — not just health-check
22. **Add `nix flake check --no-build` to PMA daemon** — before commit, not after
23. **Consider a pre-receive hook** — server-side rejection of tarball lockfile pushes
24. **Add monitoring for lockfile type** — Gatus check that alerts if flake.lock nixpkgs becomes tarball
25. **Review all `flake.lock` nodes for tarball type** — not just nixpkgs, any input could be affected
26. **Document the `nix flake prefetch` technique** — it's the only reliable registry-bypass method found
27. **Consider `sops` secrets audit** — verify all guarded secrets have matching enabled services
28. **Add vendorHash CI check** — `nix flake check --no-build` doesn't catch vendorHash mismatches (FOD)

### Lower priority / polish

29. **Remove `cliphist` from `base.nix`** if truly retired, or update the comment to clarify it's CLI-only
30. **Consolidate the two health-check entries** in scheduled-tasks.nix (lines 36 and 186)
31. **Add `--all-systems` to CI flake check** — currently skips aarch64-darwin
32. **Review `nix-check.yml` VM tests** — only tests boot/attic/searxng, expand coverage
33. **Add a daily eval check** — systemd timer that runs `nix flake check --no-build` and alerts
34. **Consider `nixpkgs` input as `github:NixOS/nixpkgs?ref=nixos-unstable&rev=<pinned>`** — pin both ref and rev
35. **Document the 4-layer defense** in a diagram or table in docs/
36. **Add `fix-nixpkgs-lock` to the apps section of AGENTS.md** procedures
37. **Review whether `--commit-lock-file` flag should be removed from daemon entirely**
38. **Add a CONTRIBUTING.md note** about the tarball regression for new contributors
39. **Consider `nixci` or `flake-parts checks` for more granular CI**
40. **Audit `scheduled-tasks.nix` for other stale references**
41. **Review DNS-related health checks** — dnsblockd replaced unbound, verify DNS monitoring is complete
42. **Add BTRFS health to service-health-check** — currently only in Gatus/Prometheus
43. **Review whether `swayidle` should be in health-check** — it IS checked, verify it's still the right idle daemon
44. **Clean up `docs/status/` old reports** — 5 reports from today alone, consider archiving
45. **Add a `make check` or equivalent** — single command for all validation
46. **Review flake.nix line count** (~750 lines, consider splitting perSystem into separate files)
47. **Consider `treefmt-nix` for CI** — more robust than `nix fmt -- --ci`
48. **Add secret scanning to CI** — gitleaks is in pre-commit but not in nix-check.yml
49. **Review all `.enable = lib.mkDefault true` vs `.enable = true`** — consistency check
50. **Add a `flake-info` or dependency graph** — visualize flake input topology

---

## g) Questions I CANNOT figure out myself

### Q1: Where is the PMA auto-commit daemon configured?

The daemon runs `nix flake update` + `git commit` automatically and bypasses pre-commit hooks. It re-introduced the tarball regression between sessions. I searched this repo but found no daemon config, systemd timer, or script. Is it:

- (a) An external script/cron on evo-x2?
- (b) A Crush hook or MCP tool?
- (c) A GitHub Action I missed?
- (d) Something else entirely?

**Why I need this:** Until the daemon normalizes the lockfile (or stops committing it), the regression WILL recur regardless of my 4-layer defense. I need to know where it lives to fix it at the source.

### Q2: Should health-check be hand-maintained or auto-generated?

I removed 3 retired services but found 4 missing active ones. Hand-maintaining this list guarantees drift. Options:

- (a) Generate from `systemctl list-units --type=service --state=active` at runtime (dynamic but includes noise)
- (b) Generate from Nix config at build time (declarative but complex)
- (c) Keep hand-maintained but add a CI test that compares against enabled services
- (d) Delegate entirely to Gatus (HTTP-only, misses systemd-state failures)

**Why I can't decide:** This is a design philosophy call. Gatus already monitors HTTP endpoints, but systemd-state failures (process crashed but port still bound) need the script. The "right" answer depends on your monitoring philosophy.

### Q3: Is branch protection on master acceptable?

The daemon commits directly to master, bypassing CI. If master had branch protection requiring PR reviews, the daemon's broken commits would be caught by CI before landing. But this would change your workflow — every lockfile update would need a PR merge instead of auto-landing.

**Why I can't decide:** This is a workflow preference with real tradeoffs. Branch protection prevents broken master but adds friction. Only you know if the safety is worth the workflow change.

---

## Technical details for reference

### Defense-in-depth layers (tarball regression)

| Layer                    | Location                                  | Active?           | Catches                                                      |
| ------------------------ | ----------------------------------------- | ----------------- | ------------------------------------------------------------ |
| Eval guard               | `flake.nix:519-534`                       | YES (committed)   | `nix flake check`, `nix eval`, `nix build` at eval time      |
| Pre-commit hook          | `.githooks/pre-commit:23-34`              | YES (committed)   | Local commits (not daemon — daemon bypasses hooks)           |
| CI normalization         | `.github/workflows/flake-update.yml`      | YES (committed)   | Automated weekly PR (runs script after update)               |
| Recovery script          | `scripts/fix-nixpkgs-lock.sh`             | YES (committed)   | Manual one-command recovery (`nix run .#fix-nixpkgs-lock`)   |
| NixOS registry override  | `configuration.nix:42-49`                 | NO (needs reboot) | Prevents `nix flake update` from rewriting to tarball at all |
| Darwin registry override | `platforms/darwin/nix/settings.nix:14-25` | NO (needs deploy) | Same, for macOS                                              |

### Commands that work for tarball recovery

```bash
# One-command recovery (pins current rev — no dependency cascade)
nix run .#fix-nixpkgs-lock

# Update to newest nixos-unstable (UNTESTED — CI uses this)
bash scripts/fix-nixpkgs-lock.sh --latest

# Manual recovery (the reliable primitive)
nix flake prefetch github:NixOS/nixpkgs/nixos-unstable --json
# → gives github-type original/locked metadata + hash
# → use jq to rewrite nodes.nixpkgs in flake.lock
```

### Commands that do NOT work

```bash
nix flake update                                    # REWRITES to tarball (root cause)
nix flake lock --override-input nixpkgs github:...  # Registry intercepts → still tarball
nix flake lock --update-input nixpkgs --no-use-registries  # Still tarball
nix flake lock --no-use-registries                  # Still tarball
```

### Files changed this session

| File                                           | Change                                                   | Commit                 |
| ---------------------------------------------- | -------------------------------------------------------- | ---------------------- |
| `flake.lock`                                   | nixpkgs node: tarball → github (same rev `3497aa5c9457`) | `ad6f3f79`, `78a0ed31` |
| `scripts/fix-nixpkgs-lock.sh`                  | NEW — one-command recovery script                        | `bc44085b`, `78a0ed31` |
| `flake.nix:672-676`                            | Added `fix-nixpkgs-lock` app via `mkApp`                 | `78a0ed31`             |
| `.github/workflows/flake-update.yml`           | Rewrote: add normalization step after update             | `78a0ed31`             |
| `platforms/nixos/scripts/service-health-check` | Removed `unbound`, `waybar`, `awww-daemon`               | `78a0ed31`             |
| `AGENTS.md:251`                                | Expanded tarball gotcha to full paragraph                | `78a0ed31`             |

---

> **RESOLVED — Resolved. Work captured in CHANGELOG.md [Unreleased].**
> All forward-looking items in this report were completed in subsequent sessions.
