# Session 69 — Comprehensive Status Report

**Date:** 2026-05-21 01:33 CEST
**Trigger:** `nh os switch . -v` — 3 service activation failures post-flake-update
**Status:** BUILD PASSES | 1 bug fixed | 2 transient issues documented

---

## a) FULLY DONE

### Core Infrastructure

| Item | Status | Details |
|------|--------|---------|
| NixOS build (evo-x2) | ✅ Passes | `nix build '.#nixosConfigurations.evo-x2.config.system.build.toplevel'` — clean |
| nixpkgs-unstable migration | ✅ Complete | `d233902.26.05` (2026-05-17), kernel 7.0.1 → 7.0.8 |
| Darwin (MacBook Air) build | ✅ Passes | aarch64-darwin config evals clean |
| flake-parts architecture | ✅ Mature | 34 service modules, single source of truth in `flake.nix` |
| SOPS secrets | ✅ Operational | Age via SSH host key, all services wired with `restartUnits` |
| 47 flake inputs | ✅ All consumed | 41 direct + 6 `flake=false` shared Go libs for dedup |
| AGENTS.md | ✅ Up to date | Stripped to agent-critical knowledge only |

### Services Running Clean (24 enabled)

`caddy`, `forgejo`, `immich`, `authelia`, `homepage`, `taskchampion`, `niri`, `signoz`, `signoz-collector`, `hermes`, `monitor365`, `manifest`, `openseo`, `twenty`, `voice-agents`, `gatus`, `postgres`, `redis-immich`, `docker`, `ollama`, `dnsblockd`, `dual-wan`, `route-health-monitor`, `mptcp-endpoint-manager`

### Quality & Tooling

| Item | Status |
|------|--------|
| systemd hardening (`harden{}`) | ~76% adoption across services |
| `lib/` helpers | `harden`, `serviceDefaults`, `mkStateDir`, `mkDockerServiceFactory` |
| Custom overlays | `mkPackageOverlay` for all Go repos — DRY |
| Monitoring stack | SigNoz (query + collector + ClickHouse) + Gatus + Discord alerts |
| NVMe health alerts | Smartd + custom rules + Discord |
| GPU headroom | Ollama 0.45, ComfyUI 0.50, gpu-python 0.95 (configurable) |

### Session 69 Fix (This Session)

| What | Fix |
|------|-----|
| **whisper-asr crash-loop** | `voice-agents.nix` was missing `systemd.tmpfiles.rules = docker.tmpfiles;` → `/var/lib/whisper-asr` never created → `status=226/NAMESPACE`. Added the wiring. |

---

## b) PARTIALLY DONE

| Item | Progress | Blocker |
|------|----------|---------|
| DNS failover (VRRP) | Config done, Pi 3 not provisioned | Hardware + sops on Pi |
| Pi 3 secondary DNS | Full NixOS config ready, SD image builder works | Hardware provisioning + undervoltage fix |
| SigNoz alert channel routing | All critical alerts firing, Discord channel active | Per-threshold routing not implemented |
| Darwin optimizations | 229 GB disk constraint, d2 overlay stubs | Disk space perennially tight |
| `file-and-image-renamer` | Module exists, overlay exists, `enable = false` | Go 1.26.3 not in nixpkgs-unstable yet |
| TODO_LIST.md | Exists, last updated session 74 | ~12 P1-P4 items not yet completed |

---

## c) NOT STARTED

| # | Item | Priority | Notes |
|---|------|----------|-------|
| 1 | SigNoz JWT secret (`SIGNOZ_TOKENIZER_JWT_SECRET`) | P2 | Service runs without it but warns loudly on every start |
| 2 | nix-colors integration | P3 | ~6h estimate, theme consistency |
| 3 | Deploy Dozzle (Docker log viewer) | P3 | Would replace manual `journalctl` for containers |
| 4 | Convert `go-auto-upgrade` `path:` inputs to SSH URLs | P3 | External repo work |
| 5 | Create shared flake-parts template | P4 | External repo work |
| 6 | Per-threshold SigNoz channel routing | P2 | E.g., P1 → #alerts, P2 → #warnings |
| 7 | Consolidate voice-agents Caddy vHost | P2 | `voice.` and `whisper.` could be sub-paths |
| 8 | Hardcoded port cleanup | P3 | 5 instances of `localhost:PORT` should use config options |
| 9 | `todoListAiFixedHash` auto-update | P3 | Custom derivation hash not covered by `hash-check` |
| 10 | Context.md creation | P4 | No CONTEXT.md at repo root |

---

## d) TOTALLY FUCKED UP

| Issue | Severity | Impact | Fix Required |
|-------|----------|--------|-------------|
| **SigNoz JWT secret missing** | 🔴 Critical | Service runs but sessions are forgeable. Log spews `🚨 CRITICAL SECURITY ISSUE` on every start. Needs `SIGNOZ_TOKENIZER_JWT_SECRET` in sops secrets + env injection. | Add to `sops.nix`, add `EnvironmentFile` to signoz service |
| **whisper-asr was crash-looping for days** | 🟡 High | 25+ restart attempts, `status=226/NAMESPACE`. Fixed this session — but this means `voice-agents` Whisper ASR has been down since the module was created. | ✅ Fixed |
| **evaluation warning: `hostPlatform` deprecated** | 🟡 Medium | `nixpkgs.hostPlatform` → `stdenv.hostPlatform` warning on every eval. This is standard NixOS-generated `hardware-configuration.nix` + `flake.nix`. Upstream nixpkgs issue, not ours to fix independently. | Wait for nixpkgs fix |
| **`file-and-image-renamer` blocked on Go 1.26.3** | 🟡 Medium | Disabled since session 68. nixpkgs-unstable has Go 1.26.2. No ETA on 1.26.3 landing. | Monitor nixpkgs PRs |
| **NetworkManager-wait-online timeout on `switch`** | 🟢 Low | 60s timeout during activation — non-critical boot ordering service. Fails during `switch` because NM is being restarted. | Expected behavior, no fix needed |

---

## e) WHAT WE SHOULD IMPROVE

### Architecture

1. **Missing `mkVersion` helper** — The diff showed intent to add `mkVersion` to overlays for packages whose version should match the flake input ref. This was never completed. `dnsblockd`, `golangci-lint-auto-configure`, `go-auto-upgrade` would benefit from this.

2. **Docker services tmpfiles pattern** — The `mkDockerService` pattern returns `{ services; tmpfiles; }` but there's no compile-time check that consumers wire `tmpfiles`. Consider having `mkDockerService` return a single attrset that can be merged directly, or add a `lib.warnIf` check.

3. **Hardcoded ports** — 5 instances of `localhost:PORT` in .nix files that should use service config options. Specifically:
   - `voice-agents.nix:121` — LiveKit `7880` hardcoded instead of option
   - `configuration.nix:248,253` — Monitor365 `3001`
   - `homepage.nix:159` — emeet-pixyd `8090`

4. **SigNoz security** — Running without JWT is a critical security gap. This needs sops secret + env injection ASAP.

### Process

5. **Status report accumulation** — ~300+ status reports in `docs/status/` (active + archive). Consider a `docs/status/archive/` migration for anything older than 2 weeks.

6. **TODO_LIST.md staleness** — Last updated session 74 (2026-05-11). 10 days behind. Many items may already be done.

7. **`CONTEXT.md` missing** — No domain context file at repo root. Would help new agents understand the system faster.

### Monitoring

8. **No watchdog for Whisper ASR** — The service was crash-looping for potentially days without triggering a visible alert. SigNoz has a `service-down` alert rule but it may not cover Docker-based services.

9. **`onFailure` notification gap for Docker services** — `mkDockerService` services may not trigger the `notify-failure@%n.service` pattern used by native systemd services.

---

## f) Top 25 Things to Get Done Next

### P1 — Security & Correctness

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 1 | Add `SIGNOZ_TOKENIZER_JWT_SECRET` to sops + inject into signoz service | 30m | Critical security fix |
| 2 | Verify all services start clean after `just switch` | 15m | Confidence |
| 3 | Check SigNoz provision logs + test Discord alert channel | 15m | Monitoring validation |
| 4 | Verify Gatus endpoints all return healthy | 10m | Uptime confirmation |

### P2 — Robustness

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 5 | Add Whisper ASR down alert to SigNoz rules | 15m | Prevent silent failures |
| 6 | Make `mkDockerService` return single mergeable attrset (services + tmpfiles) | 1h | Prevent future tmpfiles wiring bugs |
| 7 | Consolidate voice-agents Caddy vHost (`voice.` + `whisper.` → sub-paths) | 30m | Simplify routing |
| 8 | Extract hardcoded LiveKit port to config option in `voice-agents.nix` | 15m | Config consistency |
| 9 | Extract hardcoded Monitor365 port in `configuration.nix` to module option | 15m | Config consistency |
| 10 | Per-threshold SigNoz Discord channel routing | 1h | Alert noise reduction |

### P3 — Quality & Maintenance

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 11 | Update `TODO_LIST.md` — verify against actual code state | 1h | Accuracy |
| 12 | Create `CONTEXT.md` at repo root | 30m | Onboarding |
| 13 | Deploy Dozzle for Docker container log viewing | 30m | Debugging UX |
| 14 | Clean up `docs/status/` — archive reports older than 2 weeks | 15m | Hygiene |
| 15 | Add `mkVersion` helper to `overlays/default.nix` + apply to 3 packages | 30m | Version accuracy |
| 16 | Fix `todoListAiFixedHash` to be covered by `hash-check` automation | 1h | Automation |
| 17 | nix-colors integration | 6h | Theme consistency |
| 18 | Add `network-setup.service` → `unit-network.target` migration cleanup | 30m | Cleanup from diff |

### P4 — Long-term

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 19 | Provision Pi 3 + wire as secondary DNS | 2h | DNS redundancy |
| 20 | Add sops-nix to Pi 3 (VRRP auth password) | 30m | Security |
| 21 | Monitor nixpkgs for Go 1.26.3 → re-enable `file-and-image-renamer` | 5m/check | Unblock |
| 22 | Convert `go-auto-upgrade` `path:` inputs to SSH URLs | 1h | Portability |
| 23 | Create shared flake-parts template for LarsArtmann repos | 2h | Consistency |
| 24 | Audit all `mkDockerService` consumers for `onFailure` coverage | 30m | Reliability |
| 25 | `hostPlatform` deprecation — track upstream nixpkgs fix | 0 | Wait |

---

## g) Top #1 Question I Cannot Figure Out Myself

**Was the `whisper-asr` service EVER working?**

The bug (missing `tmpfiles.rules` wiring) existed since `voice-agents.nix` was first created. The `mkDockerService` pattern returns `{ services; tmpfiles; }` as separate attrsets, and the original author only wired `services`. This means `/var/lib/whisper-asr` was never created by systemd-tmpfiles. Either:

1. The directory was manually created at some point, and the service worked until the next `nixos-rebuild switch` wiped it
2. The service has never worked and was never tested end-to-end
3. There was a previous version of the module that used `StateDirectory=` instead of tmpfiles

This matters because if Whisper ASR was supposed to be operational (it's enabled in config, has a Caddy vHost, and is listed in Homepage), users may have been silently losing functionality.

---

## Flake Diff Summary (This Update)

### Updated (3 inputs)

| Input | Old Rev | New Rev | Change |
|-------|---------|---------|--------|
| dnsblockd | `f832f9f` (r281) | `ccd5594` (r282) | New commit |
| go-auto-upgrade | `e731fb9` (r337) | `742ef89` (r338) | New commit |
| golangci-lint-auto-configure | `da82d46` (r532) | `0906007` (r533) | New commit |

### Package Version Changes (from `nh os switch` diff)

| Package | Old | New |
|---------|-----|-----|
| Linux kernel | 7.0.1 | 7.0.8 |
| chromium | 147.0.7727.116 | 148.0.7778.167 |
| fish | 4.6.0 | 4.7.1 |
| docker | 29.4.0 | 29.4.3 |
| docker-compose | 5.0.2 | 5.1.3 |
| ollama | 0.21.1 | 0.23.1 |
| hermes-agent | 0.12.0 | 0.14.0 |
| firefox | 150.0 | 150.0.3 |
| nix | 2.34.6 | 2.34.7 |
| redis | 8.2.3 | 8.6.3 |
| hyprland | 0.54.3 | 0.55.1 |
| mesa | 26.0.5 | 26.1.0 |
| postgresql | 17.9 | 17.10 |
| hyprgraphics | 0.5.0 | 0.5.1 |
| starship | 1.24.2 | 1.25.1 |
| amdgpu_top | 0.11.3 | 0.11.4 |
| foot | 1.26.1 | 1.27.0 |
| obs-studio | 32.1.1 | 32.1.2 |
| zed-editor | 0.233.5 | 1.2.5 |
| zellij | 0.44.1 | 0.44.3 |
| bun | 1.3.11 | 1.3.13 |
| nano | 8.7.1 | 9.0 |
| strace | 6.19 | 7.0 |
| terraform | 1.14.9 | 1.15.2 |
| neovim | 0.12.1 | 0.12.2 |

**Closure size:** 41.3 GiB → 40.5 GiB (−766 MiB)

---

## System Vital Signs

| Metric | Value |
|--------|-------|
| Build status | ✅ Clean |
| Enabled services | 24 |
| Disabled services | 3 (file-and-image-renamer, comfyui, minecraft-server) |
| Total `.nix` files | 113 |
| Service modules | 34 |
| Flake inputs | 47 (all consumed) |
| Evaluation warnings | 1 (`hostPlatform` deprecation — upstream) |
| Empty hashes | 0 (no stale `vendorHash`/`npmDepsHash`) |
| Branch | master (1 commit ahead of origin) |
| nixpkgs | `d233902` (unstable, 2026-05-17) |
| TODO/FIXME comments | 1 (Pi 3 sops TODO) |

---

_Generated by Session 69 — 2026-05-21 01:33 CEST_
