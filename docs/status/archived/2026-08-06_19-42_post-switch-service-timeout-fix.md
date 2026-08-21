# Status: Post-Switch Cleanup + Service Timeout Fix (2026-08-06 19:42)

> **Trigger:** Previous session's `nh os switch` activated the new generation but two services (`discordsync.service`, `hermes.service`) failed to start during activation (exit status 4). This session investigated the failures, fixed root causes, cleaned up remaining issues, and verified a clean deploy.

---

## a) FULLY DONE

### 1. discordsync.service start timeout — FIXED

- **Symptom:** `discordsync.service: start-pre operation timed out. Terminating.` — failed on first 2 attempts during system switch, succeeded on 3rd
- **Root cause:** No `TimeoutStartSec` set → systemd default 90s. ExecStartPre (`dbHeal` + `waitDnsReady`) exceeded 90s during I/O-heavy system switch while dnsblockd was still settling
- **Fix:** Added `TimeoutStartSec = "3min"` in `modules/nixos/services/discordsync.nix` serviceConfig
- **Commit:** `7e4faf5f`

### 2. hermes.service start timeout — FIXED

- **Symptom:** `hermes.service: start-pre operation timed out.` — failed on first 2 attempts, succeeded on 3rd
- **Root cause:** Same as discordsync — no `TimeoutStartSec`, ExecStartPre (`aclSetupScript` + `fixPermissionsScript` + `migrateScript` processing 535 MB state + `mergeEnvScript`) exceeded 90s default
- **Fix:** Added `TimeoutStartSec = "3min"` in `modules/nixos/services/hermes.nix` serviceConfig
- **Commit:** `7e4faf5f`

### 3. libdisplay-info evaluation warning — SILENCED

- **Symptom:** `evaluation warning: libdisplay-info-0.4.0 was overridden with 'version' but not 'src'`
- **Fix:** Added `__intentionallyOverridingVersion = true` to the `overrideAttrs` call in `overlays/linux.nix:31`
- **Verified:** `nix eval` after fix shows zero libdisplay-info warnings (only the benign `system` → `stdenv.hostPlatform.system` deprecation warnings remain)
- **Commit:** `7e4faf5f`

### 4. .pc version patching made version-agnostic

- **Before:** `substituteInPlace "$pc" --replace-fail "Version: 0.4.0" "Version: 0.3.0"` — hardcodes 0.4.0, silently fails on next bump
- **After:** `sed -i 's/^Version: [0-9.]\+$/Version: 0.3.0/' "$pc"` — matches any version, future-proof
- **Commit:** `7e4faf5f`

### 5. nix fmt run

- 49 files formatted (31 changed) across the repo
- **Commit:** Auto-committed by PMA daemon

### 6. Temp files cleaned

- `/tmp/cqrs-lint-replaces.txt` and `/tmp/cqrs-lint-go-mod-original.mod` removed (did not exist — already cleaned)

### 7. AGENTS.md updated with 3 new gotchas

- `TimeoutStartSec` for ExecStartPre-heavy services (Systemd section)
- niri-flake libdisplay-info stale pin (Desktop section)
- `__intentionallyOverridingVersion` + `go mod tidy` in preBuild for mkPreparedSource (Nix & Nixpkgs section)
- **Commit:** `c71a8408`

### 8. Clean deploy verified

- `nh os switch` succeeded with zero service failures on the retry deploy
- Both discordsync and hermes started on first attempt
- No libdisplay-info evaluation warning

---

## b) PARTIALLY DONE

### 1. Upstream niri-flake issue for stale libdisplay-info pin

- The shim workaround is in place and documented, but **no issue or PR was filed** on `sodiboo/niri-flake` upstream
- The fix (drop the `assert version == "0.2.0"` and the `libdisplay-info_0_2` pin) is trivial for upstream
- Blocked: requires GitHub account access / decision on how to phrase the issue

### 2. PMA pre-commit hook broken

- `go.work: no such file or directory` when committing in `/home/lars/projects/projects-management-automation`
- Previous session bypassed with `--no-verify`
- Not investigated or fixed — this is an upstream repo issue

### 3. Hermes `google_chat` plugin warning

- `WARNING hermes_cli.plugins: Failed to load plugin 'google_chat-platform': 'google_chat' is not a valid Platform`
- Observed in logs but **not investigated** — could be benign (unused plugin) or a real regression from the hermes-agent flake update
- The service starts and runs despite this warning

---

## c) NOT STARTED

1. **File upstream issue on sodiboo/niri-flake** for the stale `libdisplay-info_0_2` pin
2. **Investigate hermes `google_chat` plugin warning** — determine if it's a regression or benign
3. **Fix PMA pre-commit hook** referencing non-existent `go.work`
4. **Fix PMA `go.work` setup** — the pre-commit hook expects a Go workspace file that doesn't exist in the repo
5. **DiscordSync Turso quota issue** — `turso: error: sync engine operation failed: database sync engine error: remote server returned an error: status=403, body={"error":"Operation was blocked: SQL read operations are forbidden (reads are blocked, do you need to upgrade your plan?)"}` — external Turso plan limitation, not a SystemNix issue but affects DiscordSync functionality

---

## d) TOTALLY FUCKED UP

Nothing this session. The previous session had cascading failures (tarball regression, libdisplay-info removal, Go dep cascade, service start failures), but all were resolved. This session was clean — investigated, identified root causes, fixed, verified.

---

## e) WHAT WE SHOULD IMPROVE

1. **Always set `TimeoutStartSec` for services with ExecStartPre** — systemd's 90s default is too short for any service doing DB operations, DNS waits, or file migrations during a system switch (I/O contention). Should be part of `serviceDefaults` or at least documented as a checklist item for new services.

2. **`nix fmt` should be run BEFORE deploy, not after** — formatting changes after deploy mean the running system doesn't match the source tree. Minor, but creates a window of inconsistency.

3. **`__intentionallyOverridingVersion` pattern should be documented proactively** — I only discovered it from reading the nixpkgs warning message. It should be in the AGENTS.md Nix patterns section from the start (now added).

4. **The libdisplay-info shim is fragile** — it depends on overlay ordering (must be first), niri-flake's stale assert (could change), and a sed regex on a `.pc` file. A proper upstream fix would eliminate all of this.

5. **The `source` diff in deploy output should be investigated** — `[C.] source +43.7 KiB` appeared in the deploy diff but was not investigated. It's likely just the SystemNix source tree changes (nix files), but we should verify it's not pulling in something unexpected.

6. **Service start failures during `nh os switch` should not block activation** — systemd's `switch-to-configuration` returns exit 4 even when services will eventually start on retry. This is systemd's design, but `nh` treats it as a hard error. A post-switch health check that waits 30s and re-checks would reduce false alarms.

7. **The 49 files reformatted by `nix fmt`** suggest formatting drift accumulated since the last `nix fmt` run. Should be run more frequently (pre-commit hook?) or CI-enforced.

---

## f) Next 50 Things To Get Done

### Immediate (this session's leftovers)

1. File upstream issue on `sodiboo/niri-flake` for stale `libdisplay-info_0_2` pin
2. Investigate hermes `google_chat` plugin warning — is `google_chat` a removed platform?
3. Check DiscordSync Turso quota — is the free plan exhausted? Upgrade or migrate to local-only SQLite?
4. Fix PMA pre-commit hook `go.work` reference in `/home/lars/projects/projects-management-automation`

### Service Hardening

5. Audit ALL services with ExecStartPre for missing `TimeoutStartSec` — grep for `ExecStartPre` without nearby `TimeoutStartSec`
6. Consider adding `TimeoutStartSec` to `serviceDefaults` or `serviceTypes` as a configurable default
7. Add Gatus health check for hermes if not present (verify monitoring coverage)
8. Verify Gatus alerts fired for the discordsync/hermes start failures — if not, alerting gap
9. Add `post-deploy-check` assertions for discordsync and hermes startup (currently checks functional outcomes but may not cover these services)

### Nixpkgs & Flake Hygiene

10. Pin the libdisplay-info shim to a named nixpkgs revision so a future nixpkgs bump doesn't silently break the sed regex
11. Add a comment in `overlays/linux.nix` with the exact niri-flake issue URL once filed
12. Consider `nix fmt` as a pre-commit hook (via `treefmt-nix` HM module or git hooks)
13. Run `nix flake check --no-build` to catch any remaining evaluation warnings
14. Clean up `flake.lock` — verify all LarsArtmann repo pins are at intentional revisions
15. Consider `nix flake update` on a schedule (weekly?) to prevent large-batch update cascades

### Documentation

16. Update `docs/status/2026-08-06_18-36_flake-update-rebuild-recovery.md` to mark all items as resolved
17. Add `TimeoutStartSec` to the "Adding a Service" checklist in AGENTS.md
18. Document the Turso quota issue in DiscordSync section of AGENTS.md
19. Add the `__intentionallyOverridingVersion` pattern to docs/CONTRIBUTING.md module templates
20. Update the status report cross-references (previous report → this report → resolved)

### Monitoring & Observability

21. Verify Gatus has health checks for both discordsync and hermes
22. Check if the `OnFailure=` alert routing worked for the initial start failures
23. Add startup-time monitoring (how long does ExecStartPre take on average?)
24. Consider systemd `ExecStartPost` health gate for hermes (now that TimeoutStartSec is generous)

### Upstream Contributions

25. File niri-flake issue: drop stale `libdisplay-info_0_2` pin
26. File niri-flake PR: update the assert or remove it entirely
27. Fix PMA pre-commit hook `go.work` reference upstream
28. Consider filing nixpkgs issue: `__intentionallyOverridingVersion` documentation is buried in warning text

### BTRFS & System Health

29. Verify btrbk snapshots completed after the deploy (2 generations changed)
30. Check nix store GC has enough free space after the generation change
31. Run `nix-collect-garbage --delete-older-than 7d` to clean up old builds
32. Check disk usage — the deploy added +43.7 KiB (minimal, but verify `/data` and `/nix` free space)

### Desktop & Quickshell

33. Verify niri is running correctly with the libdisplay-info shim (no rendering issues)
34. Check DMS (DankMaterialShell) is stable after the niri update
35. Verify Helium browser works after Chromium 151.0.7922.75 update

### CI/CD & Automation

36. Consider adding `nix flake check --no-build` as a pre-deploy gate
37. Add service startup timeout audit to `post-deploy-check`
38. Consider a "canary deploy" mode that starts services one at a time to isolate failures
39. Verify PMA daemon committed all changes correctly (check git log for gaps)

### Security

40. Verify sops secrets were correctly re-deployed (sops-install-secrets ran during activation)
41. Check that no secrets leaked in journal logs during the start failures
42. Verify the hermes EnvironmentFile is correctly owned and permissioned after the state migration

### Testing

43. Write a NixOS VM test for the libdisplay-info shim (verify niri builds with it)
44. Write a NixOS VM test for service startup with I/O contention (simulate slow ExecStartPre)
45. Add unit test for the sed regex in the .pc file patching (verify it matches various version formats)

### Cleanup

46. Remove the previous session's status report items that are now resolved (or mark them resolved)
47. Verify no orphaned processes from the failed service starts (zombie `hermes-migrate` or `sqlite3` processes)
48. Check systemd journal for any other services that had warnings during the switch
49. Review the `nix fmt` diff — 31 changed files is a lot, verify no unintended formatting changes
50. Consider archiving the `docs/gotchas-archive.md` entries that are now fully resolved into a "resolved gotchas" section

---

## g) Questions I Cannot Answer Myself

1. **Should I file the niri-flake upstream issue/PR myself, or do you want to handle it?** The fix is trivial (remove the assert + pin), but it's your call whether to submit a PR or just maintain the shim indefinitely. I can draft the issue text if you want me to file it.

2. **Is the Turso plan quota issue something to address now?** DiscordSync's Turso sync is failing with `SQL read operations are forbidden` — this means the free plan is exhausted. Do you want to upgrade the Turso plan, migrate DiscordSync to local-only SQLite, or leave it as-is (the service runs fine with local data)?

3. **Should `TimeoutStartSec` become a `serviceDefaults` standard or stay per-service?** Adding it to `serviceDefaults` (via `lib/default.nix`) would make ALL services get 3min by default, which could mask genuinely stuck services. Keeping it per-service requires manual audit. Your preference on the tradeoff.

---

> **RESOLVED — Resolved. Work captured in CHANGELOG.md [Unreleased].**
> All forward-looking items in this report were completed in subsequent sessions.
