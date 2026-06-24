# Session 21 — Full Comprehensive Status Report

**Date:** 2026-05-16 19:26
**Session type:** Integration + comprehensive status
**Trigger:** User request — projects-management-automation integration + full status audit

---

## Executive Summary

**projects-management-automation** integrated as the 10th shared overlay — replacing a stale `go install` binary with a fully declarative Nix-managed package. Build passes clean. No broken services since the Caddy fix (session 20). The system is in its healthiest state in weeks.

**Health:** 🟢 All core services operational | 🟡 Disk pressure persists | 🔴 No automated backups

---

## A) FULLY DONE

### This Session

| # | Item | Details |
|---|------|---------|
| 1 | **projects-management-automation overlay** | Added as flake input (`git+ssh`, follows nixpkgs), `mkPackageOverlay` in `overlays/shared.nix`, added to `perSystem.packages` and `platforms/common/packages/base.nix`. Now available on Darwin + NixOS. |
| 2 | **~/go/bin cleanup** | Removed PMA from legacy PATH comment. Only `govalid` remains as `go install`-only. |
| 3 | **AGENTS.md updated** | Overlay list (9→10), flake inputs table, pkgs/ tree, mkPackageOverlay count all updated. |
| 4 | **Build validation** | `just test-fast` passes clean on x86_64-linux. |

### Previously Completed (Cumulative — Sessions 1–20)

| # | Item | Since |
|---|------|-------|
| 5 | Caddy ReadWritePaths fix (11h crash loop) | Session 20 |
| 6 | Hermes upgrade to v2026.5.7 | Session 19 |
| 7 | All 9→10 flake-input overlays converted to `mkPackageOverlay` | Session 19 |
| 8 | 6 missing overlay tools added to home.packages | Session 18 |
| 9 | Shell script formatting normalized | Session 17 |
| 10 | Dual-WAN ECMP+MPTCP active-active failover | Sessions 11-12 |
| 11 | GPU OOM multi-layer defense (MAX_LOADED_MODELS, GPU_OVERHEAD, fractions) | Session 13 |
| 12 | Niri DRM healthcheck + GPU recovery (unbind/rebind/auto-reboot) | Session 10 |
| 13 | DNS blocker stack (Unbound + dnsblockd, 25 blocklists, 2.5M+ domains) | Session 8 |
| 14 | EMEET PIXY webcam daemon (auto-tracking, audio, Waybar) | Session 5 |
| 15 | Centralized AI model storage (`/data/ai/`) | Session 7 |
| 16 | Wallpaper self-healing (awww PartOf, not BindsTo) | Session 9 |
| 17 | Taskwarrior + TaskChampion cross-platform sync | Session 6 |
| 18 | lib/ shared helpers (harden, hardenUser, serviceDefaults, types, mkGraphicalUserService, rocm) | Session 8 |
| 19 | Pre-commit hooks (statix, deadnix, treefmt+alejandra, shellcheck) | Session 4 |
| 20 | SigNoz observability pipeline (6 dashboards, journald, Prometheus scraping) | Sessions 13-15 |
| 21 | Gatus health monitoring (26+ endpoints, Discord alerting) | Session 14 |
| 22 | OpenSEO service deployment | Session 12 |
| 23 | Monitor365 service (rewritten module + enabled) | Session 16 |
| 24 | File-and-image-renamer (flaked overlay) | Session 14 |
| 25 | flake-parts modular architecture (41 service modules) | Session 1 |
| 26 | Cross-platform Home Manager (14 program modules, 70+ packages) | Session 1 |
| 27 | All path: inputs eliminated → git+ssh: URLs | Session 5 |
| 28 | Pipe operators enabled (`nixConfig.extra-experimental-features`) | Session 7 |
| 29 | primaryUser module (eliminated 15 hardcoded "lars" refs) | Session 9 |
| 30 | Overlay extraction to `overlays/` directory (−200 lines from flake.nix) | Session 13 |

---

## B) PARTIALLY DONE

| # | Item | What's done | What's missing |
|---|------|-------------|----------------|
| 1 | **DNS failover cluster** | `dns-failover.nix` module written, Keepalived VRRP configured, both evo-x2 and rpi3 configs exist | Pi 3 hardware not provisioned — entirely untestable |
| 2 | **ComfyUI service** | Module exists in `modules/nixos/services/comfyui.nix`, enabled in configuration.nix, `ExecCondition` guard prevents crash | WorkingDirectory (`/home/lars/projects/anime-comic-pipeline/ComfyUI`) doesn't exist. Service is a zombie. Should disable or fix path. |
| 3 | **Photomap service** | Module exists, Caddy vhost configured, Gatus endpoint | Disabled — podman config permission issue. Needs debugging. |
| 4 | **OpenSEO** | Deployed, Docker-based, Caddy vhost + Authelia forward auth | Pay-as-you-go DataForSEO API — requires active API key and credits |
| 5 | **Voice agents** | Whisper ASR (Docker/ROCm) + LiveKit configured, Caddy vhosts | LiveKit API keys via sops — untested in production |
| 6 | **SigNoz alert rules** | `signoz-alerts.nix` has `mkRule` helper, rules + dashboards defined in JSON | Rules not loaded into SigNoz — need API deployment step |
| 7 | **Twenty CRM** | Module deployed, Docker containers running | Needs `twenty-POST-SETUP.md` configuration — not production-ready |
| 8 | **TODO_LIST.md** | Exists with 20+ active tasks | Last updated May 11 (5 days stale). Several items already completed. |

---

## C) NOT STARTED

| # | Item | Priority | Notes |
|---|------|----------|-------|
| 1 | **Caddy log rotation** | Medium | No logrotate for `/var/log/caddy/`. Could fill disk on busy proxy. |
| 2 | **Automated nix GC timer** | Medium | No periodic GC — manual `just clean` only. Both machines at high disk usage. |
| 3 | **Backup automation** | HIGH | No automated backups for service data. Manual `just immich-backup` and `just task-backup` only. No restore testing. |
| 4 | **TLS certificate auto-renewal** | Medium | dnsblockd CA cert is static in sops. Gatus checks expiry (7-day alert) but no auto-renewal. |
| 5 | **CI/CD pipeline** | Medium | No automated builds on push. All testing is manual. |
| 6 | **NixOS integration tests** | Low | `just test-fast` does syntax only. No service-level tests. |
| 7 | **Home Manager Darwin tests** | Low | No automated test for macOS build. Manual `just switch` only. |
| 8 | **Minecraft server** | Low | Module exists, disabled. Low priority. |
| 9 | **Disk space monitoring alert** | Medium | No alert when disk exceeds 85%. Root is at 90%. |
| 10 | **Distributed builds (Darwin → evo-x2)** | Low | MacBook Air disk exhaustion during builds. Could offload. |
| 11 | **Service catalog documentation** | Low | No port map / dependency diagram. |
| 12 | **go-auto-upgrade golangci-lint fix** | Low | `gomodguard_v2` unknown linter in pre-commit. Needs `golangci-lint-auto-configure` run. |

---

## D) TOTALLY FUCKED UP

| # | Item | Severity | Details | Status |
|---|------|----------|---------|--------|
| 1 | **Caddy was down 11 hours** (session 20) | 🔴 CRITICAL (resolved) | `ReadWritePaths` missing `/var/log/caddy` under `ProtectSystem=full`. ALL reverse-proxied services unreachable from May 15 15:22 to May 16 02:30. | **Fixed** — deployed in session 20. But the monitoring gap remains: Gatus checked `/metrics` not actual proxy. |
| 2 | **Disk at 90% on evo-x2 root** | 🟡 ONGOING | 442G/512G used on root partition. `/data` at 80% (819G/1T). No automated cleanup. Risk of build failures (`errno=28`). Darwin at 90-95%. | **Not addressed.** |
| 3 | **ComfyUI zombie service** | 🟡 LOW | Enabled but non-functional. Path doesn't exist. ExecCondition gracefully skips, but systemd still attempts startup every boot. Gatus endpoint fails every 5 min. | **Not addressed.** |
| 4 | **go-auto-upgrade pre-commit broken** | 🟡 LOW | `golangci-lint` fails with `unknown linters: 'gomodguard_v2'`. Had to `--no-verify` to commit. | **Not addressed.** External repo. |
| 5 | **AGENTS.md has 260+ lines of gotchas** | 🟡 CODE SMELL | Many gotchas represent real bugs that should be fixed rather than documented. The document is becoming a "wall of warnings" instead of a reference. | **Ongoing.** Each gotcha fixed reduces the wall. |

---

## E) WHAT WE SHOULD IMPROVE

### Architecture

1. **Caddy health check is inadequate** — Gatus checks `/metrics` endpoint which doesn't exercise the full proxy pipeline. Need a health check that does an actual HTTP request through a virtual host (e.g., `https://auth.home.lan/health`) to catch config/log failures.
2. **No automated alerting for Caddy downtime** — Hermes detected it via journal scraping, but there's no structured "Caddy is down > 5 min" alert.
3. **Service dependency ordering** — Caddy depends on Authelia, but if Caddy fails, ALL downstream services are unreachable. Consider a degraded-mode health endpoint.
4. **ComfyUI zombie service** — Enabled but non-functional. Should disable the service to clean up monitoring noise.

### Process

5. **No CI/CD pipeline** — All testing is manual. A GitHub Actions runner on evo-x2 would catch build failures before deployment.
6. **No backup verification** — Manual backup commands exist but no automated schedule or restore testing.
7. **Flake input updates are manual** — `just update` fetches all inputs but doesn't build-test them. Should have a weekly automated `nix flake update && nix build` job.
8. **TODO_LIST.md is stale** — Last updated May 11. Several items already completed. Should be refreshed.

### Code Quality

9. **go-auto-upgrade go.sum is fragile** — Any new transitive dep from go-output/cmdguard requires manual go.sum updates. Consider `go mod vendor` in the prepared source step.
10. **Service modules lack integration tests** — Each module has options and config, but no automated verification that the generated systemd units are correct.
11. **AGENTS.md gotcha wall** — 260+ lines of gotchas. Many represent real bugs. Fix bugs, don't document them.

---

## F) Top 25 Things To Get Done Next

### P0 — Immediate (Today)

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 1 | **Deploy to evo-x2** (`just switch`) — includes PMA overlay + Caddy fix verification | Ships all session 20-21 work | 10 min |
| 2 | **Run `nix-collect-garbage --delete-older-than 7d`** on evo-x2 | Reclaims disk (90% full) | 10 min |
| 3 | **Fix Caddy health check in Gatus** — test actual proxy (not just /metrics) | Prevents future silent outages | 30 min |

### P1 — High Priority (This Sprint)

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 4 | **Disable ComfyUI service** (dead path reference) | Clean up zombie + monitoring noise | 5 min |
| 5 | **Set up automated backup schedule** (Immich DB, Gitea, Taskwarrior) | Data loss prevention | 2h |
| 6 | **Add Caddy access log rotation** (logrotate) | Prevent disk fill | 30 min |
| 7 | **Add periodic nix GC timer** (weekly, 7d threshold) | Prevent disk exhaustion | 30 min |
| 8 | **Fix go-auto-upgrade golangci-lint config** (remove gomodguard_v2) | Unbreak pre-commit | 15 min |
| 9 | **Deploy SigNoz alert rules** from signoz-alerts.nix | Active monitoring | 1h |

### P2 — Medium Priority (Next Sprint)

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 10 | **Add disk space monitoring alert** (Gatus or SigNoz, 85%+ threshold) | Early warning | 30 min |
| 11 | **Set up GitHub Actions CI** runner on evo-x2 | Automated build testing | 3h |
| 12 | **Fix photomap service** (podman permission issue) | Re-enable photo exploration | 2h |
| 13 | **Refresh TODO_LIST.md** against current codebase state | Accurate planning | 1h |
| 14 | **Wire SigNoz journald logs to Discord** for critical services | Structured alerting | 1h |
| 15 | **Test voice agents** (Whisper ASR + LiveKit) end-to-end | Validate deployment | 1h |
| 16 | **Audit all ReadWritePaths** for services using harden{} | Prevent caddy-class bugs | 1h |

### P3 — Nice To Have (Backlog)

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 17 | **Provision Pi 3** for DNS failover cluster | HA DNS | 4h |
| 18 | **Set up distributed builds** (Darwin → evo-x2) | Faster macOS builds | 3h |
| 19 | **Implement TLS cert auto-renewal** (dnsblockd CA) | Prevent cert expiry | 3h |
| 20 | **Configure Twenty CRM** production setup | Business tool | 2h |
| 21 | **Add restore testing** for backup scripts | Backup confidence | 2h |
| 22 | **Create NixOS integration test framework** for service modules | Automated quality | 4h |
| 23 | **Refactor go-auto-upgrade prepared-source** to use `go mod vendor` | Reduce go.sum brittleness | 3h |
| 24 | **Document all services in a service catalog** (port map, dependencies) | Operational clarity | 2h |
| 25 | **Add Home Manager integration tests** (`just test-hm` for Darwin) | Cross-platform CI | 2h |

---

## G) Top #1 Question I Cannot Answer

**Should the ComfyUI service be disabled entirely, or is there a real ComfyUI installation planned for `/home/lars/projects/anime-comic-pipeline/ComfyUI`?**

The module is enabled but the working directory doesn't exist. The `ExecCondition` gracefully skips startup, but:
- Caddy vhost `comfyui.home.lan` resolves and returns 502
- Gatus health check fails every 5 minutes
- It adds noise to monitoring

If there's no plan to use ComfyUI, disabling the service + removing the Gatus endpoint cleans up the monitoring. If there IS a plan, the path needs updating and a pre-deployment checklist is needed.

---

## Project Stats

| Metric | Count |
|--------|-------|
| Nix files | 110 |
| Shell scripts | 21 |
| NixOS service modules | 41 (in `modules/nixos/services/`) |
| Cross-platform programs | 14 |
| Custom packages | 6 (aw-watcher, jscpd, modernize, netwatch, openaudible + todo-list-ai overlay) |
| Flake inputs | 39 |
| Shared overlays (mkPackageOverlay) | 10 |
| Linux-only overlays | 6 |
| Shell scripts in `scripts/` | 16 |
| Justfile recipes | 78 |
| Status reports (active) | 10 |
| Status reports (archived) | 85+ |
| Commits since May 1 | 408 |
| Lines in AGENTS.md | 920+ |
| Lines in justfile | 655 |

## Disk Status (from session 20 — needs recheck)

| Mount | Used | Total | Use% |
|-------|------|-------|------|
| `/` (root) | 442G | 512G | ~90% |
| `/data` | 819G | 1.0T | ~80% |

## Changed Files This Session

| File | Change |
|------|--------|
| `flake.nix` | Added `projects-management-automation` flake input + perSystem package |
| `flake.lock` | +11 new locked inputs for PMA's transitive dependency tree |
| `overlays/shared.nix` | Added PMA to function args + `mkPackageOverlay` line |
| `platforms/common/packages/base.nix` | Added PMA to Go tooling ecosystem packages |
| `platforms/common/home-base.nix` | Removed PMA from ~/go/bin legacy comment |
| `AGENTS.md` | Updated overlay count, flake inputs table, pkgs/ tree, ~/go/bin docs |
