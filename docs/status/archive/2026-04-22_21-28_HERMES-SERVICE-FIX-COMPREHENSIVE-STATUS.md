# Comprehensive Status Report — 2026-04-22 21:28

## Executive Summary

The Hermes Gateway service module was converted from a user-level systemd service (requiring login) to a system-level service (starts at boot). The rewrite went through 3 passes with escalating bug fixes. The current state is **functionally correct with two critical bugs just fixed** in this session. No deployment to NixOS has occurred yet.

---

## A) FULLY DONE

| Item                                        | Details                                                                                     | Commit       |
| ------------------------------------------- | ------------------------------------------------------------------------------------------- | ------------ |
| System-level service conversion             | `systemd.services.hermes` targeting `multi-user.target`                                     | `64c3203`    |
| Dedicated system user/group                 | `hermes`/`hermes` system user                                                               | `64c3203`    |
| State directory at `/var/lib/hermes`        | No `.hermes` nesting (unlike upstream)                                                      | `64c3203`    |
| `WatchdogSec` removed                       | Hermes doesn't implement `sd_notify()` — would cause 60s crash loop                         | `862c67b`    |
| `EnvironmentFile` removed                   | Hermes reads `.env` via `load_hermes_dotenv()`, not systemd                                 | `862c67b`    |
| Activation script added                     | `hermes-setup` with `stringAfter ["users" "setupSecrets"]`                                  | `862c67b`    |
| `.managed` marker in activation script      | Moved from broken `manageScript` to activation script                                       | `862c67b`    |
| Setgid directories (2770)                   | All state dirs use 2770 for group inheritance                                               | `862c67b`    |
| sops.nix secrets owner fixed                | Owner/group changed from `lars`/`users` to `hermes`/`hermes`                                | Earlier      |
| sops template mode + restartUnits           | `mode = "0400"`, `restartUnits = ["hermes.service"]`                                        | Earlier      |
| justfile commands updated                   | `systemctl` (not `--user`), `/var/lib/hermes/` paths                                        | Earlier      |
| AGENTS.md updated                           | System service architecture documented                                                      | Earlier      |
| Migration script with `+` prefix            | Runs as root to read `/home/lars/.hermes`                                                   | `64c3203`    |
| `mergeEnvScript` in ExecStartPre            | Writes `.env` from sops template at every start                                             | `64c3203`    |
| Nix syntax parse-check passes               | `nix-instantiate --parse` exits 0                                                           | This session |
| `ReadWritePaths` includes `oldStateDir`     | **Just fixed** — migration script can reach `/home/lars/.hermes` despite `ProtectHome=true` | This session |
| AGENTS.md `EnvironmentFile` reference fixed | **Just fixed** — removed incorrect `EnvironmentFile` claim                                  | This session |

## B) PARTIALLY DONE

| Item                          | Status                                                                 | What's Missing                              |
| ----------------------------- | ---------------------------------------------------------------------- | ------------------------------------------- |
| Module-level eval check       | `nix eval --impure` timed out (flake lock resolution is slow on macOS) | Need to verify on NixOS or with cached lock |
| Full build test (`just test`) | Not run                                                                | Need to run on NixOS                        |

## C) NOT STARTED

| Item                                            | Priority | Notes                                                                   |
| ----------------------------------------------- | -------- | ----------------------------------------------------------------------- |
| Deploy to NixOS (`just switch`)                 | Critical | Cannot verify until deployed                                            |
| Verify service starts at boot                   | Critical | Need `systemctl status hermes` on NixOS after reboot                    |
| Verify migration works                          | High     | Need to check `/var/lib/hermes` has data from `/home/lars/.hermes`      |
| Verify `.env` written correctly                 | High     | Check `/var/lib/hermes/.env` after service start                        |
| Verify `.managed` marker exists                 | Medium   | Check `/var/lib/hermes/.managed` after activation                       |
| Clean up old user service                       | Low      | Home Manager auto-removes `hermes-gateway` user service on next apply   |
| Remove `oldStateDir` from `ReadWritePaths`      | Low      | Only needed during migration transition; remove after confirmed         |
| Remove migration script entirely                | Low      | No-op after migration; safe to keep but should be cleaned up eventually |
| Add `hermes gateway run --replace` verification | Low      | Verify `--replace` flag is correct for Hermes version                   |

## D) TOTALLY FUCKED UP (Fixed in this session)

| Bug                                                            | Severity     | Root Cause                                                                                                                                                                                                                                                                                | Fix                                                                                                                                 |
| -------------------------------------------------------------- | ------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| `ProtectHome=true` + missing `oldStateDir` in `ReadWritePaths` | **Critical** | Last commit removed `oldStateDir` from `ReadWritePaths` "because migration script runs as root via `+` prefix" — but `+` only bypasses UID, NOT mount namespace restrictions. `ProtectHome=true` mounts `/home` as empty tmpfs, so migration script silently sees no old state and skips. | Added `oldStateDir` back to `ReadWritePaths`. systemd's `ReadWritePaths` takes precedence over `ProtectHome` for the specific path. |
| AGENTS.md claimed `EnvironmentFile` is used                    | **Medium**   | Documentation wasn't updated when `EnvironmentFile` was removed in commit `862c67b`. The doc said "loaded via `EnvironmentFile`" but Hermes actually reads `.env` via its own `load_hermes_dotenv()`.                                                                                     | Fixed to: "merged into `.env` by `mergeEnvScript` (ExecStartPre) → Hermes reads `.env` at runtime via `load_hermes_dotenv`"         |

### Previously Fixed (before this session)

| Bug                                                                         | Severity     | Commit                       |
| --------------------------------------------------------------------------- | ------------ | ---------------------------- |
| `WatchdogSec = "60"` causing crash loop                                     | **Critical** | `862c67b`                    |
| `EnvironmentFile = sopsEnvPath` causing hard failure                        | **Critical** | `862c67b`                    |
| `manageScript` definition overwritten by `migrateScript` (multiedit damage) | **Critical** | `862c67b` (rewrote cleanly)  |
| Migration script running as `hermes` user (can't read `/home/lars/.hermes`) | **Critical** | `64c3203` (added `+` prefix) |

## E) WHAT WE SHOULD IMPROVE

### Process Improvements

1. **Never use multiedit for complex script blocks** — The multiedit tool created a malformed file by overlapping two script definitions. For multi-line shell scripts in Nix, always rewrite the entire file with `write` tool.
2. **Test incrementally on NixOS** — All hermes.nix changes were made on macOS and couldn't be tested. The `ReadWritePaths` bug existed in a committed state for ~25 minutes. Running `just test-fast` after each change would have caught parse errors but not runtime issues.
3. **Update docs in the same commit as code** — AGENTS.md was out of sync with the actual code after `EnvironmentFile` removal. Docs and code should always be updated together.
4. **Cross-reference systemd hardening with script needs** — When adding `ProtectHome`/`ProtectSystem` restrictions, systematically verify that ALL ExecStartPre scripts can access the paths they need.

### Architecture Improvements

5. **Consider upstream module instead of custom** — The upstream `hermes-agent` NixOS module already handles all this correctly (no `ProtectHome` at all, activation scripts for setup, proper ordering). Our custom module exists for flake-parts compatibility, but the upstream patterns are battle-tested.
6. **Move `.env` merge to activation script** — The 30-second poll loop in `mergeEnvScript` (waiting for sops template) is fragile. An activation script with `stringAfter ["setupSecrets"]` guarantees the sops template exists before the merge runs.
7. **Config merge script** — Upstream has a Python deep-merge script for `config.yaml`. Our module doesn't handle config at all (Hermes writes it at runtime). This is fine for now but may need attention if we want declarative config.

---

## F) Top 25 Things We Should Get Done Next

### Critical — Must Do Before Any Other Work

1. **Deploy to NixOS** — `just switch` on evo-x2, verify service starts
2. **Verify `systemctl status hermes`** — Service must be active (running) after boot
3. **Verify migration** — Check `/var/lib/hermes/` has data from old `/home/lars/.hermes/`
4. **Verify `.env` file** — `/var/lib/hermes/.env` must contain API keys from sops
5. **Verify `.managed` marker** — `/var/lib/hermes/.managed` must exist after activation

### High — Important for Reliability

6. **Move `mergeEnvScript` to activation script** — Replace the 30s poll loop with proper `stringAfter ["setupSecrets"]` ordering. Keep ExecStartPre as a lightweight "ensure .env is fresh" step.
7. **Add health check** — Add `ExecStartPost` or systemd health check that verifies Hermes is actually listening (e.g., check gateway_state.json appears within 30s)
8. **Verify `ExecReload` with SIGUSR1** — Confirm Hermes actually handles SIGUSR1 for graceful reload. If not, remove it.
9. **Add `logrotate` for `/var/lib/hermes/logs/`** — Hermes writes logs there; without rotation they'll grow unbounded.
10. **Test crash recovery** — `sudo systemctl kill hermes` then verify it restarts correctly
11. **Test sops secret rotation** — Change a secret, run `just switch`, verify `hermes.service` restarts and picks up new value

### Medium — Cleanup & Polish

12. **Remove `oldStateDir` from `ReadWritePaths`** — After migration is confirmed successful on NixOS
13. **Remove migration script entirely** — After old state dir is confirmed empty/unused
14. **Remove `oldStateDir` let binding** — After migration script is removed
15. **Add `package` option** — Make `hermesPkg` configurable via module option (like upstream)
16. **Add `extraPackages` option** — Allow additional runtime dependencies (like upstream)
17. **Add `workingDirectory` option** — Separate workspace path from state dir (like upstream)
18. **Add `environmentFiles` option** — Support additional env file sources (like upstream)
19. **Add `deepConfigType` for config.yaml** — Nix-level `lib.recursiveUpdate` merging (like upstream)
20. **Add `configMergeScript`** — Python deep-merge for config.yaml (like upstream)

### Low — Nice to Have

21. **Add NixOS test** — `nixosTests.hermes` that spins up VM and verifies service starts
22. **Add `services.hermes.openFirewall` option** — If Hermes ever exposes an HTTP port
23. **Add `services.hermes.environment` option** — Extra environment variables for the service
24. **Add Prometheus metrics endpoint** — If Hermes exposes metrics, scrape them in SigNoz OTel collector
25. **Add backup recipe** — `just hermes-backup` to export gateway state + config

---

## G) Top Question I Cannot Figure Out Myself

**Does `hermes gateway run --replace` actually work with the current Hermes version?**

The `--replace` flag was added to the ExecStart in commit `64c3203` but I cannot verify:

1. Whether the current pinned `hermes-agent` flake input supports this flag
2. Whether `--replace` means "replace existing gateway instance" (desirable) or something else
3. Whether the upstream module uses this flag (it doesn't — upstream just runs `hermes gateway`)

The upstream module uses: `${cfg.package}/bin/hermes gateway ${cfg.extraArgs}`
Our module uses: `${hermesPkg}/bin/hermes gateway run --replace`

The `run` subcommand and `--replace` flag may be from a newer version or may not exist. **This can only be verified on the NixOS machine by running `hermes gateway --help` after deploy.**

---

## File Change Summary (this session)

| File                                    | Change                                                                                            |
| --------------------------------------- | ------------------------------------------------------------------------------------------------- |
| `modules/nixos/services/hermes.nix:192` | Added `oldStateDir` to `ReadWritePaths`                                                           |
| `AGENTS.md:382`                         | Fixed `EnvironmentFile` reference to describe actual `mergeEnvScript` + `load_hermes_dotenv` flow |

## Git State

- **Branch**: `master`
- **Uncommitted changes**: 2 files modified (hermes.nix, AGENTS.md)
- **Last commit**: `862c67b fix(hermes): convert from user service to system-level service for boot-time startup`
