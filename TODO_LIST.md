# SystemNix TODO List

**Updated:** 2026-05-11 (session 74)

---

## Active Tasks (SystemNix repo)

### Priority 1: Deploy & Verify

- [ ] **Deploy to evo-x2**: `just switch` + reboot (kernel 7.0.1→7.0.6)
- [ ] **Verify all services start clean**: `systemctl --failed`
- [ ] **Check SigNoz provision logs**: channel + rule creation, 4 new dashboards
- [ ] **Test Discord alert channel**: `POST /api/v1/channels/test`
- [ ] **Verify Gatus endpoints**: `status.home.lan` healthy, webhook URL loaded, TLS cert check active

### Priority 2: Code Improvements

- [ ] **Add per-threshold SigNoz channel routing** (critical→Discord, warning→log) — `signoz.nix`
- [ ] **Move `dns-failover.nix` plaintext `authPassword` to sops** — blocked on age identity (SSH host key)
- [ ] **Consolidate voice-agents Caddy vHost** into caddy.nix pattern — `caddy.nix`

### Priority 3: Documentation

- [ ] **nix-colors integration**: wire `nix-colors` to Home Manager, migrate 17+ hardcoded colors — ~6h
- [ ] **Deploy Dozzle**: Docker container log tailing at `logs.home.lan` — evaluation complete, needs implementation

### Priority 4: Hardware

- [ ] **Provision Pi 3** for DNS failover cluster
- [ ] **Wire Pi 3 as secondary DNS** in dns-failover.nix

---

## External Repos (Nix Flake Standardization)

From `docs/planning/2026-05-11_11-47-NIX-FLAKE-STANDARDIZATION.md`:

- [x] Compute real `vendorHash` for BuildFlow (fix fakeHash) — done upstream in `f4c07772`
- [x] Compute real `vendorHash` for PMA (replace null) — done upstream in `c4987a57`
- [ ] Convert go-auto-upgrade `path:` inputs to SSH URLs
- [ ] Create shared flake-parts template (mkGoPackage, checks, devshells)
- [x] Create `flake.nix` for hierarchical-errors — done upstream in `516f778`

---

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
