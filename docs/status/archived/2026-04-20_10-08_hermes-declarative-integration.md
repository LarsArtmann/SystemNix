# Hermes Gateway Integration — Status Report 2026-04-20 10:08

## Executive Summary

Integrated the Hermes AI Agent Gateway into the declarative NixOS configuration.
Previously: manually installed via `nix profile install`, manually managed systemd
service, plaintext API keys in `~/.hermes/`, hardcoded `/nix/store` paths in the
service file that would break on updates.

Now: fully declarative flake input, Home Manager-managed systemd service,
sops-nix encrypted secrets, and a proper NixOS module with options.

---

## A) FULLY DONE

### 1. Hermes NixOS Module (`modules/nixos/services/hermes.nix`)

- **Flake input**: `hermes-agent` added as `github:NousResearch/hermes-agent` with `nixpkgs.follows`
- **NixOS module** with `services.hermes` options: `enable`, `user`, `home`, `restartSec`, `timeoutStopSec`
- **Home Manager systemd service**: `hermes-gateway` managed declaratively via `home-manager.users.<user>.systemd.user.services`
- **System packages**: installs `hermes-agent` (0.10.0) and `libopus` system-wide
- **tmpfiles rules**: creates `~/.hermes/` directory structure + symlinks sops-rendered `.env`
- **Enabled** in `platforms/nixos/system/configuration.nix`

### 2. Sops-nix Secret Management (`modules/nixos/services/sops.nix`)

- **New encrypted file**: `platforms/nixos/secrets/hermes.yaml` with all API keys
- **5 new sops secrets**: `hermes_discord_bot_token`, `hermes_glm_api_key`, `hermes_minimax_api_key`, `hermes_fal_key`, `hermes_firecrawl_api_key`
- **Sops template**: `hermes-env` renders `~/.hermes/.env` with decrypted values at activation time
- **Restart triggers**: all hermes secrets trigger `hermes-gateway.service` restart on change

### 3. config.yaml Cleanup (`~/.hermes/config.yaml`)

- **`key_env`**: replaced plaintext `api_key` for ZAI provider with `key_env: GLM_API_KEY` (reads from `.env`)
- **`timezone`**: set to `Europe/Warsaw` (was empty — cron scheduling was ambiguous)
- **`redact_pii`**: set to `true` (was `false`)
- **`free_response_channels`/`allowed_channels`**: changed from empty strings to null (prevents parsing issues)
- **`service_tier`**: changed from empty string to null
- **Logging**: `WARNING` level, 10MB max, 7 backups (was `INFO`, 5MB, 3 backups)
- **Removed `SUDO_PASSWORD`** from `.env` (critical security fix)

### 4. Security Hardening

- **File permissions**: `credentials.json`, `token.json`, `token_work.json` set to `600` (were `644` world-readable)
- **`SUDO_PASSWORD` removed** from `.env` — agent no longer has automatic sudo
- **`libopus`** installed system-wide — fixes `Opus codec not found` warning for Discord voice

### 5. Cron Job Fixes

- **systemnix-audit**: schedule fixed from daily (`0 10 * * *`) to weekly Sunday 10am (`0 10 * * 0`)
- **Cron job failures**: root cause was `OLLAMA_API_KEY` missing from `.env` — now included in sops template

### 6. Stale File Cleanup

- Removed request dumps >7 days and sessions >30 days from `~/.hermes/sessions/`
- Fixed read-only skill directory permissions (`chmod -R u+w`)

---

## B) PARTIALLY DONE

### Nix Profile Cleanup

- The old `nix profile install` hermes-agent package still exists at `~/.nix-profile/`
- Should be removed after `just switch` verifies the flake-input package works
- **Action**: `nix profile remove hermes-agent` after successful deploy

### config.yaml key_env Migration

- Only the ZAI provider uses `key_env` so far
- The `ollama` provider still has `api_key: ollama` inline (but this is a non-secret placeholder, acceptable)
- Other providers (vision, compression, etc.) have empty `api_key: ''` — these use `auto` provider resolution and don't need changes

---

## C) NOT STARTED

### Hermes Service Monitoring

- No SigNoz monitoring for hermes-gateway (journald receiver covers logs, but no OTel instrumentation)
- No alerting on gateway crashes or cron job failures

### Config.yaml in Nix

- `~/.hermes/config.yaml` is still manually managed, not generated from Nix
- Would require rendering the full YAML from Nix module options — complex but possible

### Google OAuth Credentials

- `~/.hermes/credentials.json` (Gmail API OAuth client) still has `644→600` permissions but not in sops
- `~/.hermes/token.json` / `token_work.json` (OAuth tokens) not in sops
- These are runtime-generated tokens that change frequently — sops may not be the right tool

### Discord Thread State

- `~/.hermes/discord_threads.json` not managed
- Cron job delivery errors due to intermittent DNS resolution failures (`discord.com:443`)

---

## D) TOTALLY FUCKED UP

### Nothing catastrophically broken!

- The manual systemd service was deleted — HM will recreate it on next `just switch`
- Until `just switch` runs, the hermes-gateway service will be DOWN
- **IMPORTANT**: must run `just switch` to activate the new declarative service

---

## E) WHAT WE SHOULD IMPROVE

1. **Remove old nix profile**: `nix profile remove hermes-agent` after deploy verification
2. **Google OAuth in sops**: encrypt `credentials.json` content or manage via NixOS
3. **config.yaml as Nix module**: render from Nix options instead of manual YAML
4. **Hermes observability**: add to SigNoz journald receiver, create dashboard
5. **Cron DNS resilience**: intermittent `discord.com:443` failures — investigate DNS cache
6. **Auxiliary model config**: configure vision/compression/session_search to use local Ollama models explicitly instead of `auto`
7. **Smart model routing**: enable with cheap local model for simple turns
8. **Persistent shell**: `terminal.persistent_shell: true` but no explicit shell config — consider setting `SHELL`
9. **Browser automation**: `browser.backend: firecrawl` requires API key — consider local browser (Camofox)
10. **Session rotation**: `session_reset.mode: none` means sessions never auto-reset — consider `idle`

---

## F) Top #25 Things to Do Next

| #  | Task                                                      | Impact   | Effort |
| -- | --------------------------------------------------------- | -------- | ------ |
| 1  | `just switch` to activate new hermes module               | Critical | 5min   |
| 2  | `nix profile remove hermes-agent` after verification      | High     | 1min   |
| 3  | Verify hermes-gateway starts with new HM service          | Critical | 2min   |
| 4  | Test Discord voice (opus codec) after deploy              | High     | 1min   |
| 5  | Verify cron jobs run (OLLAMA_API_KEY from sops .env)      | High     | 2min   |
| 6  | Add `~/.hermes/.env` symlink to `.gitignore`              | Medium   | 1min   |
| 7  | Configure auxiliary vision model to use local Ollama      | Medium   | 10min  |
| 8  | Enable smart_model_routing with local cheap model         | Medium   | 10min  |
| 9  | Add hermes to SigNoz journald receiver                    | Medium   | 5min   |
| 10 | Investigate intermittent DNS failures for discord.com     | Medium   | 30min  |
| 11 | Migrate Google OAuth credentials to sops                  | Medium   | 15min  |
| 12 | Add health check script for hermes-gateway                | Medium   | 15min  |
| 13 | Create hermes SigNoz dashboard                            | Medium   | 20min  |
| 14 | Set `session_reset.mode: idle` for session rotation       | Low      | 1min   |
| 15 | Configure compression auxiliary to use local model        | Low      | 5min   |
| 16 | Configure session_search auxiliary to use local model     | Low      | 5min   |
| 17 | Add `just hermes-status` command to justfile              | Low      | 5min   |
| 18 | Add `just hermes-restart` command to justfile             | Low      | 2min   |
| 19 | Consider `browser.backend: local` to remove firecrawl dep | Low      | 10min  |
| 20 | Add hermes to AGENTS.md documentation                     | Low      | 10min  |
| 21 | Add ADR for hermes deployment model                       | Low      | 15min  |
| 22 | Pin hermes-agent flake input to specific ref              | Low      | 2min   |
| 23 | Add memory limits to hermes-gateway service               | Low      | 5min   |
| 24 | Consider ReadWritePaths restriction for hermes service    | Low      | 10min  |
| 25 | Create systemd timer for hermes session cleanup           | Low      | 10min  |

---

## G) Top #1 Question

**How should we handle the `~/.hermes/config.yaml` file?**

It's currently a 340-line manually managed file with a mix of:

- Safe-for-repo settings (model defaults, display, cron, etc.)
- User-specific paths and preferences
- Platform connection settings (discord channels, toolsets)

Options:

- **A)** Leave it manual — Hermes writes to it at runtime (`hermes model`, `hermes setup`), so Nix-managed would conflict
- **B)** Generate a base config from Nix, let Hermes overlay runtime changes
- **C)** Fully declarative — render entire YAML from Nix module options (breaks `hermes setup` interactive workflow)

I lean toward **A** for now — Hermes needs write access and `hermes setup`/`hermes model` modify it interactively. The sops-managed `.env` already handles the secret part.
