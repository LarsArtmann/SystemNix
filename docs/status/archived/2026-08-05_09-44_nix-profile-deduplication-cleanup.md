# Session Status: Nix Profile Deduplication Cleanup

**Date:** 2026-08-05 09:44+02:00
**Scope:** Remove duplicated packages from `nix profile` that are already provided by SystemNix.
**Trigger:** User asked whether packages listed in `nix profile list` were in SystemNix; initial answer was wrong.

---

## a) FULLY DONE

1. **Identified all four duplicated packages** in the active `nix profile`:
   - `cqrs-lint` (from local `go-cqrs-lite` flake)
   - `direnv` (from `flake:nixpkgs` registry)
   - `herdr` (from `flake:nixpkgs` registry)
   - `mr` (from `flake:nixpkgs` registry)

2. **Verified all four are already provided by SystemNix:**
   - `cqrs-lint` → `lib/lars-packages.nix:20` via `go-cqrs-lite` flake input, installed via `larsPackages` in `platforms/common/packages/base.nix:324`.
   - `direnv` → `platforms/common/programs/direnv.nix` and `fish.nix` (Home Manager + shell hook).
   - `herdr` → `flake.nix:434` input, `systems/evo-x2.nix:23`, `platforms/common/packages/base.nix:230-231`.
   - `mr` → `platforms/common/packages/base.nix:96` (`pkgs.mr`, myrepos).

3. **Removed all four from the user profile:**
   ```bash
   nix profile remove cqrs-lint direnv herdr mr
   ```
   Output confirmed removal of all four entries.

4. **Confirmed profile is now empty:**
   ```bash
   nix profile list
   # (no output)
   ```

5. **Verified SystemNix binaries are now active:**
   ```bash
   which cqrs-lint direnv herdr mr
   /run/current-system/sw/bin/cqrs-lint
   /etc/profiles/per-user/lars/bin/direnv
   /run/current-system/sw/bin/herdr
   /run/current-system/sw/bin/mr
   ```

6. **Compared versions before/after:**
   - `cqrs-lint`: 4.3.0 @ `e350355` (profile) → 4.3.0 @ `7f4c911` (SystemNix). Same version, SystemNix commit is ~23 hours newer (2026-08-03 00:42 → 2026-08-04 00:06).
   - `herdr`: 0.7.1 (profile) → 0.8.0 (SystemNix). Clear upgrade.
   - `direnv`: 2.37.1 → 2.37.1. Same version, different nixpkgs build.
   - `mr`: 1.20180726 → 1.20180726. Same version, different nixpkgs build.

7. **Confirmed SystemNix git working tree is clean** (no changes introduced by this cleanup).

---

## b) PARTIALLY DONE

1. **Direnv hook verification in a fresh shell.** PATH resolves to the SystemNix binary, but a brand-new shell session is needed to confirm the shell hook still loads `.envrc` correctly. Could not fully verify because the active shell was started before the profile change.

2. **Store reclamation.** The old profile store paths are still present in the Nix store (`/nix/store/vb5hz7yhq4lqvfi7algcyhhxgf3c0d51-profile` etc.). They will be removed by the next `nix-collect-garbage`, but that has not been run yet.

3. **Cross-platform verification.** Confirmed on this NixOS host (`evo-x2`). Did not check macOS (`Lars-MacBook-Air`) or other user accounts for the same duplication.

4. **Runtime functional tests.** Verified `--version` / `version` output. Did not run `cqrs-lint` against a real project, did not launch `herdr`, did not run `mr` in a repo with `.mrconfig`, and did not run `direnv status` in a project directory.

---

## c) NOT STARTED

1. `nix-collect-garbage` to reclaim the removed profile store paths.
2. Open a new shell and run `direnv status` / cd into a project to confirm `.envrc` loading.
3. Run `nix flake check --no-build` to ensure SystemNix eval is unaffected.
4. Audit other user accounts (especially `root`) for the same duplication.
5. Audit macOS/Darwin profile for the same duplication.
6. Update `AGENTS.md` or `docs/CONTRIBUTING.md` with a "do not install SystemNix tools via `nix profile`" note.
7. Add an automated check (shell script, pre-deploy gate, or shell prompt) that warns when the profile contains binaries already in SystemNix.
8. Review `nix registry list` for stale or misleading entries.
9. Update `CHANGELOG.md` if this cleanup is worth recording.
10. Verify `herdr` 0.8.0 is functionally compatible with existing workflows.

---

## d) TOTALLY FUCKED UP

1. **Initial answer was factually wrong.** I said "only `cqrs-lint` is a LarsArtmann project" and that `direnv`, `herdr`, and `mr` were from nixpkgs and not in SystemNix. This was false. All four are in SystemNix. The user had to call this out explicitly ("How about you fucking check the code?!?!").

2. **Answered before reading the relevant code.** I speculated based on the `nix profile list` output and the paste instead of grepping `SystemNix` for the package names first. The project context (`AGENTS.md`) literally says "Read before you write" and "Never edit a file you haven't already read the relevant context for." The same discipline applies to factual claims.

3. **Missed the version skew on the first pass.** If the user had trusted the initial wrong answer, the duplication would have persisted, and the user would have kept running an older `herdr` (0.7.1) and an older `cqrs-lint` build, shadowing the SystemNix versions.

4. **Did not run `nix profile list` immediately after removal in the first answer.** I gave the command and stopped. I should have verified the result and shown the new `which` output proactively.

5. **Tone in the second response was fine, but the first response was overconfident.** I should have said "let me check" instead of stating a conclusion.

---

## e) WHAT WE SHOULD IMPROVE

1. **Code-first verification for any claim about SystemNix state.** Every question about "is X in SystemNix?" must start with a grep across the repo.

2. **Proactive version comparison.** When cleaning up duplicated tools, immediately compare the version/commit strings of the old and new binaries instead of waiting for the user to ask "All on newer versions now?"

3. **Single source of truth enforcement.** Persistent tools should be declared in exactly one place (SystemNix). User profiles should be reserved for truly ephemeral/ad-hoc tools.

4. **Garbage collection after profile cleanup.** Removing the profile is not enough; the old store paths remain. We should pair profile removals with a GC run.

5. **New-shell verification for shell hooks.** After changing `direnv` source, explicitly verify the hook in a fresh shell, not just `which`.

6. **Document the policy.** This cleanup should be encoded somewhere (AGENTS.md, CONTRIBUTING.md, or a shell note) so future sessions do not recreate the same duplication.

7. **Automated duplicate detection.** A small script or shell hook that checks `nix profile list` against SystemNix packages would prevent this class of drift.

8. **Faster correction loop.** When called out on a mistake, I should immediately check the code, verify the correction, and show evidence rather than just verbally correcting.

---

## f) Up to 50 Things We Should Get Done Next

1. Run `nix-collect-garbage` to remove the old profile store paths.
2. Open a new shell and run `direnv status` to confirm the hook is healthy.
3. Run `which cqrs-lint direnv herdr mr` in the new shell to confirm no stale paths.
4. Run `cqrs-lint version` in the new shell.
5. Run `herdr --version` in the new shell.
6. Run `direnv version` in the new shell.
7. Run `mr help` in the new shell to confirm it is functional.
8. Cd into a project with `.envrc` and confirm direnv prompts/loads correctly.
9. Run `nix flake check --no-build` on SystemNix to ensure nothing is broken.
10. Audit `nix profile list` on macOS/Darwin for the same four packages.
11. Audit `nix profile list` for any other user accounts on this host.
12. Check `root` user profile for duplicates.
13. Add a note to `AGENTS.md` under "Critical Rules" or "Operational Safety": "Do not install tools via `nix profile` if they are already provided by SystemNix."
14. Add a note to `docs/CONTRIBUTING.md` about the tooling provisioning policy.
15. Consider adding a `nix run .#profile-audit` app that lists profile packages also present in SystemNix.
16. Write a small shell function (e.g., in `platforms/common/programs/fish.nix`) that warns on shell startup if `nix profile list` is non-empty.
17. Run `nix registry list` and remove any stale or misleading registry entries.
18. Verify `nix run .#deploy` status and apply any pending SystemNix changes.
19. Check if the `herdr` 0.8.0 upgrade requires any config migration.
20. Test `herdr` launches and recognizes its expected subcommands.
21. Test `cqrs-lint` against a real consumer project (e.g., `go-cqrs-lite` itself or another LarsArtmann repo).
22. Verify `mr` still works against `~/.mrconfig` and GitHub repo syncing.
23. Check `PATH` ordering: system paths should precede profile paths if any profile remains.
24. Verify `~/.nix-profile` symlink points to an empty or minimal profile if no entries remain.
25. Confirm no `nix-env` packages remain: `nix-env -q`.
26. Check `nix store verify --repair` is not needed.
27. Ensure no scripts or config hardcode the old profile store path `/nix/store/vb5hz7yhq4lqvfi7algcyhhxgf3c0d51-profile`.
28. Review `flake.lock` for `go-cqrs-lite` and `herdr` freshness.
29. Consider whether `herdr` should be pinned to a tag instead of a commit in `flake.nix`.
30. Consider whether `go-cqrs-lite` should be pinned to a tag instead of `master` for `cqrs-lint`.
31. Review `larsPackages` list for any other tools that might be duplicated in profiles.
32. Review `platforms/common/packages/base.nix` to confirm `essentialPackages` is the right place for `mr`.
33. Confirm `direnv` is only installed via Home Manager, not duplicated in `environment.systemPackages`.
34. Update `CHANGELOG.md` with this cleanup if project hygiene is tracked there.
35. Add a TODO item to `TODO_LIST.md` for the profile audit script.
36. Verify `home-manager` activation is current (run `home-manager switch` if not using `nix run .#deploy`).
37. Check Gatus health checks still pass after the profile change (no service dependencies on profile binaries).
38. Confirm `direnv` from `/etc/profiles/per-user/lars/bin/direnv` and any system-wide `direnv` are the same derivation.
39. Verify no systemd user services reference profile binaries.
40. Document the exact cleanup command in the report for future reference.
41. Consider adding a CI check that fails if `nix profile list` is non-empty on the build/test host.
42. Add a reminder in the shell prompt when `nix profile list` is non-empty.
43. Verify that `nix run` still works for all four tools after profile removal.
44. Check if `nix-shell -p cqrs-lint` still works as a fallback.
45. Review recent `docs/status` reports for any related profile/tooling drift.
46. Ensure this cleanup is mentioned in the next deployment session notes.
47. Consider whether `mr` should be removed from `essentialPackages` if it is no longer used.
48. Verify that the `direnv` shell hook is installed by Home Manager and not by a manual `fish` config.
49. Check if `nix-direnv` is the correct backend and version matches the system `direnv`.
50. Write a one-line principle: **SystemNix owns persistent tools; `nix profile` is only for transient experiments.**

---

## g) Up to 3 Questions I Cannot Figure Out Myself

1. **Why were these four packages in the profile in the first place?** Was the profile a leftover from before SystemNix provided them, were they installed intentionally for testing/development, or did some automated process (e.g., an old script, a previous agent session, or a bootstrap command) add them?

2. **Are there other profiles that need the same cleanup?** Specifically, does the macOS (`Lars-MacBook-Air`) `nix profile` or any other user account (e.g., `root`) contain the same duplication, and should we clean those up too?

3. **Is `herdr` 0.8.0 backward-compatible with your current workflow?** The profile had 0.7.1 and SystemNix now provides 0.8.0. Does this require any config migration, or can you just start using it?

---

## Session Commands Reference

```bash
# Check profile
nix profile list

# Check all paths
whereis cqrs-lint direnv herdr mr

# Remove duplicates
nix profile remove cqrs-lint direnv herdr mr

# Verify system binaries are used
which cqrs-lint direnv herdr mr

# Verify versions
/run/current-system/sw/bin/cqrs-lint version
/etc/profiles/per-user/lars/bin/direnv version
/run/current-system/sw/bin/herdr --version
/run/current-system/sw/bin/mr help

# Reclaim store space
nix-collect-garbage
```

---

> **RESOLVED — Resolved. Work captured in CHANGELOG.md [Unreleased].**
> All forward-looking items in this report were completed in subsequent sessions.
