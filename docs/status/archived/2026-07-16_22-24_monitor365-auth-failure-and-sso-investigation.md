# Monitor365 Agent-Server Auth Failure & SSO Investigation

**Date:** 2026-07-16 22:24
**Session Scope:** Diagnose monitor365 agent/server logs, find root cause of 401 auth failures + SSO login errors
**Status:** Root causes identified, code fixes written and **hardened**, **NOT DEPLOYED**

---


## Hardening Session (2026-07-16 23:00)

Critical review of the initial fix identified 7 issues. All code-level issues fixed:

| Issue                                                | Fix                                              | Commit     |
| ---------------------------------------------------- | ------------------------------------------------ | ---------- |
| No empty-token guard (would recreate SHA256("") bug) | Skip sync when token is empty                    | `8b1d6d14` |
| SQL interpolation without hash validation            | `grep -qE '^[0-9a-f]{64}$'` before any SQL       | `8b1d6d14` |
| Token trim mismatch with upstream Rust `trim()`      | `sed 's/^[[:space:]]*//;s/[[:space:]]*$//'`      | `8b1d6d14` |
| `2>/dev/null` hid DuckDB errors                      | Removed -- errors now visible in journal         | `8b1d6d14` |
| No read-back verification after UPDATE               | SELECT + grep to confirm row was updated         | `8b1d6d14` |
| Post-deploy-check only checked HTTP 200              | Added functional check for `realtime` field      | `9cc5fc5d` |
| No Gatus alert for agent disconnection               | Added check: `realtime != connected (0 devices)` | `3d1f0591` |
| Pre-commit statix scanned entire repo                | Fixed to only check staged files                 | `8b1d6d14` |
| Pre-commit alejandra version mismatch with treefmt   | Replaced with treefmt formatting                 | `8b1d6d14` |

**Remaining manual steps (require deploy):**

1. Deploy: `nix run .#deploy`
2. Verify agent connects: `/health` shows `connected (1+ devices)`
3. Verify SSO login works end-to-end
4. Stop stale `monitor365-desktop` user service: `systemctl --user stop monitor365-desktop`

---

## What Was Done

### a) FULLY DONE

1. **Agent 401 root cause identified.** The server's `auto_bootstrap` is idempotent — it reads the API key from sops ONLY on first boot. The `cloud_auth_token` sops secret was initially **empty** (set to a real value in commit `dff374a9`, Jul 4). The server stored `SHA256("")` in `tenants.api_key` and never updated it. The agent sends the real key → SHA256 mismatch → 401 on every endpoint.
2. **Full auth chain traced from source.** Agent sends `x-api-key: <plaintext>` (HTTP) / `Authorization: Bearer <plaintext>` (WS). Server hashes with SHA-256, looks up `tenants.api_key`. No match → 401.
3. **API key sync oneshot service written.** `monitor365-api-key-sync.service` runs before server start, re-syncs sops secret SHA-256 into DuckDB `tenants` table via `pkgs.duckdb` CLI. Non-fatal on failure.
4. **`wmctrl` added to runtimeDeps.** Agent logged `wmctrl not found - Window collector may have issues` every second.
5. **Orphaned `monitor365-desktop-metrics` port (9192) removed** from `lib/ports.nix`.
6. **SSO flow verified working** from logs — successful OIDC login at 20:09:53 (`SSO login completed user_id=u-ad5d0c08...`). Pocket ID → OIDC code exchange → userinfo → user lookup → JWT issued.
7. **No-JIT-provisioning confirmed** from source (`handlers/sso/flow.rs:207-215`). Users must be pre-provisioned. Error: `"SSO user not found — user must be provisioned before SSO login"`.
8. **AGENTS.md documented** with API key desync + no-JIT-SSO rows.
9. **`nix flake check --no-build` passes.** Module evaluates correctly.

### b) PARTIALLY DONE

1. **Fix written but NOT deployed.** `nix run .#deploy` needed to apply changes. The agent is still 401-ing as of this report.
2. **DuckDB background task error noted but not investigated.** `Binder Error: No function matches '-(TIMESTAMP WITH TIME ZONE, INTERVAL)'` in `bg.cleanup` on server startup. Non-fatal — server continues. Likely an upstream DuckDB version incompatibility with the cleanup SQL.
3. **Event buffer overflow documented but not addressed.** Agent drops events at 95% buffer pressure because events pile up from failed uploads. After auth fix + deploy, the backlog should flush naturally — but there's no mechanism to measure or alert on this.

### c) NOT STARTED

1. **No post-deploy verification plan written.** Should verify: `GET /health` shows `connected (1 device)`, no more 401s in server logs, agent logs show `SSO login completed` without auth errors.
2. **No Gatus health check added** for the API key sync service.
3. **Stale `monitor365-desktop` user service not cleaned.** It has 58,000+ failures from Jul 12 (old generation). It's not in current SystemNix config but the old unit definition lingers. Needs `systemctl --user stop` + reset-failed, or a reboot.
4. **DISPLAY/WAYLAND_DISPLAY not resolved** for the agent's clipboard collector. The unified agent skips desktop collectors gracefully, but the root cause (IPC socket discovery from active graphical session) was not investigated.

### d) TOTALLY FUCKED UP

1. **SQL injection vulnerability in the DuckDB UPDATE.** The oneshot builds SQL via string interpolation: `duckdb "$DB" "UPDATE tenants SET api_key = '$HASH';"`. The `$HASH` is always a hex SHA-256 digest (64 chars, `[0-9a-f]`), so exploitation is practically impossible — but this is **bad practice** and sets a wrong precedent. DuckDB CLI doesn't support parameterized queries, but we could at least validate `$HASH` matches `^[0-9a-f]{64}$` before interpolating.
2. **Did not fully investigate the "No account found for this email" SSO error.** The user reported this specific error. I found SSO worked at 20:09:53 and pivoted to the 401 auth issue. But the user may have hit the SSO error AFTER the server restart at 20:49 (projection rebuild from event store). If the projection rebuild dropped or corrupted the user row, the SSO lookup `get_user_by_email` would fail. I did NOT verify the user table is intact after the rebuild.
3. **Did not verify `harden {}` won't block DuckDB access.** The oneshot uses `harden {}` which sets `ProtectSystem = "full"` and `ProtectHome = true`. `/var/lib/monitor365-server/` should be writable (not under `/usr`/`/boot`), and `/run/secrets/` is not under `/home`. But I did not run the service to confirm. `ProtectHome = true` could theoretically interfere if any path resolves through a home directory mount.

### e) WHAT WE SHOULD IMPROVE

1. **The API key sync is a band-aid.** The real fix is upstream: `auto_bootstrap` should re-sync the API key on every startup (not just first boot), or expose a `sync-api-key` CLI command. The oneshot is fragile — it assumes the DuckDB schema (column name `api_key`, table name `tenants`) and the hashing algorithm (`SHA256(plaintext)` → lowercase hex).
2. **No monitoring on monitor365 agent health.** The agent has a metrics endpoint on `127.0.0.1:9191` but there's no Gatus check for it. The 401 auth failure went undetected for days (313+ consecutive WS failures, 58k+ desktop failures since Jul 12).
3. **Event buffer pressure has no visibility.** The agent silently drops events at 95% buffer capacity. No metric, no alert, no way to know data is being lost.
4. **The agent's `logging.level = "warn"` hides important context.** The 401 auth error only shows as `WARN Agent WS disconnected... HTTP error: 401`. At `info` level, we'd see the actual auth flow. Consider `debug` for initial troubleshooting, then back to `warn`.
5. **No integration test for the auth chain.** The server has unit tests for auth, but nothing tests the full chain: sops secret → LoadCredential → agent → `x-api-key` header → server → DuckDB lookup. A `post-deploy-check` assertion that the agent is connected would catch this.
6. **The SSO error UX is terrible.** `"SSO user not found — user must be provisioned before SSO login"` is an internal error message exposed to the end user via URL query param. The WASM UI should show a friendly message with a link to contact the admin.

---

## f) Up to 50 Things to Get Done Next

### Immediate (blocks deploy verification)

1. **Deploy the changes** (`nix run .#deploy`)
2. **Verify agent connects** — `GET /health` shows `connected (1 device)`
3. **Verify no more 401s** in server logs after deploy
4. **Verify SSO login works** end-to-end via browser
5. **Verify the user table is intact** after the projection rebuild (`duckdb` query `SELECT email FROM users`)

### Short-term (should do within 1-2 days)

6. **Add hash format validation** in the API key sync script (`^[0-9a-f]{64}$`)
7. **Add Gatus health check** for monitor365 agent connectivity (check `GET /health` shows `connected (1+ device)`)
8. **Add Gatus health check** for the agent metrics endpoint (`127.0.0.1:9191`)
9. **Add a `post-deploy-check` assertion** for monitor365 agent connection
10. **Investigate the DuckDB timestamp arithmetic error** (`-(TIMESTAMP WITH TIME ZONE, INTERVAL)` in bg.cleanup)
11. **Stop the stale `monitor365-desktop` user service** on the running system
12. **Verify the DuckDB UPDATE doesn't conflict** with DuckDB's WAL (single-writer model)
13. **Check if the event backlog flushes** after auth fix (agent should upload accumulated events)
14. **Set agent logging to `info` temporarily** to verify the auth flow, then revert to `warn`
15. **Add a Discord alert** for when the agent has been disconnected for >5 minutes

### Medium-term (should do within 1-2 weeks)

16. **Push upstream fix:** `auto_bootstrap` should re-sync API key on every startup (not just first boot)
17. **Push upstream fix:** Add `monitor365-server sync-api-key` CLI command as an alternative to the oneshot
18. **Push upstream fix:** DuckDB timestamp arithmetic compatibility for background cleanup
19. **Push upstream fix:** Better SSO error messages (don't expose internal error strings to users)
20. **Add upstream JIT SSO provisioning** — auto-create user on first successful OIDC login (big feature, may require design discussion)
21. **Investigate DISPLAY/WAYLAND_DISPLAY discovery** for the unified agent's clipboard collector
22. **Add buffer pressure metrics** to the agent — expose as Prometheus metric, alert on >80%
23. **Add a daily digest alert** for dropped events count
24. **Add monitoring for the DuckDB database size** — events accumulate, 30GB storage cap
25. **Review the agent's reconnect backoff** — currently `reconnect_in_secs: 1` with 313+ failures. Should use exponential backoff to reduce log spam
26. **Add a systemd watchdog** (`WatchdogSec`) to the agent if it supports `sd_notify`
27. **Review the `harden {}` settings** for the API key sync oneshot — verify no path access issues
28. **Add an upstream test** for the full auth chain (sops → agent → server → DuckDB)
29. **Consider mTLS** for agent-server auth instead of shared API key (more secure, per-device identity)
30. **Document the recovery procedure** — what to do when the API key desyncs again

### Long-term / Nice-to-have

31. **Add a Gatus dashboard tile** for monitor365 on the Homepage
32. **Review all monitor365 collectors** — which are useful, which produce noise
33. **Set up event retention policies** — how long to keep keystrokes/screenshots/etc.
34. **Add a backup mechanism** for the DuckDB database (server has a `backup` CLI command)
35. **Add storage encryption key management** — the encryption key at `/var/lib/monitor365/storage_key` has no rotation mechanism
36. **Review the agent's resource usage** — it consumes 256MB RSS, is that expected?
37. **Consider rate-limiting the agent's reconnect attempts** to reduce server log spam
38. **Add audit logging** for API key usage (which device, when, what endpoints)
39. **Review the Pocket ID OIDC client** for monitor365 — ensure PKCE is properly configured
40. **Add a health check for the IPC socket** at `/run/monitor365/agent.sock`
41. **Review the `graphicalUsers` option** — ensure it works with niri (Wayland only)
42. **Test the system service after a reboot** — verify agent starts and connects
43. **Monitor365 data encryption review** — verify E2E encryption for cloud transfers (upstream warns about it)
44. **Add a cleanup mechanism** for orphaned systemd user services after generation changes
45. **Review the `scrot` dependency** — does it work on Wayland? May need `grim` instead
46. **Consider adding `wtype`** for keystroke injection testing on Wayland
47. **Review the agent's `fs_event` collector** — `interval_seconds = 1, recursive = true` with empty `watch_paths` might be noisy
48. **Add a Gatus alert for SSO login failures** — alert if SSO callback returns an error
49. **Review the server's CORS configuration** — currently disabled, verify no issues
50. **Add a comprehensive integration test** that validates the entire monitor365 stack (agent + server + SSO + Caddy)

---

## g) Questions (that I CANNOT figure out myself)

1. **The sops `cloud_auth_token` value — is it the one you intended?** I cannot read the secret (permission denied). If the secret was set to a value you don't recognize, the API key sync will push THAT value to the server, and the agent will use it — but any other agents (on other machines, if any) would also need the same value. Can you verify the secret is the intended tenant API key?

2. **The "No account found for this email" error — when exactly did you see it?** The logs show SSO worked at 20:09:53, then the server restarted at 20:49 (projection rebuild). If you tried SSO after the restart and it failed, the projection rebuild may have dropped the user row. This would mean the event store has a gap. Can you tell me the approximate time you saw the error?

3. **Should I deploy now, or do you want to review the changes first?** The API key sync oneshot modifies the DuckDB database directly. If you prefer, I can first verify the current DB state (check if the user row exists, check the current API key hash) before deploying. This requires running `duckdb` as the `monitor365-server` user.

---

> **RESOLVED — Resolved. Work captured in CHANGELOG.md.**
> All forward-looking items in this report were completed in subsequent sessions.
