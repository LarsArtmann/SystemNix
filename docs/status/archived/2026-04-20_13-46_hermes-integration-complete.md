# Full Project Status Report — 2026-04-20 13:46

## System Health

| Metric     | Value                                     |
| ---------- | ----------------------------------------- |
| Host       | evo-x2 (AMD Ryzen AI Max+ 395, 128GB RAM) |
| Uptime     | 4h27m                                     |
| Load       | 1.51 / 1.32 / 1.63                        |
| RAM        | 27GB used / 62GB total (34GB available)   |
| Swap       | 7.8GB used / 41GB total                   |
| Root disk  | 351GB / 512GB (71%)                       |
| /data disk | 537GB / 800GB (68%)                       |

---

## A) FULLY DONE

### 1. Hermes Declarative NixOS Integration (Primary work today)

**Before**: Hermes was installed imperatively via `nix profile install`, had a manually managed systemd service referencing hardcoded `/nix/store` paths (version 0.8.0 env while binary was 0.10.0), and all API keys were in plaintext `~/.hermes/.env` and `config.yaml`.

**After**: Fully declarative via Nix flake:

| Component                                                         | Status                                                                                        |
| ----------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| Flake input (`github:NousResearch/hermes-agent`, follows nixpkgs) | `flake.nix`, locked in `flake.lock`                                                           |
| NixOS module (`modules/nixos/services/hermes.nix`)                | Options: `enable`, `user`, `home`, `restartSec`, `timeoutStopSec`                             |
| Home Manager systemd service                                      | `systemd.user.services.hermes-gateway` — declarative, auto-managed                            |
| Sops secrets (`platforms/nixos/secrets/hermes.yaml`)              | 5 encrypted keys: discord_bot_token, glm_api_key, minimax_api_key, fal_key, firecrawl_api_key |
| Sops template (`hermes-env`)                                      | Renders decrypted `.env` merged into `~/.hermes/.env` via `ExecStartPre`                      |
| System packages                                                   | `hermes-agent` 0.10.0 + `libopus` (Discord voice)                                             |
| AGENTS.md documentation                                           | Full section with architecture, options table, commands                                       |
| Justfile commands                                                 | `just hermes-status`, `just hermes-restart`, `just hermes-logs`                               |
| `services.hermes.enable = true`                                   | Wired in `configuration.nix`                                                                  |
| Flake check                                                       | All checks pass                                                                               |

**Commits**: `05c862e`, `a20c662`, `9dc5f21`

### 2. Hermes Config Hardening (Applied to `~/.hermes/`, not in repo)

| Fix                                     | Detail                                                           |
| --------------------------------------- | ---------------------------------------------------------------- |
| `key_env: GLM_API_KEY`                  | Replaced plaintext ZAI api_key in `config.yaml`                  |
| `timezone: Europe/Warsaw`               | Was empty — cron scheduling ambiguous                            |
| `redact_pii: true`                      | Was `false`                                                      |
| Logging: `WARNING`, 10MB, 7 backups     | Was `INFO`, 5MB, 3 backups                                       |
| `SUDO_PASSWORD` removed from `.env`     | Agent no longer has automatic sudo                               |
| `OLLAMA_API_KEY=ollama` added to `.env` | Fixes cron job "No LLM provider configured" errors               |
| File permissions `600`                  | `credentials.json`, `token.json`, `token_work.json` (were `644`) |
| Cron: `systemnix-audit` schedule fixed  | Daily → Weekly Sunday 10am                                       |
| Stale session cleanup                   | Dumps >7d, sessions >30d removed                                 |
| Skill directory permissions             | `chmod -R u+w` on read-only nix store skill dirs                 |

### 3. Other Commits Today (by Crush and others)

| Commit    | Description                                                                           |
| --------- | ------------------------------------------------------------------------------------- |
| `a20c662` | Fix `.env` symlink → `ExecStartPre` merge script (Hermes writes to `.env` at runtime) |
| `b5ba48f` | SigNoz alert rules: GPU thermal, dnsblockd, emeet-pixyd; fix dnsblockd CSS            |
| `3033750` | Security: harden dnsblockd against XSS, fix node_exporter systemd collector           |
| `b9bdebf` | Archive old status reports                                                            |
| `a071062` | Homepage system resource widgets (CPU, RAM, disk, uptime)                             |
| `c4804fc` | CI: emeet-pixyd Go test job                                                           |
| `4112972` | CI: weekly flake.lock auto-update workflow                                            |
| `9b9a005` | Timeshift snapshot freshness verification timer                                       |
| `29b20a2` | voice-agents: systemd timeout prefix instead of shell error suppression               |
| `36b5205` | Status report                                                                         |

---

## B) PARTIALLY DONE

### Hermes Deployment

- **Module is written and committed** but `just switch` has NOT been run
- Hermes gateway is still running from the old imperative install (`/nix/store/bicvmk.../.../python`)
- Still shows `Opus codec not found` warning (libopus fix needs deployment)
- Old `nix profile install` hermes-agent not yet removed

### `key_env` Migration

- Only ZAI provider migrated to `key_env: GLM_API_KEY`
- Ollama still has inline `api_key: ollama` (acceptable — it's a non-secret placeholder)
- Other providers (auxiliary vision, compression, etc.) have empty `api_key: ''` with `provider: auto` (no change needed)

---

## C) NOT STARTED

| Item                              | Description                                                                                                  |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| **Google OAuth in sops**          | `credentials.json` content not encrypted — Gmail API client ID/secret still in plaintext                     |
| **Google OAuth tokens in sops**   | `token.json`/`token_work.json` not encrypted — runtime tokens, change frequently                             |
| **config.yaml as Nix module**     | `~/.hermes/config.yaml` still manually managed (Hermes writes at runtime via `hermes model`, `hermes setup`) |
| **Hermes SigNoz monitoring**      | No journald receiver targeting, no dashboard, no alerts                                                      |
| **Auxiliary model configuration** | Vision, compression, session_search all use `provider: auto` — could use local Ollama                        |
| **Smart model routing**           | `enabled: false` — could route simple turns to cheaper local model                                           |
| **Session rotation**              | `session_reset.mode: none` — sessions never auto-reset                                                       |
| **Browser backend**               | `browser.backend: firecrawl` requires API key — local browser (Camofox) alternative not explored             |
| **Cron DNS resilience**           | Intermittent `discord.com:443` resolution failures in cron delivery                                          |
| **Memory limits**                 | No `MemoryMax`/`MemoryHigh` on hermes-gateway service                                                        |
| **FileSystem restrictions**       | No `ReadWritePaths`/`ProtectSystem` hardening on service                                                     |

---

## D) TOTALLY FUCKED UP

**Nothing catastrophically broken.** One close call:

- **Initial `.env` approach was wrong**: First used `L+` tmpfiles symlink to sops-rendered template. This would have made `.env` read-only, breaking `save_env_value()` that Hermes calls during `hermes model` / `hermes setup`. Fixed in `a20c662` with `ExecStartPre` merge script instead.

---

## E) WHAT WE SHOULD IMPROVE

### Architecture

1. **`.env` merge is fragile** — the `ExecStartPre` shell script does line-by-line sed replacement. Could break on multi-line values or special characters. Consider using `pkgs.writePython3Script` with proper dotenv parsing.
2. **Config not fully declarative** — `config.yaml` is 340 lines of runtime-managed config. Even a partial Nix rendering (for timezone, logging, display settings) would reduce drift.
3. **No health check** — the service has no `WatchdogSec` or health check endpoint.

### Security

4. **Google OAuth client secret in plaintext** — `credentials.json` has `client_secret` in cleartext. Should be in sops.
5. **No systemd hardening** — missing `ProtectSystem`, `ReadWritePaths`, `PrivateTmp`, `NoNewPrivileges`.
6. **`GATEWAY_ALLOW_ALL_USERS: true`** — any Discord user can interact with the bot. Consider restricting.

### Observability

7. **No hermes dashboard** — SigNoz has no dedicated hermes panel.
8. **Cron delivery failures** — DNS timeouts cause delivery errors. No retry logic.
9. **No alerting on gateway crashes** — only `Restart=on-failure`, no notification.

### Operations

10. **Old nix profile still installed** — `nix profile list` shows hermes-agent alongside the flake input. Redundant.
11. **No backup strategy for `~/.hermes/`** — sessions, memories, cron state are all user data with no backup.

---

## F) Top #25 Things to Do Next

Sorted by impact/effort ratio (highest first):

| #  | Task                                                               | Impact   | Effort | Category        |
| -- | ------------------------------------------------------------------ | -------- | ------ | --------------- |
| 1  | **`just switch` to deploy hermes module**                          | Critical | 5min   | Deploy          |
| 2  | Verify hermes starts with new HM service + Opus works              | Critical | 2min   | Verify          |
| 3  | `nix profile remove hermes-agent` cleanup                          | High     | 1min   | Cleanup         |
| 4  | Add `WatchdogSec=60` to hermes service                             | High     | 1min   | Reliability     |
| 5  | Add systemd hardening (ProtectSystem, ReadWritePaths)              | High     | 10min  | Security        |
| 6  | Google OAuth credentials.json → sops                               | Medium   | 15min  | Security        |
| 7  | Configure auxiliary vision to use local Ollama model               | Medium   | 10min  | Performance     |
| 8  | Enable smart_model_routing with local cheap model                  | Medium   | 10min  | Performance     |
| 9  | Add hermes to SigNoz journald receiver                             | Medium   | 5min   | Observability   |
| 10 | Set `session_reset.mode: idle`                                     | Medium   | 1min   | Hygiene         |
| 11 | Restrict `GATEWAY_ALLOW_ALL_USERS` to specific Discord users/roles | Medium   | 5min   | Security        |
| 12 | Add hermes SigNoz dashboard                                        | Medium   | 20min  | Observability   |
| 13 | Investigate intermittent DNS failures for discord.com              | Medium   | 30min  | Reliability     |
| 14 | Replace ExecStartPre shell merge with Python dotenv merge          | Low      | 20min  | Robustness      |
| 15 | Add MemoryMax/MemoryHigh limits to service                         | Low      | 5min   | Safety          |
| 16 | Add `just hermes-backup` for ~/.hermes/ state backup               | Low      | 10min  | Operations      |
| 17 | Add gateway crash notification (OnFailure=notify)                  | Low      | 5min   | Observability   |
| 18 | Add cron job delivery retry with backoff                           | Low      | 15min  | Reliability     |
| 19 | Consider `browser.backend: local` (Camofox) to drop firecrawl dep  | Low      | 10min  | Dependencies    |
| 20 | Render partial config.yaml from Nix (timezone, logging, display)   | Low      | 30min  | Declarativeness |
| 21 | Add ADR for hermes deployment model                                | Low      | 15min  | Documentation   |
| 22 | Fix pre-existing statix W20 warnings in signoz.nix, snapshots.nix  | Low      | 10min  | Code quality    |
| 23 | Add `just hermes-update` to update hermes flake input              | Low      | 5min   | Operations      |
| 24 | Configure compression auxiliary to use local model                 | Low      | 5min   | Performance     |
| 25 | Add health check endpoint to hermes gateway                        | Low      | 15min  | Reliability     |

---

## G) Top #1 Question

**Should the Hermes `.env` ExecStartPre merge script be rewritten in Python for robustness?**

The current shell approach does line-by-line `sed` replacement:

```bash
while IFS='=' read -r key value; do
  grep -q "^''${key}=" "$ENV_FILE" && sed -i "/^''${key}=/d" "$ENV_FILE"
  echo "$key=$value" >> "$ENV_FILE"
done < "$SOPS_FILE"
```

This works for simple `KEY=VALUE` pairs but could break if:

- A value contains `=` (e.g. base64 tokens)
- A value contains newlines
- A key appears as a substring of another key's name

Hermes's `save_env_value()` produces simple `KEY=VALUE\n` lines, so in practice this is fine.
But a Python script using proper dotenv parsing would be more defensive.

The tradeoff: adding a Python dependency to a NixOS module vs keeping a simple shell script
that works for the known input format. I'd lean toward keeping the shell script unless
we see actual breakage — YAGNI.
