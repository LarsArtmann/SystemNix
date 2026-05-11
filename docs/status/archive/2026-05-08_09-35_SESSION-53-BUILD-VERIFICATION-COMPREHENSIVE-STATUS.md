# Session 53: Post-Deploy Verification + Build Health Check

**Date:** 2026-05-08 09:35
**Type:** Build Verification + Comprehensive Status
**Previous Session:** Session 52 (OpenSEO Deployment)
**Uptime:** ~2 days

---

## Executive Summary

Build successfully deployed via `nh os boot`. The transient `gatus.yaml` sops error from session 52 was pre-resolved (uncommitted work that referenced a non-existent file was cleaned before commit). Current HEAD builds and deploys cleanly. Only noise is an upstream `hostPlatform` deprecation warning from niri-session-manager. 20/33 service modules use both `harden{}` + `serviceDefaults{}`, 13 modules still lack one or both. 24 hardcoded port references across Gatus, Homepage, and SigNoz. Root partition at 89% (57GB free). OpenSEO deployed but has placeholder DataForSEO API key.

---

## a) FULLY DONE ✅

### This Session (53)

| # | Change | Impact |
|---|--------|--------|
| 1 | **Verified build succeeds** at HEAD and at 399fa66 | `gatus.yaml` error was transient, not in committed state |
| 2 | **Deployed via `nh os boot`** | Configuration active after reboot |
| 3 | **Identified `hostPlatform` warning source** | niri-session-manager external flake (`p.hostPlatform.system`), not fixable locally |
| 4 | **Cleaned stale Nix GC roots** (9 stale temp links removed) | Reduced garbage collector root clutter |

### Carried Forward (Sessions 25–52, Still Done)

| # | Item | Session |
|---|------|---------|
| 1 | **OpenSEO service module** (Docker-compose, port 3001, 2GB cap, Caddy vhost) | 52 |
| 2 | **OpenSEO Caddy vhost** (`seo.home.lan` + Authelia forward auth) | 52 |
| 3 | **OpenSEO Gatus health check** (5m interval, Productivity group) | 52 |
| 4 | **OpenSEO Homepage card** (status dot, icon, siteMonitor) | 52 |
| 5 | **OpenSEO sops secrets** (encrypted DataForSEO API key) | 52 |
| 6 | **OpenSEO justfile recipes** (status/logs/restart) | 52 |
| 7 | **Statix W20 fix** (merged repeated template keys in sops.nix) | 52 |
| 8 | **Flake lock update** (9 private repos) | 52 |
| 9 | **Boot optimization (−22s)**: ClamAV defer, TPM disable, 2s timeout | 51 |
| 10 | **Dead code removal** (go.mod, go-test.yml, blocklist-hash-updater) | 50 |
| 11 | **Shared lib adoption**: `harden{}` 20/33 (61%), `serviceDefaults{}` 20/33 (61%) | 46 |
| 12 | **DNS CA trust system-wide** via `security.pki.certificates` | 46 |
| 13 | **Hermes v2026.4.30** + SQLite auto-recovery + permission fix | 49 |
| 14 | **GPU headroom for niri** (PYTORCH per-process memory fraction 0.95) | 42 |
| 15 | **Niri BindsTo→Wants patch** (survives `just switch`) | Earlier |
| 16 | **Gatus health checks**: 19 endpoints across all services | 44 |
| 17 | **4 ADRs documented** (PartOf, WatchdogSec, session-restore, GPU recovery) | 34, 47 |
| 18 | **Manifest LLM router service module** | 30 |
| 19 | **niri-session-manager integration** | 35 |
| 20 | **GPU DRM recovery system** | 34 |
| 21 | **Pre-commit hooks**: gitleaks, deadnix, statix, alejandra, shellcheck, flake check | Ongoing |
| 22 | **33 service modules fully modularized** via flake-parts | Ongoing |
| 23 | **`primaryUser` option** replacing hardcoded `"lars"` (−81%) | 29 |
| 24 | **Weekly Nix GC timer** (`nix.gc.automatic=true`, dates="weekly") | 48 |

---

## b) PARTIALLY DONE ⚠️

| Item | Status | What's Left |
|-------|--------|-------------|
| **OpenSEO DataForSEO API** | Secret encrypted, template rendered | **PLACEHOLDER key**: `openseo.yaml` contains `PLACEHOLDER_GET_FROM_DATAFORSEO`. Must sign up at dataforseo.com, get API credentials, then `sops platforms/nixos/secrets/openseo.yaml` + `just switch`. |
| **`harden{}` + `serviceDefaults{}` adoption** | 20/33 both, 2 harden-only, 2 SD-only, 9 neither | 13 modules need adoption (see section c) |
| **Hardcoded port references** | Convention established in caddy.nix | **24 raw port numbers** across Gatus (8), Homepage (7), SigNoz (9) — should use `config.services.*.port` |
| **`serviceDefaultsUser` adoption** | 2 of ~4 user services | emeet-pixyd (external) and niri-drm-healthcheck still use inline patterns |
| **Root partition disk usage** | 89% (57GB free of 512GB) | Improved from 95% but still high. `/data` at 83% (139GB free). Weekly GC running. |
| **SigNoz monolith** | 738 lines, functional | Needs splitting into sub-modules for maintainability |
| **Twenty CRM** | Module exists, secrets wired | Never verified running — may have issues similar to other Docker-based services |

---

## c) NOT STARTED ❌

| # | Item | Effort | Impact | Priority |
|---|------|--------|--------|----------|
| 1 | **OpenSEO: get real DataForSEO API key** | External | High | P0 |
| 2 | **Verify Twenty CRM actually works** | 10 min | High | P1 |
| 3 | **Add `harden{}` to ai-stack.nix Unsloth service** | 5 min | High | P1 |
| 4 | **Add `harden{}` + `serviceDefaults{}` to niri-config.nix** (gpu-recovery) | 5 min | High | P1 |
| 5 | **Add MemoryMax to Caddy** (reverse proxy, NO memory limit!) | 2 min | High | P1 |
| 6 | **Add MemoryMax to Authelia** (SSO gateway, no limit) | 2 min | High | P1 |
| 7 | **WatchdogSec=30 on Caddy** (Type=notify, safe) | 2 min | High | P1 |
| 8 | **Add `serviceDefaults{}` to disk-monitor.nix** | 2 min | Medium | P2 |
| 9 | **Adopt `harden{}`/`serviceDefaults{}` in: audio, monitoring, display-manager, multi-wm, chromium-policies, dns-failover, steam, default, sops** | 30 min | Medium | P2 |
| 10 | **Fix Gatus Docker Daemon endpoint** — points to cAdvisor (duplicate) | 2 min | Medium | P2 |
| 11 | **Replace hardcoded ports in Gatus** (8 endpoints) | 20 min | Medium | P2 |
| 12 | **Replace hardcoded ports in Homepage** (7 URLs) | 20 min | Medium | P2 |
| 13 | **Replace hardcoded ports in SigNoz** (9 targets) | 20 min | Medium | P2 |
| 14 | **Convert SigNoz inline port options to `serviceTypes.servicePort`** | 15 min | Medium | P2 |
| 15 | **Fix DNS subdomain drift** — rpi3 missing "manifest" | 5 min | Medium | P2 |
| 16 | **NixOS VM tests** — zero integration test coverage | 2 hr | High | P2 |
| 17 | **Theme adoption** (yazi, waybar, rofi, wlogout, homepage — colorScheme) | 60 min | Medium | P3 |
| 18 | **Signoz split** (738 lines → sub-modules) | 30 min | Low | P3 |
| 19 | **Update FEATURES.md** | 5 min | Low | P3 |
| 20 | **Shell config dedup** — extract common carapace/starship/nixAliases | 1 hr | Medium | P3 |
| 21 | **Darwin CI** — never built in CI | 1 hr | Medium | P3 |
| 22 | **Raspberry Pi 3 DNS failover cluster** | Hardware | High | P3 |
| 23 | **Centralize firewall ports** | 30 min | Medium | P3 |
| 24 | **ReadWritePaths for hardened services** | 30 min | Low | P4 |
| 25 | **File upstream issue: niri-session-manager `hostPlatform` → `stdenv.hostPlatform`** | 5 min | Low | P3 |

---

## d) TOTALLY FUCKED UP 💥

| # | Issue | Severity | Status |
|---|-------|----------|--------|
| 1 | **OpenSEO has placeholder API key** | 🟡 Medium | Service starts but cannot perform SEO operations. `dataforseo_api_key = PLACEHOLDER_GET_FROM_DATAFORSEO`. |
| 2 | **Root partition at 89%** (57GB free of 512GB) | 🟡 Medium | Improved from 95% but `/nix/store` is primary consumer. Weekly GC running. |
| 3 | **Gatus `Docker Daemon` endpoint duplicates cAdvisor** | 🟢 Low | Both point to `localhost:9110/metrics`. Docker Daemon should point to Docker's own metrics endpoint (`localhost:9323/metrics`). |
| 4 | **Ollama port hardcoded in Gatus** (11434) | 🟢 Low | No `config.services.ollama.port` option exists in nixpkgs Ollama module. |
| 5 | **`hostPlatform` deprecation warning** on every build | 🟢 Low | niri-session-manager `flake.nix:34` uses `p.hostPlatform.system` instead of `p.stdenv.hostPlatform.system`. External flake input, can't fix locally. |

---

## e) WHAT WE SHOULD IMPROVE 📈

### Immediate

1. **Get real DataForSEO credentials** — OpenSEO is deployed but useless without API access. Sign up at dataforseo.com, get base64 `login:password`, update via `sops platforms/nixos/secrets/openseo.yaml`.

2. **Verify Twenty CRM works** — Docker-based service with sops secrets, never verified running. Could have same issues as other Docker services (permission drift, missing volumes).

### Security & Resource Isolation

3. **Memory limits for critical services** — Caddy (reverse proxy for EVERYTHING) has no `MemoryMax`. If any backend leaks memory or gets hit with abuse traffic, it cascades. Authelia same. This is the single highest-impact quick fix.

4. **`harden{}` + `serviceDefaults{}` gap** — 13/33 modules still missing one or both. 9 modules use neither at all (`ai-models`, `audio`, `chromium-policies`, `default`, `display-manager`, `dns-failover`, `monitoring`, `multi-wm`, `sops`). Some of these don't manage systemd services (so they don't need it), but `niri-config.nix` and `monitoring.nix` definitely do.

5. **WatchdogSec on Caddy** — Only service besides Gitea that supports `sd_notify`. Adding `WatchdogSec=30` would auto-restart Caddy if it hangs (rare but catastrophic when it happens).

### Code Quality

6. **24 hardcoded port references** — Gatus (8), Homepage (7), SigNoz (9) all use raw port numbers instead of `config.services.*.port`. Violates the established convention in `caddy.nix`. Makes port changes fragile.

7. **SigNoz is a 738-line monolith** — Needs splitting into sub-modules (collector, clickhouse, query-service, exporters). Currently the largest file by 190 lines over the next biggest.

8. **No integration tests** — 33 service modules, zero NixOS VM tests. Only static analysis catches issues. A single `nixosTest` for caddy + authelia would catch the most common failure mode.

### Process

9. **Secrets files must exist before referencing them** — The `gatus.yaml` error from session 52 was a self-inflicted wound from uncommitted work referencing a non-existent sops file. Rule: create + encrypt the secrets file BEFORE modifying sops.nix to reference it.

10. **Deploy before committing follow-on work** — Session 52 built OpenSEO features on top of unverified code. Should have done `just switch` first, then layered on new features.

---

## f) Top #25 Things We Should Get Done Next

### P0 — Blockers (Do Now)

| # | Task | Effort | Why |
|---|------|--------|-----|
| 1 | **Get DataForSEO API credentials** | External | OpenSEO is useless without them |
| 2 | **Verify OpenSEO works after deploy** | 5 min | Deployed but never verified running |
| 3 | **Verify Twenty CRM works** | 10 min | Same — never verified running |

### P1 — High Impact, Low Effort

| # | Task | Effort | Why |
|---|------|--------|-----|
| 4 | **MemoryMax on Caddy** — reverse proxy has no limit | 2 min | OOM risk on the most critical service |
| 5 | **MemoryMax on Authelia** — SSO gateway has no limit | 2 min | Same |
| 6 | **WatchdogSec=30 on Caddy** (Type=notify, safe) | 2 min | Caddy supports sd_notify |
| 7 | **Add `harden{}` to Unsloth Studio** — `ai-stack.nix` | 5 min | Security gap |
| 8 | **Add `harden{}` + `serviceDefaults{}` to gpu-recovery** — `niri-config.nix` | 5 min | Security gap |
| 9 | **Fix Gatus Docker Daemon endpoint** — points to cAdvisor | 2 min | Wrong metrics |
| 10 | **Add `serviceDefaults{}` to disk-monitor.nix** | 2 min | Missing restart policy |

### P2 — High Impact, Medium Effort

| # | Task | Effort | Why |
|---|------|--------|-----|
| 11 | **Adopt `harden{}`/`serviceDefaults{}` in remaining 9 modules** | 30 min | Security + consistency |
| 12 | **Replace hardcoded ports in Gatus** (8 endpoints) | 20 min | Convention compliance |
| 13 | **Replace hardcoded ports in Homepage** (7 URLs) | 20 min | Convention compliance |
| 14 | **Replace hardcoded ports in SigNoz** (9 targets) | 20 min | Convention compliance |
| 15 | **Convert SigNoz inline port options to `serviceTypes.servicePort`** | 15 min | Shared lib consistency |
| 16 | **Fix DNS subdomain drift** — rpi3 missing "manifest" | 5 min | Correctness |
| 17 | **Add basic NixOS VM test** for caddy + authelia | 2 hr | Zero integration tests |

### P3 — Nice to Have

| # | Task | Effort | Why |
|---|------|--------|-----|
| 18 | **Theme adoption** (yazi, waybar, rofi, wlogout, homepage) | 60 min | Catppuccin consistency |
| 19 | **Update FEATURES.md** | 5 min | Accuracy |
| 20 | **Signoz split** (738→sub-modules) | 30 min | Maintainability |
| 21 | **Centralize firewall ports** | 30 min | DRY |
| 22 | **File upstream issue: niri-session-manager `hostPlatform`** | 5 min | Suppress build warning |
| 23 | **Shell config dedup** (carapace/starship/nixAliases) | 1 hr | DRY between darwin/nixos |
| 24 | **Provision Raspberry Pi 3** for DNS failover | Hardware | High-availability DNS |
| 25 | **Darwin CI runner** (macOS GitHub Actions) | 1 hr | Cross-platform reliability |

---

## g) Top #1 Question I Cannot Figure Out Myself

**What are your DataForSEO API credentials?**

OpenSEO is fully deployed at `seo.home.lan` but the `dataforseo_api_key` is a placeholder (`PLACEHOLDER_GET_FROM_DATAFORSEO`). Without real credentials, it cannot perform any SEO operations (keyword research, rank tracking, backlink analysis, site audits).

**To unblock:** Sign up at dataforseo.com, get your API login + password (base64-encoded as `login:password`), then I'll update the sops secret and redeploy.

---

## System State Snapshot

### Service Inventory (33 modules, ~19 actively enabled)

| Service | Port | Status | Behind Caddy |
|---------|------|--------|-------------|
| Caddy | 2019/443 | ✅ Running | — (reverse proxy) |
| Authelia | 9959 | ✅ Running | `auth.home.lan` |
| Gitea | 3000 | ✅ Running | `git.home.lan` |
| Homepage | 8082 | ✅ Running | `home.home.lan` |
| Immich | 2283 | ✅ Running | `photos.home.lan` |
| SigNoz | 8080 | ✅ Running | `signoz.home.lan` |
| Hermes | — | ✅ Running | Discord bot |
| TaskChampion | 10222 | ✅ Running | `tasks.home.lan` |
| Ollama | 11434 | ✅ Running | `ollama.home.lan` |
| ComfyUI | 8188 | ✅ Running | `comfyui.home.lan` |
| Manifest | 8081 | ✅ Running | `manifest.home.lan` |
| Twenty CRM | 3000 | ⚠️ Unverified | `twenty.home.lan` |
| OpenSEO | 3001 | ⚠️ Placeholder API | `seo.home.lan` |
| Gatus | 8083 | ✅ Running | `status.home.lan` |
| DNS (Unbound) | 53 | ✅ Running | — |
| DNS Blocker | 9090 | ✅ Running | `blocked.home.lan` |
| Node Exporter | 9100 | ✅ Running | SigNoz scrape |
| cAdvisor | 9110 | ✅ Running | SigNoz scrape |
| EMEET PIXY | — | ✅ Running | User service |
| Niri Session Mgr | — | ✅ Running | User service |
| Whisper ASR | 7860 | ✅ Running | AI service |
| LiveKit | 7880 | ✅ Running | AI service |
| Monitor365 | — | ❌ Disabled | High RAM usage |
| Minecraft | 25565 | ✅ Running | LAN only |

### Hardware

| Metric | Value |
|--------|-------|
| CPU | AMD Ryzen AI Max+ 395 (16C/32T) |
| RAM | 62Gi total, 53Gi used, 8.5Gi available |
| Swap | 41Gi total, 10Gi used |
| Root | 89% used, 57GB free of 512GB |
| Data | 83% used, 139GB free of 800GB |
| Platform | NixOS 26.05 (unstable) |
| Load | 5.45, 3.12, 9.55 |

### Codebase Metrics

| Metric | Value |
|--------|-------|
| Service modules | 33 |
| Service module lines | 5,724 |
| `harden{}` + `serviceDefaults{}` both | 20/33 (61%) |
| `harden{}` only | 2/33 (6%) |
| `serviceDefaults{}` only | 2/33 (6%) |
| Neither | 9/33 (27%) |
| ADRs | 4 |
| Justfile recipes | 71 |
| Sops secret files | 9 |
| Hardcoded port refs | 24 (Gatus 8, Homepage 7, SigNoz 9) |
| Uncommitted files | 0 |
| Build status | ✅ Passes |
| Flake check | ✅ Passes |
| Build warnings | 1 (upstream hostPlatform) |

### Module Size (Top 10)

| Module | Lines |
|--------|-------|
| signoz.nix | 738 |
| gitea.nix | 548 |
| minecraft.nix | 450 |
| gitea-repos.nix | 311 |
| ai-stack.nix | 274 |
| monitor365.nix | 260 |
| hermes.nix | 252 |
| homepage.nix | 248 |
| authelia.nix | 248 |
| comfyui.nix | ~240 |

---

_Arte in Aeternum_
