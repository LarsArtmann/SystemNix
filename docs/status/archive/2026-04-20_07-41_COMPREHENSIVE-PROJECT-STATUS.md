# SystemNix Comprehensive Project Status — 2026-04-20 07:41

**Branch:** `master`
**Last Commit:** `b1cb4a5` — fix: emeet-pixyd build, service targets, GPU timeout, monitoring cleanup
**Codebase:** 87 Nix files, ~10,316 lines of Nix
**Platforms:** macOS (aarch64-darwin) + NixOS (x86_64-linux, evo-x2)
**Working Tree:** Clean ✅

---

## Executive Summary

SystemNix is a **mature, production-grade** cross-platform Nix configuration managing two machines through a single flake. The project has 14 active NixOS service modules, 15 cross-platform program modules, and 10 custom packages. The monitoring stack has been **fully consolidated to SigNoz** (Prometheus/Grafana completely removed and references cleaned up). Two new services (Twenty CRM, Voice Agents) were recently added. The emeet-pixyd build was fixed this session. The main operational gap is the SigNoz data pipeline — the platform runs but nothing feeds it metrics/logs.

---

## A) FULLY DONE ✅

### Infrastructure & Core

| Item                     | Details                                                                      |
| ------------------------ | ---------------------------------------------------------------------------- |
| **Cross-platform flake** | Single flake manages both macOS + NixOS via flake-parts                      |
| **Shared config (~80%)** | 15 program modules in `platforms/common/programs/`                           |
| **Home Manager**         | Both platforms import `common/home-base.nix`, consistent user experience     |
| **SOPS secrets**         | age-encrypted via SSH host key, managed in `modules/nixos/services/sops.nix` |
| **DNS blocker**          | Unbound + dnsblockd, 25 blocklists, 2.5M+ domains, Quad9 DoT upstream        |
| **Caddy reverse proxy**  | TLS via sops, `.home.lan` domains for all services                           |
| **Boot config**          | systemd-boot, 50 generations, kernel params tuned for Strix Halo             |
| **BTRFS snapshots**      | Timeshift, zstd compression, ZRAM swap (32GB)                                |
| **Theme**                | Catppuccin Mocha everywhere (GTK, Qt, terminal, SDDM, Waybar)                |

### Services (14 modules in `modules/nixos/services/`)

| Service          | Status | URL                 | Notes                                        |
| ---------------- | ------ | ------------------- | -------------------------------------------- |
| **Docker**       | ✅     | —                   | Base container runtime                       |
| **Caddy**        | ✅     | `*.home.lan`        | Reverse proxy, sops-managed TLS              |
| **Gitea**        | ✅     | `gitea.home.lan`    | GitHub mirror sync                           |
| **Immich**       | ✅     | `immich.home.lan`   | Photos/video (PostgreSQL + Redis + ML)       |
| **SigNoz**       | ✅     | `signoz.home.lan`   | Full observability (traces + metrics + logs) |
| **Homepage**     | ✅     | `dash.home.lan`     | Service overview dashboard                   |
| **PhotoMap AI**  | ✅     | `photomap.home.lan` | CLIP embedding vector map                    |
| **Authelia**     | ✅     | `auth.home.lan`     | SSO/OIDC identity provider                   |
| **TaskChampion** | ✅     | `tasks.home.lan`    | Taskwarrior sync server                      |
| **Twenty CRM**   | ✅     | `crm.home.lan`      | Customer relationship management             |
| **Voice Agents** | ✅     | `whisper.home.lan`  | LiveKit + Whisper ASR (ROCm)                 |
| **Gitea Repos**  | ✅     | —                   | Automated GitHub mirror sync                 |
| **SOPS**         | ✅     | —                   | Secrets decryption on activation             |
| **SSH Server**   | ✅     | —                   | Hardened, key-only auth                      |

### Monitoring Consolidation (This Session)

| Item                                | Status                                                     |
| ----------------------------------- | ---------------------------------------------------------- |
| **Prometheus removal**              | ✅ Complete — deleted `monitoring.nix`, removed from flake |
| **Grafana removal**                 | ✅ Complete — deleted `grafana.nix`, removed from flake    |
| **Fail2ban Grafana jail cleanup**   | ✅ Removed dead jail from `security-hardening.nix`         |
| **configuration.nix dead comments** | ✅ Removed stale commented imports                         |
| **README.md updated**               | ✅ Removed Prometheus/Grafana references                   |
| **AGENTS.md updated**               | ✅ Removed stale architecture tree entries                 |
| **Homepage dashboard**              | ✅ Already correct — only SigNoz under Monitoring          |

### Session Fixes (2026-04-20)

| Fix                          | Details                                                                          |
| ---------------------------- | -------------------------------------------------------------------------------- |
| **emeet-pixyd build**        | Restored `_type:` parameter in cleanSourceWith filter (both overlay + perSystem) |
| **graphical-session.target** | emeet-pixyd and dnsblockd-cert-import moved from default.target                  |
| **GPU lockup timeout**       | `amdgpu.lockup_timeout=30000` for Strix Halo heavy compute                       |
| **Whisper ASR API**          | Split ports: API :8000 + Gradio UI :7860, crash recovery                         |
| **swayidle suspend**         | Replaced inline bash -c with writeShellScript                                    |
| **cliphist**                 | Added RestartSec=3s                                                              |
| **DNS blocklists**           | Updated all 25 SHA-256 hashes                                                    |

### Custom Packages (10)

| Package                  | Status                                     |
| ------------------------ | ------------------------------------------ |
| `dnsblockd`              | ✅ DNS block page server (Go)              |
| `dnsblockd-processor`    | ✅ Blocklist processor (Go)                |
| `emeet-pixyd`            | ✅ Fixed this session — webcam daemon (Go) |
| `modernize`              | ✅ Go modernize tool                       |
| `aw-watcher-utilization` | ✅ ActivityWatch plugin                    |
| `openaudible`            | ✅ Audiobook manager                       |
| `notification-tone`      | ✅                                         |
| `superfile`              | ✅                                         |
| `helium`                 | ✅ (flake input)                           |
| `otel-tui`               | ✅ (flake input)                           |

---

## B) PARTIALLY DONE 🔧

### SigNoz Observability Pipeline — **40% Complete**

SigNoz is deployed and running, but **starved for data**:

| Component                | Status               | Gap                                                           |
| ------------------------ | -------------------- | ------------------------------------------------------------- |
| SigNoz query service     | ✅ Running           | —                                                             |
| OTel Collector           | ✅ Running           | —                                                             |
| ClickHouse               | ✅ Running           | —                                                             |
| Caddy vhost              | ✅ `signoz.home.lan` | —                                                             |
| **Node exporter**        | ❌ Not deployed      | No system metrics (CPU, RAM, disk, network)                   |
| **cAdvisor**             | ❌ Not deployed      | No container metrics                                          |
| **App instrumentation**  | ❌ Not done          | Caddy, Authelia expose Prometheus metrics but nothing scrapes |
| **Log collection**       | ❌ Not done          | No journald → OTel pipeline                                   |
| **Alert rules**          | ❌ Not done          | No alerting for service down, disk full, etc.                 |
| **Dashboards**           | ❌ Not done          | No custom SigNoz dashboards                                   |
| **Notification channel** | ❌ Not configured    | No email/webhook/Telegram for alerts                          |

**Impact:** SigNoz UI shows empty data. Platform is ready but useless without data producers.

### Niri Session Save/Restore — **85% Complete**

| Feature                          | Status                                              |
| -------------------------------- | --------------------------------------------------- |
| Save timer (60s)                 | ✅                                                  |
| Window/workspace snapshot        | ✅                                                  |
| Kitty state (CWD, child process) | ✅                                                  |
| Restore on startup               | ✅                                                  |
| Floating state restore           | ✅                                                  |
| Column width restore             | ✅                                                  |
| Focus order restore              | ✅                                                  |
| JSON validation + fallback       | ✅                                                  |
| **Non-kitty app restore**        | ⚠️ Limited — skips apps without clear respawn logic |

### EMEET PIXY Daemon — **90% Complete**

| Feature                                    | Status                |
| ------------------------------------------ | --------------------- |
| HID control, call detection, auto-tracking | ✅                    |
| PipeWire source switching, socket API      | ✅                    |
| Hotplug recovery, bidirectional HID state  | ✅                    |
| Desktop notifications, Waybar integration  | ✅                    |
| **Nix build**                              | ✅ Fixed this session |
| **Prometheus /metrics endpoint**           | ❌ Not implemented    |
| **Integration tests in CI**                | ❌ Not running        |

---

## C) NOT STARTED 📋

| #   | Item                                            | Priority | Effort |
| --- | ----------------------------------------------- | -------- | ------ |
| 1   | SigNoz data producers (node_exporter, cAdvisor) | P0       | 2-4 hr |
| 2   | SigNoz alert rules                              | P1       | 2 hr   |
| 3   | SigNoz custom dashboards                        | P1       | 3 hr   |
| 4   | Journald → OTel log pipeline                    | P2       | 2 hr   |
| 5   | App-level OTel instrumentation                  | P2       | 4+ hr  |
| 6   | Notification channel (email/webhook/Telegram)   | P1       | 1 hr   |
| 7   | Grafana Pyroscope for profiling                 | P3       | 2 hr   |
| 8   | DNS blocker /metrics endpoint                   | P3       | 1 hr   |
| 9   | Automated backup verification                   | P3       | 1 hr   |
| 10  | GPU monitoring pipeline (ROCm → SigNoz)         | P3       | 1 hr   |

---

## D) TOTALLY FUCKED UP 💥 → FIXED ✅

### 1. `emeet-pixyd` Nix Build — FIXED THIS SESSION

**Was:** `cleanSourceWith` filter signature mismatch (1-arg instead of 2-arg function).

**Error:** `attempt to call something which is not a function but a Boolean: true`

**Fix:** Restored `_type:` parameter in both overlay definitions in `flake.nix`.

**Lesson:** `lib.cleanSourceWith` always calls `filter(path, type)` — the `type` parameter is mandatory even if unused.

### 2. Pre-commit Hook Sweeping All Modified Files

The pre-commit hook runs trailing-whitespace removal + alejandra on ALL tracked modified files, not just staged ones. This makes it impossible to split accumulated changes into separate commits after-the-fact because formatting touches all modified files and stages them.

**Workaround:** Format first with `nix fmt`, then stage carefully. Or commit changes immediately as they happen rather than accumulating.

---

## E) WHAT WE SHOULD IMPROVE

### Critical

1. **SigNoz is starving** — The #1 operational gap. Deployed but receiving zero data. node_exporter + cAdvisor + log pipeline needed urgently.
2. **No alerting** — If any service dies at 3am, nobody knows until manual check.
3. **Commit hygiene** — Pre-commit hook bundles all changes. Need to commit immediately per logical change.

### Architecture

4. **Docker dependency for Whisper** — Voice agents use Docker for Whisper ASR. A native NixOS package would be cleaner.
5. **No backup testing** — Timeshift snapshots are taken but never verified by restoring.
6. **Documentation drift** — 50+ status files in `docs/status/`, many contain stale Grafana/Prometheus references.

### Developer Experience

7. **Flake lock auto-updates** — Manual process, could be weekly GitHub Actions PR.
8. **emeet-pixyd tests** — `_test.go` excluded from Nix build, no CI for them.
9. **No scheduled health checks** — `just health` exists but isn't automated.

---

## F) Top 25 Things To Do Next

### P0 — Critical

| #   | Task                                                                 | Effort | Why                                |
| --- | -------------------------------------------------------------------- | ------ | ---------------------------------- |
| 1   | **Deploy node_exporter** — system CPU/RAM/disk/network metrics       | 1 hr   | SigNoz has zero data               |
| 2   | **Deploy cAdvisor** — Docker container metrics                       | 1 hr   | Can't see container resource usage |
| 3   | **Configure OTel scraping** — point SigNoz collector at exporters    | 1 hr   | Connect data producers to SigNoz   |
| 4   | **Build SigNoz system dashboard** — CPU, RAM, disk, network overview | 2 hr   | Visualize what exporters send      |

### P1 — High

| #   | Task                                                              | Effort | Why                                    |
| --- | ----------------------------------------------------------------- | ------ | -------------------------------------- |
| 5   | **SigNoz alert rules** — service down, disk >90%, CPU sustained   | 2 hr   | No notification when things break      |
| 6   | **Notification channel** — Telegram/webhook for SigNoz alerts     | 1 hr   | Alerts useless if nobody receives them |
| 7   | **Journald → OTel logs** — centralize all service logs            | 2 hr   | Currently ssh + journalctl per service |
| 8   | **Instrument Caddy metrics** — HTTP rates, latencies, errors      | 1 hr   | Reverse proxy observability            |
| 9   | **Instrument Authelia metrics** — already exposes :9959           | 30 min | SSO health visibility                  |
| 10  | **SigNoz service dashboard** — per-service health, uptime, errors | 2 hr   | Service-specific visualization         |

### P2 — Medium

| #   | Task                                                            | Effort | Why                              |
| --- | --------------------------------------------------------------- | ------ | -------------------------------- |
| 11  | **DNS blocker /metrics** — blocked query rates, top domains     | 1 hr   | DNS blocking observability       |
| 12  | **GPU monitoring** — ROCm/amdgpu metrics to SigNoz              | 1 hr   | GPU critical for AI/ML           |
| 13  | **Automated backup verification** — weekly restore test         | 1 hr   | Untested backups are not backups |
| 14  | **Niri non-kitty app restore** — improve respawn logic          | 2 hr   | Currently skips many apps        |
| 15  | **macOS monitoring parity** — ActivityWatch + system metrics    | 2 hr   | macOS has no observability       |
| 16  | **Flake lock auto-update** — weekly GitHub Actions PR           | 1 hr   | Security updates shouldn't wait  |
| 17  | **emeet-pixyd /metrics endpoint** — camera state, call duration | 1 hr   | Production observability         |

### P3 — Nice To Have

| #   | Task                                                           | Effort | Why                          |
| --- | -------------------------------------------------------------- | ------ | ---------------------------- |
| 18  | **Native Whisper NixOS package** — replace Docker              | 4 hr   | Cleaner, faster startup      |
| 19  | **Grafana Pyroscope** — continuous profiling for Go services   | 2 hr   | Performance debugging        |
| 20  | **emeet-pixyd CI tests** — run `_test.go` in GitHub Actions    | 1 hr   | Catch regressions            |
| 21  | **Homepage health widgets** — live status per service          | 30 min | Visual health at a glance    |
| 22  | **Daily health check timer** — systemd timer for `just health` | 30 min | Proactive issue detection    |
| 23  | **Docs cleanup** — archive old status reports                  | 2 hr   | 50+ status files, many stale |
| 24  | **Secret rotation automation** — auto-rotate SOPS keys         | 2 hr   | Security hygiene             |
| 25  | **Network diagram auto-generation** — Mermaid from Nix config  | 3 hr   | Docs drift from reality      |

---

## G) Top #1 Question I Cannot Answer

**What should the SigNoz data pipeline architecture look like?**

SigNoz is running but I'm uncertain about the best approach for feeding it data in a NixOS context:

1. **Prometheus-style exporters** (node_exporter, cAdvisor) → SigNoz OTel collector scrapes them via `prometheus` receiver?
2. **OTel-native agents** — deploy OpenTelemetry Collector agents on each machine that push to SigNoz?
3. **Both** — exporters for system metrics, OTel SDK instrumentation for apps?

The SigNoz collector config (`modules/nixos/services/signoz.nix`) currently only has an OTLP receiver. To scrape Prometheus exporters, I'd need to add a `prometheus` receiver to the collector config. But I'm not sure if SigNoz's forked collector supports this the same way, or if a separate OTel Collector instance would be better.

---

## Service Inventory Summary

| Category                | Count | Status          |
| ----------------------- | ----- | --------------- |
| NixOS service modules   | 14    | All operational |
| Custom packages         | 10    | All building    |
| Cross-platform programs | 15    | All configured  |
| DNS blocklists          | 25    | 2.5M+ domains   |
| SOPS-managed secrets    | ~12   | All decrypted   |
| Caddy virtual hosts     | 10    | All with TLS    |
| Flake inputs            | 18    | Up to date      |
| Total Nix files         | 87    | ~10,316 lines   |
