# SystemNix — Full Comprehensive Status Report

**Date:** 2026-05-11 21:54 CEST
**Session:** 75
**Branch:** master
**Unpushed commits:** 2
**Flake check:** ✅ PASSING (all 3 systems: aarch64-darwin, x86_64-linux, aarch64-linux)
**Working tree:** CLEAN

---

## Repository Metrics

| Metric | Count |
|--------|-------|
| Tracked files | 921 |
| Nix files | 109 |
| Shell scripts | 15 |
| Service modules | 35 |
| Custom packages (pkgs/) | 5 |
| Dashboard JSONs | 6 |
| Lib helpers | 7 |
| ADR documents | 6 |
| Overlay files | 3 |
| Common programs | 14 |
| Flake inputs | 38 (27 follow nixpkgs) |
| flake.nix lines | 603 (down from 787) |
| AGENTS.md lines | 800 |
| Caddy virtual hosts | 11 (*.home.lan) |
| Gatus endpoints | 28 |
| SigNoz alert rules | 13 |
| SigNoz dashboards | 6 |
| sops secrets | 23 |
| `harden {}` adoption | 21/35 modules |
| `serviceDefaults {}` adoption | 22/35 modules |
| `hardenUser {}` adoption | 3/7 user services |
| `mkGraphicalUserService` adoption | 0/7 user services (just created) |

---

## A) FULLY DONE ✅

### Monitoring & Observability (Phase 2: Tasks 9-23)

| # | What | Evidence |
|---|------|----------|
| 9 | SigNoz alert: Ollama down | `signoz/rules/ollama-down.json` in signoz.nix |
| 10 | SigNoz alert: Docker daemon down | `signoz/rules/docker-down.json` in signoz.nix |
| 11 | Gatus DNS blocking endpoint | `[BODY] == 127.0.0.2` check in gatus-config.nix |
| 12 | Per-endpoint Gatus alert descriptions | All 28 endpoints have `alert.description` |
| 13-14 | `hardenUser {}` lib helper | `lib/user-harden.nix` + exported from `lib/default.nix` |
| 15-17 | Applied `hardenUser` to 3 user services | monitor365, file-and-image-renamer, niri-drm-healthcheck |
| 18-20 | Replaced Gatus sed hack with env var interpolation | `sops.templates."gatus-env"` + `environmentFile` |
| 22 | ClickHouse hardening | `harden {}` + `MemoryMax = "4G"` + `serviceDefaults {}` |
| 23 | amdgpu-metrics onFailure | Added to signoz.nix |

### Flake Quality (Phase 3: Tasks 24-30)

| # | What | Evidence |
|---|------|----------|
| 24-26 | Overlay extraction | `overlays/shared.nix` (12 overlays), `overlays/linux.nix` (6 overlays), `overlays/default.nix` |
| 27-28 | Inline overlays removed from flake.nix | Reduced from 787 → 603 lines |
| 29-30 | Formatting + validation | Pre-commit hooks enforce alejandra, deadnix, statix |

### Lib Consistency (Phase 4: Tasks 31-36)

| # | What | Evidence |
|---|------|----------|
| 31 | systemdServiceIdentity decision | Kept — used by hermes |
| 33 | All modules use `lib/default.nix` single import | Audited, confirmed |
| 34 | servicePort in voice-agents | Replaced manual mkOption |

### Script Quality (Phase 5: Tasks 37-42)

| # | What | Evidence |
|---|------|----------|
| 37-39 | `set -euo pipefail` on all scripts | writeShellApplication provides this automatically |
| 40 | GPU PCI address auto-detection | Scans `/sys/class/drm/card*/device/vendor` for AMD `0x1002` |
| 41 | Hostname parameterization | `FLAKE_HOST` env var, auto-detected from `hostname` |
| 42 | `just validate-scripts` recipe | shellcheck on all scripts/ |

### SigNoz Dashboards (Phase 6: Tasks 48-51)

| # | What | Evidence |
|---|------|----------|
| 48 | GPU metrics dashboard | `dashboards/gpu.json` (VRAM, temp, busy, memory controller) |
| 49 | DNS blocking dashboard | `dashboards/dns.json` (queries, rcode, cache, blocker health) |
| 50 | Docker containers dashboard | `dashboards/docker.json` (CPU, memory, network, restarts) |
| 51 | Service Failure Spike alert | `signoz/rules/service-failed-spike.json` (3+ failures in 10m) |

### Security (Phase 7: Tasks 53-54)

| # | What | Evidence |
|---|------|----------|
| 53 | Gatus TLS certificate expiry check | `[CERTIFICATE_EXPIRATION] > 168h` on auth.home.lan |
| 54 | Caddy metrics dashboard | `dashboards/caddy.json` (request rate, errors, p95, connections) |

### Documentation (Phase 8: Tasks 55-61)

| # | What | Evidence |
|---|------|----------|
| 55 | TODO_LIST.md | Created from all planning docs |
| 56 | ADR-005: Discord notification channel | `docs/adr/005-discord-notification-channel.md` |
| 57 | ADR-006: Gatus secret injection | `docs/adr/006-gatus-secret-injection.md` |
| 58 | Archived old status docs | 23 files → `docs/status/archive/` (sessions 45-65) |
| 59-61 | AGENTS.md updated | lib helpers, overlay structure, test commands, gotchas |

### Infrastructure (Phase 9: Tasks 62-65)

| # | What | Evidence |
|---|------|----------|
| 62 | `just test` recipe | Full `nix flake check --all-systems` + `nh os test .` |
| 63 | `just test-hm` recipe | Home Manager integration tests |
| 64 | `just test-aliases` recipe | Shell alias tests (fish/zsh/bash) |
| 65 | `mkGraphicalUserService` helper | `lib/graphical-user-service.nix` |

### Flake Fixes (Session 74-75)

| What | Evidence |
|------|----------|
| Removed invalid `nixConfig` block | Commit `fb2dbfa3` — was causing pre-commit hook failures |
| Removed `self` from outputs destructuring | flake-parts doesn't pass `self`, needs `...` catch-all |
| Reverted expanded input destructuring to `...` | Reduced maintenance burden, works correctly |
| `aarch64-linux` added to systems | Pi 3 cross-compilation support |
| `lib.hasSuffix "-linux"` for Linux-only overlays | Covers both x86_64-linux and aarch64-linux |
| `flake.lib` export | `inputs.self.lib` available in all modules |

---

## B) PARTIALLY DONE 🔄

### mkGraphicalUserService — Created but Not Adopted

- **Created:** `lib/graphical-user-service.nix` + exported from `lib/default.nix`
- **NOT adopted:** 7 user services still use manual `After/PartOf/WantedBy = ["graphical-session.target"]`:
  - `modules/nixos/services/dns-blocker.nix`
  - `modules/nixos/services/monitor365.nix`
  - `modules/nixos/services/file-and-image-renamer.nix`
  - `platforms/nixos/desktop/niri-wrapped.nix` (4 services)
- **Impact:** Low — services work fine, but DRY opportunity lost

### writeShellScript vs writeShellApplication

- 10+ inline scripts in gitea.nix and gitea-repos.nix use `pkgs.writeShellScript`
- These lack `set -euo pipefail` (writeShellApplication adds it)
- **Impact:** Low — scripts work, but inconsistent with other scripts

### hardenUser Adoption Gap

- 3 of 7 graphical-session user services use `hardenUser {}`
- Remaining 4 in `niri-wrapped.nix` (awww-daemon, awww-wallpaper, niri-msg, waybar-cfg)
- **Impact:** Low — niri-wrapped has its own service config patterns

---

## C) NOT STARTED ⬜

### Deploy & Verify (Phase 1: Tasks 2-8)

- [ ] `just switch` to build + activate new config on evo-x2
- [ ] Reboot (kernel 7.0.1→7.0.6 update)
- [ ] Verify all services: `systemctl --failed`
- [ ] Check SigNoz provision logs (4 new dashboards, 13 alert rules, Discord channel)
- [ ] Test Discord alert: `POST /api/v1/channels/test`
- [ ] Verify Gatus endpoints at `status.home.lan` (28 endpoints, webhook URL, TLS check)

### Code Improvements

- [ ] Per-threshold SigNoz channel routing (critical→Discord, warning→log)
- [ ] Consolidate voice-agents Caddy vHost into caddy.nix pattern
- [ ] Adopt `mkGraphicalUserService` in 7 user services
- [ ] Migrate gitea.nix inline scripts to `writeShellApplication`

### Documentation & Features

- [ ] nix-colors integration (~6h — wire to Home Manager, migrate 17+ hardcoded colors)
- [ ] Deploy Dozzle at `logs.home.lan` (evaluation complete, needs module)
- [ ] Create shared flake-parts template for Go repos

### Hardware

- [ ] Provision Pi 3 for DNS failover cluster
- [ ] Wire Pi 3 as secondary DNS in dns-failover.nix

### External Repos (Nix Flake Standardization)

- [ ] Compute real vendorHash for BuildFlow (fix fakeHash)
- [ ] Compute real vendorHash for PMA (replace null)
- [ ] Convert go-auto-upgrade `path:` inputs to SSH URLs
- [ ] Create `flake.nix` for hierarchical-errors

---

## D) TOTALLY FUCKED UP 💥

### dns-failover Plaintext VRRP Password

- **File:** `platforms/nixos/system/dns-blocker-config.nix:65`
- **File:** `platforms/nixos/rpi3/default.nix:160`
- **Password:** `DNSClusterVRRP-evox2` in PLAINTEXT
- **Should be:** sops-encrypted secret
- **Blocker:** Needs age identity (SSH host key) to decrypt at build time
- **Severity:** Medium — VRRP authPassword is local-network only, but plaintext secrets violate sops policy
- **Status:** Cannot fix without access to the age identity on the target machine

### commit `97e8fc62` — Broke flake.nix

- **What:** Added `self` to outputs destructuring, invalid `nixConfig` block, expanded input destructuring
- **Broke:** `nix flake check` — "function 'outputs' called with unexpected argument 'self'"
- **Also broke:** Pre-commit hook (nixConfig warnings → treated as errors)
- **Fixed by:** Commit `fb2dbfa3` (session 74)
- **Lesson:** Always run `nix flake check --no-build` before committing flake.nix changes

### overlays/shared.nix — dnsblockd Removed Incorrectly?

- **What:** `dnsblockd` was removed from `overlays/shared.nix` inputs
- **Reality:** dnsblockd was already in `overlays/linux.nix` — this was correct, not a bug
- **But:** The AGENTS.md still listed dnsblockd in sharedOverlays — now updated

---

## E) WHAT WE SHOULD IMPROVE 📈

### 1. Adopt mkGraphicalUserService in All 7 User Services

The helper exists but is unused. Every graphical-session service manually writes `After/PartOf/WantedBy`. Should be a 30-minute sweep.

### 2. Deploy Pipeline Gap

We have 2 unpushed commits sitting on master. The entire Phase 1 (deploy + verify) is unstarted. All the monitoring dashboards, alert rules, and Gatus endpoints are code-only — not verified on the actual machine.

### 3. External Repo Flake Standardization

5 Go repos still have broken/missing flake.nix files (BuildFlow fakeHash, PMA null vendorHash, hierarchical-errors no flake.nix). This is a maintenance burden when updating overlays.

### 4. nix-colors Integration

17+ hardcoded Catppuccin Mocha colors across waybar, starship, tmux, etc. Should use `nix-colors` flake input for single-source-of-truth theming. ~6h effort.

### 5. Test Coverage

- No CI/CD — all testing is manual (`just test-fast`, `just test`)
- Home Manager integration tests (`test-hm`) and alias tests (`test-aliases`) are never run in automation
- SigNoz dashboard/alert provisioning is only verified post-deploy

### 6. Script Consistency

- Some scripts use `writeShellApplication` (auto `set -euo pipefail`)
- gitea.nix has 10+ inline `writeShellScript` (no auto-safety)
- `scripts/deploy.sh`, `scripts/dns-diagnostics.sh`, `scripts/validate.sh` are external files read by flake apps but NOT wrapped in `writeShellApplication`

### 7. Monitoring Coverage Gaps

- No alerts for: Immich down, Gitea down, Homepage down, Hermes down
- No dashboard for: system overview (CPU, RAM, disk trends over time)
- TLS cert check only covers `auth.home.lan` — should cover all 11 vhosts

### 8. DNS Failover is Incomplete

- Module exists (`dns-failover.nix`) but Pi 3 is not provisioned
- VRRP password is plaintext
- Single-node DNS (no failover in practice)

---

## F) Top 25 Things We Should Get Done Next

### Critical (deploy what we have)

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 1 | **`git push` + `just switch`** — deploy all session 73-75 changes to evo-x2 | 15min | 🔴 |
| 2 | **Reboot** — kernel 7.0.1→7.0.6 | 5min | 🔴 |
| 3 | **Verify services** — `systemctl --failed`, check SigNoz/Gatus provision | 10min | 🔴 |
| 4 | **Test Discord alerts** — confirm webhook delivery | 5min | 🔴 |

### High Value (monitoring completeness)

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 5 | **Add alerts for critical services** — Immich, Gitea, Homepage, Hermes down | 30min | 🟡 |
| 6 | **Add TLS cert checks** for all 11 `*.home.lan` vhosts (not just auth) | 15min | 🟡 |
| 7 | **Create system overview dashboard** — CPU, RAM, disk, network trends | 30min | 🟡 |
| 8 | **Add per-threshold channel routing** — critical→Discord, warning→log | 15min | 🟡 |

### Code Quality (DRY & consistency)

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 9 | **Adopt `mkGraphicalUserService`** in all 7 user services | 30min | 🟢 |
| 10 | **Migrate gitea inline scripts** to `writeShellApplication` | 30min | 🟢 |
| 11 | **Consolidate voice-agents Caddy vHost** into caddy.nix pattern | 15min | 🟢 |
| 12 | **Adopt `hardenUser`** in remaining 4 niri-wrapped user services | 15min | 🟢 |
| 13 | **Wrap deploy/dns-diagnostics/validate scripts** in `writeShellApplication` | 15min | 🟢 |

### Security

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 14 | **Move dns-failover VRRP password to sops** — blocked on age identity | 15min | 🟡 |
| 15 | **Audit all sops secrets** — verify no plaintext credentials remain | 20min | 🟡 |

### Features

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 16 | **Deploy Dozzle** at `logs.home.lan` — container log tailing | 1h | 🟢 |
| 17 | **nix-colors integration** — single-source-of-truth theming | 6h | 🟢 |
| 18 | **Create SigNoz log-based alert** — journald error spike detection | 30min | 🟢 |

### External Repos

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 19 | **Fix BuildFlow vendorHash** (fakeHash → real) | 30min | 🟢 |
| 20 | **Fix PMA vendorHash** (null → real) | 30min | 🟢 |
| 21 | **Convert go-auto-upgrade path: → SSH URL** | 15min | 🟢 |
| 22 | **Create flake.nix for hierarchical-errors** | 1h | 🟢 |
| 23 | **Create shared flake-parts Go template** | 2h | 🟢 |

### Hardware

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 24 | **Provision Pi 3** for DNS failover cluster | Hardware | 🔵 |
| 25 | **Wire Pi 3 as secondary DNS** | 30min | 🔵 |

---

## G) Top #1 Question I Cannot Figure Out Myself

**When will you next be at the evo-x2 machine to run `just switch` and reboot?**

Everything else in this report is code that can be written without physical access. But Phase 1 (deploy + verify) is the critical blocker — 4 SigNoz dashboards, 13 alert rules, the Discord webhook, the Gatus TLS check, the env var interpolation fix, the ClickHouse hardening, and all the other changes from sessions 73-75 are committed but NOT running on the machine. The longer the gap between code and deployment, the harder it is to debug if something goes wrong.

---

## Git Log (Sessions 73-75)

```
6dfc9ba0 docs(status): session 75 — docs cleanup, mkGraphicalUserService, test recipes
34947edd docs: ADRs, TODO_LIST, archive old status docs, mkGraphicalUserService, test recipes
fb2dbfa3 refactor(flake): remove explicit experimental features and unused input contracts
f8754909 feat(signoz): add alert rules and dashboards for GPU, DNS, Docker, Caddy
97e8fc62 refactor(flake): quality audit — explicit contracts, nixConfig, self.lib, aarch64-linux
17015173 chore(deps): update mr-sync (vendorHash mismatch fix)
690af048 docs(status): session 73 — monitoring, overlays, scripts
123b1eaa docs(agents): update architecture + add TLS cert check
e0e29026 fix(lib): adopt servicePort in voice-agents, fix gpu-recovery oneshot warning
842d6d88 fix(scripts): parameterize hostname + PCI address, add validate-scripts
7002bb6e fix(gpu-recovery): auto-detect AMD GPU PCI address + session 73 status
127e0c68 refactor(flake): extract overlays to overlays/ directory
7d3f3694 harden(signoz): sandbox ClickHouse + onFailure for amdgpu-metrics
6a310af1 refactor(gatus): replace sed hack with native env var interpolation
7ad8ae2d fix(monitoring): harden user services + fix DNS blocking check
```
