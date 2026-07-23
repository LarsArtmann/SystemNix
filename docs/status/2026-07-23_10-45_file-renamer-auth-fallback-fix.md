# Status: file-and-image-renamer Auth Fix — Session Report

**Date:** 2026-07-23 10:45
**Session Goal:** Diagnose and fix file-and-image-renamer AI auth failures

---

## a) FULLY DONE

### Upstream fix (file-and-image-renamer repo, commit `8bf60bd`, pushed to master)

1. **Added `ErrorTypeAuth`** to `pkg/domain/errors/errors.go` — a new error type for authentication failures (401/403, missing API keys). Non-retryable by design: a bad key will always be bad.
2. **Updated `IsRetryable()`** to exclude `ErrorTypeAuth` — auth errors are never retried.
3. **Added `IsAuth()` method** on `TypedError`.
4. **Updated `errorTypeNames`** `ValueSet` with `"auth_error"` string representation.
5. **Fixed `mapProviderError`** in `vision_adapter.go` — HTTP 401/403 now maps to `ErrorTypeAuth` instead of `ErrorTypeAPI`.
6. **Fixed `createVisionProvider`** in `vision_factory.go` — "API key not configured" now maps to `ErrorTypeAuth`.
7. **Added `FallbackOnAuth`** to `FallbackConfig` (default `true`) in `provider.go`.
8. **Added `ErrorTypeAuth` alias** to the provider package constants.
9. **Updated `classifyError`** in `retry.go` — auth errors trigger immediate fallback to the secondary provider.
10. **Updated test assertions** in `vision_pure_test.go` — 401/403 now expect `ErrorTypeAuth`.
11. **All 26 upstream test packages pass.**

### SystemNix changes (committed via auto-commit hook, commits `6a390c82` through `b5db6d5c`)

1. **Added sops secret** `file_renamer_synthetic_api_key` in `sops.nix` — reads the encrypted `synthetic_api_key` from `crush-daily.yaml`, owned by `primaryUser:users`, guarded with `svcEnabled "file-and-image-renamer"`.
2. **Updated module** `file-and-image-renamer.nix` — `apiKeyFile` is now `nullOr str` (default `null`). When null, no `ZAI_API_KEY_FILE` env var is emitted.
3. **Updated `configuration.nix`** — `syntheticApiKeyFile` now points to `config.sops.secrets.file_renamer_synthetic_api_key.path` instead of a plaintext file.
4. **Updated `flake.lock`** — `file-and-image-renamer` input updated to commit `8bf60bd`.
5. **Updated `AGENTS.md`** — Added gotcha entry documenting the auth fallback bug and fix.
6. **Updated `.crush/skills/sops-secret-management/SKILL.md`** — Documented the shared `crush-daily.yaml` secret.
7. **`nix flake check --no-build` passes.**
8. **`nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel` passes.**

---

## b) PARTIALLY DONE

1. **Testing** — `nix flake check --no-build` and `nix eval` pass, but no `nix build` or deploy was attempted. The build may reveal vendorHash changes or compilation issues from the upstream update.
2. **Dead-letter queue** — Identified 157 stale entries in `~/.file-renamer/dead-letter.json` from the auth failures. Documented the cleanup command but did NOT execute it.
3. **Monitoring** — No new Gatus health check was added to specifically detect auth failure patterns. The existing health check only monitors the HTTP `/status` endpoint, not AI processing success rate.

---

## c) NOT STARTED

1. **Deploy** — `nix run .#deploy` was NOT run. Changes exist in the Nix store eval but are not deployed to the running system.
2. **Dead-letter cleanup** — `echo '[]' > ~/.file-renamer/dead-letter.json` not executed.
3. **Stale plaintext file cleanup** — `~/.zai_api_key` (stale, invalid) still on disk. No longer referenced by the module, but should be `trash`ed.
4. **Post-deploy smoke test** — `nix run .#post-deploy-check` not run (requires deploy first).
5. **Runtime verification** — No confirmation that the Synthetic provider actually works with the sops-provisioned key after deploy.
6. **ZAI key rotation** — If ZAI is still desired as a primary provider, the key in `~/.zai_api_key` is stale/invalid and needs replacement or removal.

---

## d) TOTALLY FUCKED UP

1. **Auto-commit hook created misleading commit messages.** A pre-commit/post-edit hook auto-committed my changes with generic AI-generated messages (`feat(nixos): add file-renamer and sops service modules`, `chore(deps): update flake.lock`, etc.) that do NOT describe the actual auth fix. The real changes (auth error type, sops migration, nullable apiKeyFile) are buried in commits that sound like initial module creation. Anyone reading `git log` will be misled. The commits also include unrelated formatting changes (AGENTS.md table alignment) injected by a formatter in the hook.

2. **No regression test for the fallback-on-auth path.** I updated existing test assertions but did NOT write a new test that specifically verifies: "when primary provider returns 401, the fallback provider is called and succeeds." The `classifyError` change is tested implicitly but not explicitly. A future refactor could silently break the auth-fallback behavior without any test catching it.

3. **`/tmp` was 100% full (24GB tmpfs).** Discovered when cloning the upstream repo. Cleaned 22GB of stale go-build artifacts and gexec artifacts. This is a recurring problem — the AGENTS.md documents a 16GB cap on `/tmp` but the cap either isn't deployed or isn't effective. Build artifacts from tests accumulate silently.

---

## e) WHAT WE SHOULD IMPROVE

### Code Quality
1. **Add explicit regression test** — `TestFallbackProvider_AuthErrorTriggersFallback` that verifies the secondary provider is called when the primary returns `ErrorTypeAuth`.
2. **Add integration test** — end-to-end test that simulates a 401 from GLM and verifies Synthetic is used.
3. **Consider `ErrorTypeAuth` in the deadletter package** — `deadletter.go` has `ErrorTypeAPIError` but no `ErrorTypeAuthError` alias. Auth failures in the dead-letter queue will show as `"auth_error"` which is correct, but the package should export the constant for consistency.

### SystemNix Module
4. **Add `zaiApiKeyFile` sops secret** — If ZAI is ever re-enabled, it should also be sops-managed, not a plaintext file. Currently `apiKeyFile` defaults to `null` (ZAI disabled).
5. **Add Gatus check for AI processing health** — The existing health check only verifies the HTTP server is alive. A check that monitors `dead-letter.json` growth rate or `history.json` operation count would catch silent AI failures.
6. **Add `restartTriggers`** — The module has no `restartTriggers` on the watcher service. If the sops secret is rotated, the service won't restart automatically.
7. **Consider `LoadCredential` instead of env var** — The watcher passes the secret path via `SYNTHETIC_API_KEY_FILE` env var. Using systemd `LoadCredential` would be more secure (secret in `$CREDENTIALS_DIRECTORY`, not in `/proc/<pid>/environ`).

### Operational
8. **Remove stale plaintext files** — `~/.zai_api_key` and any `~/.synthetic_api_key` should be `trash`ed after deploy confirms the sops path works.
9. **Clear dead-letter queue** — 157 entries from Jul 13 are permanently stuck. They need either manual clearing or a `retry` command run.
10. **Verify Synthetic API key is valid** — The sops secret was originally for crush-daily. It SHOULD be the same key, but this was not verified end-to-end.
11. **Fix the auto-commit hook** — The hook generates misleading messages. Either disable it, improve its message generation, or manually amend the commits.

### Documentation
12. **Document the `ErrorTypeAuth` in upstream AGENTS.md** — The upstream repo's docs should explain the error type taxonomy and fallback behavior.
13. **Add upstream CHANGELOG entry** — The `8bf60bd` commit has no CHANGELOG entry.

---

## f) Up to 50 Things We Should Get Done Next

| # | Task | Priority | Effort |
|---|------|----------|--------|
| 1 | **Deploy** the changes (`nix run .#deploy`) | P0 | 5min |
| 2 | **Clear dead-letter queue** after deploy | P0 | 1min |
| 3 | **Run post-deploy smoke test** (`nix run .#post-deploy-check`) | P0 | 2min |
| 4 | **Verify** Synthetic API key works by dropping a test image in `~/Downloads` | P0 | 2min |
| 5 | **Trash stale `~/.zai_api_key`** after confirming Synthetic works | P1 | 1min |
| 6 | **Add regression test** `TestFallbackProvider_AuthErrorTriggersFallback` upstream | P1 | 15min |
| 7 | **Add CHANGELOG entry** to upstream repo for `8bf60bd` | P2 | 5min |
| 8 | **Add `restartTriggers`** to watcher service for sops secret rotation | P1 | 10min |
| 9 | **Add Gatus check** for dead-letter queue growth (alert if >5 new entries in 1h) | P2 | 20min |
| 10 | **Migrate `SYNTHETIC_API_KEY_FILE` to systemd `LoadCredential`** for better security | P2 | 15min |
| 11 | **Fix or disable auto-commit hook** — misleading commit messages | P1 | 30min |
| 12 | **Investigate `/tmp` cap effectiveness** — 24GB used despite documented 16GB cap | P1 | 15min |
| 13 | **Add `ErrorTypeAuthError` alias** to deadletter package for consistency | P3 | 5min |
| 14 | **Add ZAI sops secret** if ZAI provider is ever re-enabled | P3 | 10min |
| 15 | **Add health dashboard view** for auth failure count (track `ErrorTypeAuth` in dead-letter) | P3 | 30min |
| 16 | **Consider provider health metrics** — expose primary/secondary success ratio to Prometheus | P3 | 45min |
| 17 | **Add circuit breaker state** to health dashboard — currently invisible | P3 | 20min |
| 18 | **Document provider selection logic** in upstream README | P3 | 15min |
| 19 | **Review all other LarsArtmann Go services** for the same ErrorTypeAPI/auth classification bug | P2 | 60min |
| 20 | **Add pre-deploy check** that verifies sops secret exists and is readable | P2 | 15min |
| 21 | **Consider encrypting `~/.file-renamer/history.json`** — contains file paths and AI descriptions | P4 | 30min |
| 22 | **Add log rotation** for `~/.file-renamer/logs/watcher.log` — grows unbounded | P3 | 10min |
| 23 | **Add file size limit** for dead-letter.json — 157 entries already, could grow to thousands | P3 | 10min |
| 24 | **Add dead-letter auto-retry timer** — periodically retry `pending` entries after provider key rotation | P3 | 45min |
| 25 | **Review crush-daily** — shares the same Synthetic key, verify it's also not using a plaintext file | P2 | 10min |

---

## g) Questions I CANNOT Answer Myself

1. **Is the Synthetic API key in `crush-daily.yaml` still valid?** The key was encrypted for crush-daily. It SHOULD be the same Synthetic.new API key, but I cannot verify it without deploying and testing. If it's expired, both crush-daily AND file-renamer will fail.

2. **Do you want to keep ZAI as a provider at all?** Currently `apiKeyFile` defaults to `null` (ZAI disabled). The stale `~/.zai_api_key` suggests it was used before. If ZAI should still be the primary with Synthetic as fallback, I need a valid ZAI key in sops. If Synthetic-only is the intended future, the `apiKeyFile` option and `model` option can be deprecated.

3. **Should I amend the auto-commit messages, or leave them?** The commits `6a390c82` through `b5db6d5c` have misleading messages. I can `git rebase -i` to fix them, but that rewrites history on a repo that may be shared (the commits are not pushed to origin yet — `git status` shows "up to date with origin/master" which means the auto-commits are local-only). Per the rules, I will NOT do this without explicit instruction.
