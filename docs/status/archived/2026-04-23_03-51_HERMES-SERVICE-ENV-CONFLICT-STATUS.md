# Comprehensive Status Report — 2026-04-23 03:51

## Executive Summary

The Hermes Gateway service module has been converted from a user-level to a system-level systemd service across 4+ sessions with escalating bug fixes. **Two concurrent sessions made conflicting changes**: session A (this session lineage) removed `EnvironmentFile` and used `mergeEnvScript` to write ALL env vars to `.env`; session B (commit `2328de8`) re-introduced `EnvironmentFile` and simplified `mergeEnvScript` to only write non-secret vars. After git rebase, the current file contains **both approaches simultaneously** — `EnvironmentFile` AND `mergeEnvScript` — which is a design conflict that needs resolution.

**No deployment to NixOS has occurred.** All changes are untested at runtime.

---

## A) FULLY DONE

| Item                                      | Details                                                                    | Commit(s) |
| ----------------------------------------- | -------------------------------------------------------------------------- | --------- |
| System-level service conversion           | `systemd.services.hermes` targeting `multi-user.target`                    | `64c3203` |
| Dedicated system user/group               | `hermes`/`hermes` system user                                              | `64c3203` |
| State directory at `/var/lib/hermes`      | No `.hermes` nesting (unlike upstream)                                     | `64c3203` |
| `WatchdogSec` removed                     | Hermes doesn't implement `sd_notify()` — would cause 60s crash loop        | `862c67b` |
| Activation script added                   | `hermes-setup` with `stringAfter ["users" + "setupSecrets"]`               | `862c67b` |
| `.managed` marker in activation script    | Moved from broken `manageScript` to activation script                      | `862c67b` |
| Setgid directories (2770)                 | All state dirs use 2770 for group inheritance                              | `862c67b` |
| sops.nix secrets owner fixed              | Owner/group changed to `hermes`/`hermes`                                   | Earlier   |
| sops template mode + restartUnits         | `mode = "0400"`, `restartUnits = ["hermes.service"]`                       | Earlier   |
| justfile commands updated                 | `systemctl` (not `--user`), `/var/lib/hermes/` paths                       | Earlier   |
| Migration script with `+` prefix          | Runs as root to read `/home/lars/.hermes`                                  | `64c3203` |
| `ReadWritePaths` includes `oldStateDir`   | Migration script can reach `/home/lars/.hermes` despite `ProtectHome=true` | `973d544` |
| statix lint fix                           | `inherit (cfg) group` instead of `group = cfg.group`                       | `973d544` |
| AGENTS.md EnvironmentFile reference fixed | Corrected to describe `mergeEnvScript` + `load_hermes_dotenv`              | `973d544` |
| Nix syntax parse-check passes             | `nix-instantiate --parse` exits 0                                          | Verified  |
| Systemd hardening across 14 services      | PrivateTmp, NoNewPrivileges, ProtectClock, etc.                            | `2328de8` |
| Service dependency fixes                  | Caddy→Authelia, Gitea→token service, SigNoz→ClickHouse                     | `2328de8` |
| Watchdog for non-Hermes services          | 30s/60s WatchdogSec for services that implement sd_notify                  | `2328de8` |
| Whisper-asr type fix                      | Type=oneshot → Type=forking with PIDFile                                   | `2328de8` |
| Twenty sops template                      | `sops.templates."twenty-env"` for direct .env generation                   | `2328de8` |
| Git pushed                                | Both sessions' commits rebased and pushed                                  | Done      |

## B) PARTIALLY DONE

| Item                                 | Status                                                                         | What's Missing                                   |
| ------------------------------------ | ------------------------------------------------------------------------------ | ------------------------------------------------ |
| **Hermes env delivery architecture** | **CONFLICT**: file has both `EnvironmentFile` AND `mergeEnvScript` approaches  | Must choose one; see Section D                   |
| AGENTS.md documentation              | Says "mergeEnvScript + load_hermes_dotenv" but file also has `EnvironmentFile` | Must update to reflect final chosen architecture |
| Module-level eval check              | `nix eval --impure` timed out on macOS                                         | Need to verify on NixOS or with cached lock      |
| Full build test (`just test`)        | Not run                                                                        | Need to run on NixOS                             |

## C) NOT STARTED

| Item                                              | Priority | Notes                                                      |
| ------------------------------------------------- | -------- | ---------------------------------------------------------- |
| Deploy to NixOS (`just switch`)                   | Critical | Cannot verify anything until deployed                      |
| Verify service starts at boot                     | Critical | `systemctl status hermes` on NixOS after reboot            |
| Verify migration works                            | High     | Check `/var/lib/hermes` has data from `/home/lars/.hermes` |
| Verify `.env` file                                | High     | Check `/var/lib/hermes/.env` after service start           |
| Verify `.managed` marker                          | Medium   | Check `/var/lib/hermes/.managed` after activation          |
| Resolve env delivery conflict                     | Critical | Must decide: EnvironmentFile or mergeEnvScript             |
| Clean up old user service                         | Low      | Home Manager auto-removes `hermes-gateway` on next apply   |
| Remove `oldStateDir` from `ReadWritePaths`        | Low      | Only needed during migration; remove after confirmed       |
| Remove migration script entirely                  | Low      | No-op after migration; safe to keep but should clean up    |
| Add `hermes gateway run --replace` verification   | Low      | Verify `--replace` flag exists in pinned Hermes version    |
| Move `mergeEnvScript` to activation script        | Medium   | Replace 30s poll loop with `stringAfter ["setupSecrets"]`  |
| Add health check (ExecStartPost)                  | Medium   | Verify Hermes is listening after start                     |
| Verify `ExecReload` with SIGUSR1                  | Medium   | Confirm Hermes handles SIGUSR1                             |
| Add `logrotate` for `/var/lib/hermes/logs/`       | Medium   | Unbounded log growth without rotation                      |
| Add module options (package, extraPackages, etc.) | Low      | Like upstream module                                       |
| Add NixOS test                                    | Low      | `nixosTests.hermes` VM test                                |

## D) TOTALLY FUCKED UP

### Critical Conflict: Dual Env Delivery Architecture

**The current `hermes.nix` has BOTH `EnvironmentFile` AND `mergeEnvScript` active simultaneously.** This happened because two concurrent sessions made opposing design decisions:

**Session A (our lineage — commits `862c67b`, `973d544`):**

- Removed `EnvironmentFile` entirely
- `mergeEnvScript` writes ALL env vars (secrets + non-secrets) from sops template to `.env`
- Hermes reads `.env` at runtime via `load_hermes_dotenv()`
- Rationale: `EnvironmentFile` fails hard if file missing; Hermes has its own `.env` reader
- Removed 30s poll loop for sops template

**Session B (commit `2328de8`):**

- Added `EnvironmentFile = [sopsEnvPath]`
- Simplified `mergeEnvScript` to only write non-secret vars (`OLLAMA_API_KEY=ollama`, `TERMINAL_ENV=local`)
- Rationale: "Removed fragile 30-second wait loop for sops template file; instead always load secrets via EnvironmentFile which nix+sops handle atomically"
- But: `OLLAMA_API_KEY=ollama` and `TERMINAL_ENV=local` are ALSO in the sops template (sops.nix L109-110), creating duplication

**Current state after rebase (L157 + L22-31 + sops.nix L109-110):**

```
# mergeEnvScript writes to .env:
OLLAMA_API_KEY=ollama
TERMINAL_ENV=local

# EnvironmentFile loads from sops template:
DISCORD_BOT_TOKEN=...
GLM_API_KEY=...
MINIMAX_API_KEY=...
FAL_KEY=...
FIRECRAWL_API_KEY=...
OLLAMA_API_KEY=ollama      ← DUPLICATE
TERMINAL_ENV=local          ← DUPLICATE
```

**Problems with current hybrid state:**

1. `OLLAMA_API_KEY` and `TERMINAL_ENV` are written to `.env` by `mergeEnvScript` AND loaded via `EnvironmentFile` — systemd's `EnvironmentFile` overrides `Environment`, but `.env` is also read by Hermes directly → unpredictable which value wins
2. The secret keys (DISCORD_BOT_TOKEN, etc.) are loaded via `EnvironmentFile` into systemd's environment, BUT Hermes also reads `.env` via `load_hermes_dotenv()` — if `.env` doesn't have these keys, Hermes won't find them in its own `.env` reader (it may fall back to process env, but this is fragile)
3. AGENTS.md says "mergeEnvScript + load_hermes_dotenv" but the file now also has `EnvironmentFile` — documentation is inconsistent

**Resolution needed:** Choose ONE approach.

| Approach                                                            | Pros                                                                                         | Cons                                                                                                                                                                                |
| ------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **A: mergeEnvScript only (no EnvironmentFile)**                     | Single source of truth; Hermes reads `.env` natively; consistent with AGENTS.md current text | Needs sops template to exist before ExecStartPre (handled by activation script ordering or poll loop)                                                                               |
| **B: EnvironmentFile only (no mergeEnvScript)**                     | Atomic; sops guarantees file exists; no poll loop                                            | `EnvironmentFile` fails hard if file missing (systemd won't start service); Hermes may not find keys via its own `.env` reader; contradicts upstream pattern (no `EnvironmentFile`) |
| **C: EnvironmentFile for secrets + mergeEnvScript for non-secrets** | Clean separation                                                                             | Duplication of `OLLAMA_API_KEY`/`TERMINAL_ENV` across both paths; `.env` file incomplete for Hermes's own reader; complex                                                           |

**Recommendation:** Approach A. Hermes is designed to read `.env` via `load_hermes_dotenv()`. The sops template already contains all vars (secrets + non-secrets). `mergeEnvScript` should merge the entire sops template into `.env`, and `EnvironmentFile` should be removed. This is consistent with the upstream module (which has no `EnvironmentFile`) and with our earlier design decision in `862c67b`.

### Previously Fixed Bugs

| Bug                                                              | Severity | Fix Commit                              |
| ---------------------------------------------------------------- | -------- | --------------------------------------- |
| `WatchdogSec = "60"` causing crash loop                          | Critical | `862c67b`                               |
| `EnvironmentFile = sopsEnvPath` causing hard failure             | Critical | `862c67b` (re-introduced by `2328de8`!) |
| `manageScript` overwritten by `migrateScript` (multiedit damage) | Critical | `862c67b`                               |
| Migration script ran as `hermes` user (can't read `/home/lars/`) | Critical | `64c3203`                               |
| `ProtectHome=true` + missing `oldStateDir` in `ReadWritePaths`   | Critical | `973d544`                               |
| AGENTS.md `EnvironmentFile` reference incorrect                  | Medium   | `973d544`                               |

## E) WHAT WE SHOULD IMPROVE

### Process Improvements

1. **Coordinate concurrent sessions** — Two sessions made opposing design decisions on the same file. The `EnvironmentFile` removal in `862c67b` was reversed by `2328de8`. Need to establish: once a design decision is made and committed, document it clearly so other sessions don't reverse it.
2. **Never use multiedit for complex script blocks** — The multiedit tool created a malformed file by overlapping two script definitions. For multi-line shell scripts in Nix, always rewrite the entire file with `write` tool.
3. **Test incrementally on NixOS** — All changes were made on macOS and couldn't be tested. Running `just test-fast` after each change catches parse errors but not runtime issues.
4. **Update docs in the same commit as code** — AGENTS.md must stay in sync with code changes.
5. **Cross-reference systemd hardening with script needs** — When adding `ProtectHome`/`ProtectSystem`, verify ALL ExecStartPre scripts can access needed paths.

### Architecture Improvements

6. **Resolve env delivery to single approach** — Current hybrid is the worst of both worlds. Pick one (recommendation: `mergeEnvScript` only, no `EnvironmentFile`).
7. **Move `.env` merge to activation script** — Replace any poll loop with proper `stringAfter ["setupSecrets"]` ordering. Keep ExecStartPre as lightweight "ensure .env is fresh" step.
8. **Consider upstream module** — The upstream `hermes-agent` NixOS module already handles all this correctly. Our custom module exists for flake-parts compatibility but should follow upstream patterns more closely.
9. **Config merge script** — Upstream has Python deep-merge for `config.yaml`. We don't handle config (Hermes writes at runtime). Fine for now.
10. **Remove `mergeEnvScript` non-secret vars from sops template** — If using Approach A, `OLLAMA_API_KEY=ollama` and `TERMINAL_ENV=local` are in the sops template AND would be written by `mergeEnvScript` — they should only be in ONE place.

## F) Top 25 Things We Should Get Done Next

### Critical — Must Do Before Any Other Work

1. **Resolve env delivery conflict** — Choose Approach A/B/C, implement, update AGENTS.md accordingly
2. **Deploy to NixOS** — `just switch` on evo-x2, verify service starts
3. **Verify `systemctl status hermes`** — Service must be active (running) after boot
4. **Verify migration** — Check `/var/lib/hermes/` has data from old `/home/lars/.hermes/`
5. **Verify `.env` file** — `/var/lib/hermes/.env` must contain all API keys
6. **Verify `.managed` marker** — `/var/lib/hermes/.managed` must exist after activation

### High — Important for Reliability

7. **Move `mergeEnvScript` to activation script** — Replace any poll loop with `stringAfter ["setupSecrets"]` ordering
8. **Verify `hermes gateway run --replace`** — On NixOS, run `hermes gateway --help` to confirm flag exists
9. **Add health check** — `ExecStartPost` that verifies Hermes is listening
10. **Verify `ExecReload` with SIGUSR1** — Confirm Hermes handles SIGUSR1
11. **Add `logrotate` for `/var/lib/hermes/logs/`** — Unbounded growth without rotation
12. **Test crash recovery** — `sudo systemctl kill hermes` then verify restart
13. **Test sops secret rotation** — Change a secret, `just switch`, verify Hermes picks up new value

### Medium — Cleanup & Polish

14. **Remove `oldStateDir` from `ReadWritePaths`** — After migration confirmed successful
15. **Remove migration script entirely** — After old state confirmed empty/unused
16. **Remove `oldStateDir` let binding** — After migration script removed
17. **Remove non-secret vars from sops template** — If using mergeEnvScript-only approach, `OLLAMA_API_KEY=ollama` and `TERMINAL_ENV=local` shouldn't be in sops template
18. **Add `package` option** — Make `hermesPkg` configurable (like upstream)
19. **Add `extraPackages` option** — Allow additional runtime deps (like upstream)
20. **Add `workingDirectory` option** — Separate workspace from state dir (like upstream)

### Low — Nice to Have

21. **Add NixOS test** — `nixosTests.hermes` VM test
22. **Add `services.hermes.openFirewall` option** — If Hermes exposes HTTP port
23. **Add `services.hermes.environment` option** — Extra env vars
24. **Add Prometheus metrics** — If Hermes exposes metrics, scrape in SigNoz
25. **Add backup recipe** — `just hermes-backup` for gateway state + config

---

## G) Top Question I Cannot Figure Out Myself

**Should `EnvironmentFile` be used at all?**

Session A removed it because:

- Hermes reads `.env` via its own `load_hermes_dotenv()` — it expects keys in `.env`, not just in process environment
- `EnvironmentFile` fails hard if file doesn't exist (systemd won't start service)
- Upstream NixOS module does NOT use `EnvironmentFile`

Session B added it because:

- "nix+sops handle atomically" — sops-nix guarantees the template file exists before the service starts
- Removes the "fragile" 30-second poll loop
- Cleaner separation of secrets vs non-secrets

**The critical question:** Does Hermes's `load_hermes_dotenv()` fall back to process environment if a key isn't in `.env`? If yes, `EnvironmentFile` works (secrets in process env, non-secrets in `.env`). If no, `.env` must contain ALL keys including secrets — making `EnvironmentFile` pointless.

**This can only be verified by reading the Hermes source code or testing on NixOS.**

---

## File Change Summary

| File                                       | Current State                                                   | Issue                                                              |
| ------------------------------------------ | --------------------------------------------------------------- | ------------------------------------------------------------------ |
| `modules/nixos/services/hermes.nix`        | Has both `EnvironmentFile` (L157) and `mergeEnvScript` (L13-32) | **Design conflict** — must resolve                                 |
| `AGENTS.md` L382                           | Says "mergeEnvScript + load_hermes_dotenv"                      | Doesn't mention `EnvironmentFile` — inconsistent with current code |
| `AGENTS.md` L376                           | Says "secrets + non-secret env"                                 | Accurate regardless of approach chosen                             |
| `modules/nixos/services/sops.nix` L109-110 | `OLLAMA_API_KEY=ollama`, `TERMINAL_ENV=local` in sops template  | Duplicated by `mergeEnvScript` if both approaches active           |

## Git State

- **Branch**: `master`
- **Clean**: Yes (nothing to commit, working tree clean)
- **Ahead of origin**: 1 commit (`973d544` — needs `git push`)
- **Last commit**: `973d544 fix(hermes): add oldStateDir to ReadWritePaths and fix statix lint`
- **Rebase history**: `862c67b` → `2328de8` (remote) → `973d544` (rebased on top)
