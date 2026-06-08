# SystemNix TODO List

**Updated:** 2026-06-08 (session 122 — COMPLETION SPRINT)

---

## Active Tasks (SystemNix repo)

### Priority 0: Hermes Follow-up

- [x] **Configure secondary LLM provider** for hermes (OpenRouter/OpenAI) as GLM-5.1 fallback
  - Nix config DONE: added `hermes_openai_api_key` secret placeholder + `OPENAI_API_KEY` env var in `hermes-env` template
  - **MANUAL STEP REQUIRED**: Add `openai_api_key` to `platforms/nixos/secrets/hermes.yaml` via `sops platforms/nixos/secrets/hermes.yaml`
  - **MANUAL STEP REQUIRED**: Set fallback model in hermes runtime: `hermes config set fallback_model openrouter/gpt-4o` (in `/home/hermes/`)
- [x] **Hermes git remote access** — SSH deploy key for sandbox (`origin` unreachable)
  - DONE: Generated ed25519 key pair in `scripts/hermes-setup/`
  - **MANUAL STEP REQUIRED**: Install private key to `/home/hermes/.ssh/id_ed25519` and add public key to GitHub deploy keys
  - See `scripts/hermes-setup/README.md` for full instructions
- [ ] **Monitor GLM-5.1 rate limit** — verify cron jobs recovered after reset
  - *Blocked*: Requires `journalctl -u hermes` on evo-x2
  - Run `just verify` to check remotely, or `journalctl -u hermes --since "24h ago" | grep -i rate` on evo-x2

### Priority 1: Deploy & Verify

- [x] **Deploy committed changes** — color migration, SigNoz routing, Darwin parity, just status
- [ ] **Verify boot time** — expect ~35s with all optimizations
  - *Blocked*: Requires reboot of evo-x2
  - Run `systemd-analyze` after next reboot
- [ ] **Check SigNoz provision logs**: channel + rule creation, 4 new dashboards
  - *Blocked*: Requires curl to localhost:8080 on evo-x2
  - Use `scripts/verify-deployment.sh` or run: `curl http://localhost:8080/api/v1/dashboards` and `curl http://localhost:8080/api/v1/rules`
- [ ] **Test Discord alert channel**: `POST /api/v1/channels/test`
  - *Blocked*: Requires curl + Discord webhook secret on evo-x2
  - Script checks this in `verify-deployment.sh`
- [ ] **Verify Gatus endpoints**: `status.home.lan` healthy, webhook URL loaded, TLS cert check active
  - *Blocked*: Requires curl to localhost:9110 on evo-x2
  - Script checks this in `verify-deployment.sh`

### Priority 2: Code Improvements

- [x] **Add per-threshold SigNoz channel routing** (critical→Discord, warning→log) — `_signoz-alerts.nix`
- [x] **Flake inputs audit** — 45 inputs checked, all used
- [x] **Bring Darwin home.nix to parity** — terminal, editor, theme, xdg

### Priority 3: Documentation & Tools

- [x] **nix-colors integration**: wire `nix-colors` to Home Manager, migrate 17+ hardcoded colors
- [x] **Create `just status` command** for automated status report generation
- [x] **Create post-deploy verification script** (`scripts/verify-deployment.sh`) + `just verify` recipe

### Priority 4: Hardware

- [ ] **Provision Pi 3** for DNS failover cluster
  - *Blocked*: Requires physical Raspberry Pi 3 hardware
- [ ] **Wire Pi 3 as secondary DNS** in dns-failover.nix
  - *Blocked*: Depends on Pi 3 provisioned first

---

## External Repos (Nix Flake Standardization)

- [x] **Convert go-auto-upgrade `path:` inputs to SSH URLs**
  - DONE: Already converted in go-auto-upgrade repo (commit `97df102` — "fix(nix): convert path: inputs to SSH URLs, add overlay")
- [x] **Create shared flake-parts template** (mkGoPackage, checks, devShells)
  - DONE: Created `templates/go-flake-parts/flake.nix` + `README.md` in SystemNix
  - Also copied to `go-nix-helpers/templates/go-flake-parts/` — **needs commit + push**

---

## Verification Instructions for Blocked Items

All blocked verification items can be checked by running on evo-x2:

```bash
# Clone/pull latest SystemNix, then:
cd /path/to/SystemNix
bash scripts/verify-deployment.sh
```

Or remotely via just:
```bash
just verify  # Runs verify-deployment.sh over SSH to evo-x2
```

### Manual Verification Checklist

| Task | Command on evo-x2 |
|------|-------------------|
| GLM-5.1 rate limit | `journalctl -u hermes --since "24h ago" \| grep -iE "rate\|429\|402"` |
| Boot time | `systemd-analyze` |
| SigNoz health | `curl -s http://localhost:8080/api/v1/health` |
| SigNoz dashboards | `curl -s http://localhost:8080/api/v1/dashboards \| grep -c '"id"'` |
| SigNoz rules | `curl -s http://localhost:8080/api/v1/rules \| grep -c '"id"'` |
| Discord webhook | `curl -X POST -H "Content-Type: application/json" -d '{"content":"test"}' $(cat /var/lib/signoz/discord-webhook.url)` |
| Gatus health | `curl -s http://localhost:9110/api/v1/endpoints/status` |
| BTRFS snapshots | `ls -t /mnt/btrfs-root/@snapshots \| head -1` |

---

## Hermes Sops Secret Setup (Manual)

After the next `just switch`, the hermes service will expect `openai_api_key` in the encrypted secrets file. To add it:

```bash
# On evo-x2, with age key available:
cd /path/to/SystemNix
sops platforms/nixos/secrets/hermes.yaml
# Add: openai_api_key: <your_openrouter_or_openai_key>
# Save and exit
just switch
```

Then set the fallback model in hermes:
```bash
sudo -u hermes hermes config set fallback_model openrouter/gpt-4o
# Or for OpenAI directly:
# sudo -u hermes hermes config set fallback_model openai/gpt-4o
```

---

## Completed (session 122)

- [x] Verify go-auto-upgrade already uses SSH URLs (no `path:` inputs remain)
- [x] Create `templates/go-flake-parts/flake.nix` — standardized Go flake-parts template
- [x] Add `hermes_openai_api_key` to sops secrets definition (`modules/nixos/services/sops.nix`)
- [x] Add `OPENAI_API_KEY` to hermes-env template (enables OpenRouter/OpenAI fallback)
- [x] Generate hermes SSH deploy key (`scripts/hermes-setup/id_ed25519`)
- [x] Write hermes git remote access setup guide (`scripts/hermes-setup/README.md`)
- [x] Write post-deploy verification script (`scripts/verify-deployment.sh`)
- [x] Add `just verify` recipe to justfile for remote verification

## Completed (session 121)

- [x] Expand Catppuccin palette in `theme.nix` with 26 named colors + base16 aliases
- [x] Migrate 164 hardcoded hex colors across 9 files to `colorScheme.palette`
- [x] Add `just status` command for automated status report generation
- [x] Add per-threshold SigNoz channel routing (critical→Discord, warning→UI only)
- [x] Bring Darwin home.nix to parity with NixOS (zellij, yazi, zed-editor, session vars, xdg)
- [x] Fix `crush-daily` stale flake lock (rev 66 → rev 67, overlays.default now available)
- [x] Make `zellij.nix` cross-platform (pbcopy on Darwin, wl-copy on Linux)
- [x] Deploy all changes to evo-x2 via `just switch`

## Completed (session 118)

- [x] Delete orphan `ai-stack.nix` module (109 lines)
- [x] Fix port 8050 conflict — reassign photomap from 8050→8051
- [x] Restore `go-structure-linter` — upstream fixed, overlay + package re-enabled
- [x] Add stale LSP cleanup timer — daily, kills gopls/vtsls/rust-analyzer/lua-ls running >24h
- [x] Deploy Dozzle — Docker log viewer at `logs.home.lan` (inline in configuration.nix)
- [x] Add disk growth check timer — daily, alerts if `/data` grows >5G/24h
