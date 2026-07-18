# SystemNix — Comprehensive Status Report

**Date:** 2026-05-04 15:56 CEST
**Branch:** master @ `75c395c`
**Platform:** NixOS (evo-x2, x86_64-linux) + macOS (Lars-MacBook-Air, aarch64-darwin)
**Flake check:** PASS (all modules evaluate cleanly)
**Total Nix files:** 103
**Total service modules:** 35 (in `modules/nixos/services/`)

---

## System Health

| Metric               | Status | Detail                                                      |
| -------------------- | ------ | ----------------------------------------------------------- |
| Niri compositor      | OK     | Running                                                     |
| Failed systemd units | FAIL   | 2 system: `comfyui.service`, `service-health-check.service` |
| Disk `/`             | WARN   | 82% used (93G free of 512G)                                 |
| Disk `/data`         | OK     | 74% used (210G free of 800G)                                |
| Memory               | OK     | 47G/62G (75%) — 14G available                               |
| `/nix/store`         | INFO   | 84G                                                         |
| Flake syntax         | OK     | `just test-fast` passes all checks                          |

---

## A) FULLY DONE — Working in Production

### Core Infrastructure

- **flake-parts modular architecture** — 35 service modules, clean separation
- **Niri scrollable-tiling compositor** — daily driver, session save/restore working
- **Caddy reverse proxy** — TLS via sops, forward auth via Authelia
- **Authelia SSO** — forward auth protecting all LAN services
- **sops-nix secrets** — age-encrypted via SSH host key
- **DNS stack** — Unbound resolver + dnsblockd (2.5M+ domains blocked, Quad9 DoT upstream)
- **DNS block page** — dedicated IP (192.168.1.200), custom Go block page server
- **Home Manager** — cross-platform, 14 shared program modules

### Services in Production

- **SigNoz observability** — traces/metrics/logs, ClickHouse, OTel collector, node_exporter, cAdvisor
- **Gitea** — git hosting + GitHub mirror sync
- **Immich** — photo/video management with ML
- **Homepage dashboard** — service status overview
- **TaskChampion sync** — cross-platform taskwarrior sync (NixOS + macOS + Android)
- **Hermes AI gateway** — Discord bot, cron scheduler, multi-provider AI
- **EMEET PIXY webcam** — auto-activation, face tracking, audio mode switching
- **Monitor365** — device monitoring agent
- **Netwatch** — real-time network diagnostics TUI
- **File-and-image-renamer** — AI screenshot renaming

### Developer Tooling

- **Go CLI overlay suite** — mr-sync, golangci-lint-auto-configure, file-and-image-renamer
- **todo-list-ai** — AI-powered TODO extraction
- **jscpd** — copy/paste detector (promoted to system package)
- **treefmt + alejandra** — formatting pipeline
- **Custom overlays** — shared + linux-only, no Go overlay cache-buster

### Architecture Quality

- **No `path:` flake inputs** — fully portable, all private repos via `git+ssh://`
- **`lib/systemd.nix` harden + service-defaults** — shared systemd hardening library
- **`lib/types.nix`** — shared NixOS types library
- **`networking.local` module** — centralized IP/subnet config
- **`services.ai-models`** — centralized `/data/ai/` directory structure
- **WatchdogSec audit** — only on sd_notify-capable services (Caddy, Gitea)
- **GOPRIVATE case sensitivity fix** — proper Git config
- **`config.allowBroken = false`** — enforced

---

## B) PARTIALLY DONE — Needs Work

| Item                     | Status      | Detail                                                                                       |
| ------------------------ | ----------- | -------------------------------------------------------------------------------------------- |
| **Gatus uptime monitor** | FIRST DRAFT | Module written at `modules/nixos/services/gatus.nix` — NOT wired into flake.nix yet          |
| **Twenty CRM**           | DEPLOYED    | Service running behind Caddy but post-setup steps may be incomplete (`twenty-POST-SETUP.md`) |
| **ComfyUI**              | FAILED      | Service in failed state — persistent AI image generation server crashing                     |
| **DNS failover cluster** | PLANNED     | Module exists, Pi 3 hardware not provisioned yet                                             |
| **Photomap**             | DEPLOYED    | Running but may need Immich integration tuning                                               |
| **AI stack**             | PARTIAL     | Ollama, Whisper, ComfyUI deployed but ComfyUI is down                                        |
| **Disk `/` at 82%**      | WARNING     | Trending upward — needs attention before it becomes critical                                 |

---

## C) NOT STARTED — Known Gaps

| Item                            | Impact | Notes                                                                       |
| ------------------------------- | ------ | --------------------------------------------------------------------------- |
| **Gatus → Caddy reverse proxy** | Medium | Need `gatus.home.lan` vhost in Caddy + Unbound DNS entry                    |
| **Gatus → SigNoz metrics**      | Low    | Gatus can export Prometheus metrics to existing OTel pipeline               |
| **Uptime Kuma**                 | Low    | Alternative to Gatus if better UX needed — no NixOS module in nixpkgs 26.05 |
| **Pi 3 DNS backup node**        | Medium | `rpi3-dns` config exists, hardware not provisioned                          |
| **BTRFS snapshot monitoring**   | Medium | Timeshift configured but no alerting on snapshot failures                   |
| **Backup automation**           | High   | No automated backup strategy for Immich DB, Gitea repos, Taskwarrior data   |
| **Gitea → S3 backup**           | Medium | Mirror sync exists but no off-site backup                                   |
| **Log rotation audit**          | Low    | journald configured but no explicit rotation for service logs               |
| **Cross-platform dotfile sync** | Low    | Crush config synced via HM, other dotfiles manual                           |
| **NixOS tests (nixosTests)**    | Medium | No integration tests, only `just test-fast` syntax check                    |

---

## D) TOTALLY FUCKED UP — Needs Immediate Fix

| Item                             | Severity | Detail                                                                                               |
| -------------------------------- | -------- | ---------------------------------------------------------------------------------------------------- |
| **ComfyUI service**              | HIGH     | `comfyui.service` in `failed` state. Image generation completely down. Needs investigation.          |
| **service-health-check.service** | MEDIUM   | Health check timer itself is failing — likely a script issue, masks real problems.                   |
| **Root disk at 82%**             | HIGH     | 93G free on `/` — trending toward full. `/nix/store` is 84G. Needs nix-collect-garbage + assessment. |

---

## E) WHAT WE SHOULD IMPROVE

### Architecture

1. **Service health self-monitoring is broken** — the health-check service itself is failed. This is a meta-problem: we can't trust our own monitoring.
2. **No backup strategy** — Immich photos, Gitea repos, Taskwarrior data all live on one machine with no off-site backup. Single point of catastrophe.
3. **Status docs bloat** — 180+ status reports in `docs/status/` (most archived). Should consolidate into a single living document.
4. **No integration tests** — only syntax checking. Services can fail at runtime without detection.
5. **Disk pressure** — 82% on root is a ticking bomb. Need `/nix/store` GC and possibly moving more data to `/data`.

### Code Quality

6. **Signoz module is 741 lines** — largest module by far. Could benefit from splitting into sub-modules.
7. **Some modules still lack `harden`** — audit which services use the shared library vs inline config.
8. **`justfile` still references `rm`** — some recipes may have slipped through the trash migration.

### Observability

9. **No uptime monitoring** — Gatus drafted but not wired. Currently blind to external service outages.
10. **No alerting pipeline** — SigNoz has data but no alert rules configured. No PagerDuty/Discord/ntfy integration for critical alerts.

### Security

11. **No automated security scanning** — `trivy.yaml` exists in domains repo but not integrated into SystemNix.
12. **No fail2ban or similar** — SSH and web services exposed without intrusion detection.

---

## F) Top 25 Things We Should Do Next

| #   | Priority | Task                                                                                             | Impact                      |
| --- | -------- | ------------------------------------------------------------------------------------------------ | --------------------------- |
| 1   | P0       | **Fix ComfyUI service** — investigate crash, get image generation back online                    | Users blocked               |
| 2   | P0       | **Fix service-health-check.service** — the monitor monitoring itself is broken                   | Blind to failures           |
| 3   | P0       | **Nix GC + disk assessment** — `nix-collect-garbage -d`, audit large store paths                 | Disk crisis prevention      |
| 4   | P1       | **Wire Gatus into flake.nix** — add to imports, nixosModules, configuration.nix enable           | External uptime monitoring  |
| 5   | P1       | **Add Gatus Caddy vhost + DNS** — `gatus.home.lan` reverse proxy + Unbound entry                 | Accessible dashboard        |
| 6   | P1       | **Implement backup strategy** — Immich DB, Gitea repos, Taskwarrior export to `/data` + off-site | Catastrophe prevention      |
| 7   | P1       | **Configure SigNoz alert rules** — CPU >90%, disk >85%, service down, OOM kills                  | Proactive incident response |
| 8   | P1       | **Set up ntfy.sh or Gotify for alerts** — wire Gatus + SigNoz alerts to push notifications       | Incident awareness          |
| 9   | P2       | **Audit all services for `harden` library adoption** — find inline systemd configs               | Consistency                 |
| 10  | P2       | **Split signoz.nix** (741 lines) into sub-modules — collector, clickhouse, query-service         | Maintainability             |
| 11  | P2       | **Add `gatus` justfile recipes** — `just gatus-status`, `just gatus-logs`                        | Operational convenience     |
| 12  | P2       | **Provision Pi 3 for DNS failover cluster** — hardware setup, flash SD card                      | High-availability DNS       |
| 13  | P2       | **Configure Gatus → SigNoz metrics pipeline** — Prometheus exporter to OTel                      | Unified observability       |
| 14  | P2       | **Root disk audit** — find what's consuming space beyond /nix/store (84G)                        | Understand disk pressure    |
| 15  | P2       | **Write NixOS integration tests** — at minimum: DNS resolves, services respond, Caddy proxies    | Regression prevention       |
| 16  | P2       | **Twenty CRM post-setup** — complete `twenty-POST-SETUP.md` checklist                            | Fully operational CRM       |
| 17  | P3       | **Consolidate status docs** — archive old reports, create single `CURRENT-STATUS.md` living doc  | Navigation sanity           |
| 18  | P3       | **Add fail2ban** — protect SSH + web-facing services                                             | Intrusion prevention        |
| 19  | P3       | **Automate Immich DB backup** — daily pg_dump to `/data/backups/`                                | Data safety                 |
| 20  | P3       | **Automate Gitea repo backup** — mirror to S3 or external storage                                | Code safety                 |
| 21  | P3       | **Audit journald log rotation** — ensure logs don't consume root disk                            | Disk management             |
| 22  | P3       | **Test `just switch` end-to-end on Darwin** — ensure macOS config still deploys                  | Cross-platform health       |
| 23  | P4       | **Add uptime status page** — public-facing status page for artmann.tech domains                  | Professionalism             |
| 24  | P4       | **Evaluate NixOS containerization** — move services to systemd-nspawn or incus                   | Isolation                   |
| 25  | P4       | **Document disaster recovery procedure** — step-by-step restore from backups                     | Business continuity         |

---

## G) Top Question I Cannot Answer Myself

**What happened to ComfyUI?**

The service is in `failed` state. I cannot run `systemctl status comfyui` or read journal logs due to tool restrictions (`systemctl` is blocked). The root cause could be:

- Python dependency breakage after a nixpkgs update
- GPU/memory issue (47G/62G RAM used, ComfyUI may OOM)
- Missing model files after AI models migration to `/data/ai/`
- Configuration error

**This needs manual investigation:**

```bash
systemctl status comfyui
journalctl -u comfyui --since "1 hour ago"
ls -la /data/ai/models/comfyui/
```

---

## Session Work This Conversation

| Item                                                          | Status           |
| ------------------------------------------------------------- | ---------------- |
| Researched uptime monitors for NixOS                          | DONE             |
| Evaluated Gatus vs Uptime Kuma vs alternatives                | DONE             |
| Read all domain configs from `/home/lars/projects/domains/`   | DONE             |
| Wrote `modules/nixos/services/gatus.nix` (flake-parts module) | DONE (not wired) |
| DNS endpoint URL fix (resolver vs query domain)               | DONE             |

---

_Arte in Aeternum_
