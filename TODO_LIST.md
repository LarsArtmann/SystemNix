# SystemNix TODO List

**Updated:** 2026-05-21 (session 73)

---

## Active Tasks (SystemNix repo)

### Priority 0: Hermes Follow-up

- [ ] **Add `firecrawl` to hermes `extraDependencyGroups`** — web_search tool broken (pip unavailable in Nix)
- [ ] **Add `edge-tts` to hermes `extraDependencyGroups`** — TTS broken in Nix
- [ ] **Add `fal` to hermes `extraDependencyGroups`** — image generation broken in Nix
- [ ] **Add `exa` to hermes `extraDependencyGroups`** — web search alt backend
- [ ] **Configure secondary LLM provider** for hermes (OpenRouter/OpenAI) as GLM-5.1 fallback
- [ ] **Hermes git remote access** — SSH deploy key for sandbox (`origin` unreachable)
- [ ] **Monitor GLM-5.1 rate limit reset** — resets ~07:32 CEST, verify cron jobs recover

### Priority 1: Deploy & Verify

- [x] **Deploy to evo-x2**: `just switch` + reboot (kernel 7.0.1→7.0.6) — deployed session 71-73
- [x] **Verify all services start clean** — hermes verified session 73, others running
- [ ] **Check SigNoz provision logs**: channel + rule creation, 4 new dashboards
- [ ] **Test Discord alert channel**: `POST /api/v1/channels/test`
- [ ] **Verify Gatus endpoints**: `status.home.lan` healthy, webhook URL loaded, TLS cert check active

### Priority 2: Code Improvements

- [ ] **Add per-threshold SigNoz channel routing** (critical→Discord, warning→log) — `signoz.nix`
- [x] **`dns-failover.nix` authPassword → sops** — activation script provisions secret during `just switch`, no manual steps needed
- [ ] **Consolidate voice-agents Caddy vHost** into caddy.nix pattern — `caddy.nix`

### Priority 3: Documentation & Tools

- [ ] **nix-colors integration**: wire `nix-colors` to Home Manager, migrate 17+ hardcoded colors — ~6h
- [ ] **Deploy Dozzle**: Docker container log tailing at `logs.home.lan` — evaluation complete, needs implementation
- [ ] **Create `just status` command** for automated status report generation

### Priority 4: Hardware

- [ ] **Provision Pi 3** for DNS failover cluster
- [ ] **Wire Pi 3 as secondary DNS** in dns-failover.nix

### Priority 5: Maintenance

- [ ] **Audit memory usage** — 9.2GiB swap used, identify hogs
- [ ] **GC Nix store** — 82% disk usage, 7,479 paths eligible
- [ ] **Flake inputs audit** — 47 inputs, some may be stale/unused
- [ ] **Push 4 unpushed commits** to origin/master

---

## External Repos (Nix Flake Standardization)

From `docs/planning/2026-05-11_11-47-NIX-FLAKE-STANDARDIZATION.md`:

- [x] Compute real `vendorHash` for BuildFlow (fix fakeHash) — done upstream in `f4c07772`
- [x] Compute real `vendorHash` for PMA (replace null) — done upstream in `c4987a57`
- [ ] Convert go-auto-upgrade `path:` inputs to SSH URLs
- [ ] Create shared flake-parts template (mkGoPackage, checks, devshells)
- [x] Create `flake.nix` for hierarchical-errors — done upstream in `516f778`

---

## Completed (session 73)

- [x] Fix hermes missing `discord.py` + `anthropic` — added `extraDependencyGroups = ["messaging" "anthropic"]`
- [x] Move hermes from `multi-user.target` to `graphical.target`
- [x] Update AGENTS.md with `extraDependencyGroups` pattern

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

## Completed (session 73-74)

- [x] Extract overlays from flake.nix to `overlays/` directory (−200 lines)
- [x] Create `hardenUser {}` + apply to 3 user services
- [x] Replace Gatus sed hack with native env var interpolation
- [x] Harden ClickHouse + add onFailure for amdgpu-metrics
- [x] Auto-detect GPU PCI address in `gpu-recovery.sh`
- [x] Parameterize hostname in `nixos-diagnostic.sh`
- [x] Create 4 SigNoz dashboards (GPU, DNS, Docker, Caddy)
- [x] Add Service Failure Spike alert rule
- [x] Add Gatus TLS certificate expiry check
- [x] Add ADRs for Discord notifications + Gatus secret injection
- [x] Add `just test-hm` and `just test-aliases` recipes
- [x] Create `mkGraphicalUserService` lib helper
- [x] Archive old status docs (sessions 45–65)
- [x] Fix DNS Blocking Active endpoint (verify `[BODY] == 127.0.0.2`)
- [x] Adopt `serviceTypes.servicePort` in voice-agents
- [x] Fix gpu-recovery `Type=oneshot` + `Restart=always` conflict
