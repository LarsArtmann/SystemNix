# Status Report: Post-Deploy Check Hardening & Shellcheck

**Date:** 2026-08-09 06:36
**Session scope:** Fix 3 remaining manual-only items from post-deploy-check automation work
**Commits this session:** `5a798cb6`, `57bb772e` (auto-git daemon)

---

## a) FULLY DONE

### 1. Double-000 curl bug fixed (post-deploy-check.sh)

**Root cause:** `curl -w "%{http_code}"` already emits `"000"` to stdout on connection failure. The `|| echo "000"` fallback then appended a second `"000"`, producing `"000000"`. This never matched the `000)` case, so unreachable vHosts silently fell through to the `*)` WARN branch instead of being reported as unreachable (SKIP).

**Fix:** `|| echo "000"` → `|| true` at all 3 sites:

| Line | Context | Fix |
|------|---------|-----|
| 32 | `check()` function — main HTTP check | `|| true` preserves curl's `000` output |
| 138 | DiscordSync readiness retry loop | Same pattern |
| 443 | Auth gateway vHost health loop | Same pattern |

**Verification:** `grep -rn '|| echo "000"' scripts/` — zero remaining instances across all `.sh` files.

### 2. RuntimeInputs declared hermetically (flake.nix)

Expanded from `[curl jq]` (2 packages) to 9 packages covering every command the script invokes:

| Package | Provides | Used at |
|---------|----------|---------|
| `coreutils` | `date`, `wc`, `head`, `tr`, `sleep`, `id` | Multiple sites |
| `curl` | `curl` | All HTTP checks |
| `fish` | `fish` | Shell startup time check (L505) |
| `glibc` | `getent` | DNS resolution check (L111) |
| `gnugrep` | `grep` | Pattern matching throughout |
| `jq` | `jq` | SigNoz rule count (L271) |
| `nix` | `nix` | Registry check (L483) |
| `procps` | `pgrep` | DiscordSync process check (L147) |
| `systemd` | `systemctl`, `journalctl` | Service state, journal scanning |

**Verification:** `nix eval .#apps.x86_64-linux.post-deploy-check.program` — resolves to store path. `nix flake check --no-build` — passes.

**Known limitation:** `sudo` (used at L303, L304, L367, L376) is inherently non-hermetic — it's a setuid binary that must come from the system. `dms` (L514) is a desktop binary guarded by `command -v`, intentionally non-hermetic.

### 3. Shellcheck pre-commit hook added (.githooks/pre-commit)

Added shellcheck stage between Nix linters and `nix flake check`, following the existing deadnix/statix pattern:

```bash
STAGED_SH=$(git diff --cached --name-only --diff-filter=ACM '*.sh')
if [ -n "$STAGED_SH" ]; then
    echo "$STAGED_SH" | xargs nix shell nixpkgs#shellcheck --command shellcheck --severity=warning
fi
```

**Severity:** `--severity=warning` (matches the existing `pre-commit.nix` config for other repos).

**Pre-existing fix:** Removed dead variable `DESKTOP_MODULES` from `doc-freshness-check.sh:23` (SC2034 — assigned but never used) so all scripts pass clean.

**Verification:** `shellcheck --severity=warning scripts/*.sh` — exit 0, zero warnings.

### 4. Flake check passes

`nix flake check --no-build` — all checks passed (only `aarch64-darwin` omitted as incompatible).

---

## b) PARTIALLY DONE

### Formatting drift discovered but not cleaned up

Running `nix fmt` to verify my edits triggered `shfmt`/`alejandra` reformatting on **pre-existing** code I did not author:

| File | Lines changed | Cause |
|------|--------------|-------|
| `scripts/post-deploy-check.sh` | 20 | shfmt expanded one-liner functions, removed `$(( ))` spaces |
| `modules/nixos/services/browser-history.nix` | 5 | alejandra formatting drift |
| `modules/nixos/services/monitor365.nix` | 1101 | alejandra formatting drift (massive) |

**These changes are uncommitted** in the working tree. They are NOT my edits — they are pre-existing formatting drift that the formatter surfaced. The auto-git daemon has not yet committed them.

**What I should have done:** Verified my edits with `alejandra --check` on only the files I changed, instead of running `nix fmt` on the entire repo.

---

## c) NOT STARTED

- Shellcheck in CI (`.github/workflows/`) — only in pre-commit hook
- Shellcheck on `.githooks/pre-commit` itself (irony)
- Shellcheck on inline shell scripts embedded in `.nix` files (writeShellApplication blocks, ExecStart strings)

---

## d) TOTALLY FUCKED UP

### Nothing catastrophic, but:

1. **Ran `nix fmt` on the entire repo** — this was unnecessary and produced 1101 lines of formatting churn in `monitor365.nix` that I did not intend to touch. The working tree now has uncommitted formatting changes that are noise. This makes the diff harder to review and could mask real changes.

2. ~~**Didn't verify whether `deploy.sh` calls post-deploy-check via the flake app or directly** — if `deploy.sh` calls `./scripts/post-deploy-check.sh` directly (not `nix run .#post-deploy-check`), the hermetic runtimeInputs are bypassed entirely, making that work moot for the most common invocation path. (I didn't check this — it's a gap in my verification.)~~ done — verified: deploy.sh uses `nix run .#post-deploy-check` (hermetic path)

---

## e) WHAT WE SHOULD IMPROVE

### Directly related to this session's work:

1. **Add shellcheck to CI** — pre-commit hooks are bypassable with `--no-verify`. CI is the enforcement layer. The `.github/workflows/nix-check.yml` job should run `shellcheck --severity=warning` on all `.sh` files.

2. **Use devShell shellcheck instead of `nix shell nixpkgs#shellcheck`** in the pre-commit hook — the devShell already has shellcheck (flake.nix:616). The `nix shell nixpkgs#shellcheck` pattern requires network access and is slow (~5s cold start per invocation). Same issue exists for deadnix/statix/alejandra in the same hook.

3. ~~**Verify `deploy.sh` invocation path** — confirm whether post-deploy-check runs via `nix run .#post-deploy-check` (hermetic) or `bash scripts/post-deploy-check.sh` (non-hermetic, system PATH).~~ done — deploy.sh uses `nix run .#post-deploy-check` (hermetic)

4. **Add shellcheck SC2360/SC2086 guards** — the script has many unquoted variables (`$url`, `$expect_body`). Shellcheck at `--severity=warning` doesn't catch all word-splitting issues. Consider `--severity=info` for new code.

### Observations from this session:

5. **Formatting drift is endemic** — `monitor365.nix` had 1101 lines of alejandra drift. This means recent commits to that file bypassed the pre-commit alejandra hook. The hook uses `|| true` on alejandra (L121), which silently swallows formatting failures. Consider removing `|| true` or adding a `--check` verification step.

6. **The `nix shell nixpkgs#X` pattern in pre-commit is fragile** — requires network, blocks on cache misses, and is slow. Consider pre-installing linters in the devShell and sourcing them from PATH.

7. **`doc-freshness-check.sh` had dead code** (`DESKTOP_MODULES`) — the doc-freshness script was never shellchecked before. There may be more latent issues in scripts that were written before shellcheck was enforced.

---

## f) Up to 50 Things to Get Done Next

#### High Priority — Correctness & Safety
1. ~~Verify `deploy.sh` invocation path for post-deploy-check (hermetic vs system PATH)~~ done — uses `nix run .#post-deploy-check`
2. Add shellcheck to `.github/workflows/nix-check.yml` CI job
3. ~~Clean up uncommitted formatting drift in `monitor365.nix` (1101 lines — commit or revert)~~ done at `0a67e776`
4. ~~Clean up uncommitted formatting drift in `browser-history.nix` (5 lines)~~ done at `0a67e776`
5. ~~Clean up uncommitted shfmt changes in `post-deploy-check.sh`~~ done at `0a67e776`
6. Remove `|| true` from alejandra in pre-commit (L121) — it silently swallows formatting failures
7. Run shellcheck on `.githooks/pre-commit` itself

#### Medium Priority — Hermeticity & Tooling
8. Replace `nix shell nixpkgs#shellcheck` in pre-commit with devShell PATH lookup
9. Replace `nix shell nixpkgs#deadnix` in pre-commit with devShell PATH lookup
10. Replace `nix shell nixpkgs#statix` in pre-commit with devShell PATH lookup
11. Replace `nix shell nixpkgs#alejandra` in pre-commit with devShell PATH lookup
12. Add a `treefmt --check` CI step to catch formatting drift before merge
13. Audit all `.sh` scripts with `shellcheck --severity=info` for deeper analysis
14. Extract inline shell scripts from `.nix` files and shellcheck them (writeShellApplication blocks)
15. Add `pre-deploy-check.sh` runtimeInputs audit (same pattern — verify hermeticity)
16. Add `deploy.sh` runtimeInputs audit (same pattern)

#### Shellcheck Enhancements
17. Consider `--severity=style` for new shell code (catches more issues)
18. Add `.shellcheckrc` to configure excludes globally (SC2312 for command substitution, etc.)
19. Add shellcheck to the `checks` section of flake.nix (runs on every `nix flake check`)
20. Create a `scripts/.shellcheckrc` with project-specific excludes

#### Post-Deploy Check Improvements
21. Add `/proc/pressure/io` avg10 check (>80% sustained = I/O contention warning)
22. Add oauth2-proxy itself as a Gatus health check target
23. Add Caddy config reload success check (detects `PrivateTmp=true` blocking reload)
24. Add BTRFS scrub freshness as a textfile metric + post-deploy check
25. Add dnsblockd block page HTTPS endpoint check
26. Add post-deploy-check for the `sudo` commands — verify they work in hermetic context
27. Consider splitting post-deploy-check.sh into separate check modules for maintainability

#### Pre-Commit Hook Improvements
28. Add `--no-commit` dry-run mode to pre-commit hook for testing
29. Add timing output to each pre-commit stage (identify slow stages)
30. Cache `nix shell` invocations across hook runs (nix-shell cache)
31. Add `--fix` mode to shellcheck stage (auto-fix simple issues like `$()` quoting)
32. Add hook for `statix fix` (auto-fix statix issues, not just detect)

#### Documentation
33. Document the shellcheck pre-commit hook in AGENTS.md prevention layers table
34. Update TODO_LIST.md to mark the 3 items as done
35. Document the `|| true` vs `|| echo "000"` gotcha in `docs/gotchas-archive.md`
36. Add runtimeInputs declaration requirement to AGENTS.md "Adding a Service" procedure
37. Create a `scripts/README.md` documenting each script and its runtimeInputs

#### Broader Quality
38. Audit all flake apps for complete runtimeInputs (not just post-deploy-check)
39. Add a flake check that verifies all `writeShellApplication` apps have non-empty runtimeInputs
40. Run `statix check` on the entire repo (not just staged files) for a baseline
41. Run `deadnix` on the entire repo for a baseline
42. Consider adding `shellharden` (auto-formats shell scripts to be safer) as an alternative/complement
43. Add `shfmt` to the devShell and pre-commit (it's already run by treefmt, but not enforced in pre-commit)
44. Audit inline `ExecStart` scripts in `.nix` modules for shellcheck issues
45. Add a `nix run .#shellcheck-all` app that runs shellcheck on every `.sh` file in the repo
46. Consider migrating pre-commit from `.githooks/pre-commit` to `pre-commit.nix` (nix-native hooks)
47. Add CI job that runs `nix fmt -- --fail-on-change` (or equivalent) to prevent formatting drift
48. Add a daily scheduled CI job that runs shellcheck on ALL scripts (not just changed ones)
49. Track pre-commit hook execution time as a metric (identify slow stages over time)
50. Add `set -o nounset` compliance audit — some scripts may reference unset variables

---

## g) Questions I Cannot Answer Myself

1. **Should I commit the formatting drift changes** (`monitor365.nix` 1101 lines, `browser-history.nix` 5 lines, `post-deploy-check.sh` shfmt changes) or revert them? They're pre-existing drift I accidentally surfaced by running `nix fmt`. Committing them pollutes the diff; reverting leaves known formatting debt.

2. **Does `deploy.sh` invoke post-deploy-check via `nix run .#post-deploy-check` or `bash scripts/post-deploy-check.sh`?** If the latter, the hermetic runtimeInputs work is bypassed on the primary deploy path. I should have checked this during the session but didn't.

3. **Should the pre-commit hook's `nix shell nixpkgs#X` pattern be replaced with direct devShell binaries?** This is a significant refactor of the hook (affects deadnix, statix, alejandra, shellcheck). The current pattern is slow (~20s total) but works without activating a devShell. The devShell approach is faster but requires `nix develop` to be active.

---

## Session Metrics

| Metric | Value |
|--------|-------|
| Tasks assigned | 3 |
| Tasks completed | 3 |
| Files edited by me | 4 (`post-deploy-check.sh`, `flake.nix`, `.githooks/pre-commit`, `doc-freshness-check.sh`) |
| Files accidentally reformatted | 3 (`post-deploy-check.sh`, `browser-history.nix`, `monitor365.nix`) |
| Lines of formatting churn | ~1126 (mostly monitor365.nix) |
| Shell bugs fixed | 3 (double-000 at 3 sites) |
| Dead variables removed | 1 (`DESKTOP_MODULES`) |
| Pre-commit hooks added | 1 (shellcheck) |
| Verification commands run | 5 (grep, shellcheck, nix eval, nix flake check, nix fmt) |
| Things I should have done differently | 2 (ran nix fmt globally, didn't check deploy.sh invocation) |

---

## Resolution (2026-08-10)

All 3 manual-only items (double-000 fix, hermetic runtimeInputs, shellcheck pre-commit) resolved and in CHANGELOG [Unreleased]. Forward-looking items (shellcheck in CI, formatting drift cleanup, devShell linter lookup) harvested into TODO_LIST.
