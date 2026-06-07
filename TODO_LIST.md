# SystemNix TODO List

**Updated:** 2026-06-03 (session 118)

---

## Active Tasks (SystemNix repo)

### Priority 0: Hermes Follow-up

- [ ] **Configure secondary LLM provider** for hermes (OpenRouter/OpenAI) as GLM-5.1 fallback
- [ ] **Hermes git remote access** — SSH deploy key for sandbox (`origin` unreachable)
- [ ] **Monitor GLM-5.1 rate limit** — verify cron jobs recovered after reset

### Priority 1: Deploy & Verify

- [ ] **Deploy committed changes** — ghostty migration, justfile fixes, alerting improvements
- [ ] **Verify boot time** — expect ~35s with all optimizations
- [ ] **Check SigNoz provision logs**: channel + rule creation, 4 new dashboards
- [ ] **Test Discord alert channel**: `POST /api/v1/channels/test`
- [ ] **Verify Gatus endpoints**: `status.home.lan` healthy, webhook URL loaded, TLS cert check active

### Priority 2: Code Improvements

- [ ] **Add per-threshold SigNoz channel routing** (critical→Discord, warning→log) — `signoz.nix`
- [ ] **Flake inputs audit** — 48 inputs, some may be stale/unused
- [ ] **Bring Darwin home.nix to parity** — terminal, editor, theme, xdg (4h, depends on whether Darwin is actively used)

### Priority 3: Documentation & Tools

- [x] **nix-colors integration**: wire `nix-colors` to Home Manager, migrate 17+ hardcoded colors — ~6h
- [ ] **Create `just status` command** for automated status report generation

### Priority 4: Hardware

- [ ] **Provision Pi 3** for DNS failover cluster
- [ ] **Wire Pi 3 as secondary DNS** in dns-failover.nix

---

## External Repos (Nix Flake Standardization)

- [ ] Convert go-auto-upgrade `path:` inputs to SSH URLs
- [ ] Create shared flake-parts template (mkGoPackage, checks, devshells)

---

## Completed (session 118)

- [x] Delete orphan `ai-stack.nix` module (109 lines)
- [x] Fix port 8050 conflict — reassign photomap from 8050→8051
- [x] Restore `go-structure-linter` — upstream fixed, overlay + package re-enabled
- [x] Add stale LSP cleanup timer — daily, kills gopls/vtsls/rust-analyzer/lua-ls running >24h
- [x] Deploy Dozzle — Docker log viewer at `logs.home.lan` (inline in configuration.nix)
- [x] Add disk growth check timer — daily, alerts if `/data` grows >5G/24h

## Completed (session 117)

- [x] Fix `xdg-desktop-portal-gtk.service` race condition — add `After=niri.service`
- [x] Add `Restart=on-failure` resilience to `home-manager-lars.service` (3 retries, 5s)
- [x] Fix `dnsblockd.service` start limits — `StartLimitBurst=10/120s` + blockIP readiness check
- [x] Eliminate ALL sed patches from overlays — fixed upstream repos, tagged semver releases

## Completed (session 115)

- [x] Fix duplicate ghostty (removed from base.nix, kept HM only)
- [x] Fix duplicate swappy (removed from base.nix, kept HM only)
- [x] Fix justfile `gatus-status` port (8083→9110)
- [x] Fix justfile `update-vendor-hashes` missing `#` in `nix build`
- [x] Fix justfile `auth-bootstrap` wrong filename (pocket-id.yaml→secrets.yaml)
- [x] Remove dead `comfyui.service` stop from `snapshot-migrate-data`
- [x] Delete stale `authelia-secrets.yaml` (leftover from Authelia→Pocket ID migration)
- [x] Delete stale `lib/ports.nix.bak`
- [x] Delete boilerplate `CHANGELOG.md` (never updated, status docs are the real changelog)
- [x] Remove 4 dead script references from FEATURES.md
- [x] Add Gatus memory/swap metric collection checks with Discord alerts
- [x] Verify voice-agents Caddy vHost already consolidated in caddy.nix
- [x] Verify SigNoz already has memory-critical and swap-critical alert rules

## Completed (session 112-114)

- [x] Patch `golangci-lint-auto-configure` for `finding.Merge→Combine` API break
- [x] Patch `buildflow` for `finding.Merge→Combine` + `WriteSARIF` signature change
- [x] Disable `go-structure-linter` — broken upstream `go.sum`

## Completed (session 75)

- [x] Add `firecrawl`, `edge-tts`, `fal`, `exa` to hermes `extraDependencyGroups`
- [x] Run Nix store GC — 7,898 paths deleted, 7.5 GiB freed

## Completed (session 73-74)

- [x] Fix hermes missing `discord.py` + `anthropic` — `extraDependencyGroups = ["messaging" "anthropic"]`
- [x] Move hermes from `multi-user.target` to `graphical.target`
- [x] Mass-move user-facing services to `graphical.target`
- [x] Delete ComfyUI module (112 lines removed)
- [x] Update AGENTS.md with `extraDependencyGroups` pattern
- [x] Extract overlays from flake.nix to `overlays/` directory (−200 lines)
- [x] Create `hardenUser {}` + apply to 3 user services
- [x] Replace Gatus sed hack with native env var interpolation
- [x] Create 4 SigNoz dashboards (GPU, DNS, Docker, Caddy)
- [x] Add Service Failure Spike alert rule
- [x] Add Gatus TLS certificate expiry check
- [x] Archive old status docs (sessions 45–65)

## Completed (session 71-72)

- [x] Boot performance: `boot.tmp.useTmpfs = true` — 56% reduction (2m13s → 58s)
- [x] Eliminate `unbound-anchor` fetch — saves ~4s per boot
- [x] Conditional `hermes fixPermissionsScript` — saves ~18s when perms correct

## Completed (session 70)

- [x] Eliminate `self.rev` anti-pattern across 29 repos
- [x] Automate versioning with update scripts

## Completed (session 68-69)

- [x] Fix vendor hash cascade for Go dependencies
- [x] Fix whisper-asr tmpfiles for voice-agents Docker
