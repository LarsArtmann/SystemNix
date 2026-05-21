# SystemNix TODO List

**Updated:** 2026-05-21 (session 75)

---

## Active Tasks (SystemNix repo)

### Priority 0: Hermes Follow-up

- [x] **Add `firecrawl` to hermes `extraDependencyGroups`** — added session 75, awaiting deploy
- [x] **Add `edge-tts` to hermes `extraDependencyGroups`** — added session 75, awaiting deploy
- [x] **Add `fal` to hermes `extraDependencyGroups`** — added session 75, awaiting deploy
- [x] **Add `exa` to hermes `extraDependencyGroups`** — added session 75, awaiting deploy
- [ ] **Configure secondary LLM provider** for hermes (OpenRouter/OpenAI) as GLM-5.1 fallback
- [ ] **Hermes git remote access** — SSH deploy key for sandbox (`origin` unreachable)
- [ ] **Monitor GLM-5.1 rate limit** — verify cron jobs recovered after reset

### Priority 1: Deploy & Verify

- [ ] **Deploy committed changes** — hermes extra deps, boot fixes, service restructuring
- [ ] **Verify boot time** — expect ~35s with all optimizations
- [ ] **Verify hermes new Python deps** — no firecrawl/edge-tts/fal/exa ImportError in journal
- [ ] **Check SigNoz provision logs**: channel + rule creation, 4 new dashboards
- [ ] **Test Discord alert channel**: `POST /api/v1/channels/test`
- [ ] **Verify Gatus endpoints**: `status.home.lan` healthy, webhook URL loaded, TLS cert check active

### Priority 2: Code Improvements

- [ ] **Add per-threshold SigNoz channel routing** (critical→Discord, warning→log) — `signoz.nix`
- [x] **`dns-failover.nix` authPassword → sops** — activation script provisions secret
- [ ] **Consolidate voice-agents Caddy vHost** into caddy.nix pattern — `caddy.nix`

### Priority 3: Documentation & Tools

- [ ] **nix-colors integration**: wire `nix-colors` to Home Manager, migrate 17+ hardcoded colors — ~6h
- [ ] **Deploy Dozzle**: Docker container log tailing at `logs.home.lan`
- [ ] **Create `just status` command** for automated status report generation

### Priority 4: Hardware

- [ ] **Provision Pi 3** for DNS failover cluster
- [ ] **Wire Pi 3 as secondary DNS** in dns-failover.nix

### Priority 5: Maintenance

- [ ] **Investigate swap exhaustion** — 13Gi/13Gi, 7 gopls instances eating ~7.4Gi RSS
- [ ] **Flake inputs audit** — 47 inputs, some may be stale/unused
- [ ] **Add memory/swap alerting** to SigNoz/Gatus

---

## External Repos (Nix Flake Standardization)

- [x] Compute real `vendorHash` for BuildFlow — done upstream
- [x] Compute real `vendorHash` for PMA — done upstream
- [ ] Convert go-auto-upgrade `path:` inputs to SSH URLs
- [ ] Create shared flake-parts template (mkGoPackage, checks, devshells)
- [x] Create `flake.nix` for hierarchical-errors — done upstream

---

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
