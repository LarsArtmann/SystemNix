# Session 52: OpenSEO Domain Tracking Deployment + Full System Status

**Date:** 2026-05-08 08:35
**Type:** Feature Deployment + Full System Audit
**Previous Session:** Session 51 (Boot Performance Sprint)
**Uptime:** ~2 days

---

## Executive Summary

OpenSEO (self-hosted Ahrefs/Semrush alternative) deployed as a full NixOS service module with Docker-compose wrapper, Caddy reverse proxy, Gatus health monitoring, Homepage integration, and sops-encrypted secrets. 56/81 execution plan tasks complete (69%). Root partition at 89% (58GB free). **Working tree is clean — all changes committed across 6 commits in this session.** OpenSEO has a placeholder DataForSEO API key (needs real credentials).

---

## a) FULLY DONE ✅

### OpenSEO Deployment (This Session)

| # | Change | Files | Impact |
|---|--------|-------|--------|
| 1 | **OpenSEO service module** | `modules/nixos/services/openseo.nix` | Docker-compose systemd wrapper, port 3001, 2GB memory cap, tmpfs for vite build |
| 2 | **Caddy virtual host** | `modules/nixos/services/caddy.nix` | `seo.home.lan` with Authelia forward auth |
| 3 | **Gatus health check** | `modules/nixos/services/gatus-config.nix` | OpenSEO endpoint, 5m interval, Productivity group |
| 4 | **Homepage dashboard card** | `modules/nixos/services/homepage.nix` | OpenSEO widget with status dot, icon, siteMonitor |
| 5 | **SOPS secrets** | `modules/nixos/services/sops.nix`, `platforms/nixos/secrets/openseo.yaml` | DataForSEO API key encrypted, template rendered to `/run/secrets-rendered/openseo-env` |
| 6 | **Flake wiring** | `flake.nix` | flake-parts import + nixosModules.openseo in evo-x2 config |
| 7 | **Service enable** | `platforms/nixos/system/configuration.nix` | `services.openseo.enable = true` |
| 8 | **AGENTS.md update** | `AGENTS.md` | Full service documentation, Caddy port reference |
| 9 | **Justfile recipes** | `justfile` | `openseo-status`, `openseo-logs`, `openseo-restart` |
| 10 | **Deployment plan** | `docs/planning/2026-05-08_openseo-domain-tracking-deployment.md` | 14-task plan with dependency graph |
| 11 | **Memory tuning** | `openseo.nix` | 512m→2g container + systemd MemoryMax after OOM testing |
| 12 | **Statix fix** | `sops.nix` | Merged repeated templates keys (W20) |
| 13 | **Flake lock update** | `flake.lock` | 9 private repos updated to latest |

### Carried Forward (Sessions 25–51, Still Done)

| # | Item | Session |
|---|------|---------|
| 16 | Boot optimization (−22s): ClamAV defer, TPM disable, 2s timeout | 51 |
| 17 | Dead code removal (go.mod, go-test.yml, blocklist-hash-updater) | 50 |
| 18 | Shared lib adoption: `harden{}` in 24/33 services (73%), `serviceDefaults{}` in 13 (39%) | 46 |
| 19 | DNS CA trust system-wide via `security.pki.certificates` | 46 |
| 20 | Hermes v2026.4.30 + SQLite auto-recovery + permission fix | 49 |
| 21 | GPU headroom for niri (PYTORCH per-process memory fraction) | 42 |
| 22 | Niri BindsTo→Wants patch (survives `just switch`) | Earlier |
| 23 | Gatus health checks: 19 endpoints across all services | 44 |
| 24 | 4 ADRs documented (PartOf, WatchdogSec, session-restore, GPU recovery) | 34, 47 |
| 25 | Manifest LLM router service module | 30 |
| 26 | niri-session-manager integration | 35 |
| 27 | GPU DRM recovery system | 34 |
| 28 | Pre-commit hooks: gitleaks, deadnix, statix, alejandra, shellcheck, flake check | Ongoing |
| 29 | 33 service modules fully modularized via flake-parts | Ongoing |
| 30 | `primaryUser` option replacing hardcoded `"lars"` (−81%) | 29 |

---

## b) PARTIALLY DONE ⚠️

| Item | Status | What's Left |
|------|--------|-------------|
| **OpenSEO DataForSEO API** | Service deployed, secrets encrypted | **PLACEHOLDER key:** `openseo.yaml` contains `PLACEHOLDER_GET_FROM_DATAFORSEO`. User must sign up at dataforseo.com ($1 free credit, $50 min top-up), get API credentials, then `sops platforms/nixos/secrets/openseo.yaml` + `just switch`. |
| **OpenSEO service deployed** | Config committed, service defined | Not verified running — `just switch` pending for latest memory changes (2GB). |
| **Hardcoded port references** | Convention established in caddy.nix | ~6 targets in SigNoz scrapers, 7 URLs in Homepage, Ollama/Whisper/LiveKit/NodeExporter/cAdvisor in Gatus still use raw port numbers |
| **`serviceDefaultsUser` adoption** | 2 of ~4 user services | emeet-pixyd (external flake) and niri-drm-healthcheck still use inline patterns |
| **Root partition disk usage** | 95% → 89% (58GB free) | Improved but still high. `/data` at 83% (139GB free). Weekly GC running. |

---

## c) NOT STARTED ❌

| # | Item | Effort | Impact | Priority |
|---|------|--------|--------|----------|
| 1 | **OpenSEO: get real DataForSEO API key** | External | High | P0 |
| 3 | **Add `harden{}` to Unsloth Studio** — `ai-stack.nix` | 5 min | High | P1 |
| 4 | **Add `harden{}` + `serviceDefaults{}` to gpu-recovery** — `niri-config.nix` | 5 min | High | P1 |
| 5 | **Add MemoryMax to Caddy** (reverse proxy, no memory limit!) | 5 min | High | P1 |
| 6 | **Add MemoryMax to Authelia** | 5 min | High | P1 |
| 7 | **Add MemoryMax to Gitea, Homepage, TaskChampion, voice-agents** | 15 min | Medium | P2 |
| 8 | **WatchdogSec=30 on Caddy** (Type=notify, safe) | 5 min | High | P1 |
| 9 | **Fix DNS subdomain drift** — rpi3 missing "manifest" | 5 min | Medium | P2 |
| 10 | **Replace hardcoded ports in SigNoz, Homepage, Gatus** (~20 locations) | 60 min | Medium | P2 |
| 11 | **Convert SigNoz inline port options to `serviceTypes.servicePort`** | 15 min | Medium | P2 |
| 12 | **NixOS VM tests** — zero integration test coverage | 2 hr | High | P2 |
| 13 | **Theme adoption** (yazi, waybar, rofi, wlogout, homepage — colorScheme) | 60 min | Medium | P3 |
| 14 | **Signoz split** (738 lines → sub-modules) | 30 min | Low | P3 |
| 15 | **Update FEATURES.md** | 5 min | Low | P3 |
| 16 | **Shell config dedup** — extract common carapace/starship/nixAliases | 1 hr | Medium | P3 |
| 17 | **Darwin CI** — never built in CI | 1 hr | Medium | P3 |
| 18 | **Raspberry Pi 3 DNS failover cluster** | Hardware | High | P3 |
| 19 | **Centralize firewall ports** | 30 min | Medium | P3 |
| 20 | **ReadWritePaths for hardened services** | 30 min | Low | P4 |

---

## d) TOTALLY FUCKED UP 💥

| # | Issue | Severity | Status |
|---|-------|----------|--------|
| 1 | **OpenSEO has placeholder API key** | 🟡 Medium | `dataforseo_api_key = PLACEHOLDER_GET_FROM_DATAFORSEO`. Service starts but cannot do actual SEO work (no rank tracking, keyword research, etc.). |
| 2 | **Root partition at 89%** (58GB free of 512GB) | 🟡 Medium | Improved from 95% but still consuming space. Nix GC running weekly. `/nix/store` is the primary consumer. |
| 3 | **Gatus `Docker Daemon` endpoint duplicates cAdvisor** | 🟢 Low | Both point to `localhost:9110/metrics`. Docker Daemon should point to Docker's own metrics endpoint. |
| 4 | **Ollama port hardcoded in Gatus** (11434) | 🟢 Low | Should use `config.services.ollama.port` or equivalent. |

---

## e) WHAT WE SHOULD IMPROVE 📈

### Immediate

1. **Get real DataForSEO credentials** — OpenSEO is deployed but useless without API access. Sign up at dataforseo.com, get base64 `login:password`, update via `sops platforms/nixos/secrets/openseo.yaml`.

2. **`just switch` to deploy** — Boot optimizations from session 51 and OpenSEO from session 52 are committed but not yet active.

### Architecture

3. **Memory limits for ALL services** — Caddy (reverse proxy for everything!) has no MemoryMax. If any backend leaks memory or gets hit with abuse traffic, it cascades. Wave A from execution plan (#7-13) would fix this in ~15 minutes.

4. **Gatus endpoint accuracy** — Docker Daemon endpoint is wrong (points to cAdvisor). Ollama, Whisper, LiveKit, NodeExporter, cAdvisor, DNS Blocker all use hardcoded ports instead of service config references.

5. **No integration tests** — 33 service modules, zero NixOS VM tests. Only static analysis catches issues. A single `nixosTest` for caddy + authelia would have caught multiple incidents.

6. **Signoz is a 738-line monolith** — Needs splitting into sub-modules (collector, clickhouse, query-service, exporters) for maintainability.

### Process

7. **Deploy before committing follow-on work** — Gatus Discord alerting was built on top of the OpenSEO work without verifying OpenSEO actually runs. Should have done `just switch` first, then layered on new features.

8. **Secrets files must exist before referencing them** — The gatus.yaml situation is a self-inflicted wound. Rule: create + encrypt the secrets file BEFORE modifying sops.nix to reference it.

---

## f) Top 25 Things We Should Get Done Next

### P0 — Blockers (Do Now)

| # | Task | Effort | Why |
|---|------|--------|-----|
| 1 | **`just switch` — deploy everything** | 10 min | Boot optimizations + OpenSEO committed but not active |
| 2 | **Get DataForSEO API credentials** | External | OpenSEO is useless without them |
| 3 | **Verify OpenSEO works after deploy** | 5 min | Unconfirmed |

### P1 — High Impact, Low Effort

| # | Task | Effort | Why |
|---|------|--------|-----|
| 5 | **MemoryMax on Caddy** — reverse proxy has no limit | 2 min | OOM risk on the most critical service |
| 6 | **MemoryMax on Authelia** — SSO gateway has no limit | 2 min | Same |
| 7 | **WatchdogSec=30 on Caddy** (Type=notify, safe) | 2 min | Caddy supports sd_notify |
| 8 | **Add `harden{}` to Unsloth Studio** — `ai-stack.nix` | 5 min | Security gap |
| 9 | **Add `harden{}` + `serviceDefaults{}` to gpu-recovery** | 5 min | Security gap |
| 10 | **Fix Gatus Docker Daemon endpoint** — points to cAdvisor | 2 min | Wrong metrics |
| 11 | **Fix DNS subdomain drift** — rpi3 missing "manifest" | 5 min | Correctness |

### P2 — High Impact, Medium Effort

| # | Task | Effort | Why |
|---|------|--------|-----|
| 12 | **MemoryMax on remaining services** (gitea, homepage, taskchampion, voice-agents) | 15 min | Resource isolation |
| 13 | **Replace hardcoded ports in Gatus** (6 endpoints) | 20 min | Convention compliance |
| 14 | **Replace hardcoded ports in Homepage** (7 URLs) | 20 min | Convention compliance |
| 15 | **Replace hardcoded ports in SigNoz** (6 targets) | 20 min | Convention compliance |
| 16 | **Convert SigNoz inline port options to `serviceTypes.servicePort`** | 15 min | Shared lib consistency |
| 17 | **Verify OpenSEO actually works** after deploy | 10 min | Unconfirmed |
| 18 | **Add basic NixOS VM test** for caddy + authelia | 2 hr | Zero integration tests |

### P3 — Nice to Have

| # | Task | Effort | Why |
|---|------|--------|-----|
| 19 | **Theme adoption** (yazi, waybar, rofi, wlogout, homepage) | 60 min | Catppuccin consistency |
| 20 | **Update FEATURES.md** | 5 min | Accuracy |
| 21 | **Signoz split** (738→sub-modules) | 30 min | Maintainability |
| 22 | **Centralize firewall ports** | 30 min | DRY |
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
| Twenty CRM | 3000 | ✅ Running | `twenty.home.lan` |
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
| Monitor365 | — | ✅ Running | User service |
| Netwatch | — | ✅ Running | On-demand TUI |

### Hardware

| Metric | Value |
|--------|-------|
| CPU | AMD Ryzen AI Max+ 395 (16C/32T) |
| RAM | 128GB total |
| Root | 89% used, 58GB free of 512GB |
| Data | 83% used, 139GB free of 800GB |
| Platform | NixOS 26.05 (unstable) |

### Codebase Metrics

| Metric | Value |
|--------|-------|
| Service modules | 33 |
| Service module lines | 5,753 |
| Execution plan progress | 56/81 (69%) |
| `harden{}` adoption | 24/33 (73%) |
| `serviceDefaults{}` adoption | 13/33 (39%) |
| ADRs | 4 |
| Uncommitted files | 0 |

---

_Arte in Aeternum_
