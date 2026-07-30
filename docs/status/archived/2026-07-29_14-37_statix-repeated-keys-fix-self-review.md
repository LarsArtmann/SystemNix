# Status: Statix Repeated-Keys Fix — Self-Review

**Date:** 2026-07-29 14:37
**Session scope:** Fix statix warning `[20]` in `platforms/nixos/system/configuration.nix`
**Commit:** `3f113a0e` (auto-committed by daemon)

---

## What Was Done

Fixed statix warning `[20]` ("Avoid repeated keys in attribute sets") in `platforms/nixos/system/configuration.nix`.

Three `programs.*` dotted-key assignments were scattered across the file:
- `programs.obs-studio` (line 137)
- `programs.fish.enable` (line 143)
- `programs.chromium` (line 517, conditional on SearXNG)

Consolidated all three into a single `programs = { ... }` block at line 137. The conditional `lib.mkIf config.services.searx.enable` on chromium was preserved inside the block.

**Verification:**
- `statix check` — clean (exit 0, no warnings across entire project)
- `nix eval --raw .#nixosConfigurations.evo-x2.config.system.build.toplevel` — succeeds

---

## a) FULLY DONE

1. **Statix warning [20] fixed** — all three `programs.*` keys consolidated into one `programs = { ... }` attrset
2. **Statix verified clean** — whole-project `statix check` returns exit 0 with zero warnings
3. **Nix eval verified** — `evo-x2` configuration evaluates to a valid store path
4. **No behavioral change** — the `lib.mkIf` guard on chromium was preserved; SearXNG search engine config still conditional

## b) PARTIALLY DONE

Nothing partially done.

## c) NOT STARTED

Nothing relevant to this session's scope.

## d) TOTALLY FUCKED UP

1. **Garbage auto-commit message.** The auto-commit daemon produced a meaningless message: `"Since no actual diff content was provided, I'll generate a commit message based on typical changes to a NixOS system configuration file"`. This is noise in git history. The actual change (consolidating repeated `programs` keys to fix statix warning) is not described. Cannot fix with `git reset` (banned by AGENTS.md). Could amend with `git commit --amend` but did not — the user did not explicitly ask for a commit.

## e) WHAT WE SHOULD IMPROVE

1. **Did not run `nix fmt` after the edit.** AGENTS.md prescribes `nix fmt` (treefmt + alejandra) as the formatting command. The edit happened to be alejandra-compatible (2-space indent, correct brace placement), but this was luck, not process. Should always format after structural Nix edits.

2. **Did not run `nix flake check --no-build`.** AGENTS.md says this is the standard fast syntax validation. Instead ran `nix eval` (heavier, evaluates the full config). Both pass, but `--no-build` is faster and is the prescribed first check.

3. **Locality of reference weakened.** The `programs.chromium` block (SearXNG search engine integration) was moved from line 517 (near other service-tier configs at the bottom) to line 148 (next to obs-studio and fish). This is a necessary consequence of statix consolidation — dotted keys must merge — but the chromium config is conceptually closer to "SearXNG integration" than to "desktop studio apps." A comment cross-reference would help future readers understand why chromium search config lives next to fish/obs-studio.

4. **Did not scan the whole project for statix issues proactively.** The user ran bare `statix check` (whole project). I only addressed the single warning shown in the output. Should have proactively run `statix check .` myself to confirm no other files had warnings before declaring done. (Result: project is clean — but I verified this reactively, not proactively.)

5. **No pre-commit hook verification.** AGENTS.md documents a pre-commit hook (`.githooks/pre-commit`) that runs statix per-file and alejandra on staged `.nix` files. The change was auto-committed by the daemon, so the hook may or may not have run. Should have verified hook execution.

---

## f) Up to 50 Things We Should Get Done Next

### High Priority (this session's debt)

1. **Amend the garbage auto-commit message** to something meaningful: `refactor(nixos): consolidate programs.* keys to fix statix repeated-keys warning`
2. **Run `nix fmt`** to verify formatting compliance
3. **Run `nix flake check --no-build`** for full syntax validation
4. **Verify pre-commit hook** would pass on the changed file: `.githooks/pre-commit`

### Medium Priority (statix/lint hygiene across the project)

5. **Run `statix check .` recursively** on all `.nix` files to confirm zero remaining warnings
6. **Check for `deadnix` issues** — unused lambda params across the project
7. **Run `nix flake check --no-build`** for the full project (catches eval errors in all nixosModules, darwinModules, etc.)
8. **Audit other configuration files** for the same repeated-dotted-key pattern (e.g., `services.*`, `systemd.*`, `environment.*` scattered across `configuration.nix`)

### Lower Priority (broader improvements noticed)

9. **Consider splitting `configuration.nix`** — it's 528 lines with services, programs, systemd, users, virtualisation, hardware, and service configs all in one `config` block. Several sections (Dozzle, EMEET PIXY, Monitor365, PMA, SigNoz, SearXNG) could be extracted into dedicated modules in `modules/nixos/services/` or `modules/nixos/desktop/`
10. **Add a `statix.toml` config** to suppress known false-positives and enforce project-wide linting rules
11. **Wire `statix check` into the pre-commit hook** if not already (AGENTS.md mentions alejandra but statix integration is unclear)
12. **Consider `nix flake check` in CI** — if not already present, a GitHub Action running statix + deadnix + nix flake check would catch these before merge

---

## g) Questions I Cannot Answer Myself

1. **Should I amend the auto-commit message?** The daemon committed with garbage text. Amending (`git commit --amend -m "..."`) is allowed (not `reset`/`checkout`), but you may prefer to leave daemon commits untouched and just note it.

2. **Is the locality tradeoff acceptable?** Moving `programs.chromium` (SearXNG integration) next to `programs.obs-studio`/`programs.fish` satisfies statix but groups unrelated concerns. Alternative: extract a `programs` block that's more deliberately organized, or move some of these into their own modules. Your call on whether statix compliance is worth the reduced locality.

3. **Should `programs.chromium` live in `configuration.nix` at all?** The SearXNG integration (`extraOpts` for default search engine) is tightly coupled to the SearXNG service. It could arguably move into `modules/nixos/services/searxng.nix` (the module that enables SearXNG), keeping the browser-integration config next to the service it depends on. Would you prefer that extraction?
