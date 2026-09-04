# SystemNix: Comprehensive Status Report

**Date:** 2026-04-10 07:32
**Report Type:** Full Comprehensive Audit
**Previous Major Audit:** 2026-04-05 (5 days ago)
**Commits Since Last Audit:** 24
**Total Commits:** 1,539
**Working Tree:** Clean
**Branch:** master (up to date with origin)

---

## Executive Summary

SystemNix is a **mature, production-grade** cross-platform Nix configuration managing 2 machines (NixOS desktop + macOS laptop) through a single flake with ~80% shared configuration. The project has stabilized significantly over the past 2 months with 85 `.nix` files, 10 infrastructure services, 20 flake inputs, and a 1,828-line justfile providing 100+ commands.

**Current state: Stable but with known security debt.** The red team security assessment (2026-04-09) revealed 4 CRITICAL and 5 HIGH findings that need remediation. No Taskwarrior sync, no AI agent task integration, and several security hardening items remain incomplete.

---

## a) FULLY DONE ✅

### Cross-Platform Shared (17 modules in `platforms/common/`)

| Module                        | Status | Notes                                          |
| ----------------------------- | ------ | ---------------------------------------------- |
| `home-base.nix`               | ✅     | Central HM config importing 14 program modules |
| `core/nix-settings.nix`       | ✅     | Nix daemon settings (both platforms)           |
| `environment/variables.nix`   | ✅     | GOPATH, GOPRIVATE, session vars                |
| `preferences.nix`             | ✅     | Shared preferences                             |
| `packages/base.nix`           | ✅     | 70+ packages (Essential, Dev, AI, GUI)         |
| `packages/fonts.nix`          | ✅     | Cross-platform font management                 |
| `programs/fish.nix`           | ✅     | Fish shell config                              |
| `programs/zsh.nix`            | ✅     | Zsh config                                     |
| `programs/bash.nix`           | ✅     | Bash config                                    |
| `programs/nushell.nix`        | ✅     | Nushell config                                 |
| `programs/starship.nix`       | ✅     | Prompt with Catppuccin, 50+ modules configured |
| `programs/git.nix`            | ✅     | Git config with aliases, delta, lfs            |
| `programs/tmux.nix`           | ✅     | Tmux with Catppuccin theme                     |
| `programs/fzf.nix`            | ✅     | Fuzzy finder config                            |
| `programs/pre-commit.nix`     | ✅     | Pre-commit hooks                               |
| `programs/keepassxc.nix`      | ✅     | Password manager config                        |
| `programs/chromium.nix`       | ✅     | Browser with extensions, Catppuccin            |
| `programs/activitywatch.nix`  | ✅     | Time tracking (fixed theme API)                |
| `programs/shell-aliases.nix`  | ✅     | Shared aliases for all shells                  |
| `programs/ublock-filters.nix` | ⚠️      | Installed but **disabled** (time parsing bug)  |

### macOS / Darwin (10 modules)

| Module                      | Status | Notes                                      |
| --------------------------- | ------ | ------------------------------------------ |
| `default.nix`               | ✅     | System config (nix-darwin + HM + Homebrew) |
| `home.nix`                  | ✅     | HM config importing common/home-base.nix   |
| `environment.nix`           | ✅     | Darwin environment                         |
| `nix/settings.nix`          | ✅     | Nix settings (sandbox disabled for macOS)  |
| `system/settings.nix`       | ✅     | macOS system preferences                   |
| `system/activation.nix`     | ✅     | Post-activation scripts                    |
| `services/launchagents.nix` | ✅     | ActivityWatch + Crush update agents        |
| `programs/chrome.nix`       | ✅     | Chrome preferences                         |
| `programs/shells.nix`       | ✅     | Darwin shell aliases (darwin-rebuild)      |
| `security/keychain.nix`     | ✅     | macOS Keychain integration                 |
| `security/pam.nix`          | ✅     | PAM configuration                          |
| `networking/default.nix`    | ✅     | Networking (Wake-on-LAN disabled)          |

### NixOS Desktop (15+ modules)

| Module                           | Status | Notes                                        |
| -------------------------------- | ------ | -------------------------------------------- |
| `desktop/niri-config.nix`        | ✅     | Scrollable-tiling Wayland compositor         |
| `desktop/waybar.nix`             | ✅     | Status bar (Catppuccin Mocha)                |
| `desktop/display-manager.nix`    | ✅     | SDDM with silent-sddm theme                  |
| `desktop/audio.nix`              | ✅     | PipeWire + WirePlumber                       |
| `desktop/ai-stack.nix`           | ✅     | Ollama (optimized for multi-agent)           |
| `desktop/monitoring.nix`         | ✅     | System monitoring tools                      |
| `desktop/multi-wm.nix`           | ✅     | Multi-window-manager support                 |
| `desktop/security-hardening.nix` | ⚠️      | Partially done — auditd disabled (NixOS bug) |
| `programs/rofi.nix`              | ✅     | Launcher with Catppuccin grid theme          |
| `programs/swaylock.nix`          | ✅     | Screen locker with blur                      |
| `programs/wlogout.nix`           | ✅     | Power menu                                   |
| `programs/zellij.nix`            | ✅     | Terminal multiplexer                         |
| `programs/yazi.nix`              | ✅     | File manager with Catppuccin                 |
| `programs/steam.nix`             | ✅     | Gaming (GameMode + MangoHud)                 |
| `programs/chrome.nix`            | ✅     | Chrome preferences                           |
| `programs/shells.nix`            | ✅     | NixOS shell aliases                          |
| `programs/niri-wrapped.nix`      | ✅     | Niri keybinds via wrapper-modules            |

### NixOS System (7 modules)

| Module                          | Status | Notes                                               |
| ------------------------------- | ------ | --------------------------------------------------- |
| `system/configuration.nix`      | ✅     | Main system entry                                   |
| `system/boot.nix`               | ✅     | systemd-boot, kernel params, ZRAM                   |
| `system/networking.nix`         | ✅     | Static IP, firewall                                 |
| `system/dns-blocker-config.nix` | ✅     | Unbound + 25 blocklists (2.5M+ domains)             |
| `system/snapshots.nix`          | ✅     | BTRFS + Timeshift                                   |
| `system/scheduled-tasks.nix`    | ✅     | Crush provider updates, health checks               |
| `system/sudo.nix`               | ✅     | Sudo configuration (⚠️ passwordless — security risk) |

### NixOS Hardware (4 modules)

| Module                                | Status | Notes                          |
| ------------------------------------- | ------ | ------------------------------ |
| `hardware/amd-gpu.nix`                | ✅     | AMD GPU (Vulkan, ROCm, VAAPI)  |
| `hardware/amd-npu.nix`                | ✅     | AMD XDNA NPU driver            |
| `hardware/bluetooth.nix`              | ✅     | Bluetooth config               |
| `hardware/hardware-configuration.nix` | ✅     | Auto-generated hardware config |

### NixOS Infrastructure Services (10 modules)

| Service     | Status | Port   | Domain            | Notes                              |
| ----------- | ------ | ------ | ----------------- | ---------------------------------- |
| Caddy       | ✅     | 80/443 | —                 | Reverse proxy, TLS via sops        |
| Authelia    | ✅     | 9091   | auth.home.lan     | SSO/forward auth                   |
| Gitea       | ✅     | 3000   | gitea.home.lan    | Git hosting + GitHub mirror        |
| Immich      | ✅     | 2283   | immich.home.lan   | Photo/video management             |
| Homepage    | ✅     | 8082   | dash.home.lan     | Service dashboard                  |
| PhotoMap    | ✅     | 8050   | photomap.home.lan | AI photo exploration               |
| SigNoz      | ✅     | 8080   | signoz.home.lan   | Observability                      |
| SOPS        | ✅     | —      | —                 | Secrets management (age-encrypted) |
| Docker      | ✅     | —      | —                 | Container runtime (on /data)       |
| Gitea Repos | ✅     | —      | —                 | GitHub → Gitea sync                |

### Tooling & DevEx

| Item             | Status | Notes                                                                                |
| ---------------- | ------ | ------------------------------------------------------------------------------------ |
| `flake.nix`      | ✅     | 417 lines, flake-parts, 20 inputs, 4 overlays                                        |
| `justfile`       | ✅     | 1,828 lines, 100+ recipes                                                            |
| `AGENTS.md`      | ✅     | Comprehensive agent guide                                                            |
| Custom packages  | ✅     | dnsblockd, dnsblockd-processor, modernize, aw-watcher-utilization, notification-tone |
| Pre-commit hooks | ✅     | gitleaks, treefmt, deadnix, statix                                                   |
| SSH config       | ✅     | External flake input (nix-ssh-config)                                                |
| Crush config     | ✅     | External flake input (crush-config)                                                  |
| DNS blocker      | ✅     | Unbound + dnsblockd, 25 blocklists, Quad9 DoT                                        |

---

## b) PARTIALLY DONE ⚠️

| Item                    | What's Done                                                                 | What's Missing                                                                                             | Priority    |
| ----------------------- | --------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- | ----------- |
| **Security Hardening**  | Kernel hardening params, AppArmor profile prepared, USBGuard not configured | Auditd disabled (NixOS bug #483085), AppArmor not enabled, IOMMU disabled                                  | P1          |
| **Authelia SSO**        | Running, protecting 6 services via forward auth                             | Password hash in nix config (not sops), OIDC secrets are placeholders                                      | P1-CRITICAL |
| **DNS Blocker**         | Fully functional, 25 blocklists, block page, stats                          | Blocklist hashes need periodic manual updates (3 commits in last week just for hash updates)               | P3          |
| **uBlock Filters**      | Module exists, auto-update logic written                                    | Disabled due to time parsing bug — needs debugging                                                         | P4          |
| **Monitoring**          | SigNoz for traces/metrics/logs, some Prometheus exporters                   | No alerting rules, no runbook, no Grafana dashboards (Prometheus was removed after internet loss incident) | P2          |
| **Ollama**              | Running, optimized for multi-agent workloads                                | No model pre-pulling, no GPU memory limits configured declaratively                                        | P3          |
| **Taskwarrior**         | Package installed (`taskwarrior3` + `timewarrior`)                          | Zero configuration — no `.taskrc`, no sync, no reports, no Android integration                             | P2          |
| **Cross-platform sync** | SSH config synced via flake input, Crush config synced                      | Taskwarrior not synced, no shared clipboard/notifications                                                  | P3          |

---

## c) NOT STARTED ❌

1. **Taskwarrior sync server** — `taskchampion-sync-server` (NixOS module exists in nixpkgs, ready to use)
2. **Taskwarrior Android client** — TaskStrider (Play Store) for TaskChampion sync
3. **Taskwarrior Home Manager config** — `programs.taskwarrior` with reports, themes, UDAs
4. **AI Agent task integration** — Tags, UDAs, and workflow for agents to create/track tasks
5. **Caddy vhost for tasks.home.lan** — Reverse proxy to sync server
6. **Homepage entry for Taskwarrior** — Dashboard link
7. **DNS record for tasks.home.lan** — Unbound local zone entry
8. **Security remediation** — 4 CRITICAL + 5 HIGH findings from red team assessment (21 of 25 items not started)
9. **Alerting infrastructure** — No alerts on service failures, disk space, etc.
10. **Automated blocklist hash updates** — Currently manual, 3 commits/week for hash bumps
11. **Backup verification** — BTRFS snapshots exist but no restore testing documented
12. **Secrets audit** — Authelia secrets should move from nix config to sops
13. **IOMMU enablement** — `amd_iommu=off` in kernel params (security risk for VMs)
14. **Password sudo** — Currently passwordless (wheel group), should require password
15. **Gitea token permissions** — World-readable (644), should be restricted
16. **Git credential security** — Plaintext `store` helper, should use libsecret/keychain
17. **Docker rootless** — Docker group = root equivalent currently
18. **Firewall hardening** — SigNoz ClickHouse/Collector ports unnecessarily open
19. **Steam firewall cleanup** — Unnecessary port openings
20. **Automated dependency updates** — flake.lock updates are manual
21. **Monitoring dashboards** — No Grafana, no custom SigNoz dashboards
22. **Documentation cleanup** — 110 status docs (8.8MB), many outdated
23. **uBlock filter fix** — Time parsing bug blocking auto-updates
24. **NixOS tests** — No automated NixOS VM tests for service modules
25. **Mobile integration** — No task/clipboard/notification sync with Android

---

## d) TOTALLY FUCKED UP 💥

| Item                            | Severity    | Description                                                                                                                                                                          | Status                                |
| ------------------------------- | ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------- |
| **Authelia secrets in git**     | 🔴 CRITICAL | Password hash + OIDC client secret in nix config tracked in git. If repo is public, these are immediately exploitable. Even if private, they're in git history forever.              | Known, not fixed                      |
| **Passwordless sudo**           | 🔴 CRITICAL | Entire wheel group has NOPASSWD. Any process running as `lars` can instantly become root. Combined with browser exploits or malicious code, this is a full system compromise vector. | Known, not fixed                      |
| **IOMMU disabled**              | 🔴 CRITICAL | `amd_iommu=off` in kernel params. Prevents DMA protection, breaks VFIO for VMs, undermines kernel security.                                                                          | Known, not fixed                      |
| **DNS service ordering race**   | 🟡 HIGH     | During `nixos-rebuild switch`, Unbound may restart before Caddy is ready, causing transient DNS resolution failures. Documented but not fixed structurally.                          | Documented, workaround: rebuild again |
| **Prometheus removal incident** | 🟡 HIGH     | Prometheus was removed, caused complete internet loss due to dependency chain. Removed and not replaced — monitoring gap.                                                            | Known, monitoring gap                 |
| **uBlock filter parsing**       | 🟡 MEDIUM   | `programs.ublock-filters.enable = false` due to time parsing issue. Feature exists but is broken.                                                                                    | Disabled, not investigated            |

---

## e) IMPROVEMENTS NEEDED

### Architecture

1. **Consolidate docs/status/** — 110 files (8.8MB) is excessive. Archive everything older than 2 weeks. Keep only the latest comprehensive report + incident reports.
2. **Automate blocklist hash updates** — Create a scheduled task or GitHub Action that updates HaGeZi blocklist hashes and submits a PR. Currently 3 manual commits per week.
3. **Extract more secrets to sops** — Authelia password, OIDC secrets, Gitea tokens should all be in sops-nix.
4. **Add NixOS VM tests** — Even basic smoke tests for service modules would catch regressions before deploy.
5. **Centralize security policy** — Create a security.nix module that aggregates all hardening in one place.

### Workflow

6. **Taskwarrior as single source of truth** — The whole point of today's conversation. Sync across NixOS, macOS, and Android.
7. **AI Agent task protocol** — Standardized way for Crush and other agents to create, update, and query tasks.
8. **Flake.lock auto-updates** — Use GitHub Actions or `nix flake update` on a schedule with auto-PR.
9. **Pre-commit hook for secrets** — gitleaks exists but Authelia secrets are still in nix files. Add a custom rule.
10. **Status report template** — Standardize the format so each report is comparable.

### Infrastructure

11. **Alerting** — SigNoz can alert but no rules are configured. At minimum: disk space, service down, OOM.
12. **Backup verification** — Automated restore test on a timer.
13. **Rate limiting on Caddy** — Protect services from brute force.
14. **Audit logging** — Get auditd working once NixOS bug is resolved.
15. **Rootless Docker** — Remove the docker-group-equals-root risk.

---

## f) TOP 25 THINGS TO DO NEXT

### Priority 1 — Security (Do This Week)

| # | Task                                                                                             | Effort | Impact       |
| - | ------------------------------------------------------------------------------------------------ | ------ | ------------ |
| 1 | **Move Authelia secrets to sops** — Password hash + OIDC secret out of nix config                | 1h     | CRITICAL fix |
| 2 | **Enable password sudo** — Remove NOPASSWD for wheel, require password                           | 30min  | CRITICAL fix |
| 3 | **Enable IOMMU** — Remove `amd_iommu=off` from kernel params, verify boot                        | 15min  | CRITICAL fix |
| 4 | **Fix Gitea token permissions** — `chmod 600` on token file                                      | 5min   | HIGH fix     |
| 5 | **Close SigNoz firewall ports** — Remove ClickHouse (9000) + Collector (4317/4318) from firewall | 10min  | HIGH fix     |
| 6 | **Switch git credential helper to libsecret** — Replace plaintext `store`                        | 30min  | HIGH fix     |
| 7 | **Close Steam firewall ports** — Remove unnecessary openings                                     | 5min   | HIGH fix     |

### Priority 2 — Taskwarrior + AI Integration (This Week)

| #  | Task                                                                                            | Effort | Impact            |
| -- | ----------------------------------------------------------------------------------------------- | ------ | ----------------- |
| 8  | **Enable `taskchampion-sync-server`** — New NixOS service module                                | 2h     | New capability    |
| 9  | **Configure Caddy vhost** — `tasks.home.lan` → sync server                                      | 30min  | Access            |
| 10 | **Add DNS record** — `tasks` to Unbound local zone                                              | 5min   | Resolution        |
| 11 | **Home Manager Taskwarrior config** — Both platforms, reports, Catppuccin theme, sync settings  | 1h     | Usability         |
| 12 | **Define AI Agent task protocol** — Tags (`+agent`), UDAs (`source`, `priority`), workflow docs | 1h     | Agent integration |
| 13 | **Install TaskStrider on Android** — Connect to sync server                                     | 15min  | Mobile access     |
| 14 | **Add Taskwarrior to Homepage** — Dashboard entry                                               | 10min  | Visibility        |

### Priority 3 — Monitoring & Reliability (Next Week)

| #  | Task                                                                  | Effort | Impact                |
| -- | --------------------------------------------------------------------- | ------ | --------------------- |
| 15 | **Configure SigNoz alerts** — Disk space, service down, OOM           | 2h     | Operational safety    |
| 16 | **Fix DNS rebuild race condition** — Add proper service ordering deps | 1h     | Reliability           |
| 17 | **Create monitoring dashboards** — SigNoz or re-add Grafana           | 3h     | Observability         |
| 18 | **Automate blocklist hash updates** — Scheduled task or GitHub Action | 2h     | Maintenance reduction |
| 19 | **Test backup restore** — Verify BTRFS snapshot restore works         | 1h     | Disaster recovery     |

### Priority 4 — Cleanup & Quality (Ongoing)

| #  | Task                                                                        | Effort | Impact                |
| -- | --------------------------------------------------------------------------- | ------ | --------------------- |
| 20 | **Archive old status docs** — Move 90+ files older than 2 weeks to archive/ | 15min  | Repo cleanliness      |
| 21 | **Fix uBlock filter time parsing** — Debug and re-enable                    | 1h     | Feature completion    |
| 22 | **Evaluate rootless Docker** — Test podman or rootless docker               | 3h     | Security              |
| 23 | **Add flake.lock auto-update** — GitHub Action with auto-PR                 | 2h     | Maintenance           |
| 24 | **Write NixOS VM test for dnsblockd** — Smoke test the custom DNS stack     | 2h     | Regression prevention |
| 25 | **Review and update AGENTS.md** — Reflect all changes since 2026-04-04      | 30min  | Agent accuracy        |

---

## g) TOP QUESTION I CANNOT FIGURE OUT MYSELF

**Is this repository public or private?**

The red team security assessment (2026-04-09) identified Authelia password hashes and OIDC client secrets directly in nix files tracked in git. The severity of findings C1 and C2 **depends entirely** on whether this repo is public:

- **If public** → These are immediately exploitable. An attacker can crack the Argon2id hash offline, derive the OIDC secret, and gain SSO access to all protected services.
- **If private** → Still bad practice (secrets in git history, accessible to anyone with repo access) but not an immediate emergency.

I cannot determine this from the codebase alone. The GitHub remote URL would tell me, but I can't access it. **This directly changes the priority order of items 1-2 in the Top 25.**

---

## Key Metrics Summary

| Metric                            | Value                                        |
| --------------------------------- | -------------------------------------------- |
| Total `.nix` files                | 85                                           |
| Total commits                     | 1,539                                        |
| Commits since last audit (5 days) | 24                                           |
| Flake inputs                      | 20+                                          |
| Infrastructure services           | 10                                           |
| Caddy virtual hosts               | 7                                            |
| SOPS secrets                      | 13                                           |
| DNS blocklists                    | 25+ (~2.5M domains)                          |
| Shared program modules            | 14                                           |
| Justfile recipes                  | 100+                                         |
| Status documents                  | 110 (8.8MB)                                  |
| Security findings                 | 4 CRITICAL, 5 HIGH, 8 MEDIUM, 6 LOW          |
| TODOs in codebase                 | 2 (both in security-hardening.nix)           |
| Disabled features                 | 2 (uBlock filters, auditd)                   |
| Platforms                         | 2 (NixOS x86_64-linux, macOS aarch64-darwin) |

---

## Commits Since Last Audit (2026-04-05 → 2026-04-10)

```
af54687 docs(status): add full red team security assessment of NixOS and macOS
12cd7b2 docs: document DNS service ordering race condition during nixos-rebuild
a9144e5 docs: document Immich OAuth 500 error root cause + add notification sound package
55bde81 chore(flake): update flake.lock with package and dependency updates
13f73d6 docs: document wallpaper startup race condition fix
97cda7b docs: add input/clipboard overhaul status report + immich TLS fix + dnsblockd service ordering
b053277 chore: remove Dagger CI/CD integration
92bbed9 feat(nixos): enhance clipboard management with retry logic, JSON tooltips, and improved UI
7f4976f feat(darwin,nixos): enhance input device configuration with tap-drag and trackpad improvements
23980b3 Optimize Ollama for multi-agent coding workloads
1d2a312 feat(nixos,darwin): unify input device configuration with flat acceleration profile
ce97a98 docs(status): add SSH hardening deployment session 13 comprehensive status
89d093f feat(nixos/steam): enhance Steam gaming configuration with additional tools and browser hardening
6859125 fix(nixos/dns-blocker): add hf.co to allowlist to whitelist Hugging Face alias domain
aacf1c7 chore(nixos/dns-blocker): update hash for HaGeZi-ultimate and HaGeZi-tif blocklists
4989a0d chore(nixos): update Authelia password hash to argon2id and refresh HaGeZi blocklist hashes
ccbf893 chore(nixos/dns-blocker): update blocklist hashes for 20 HaGeZi and StevenBlack lists
2f3b403 chore(nixos/niri): remove redundant environment variables from niri-wrapped
9014992 docs: add global gitignore management status report
3048922 fix(linux): update ActivityWatch theme API call and standardize cursor configuration
e2a42e6 feat(linux): add OpenAudible package and improve ActivityWatch window tracking
6e4524f chore(nixos/dns-blocker): simplify wait loops for IP detection and CA cert availability
721da92 chore(nixos): improve systemd service reliability and permission handling across modules
b33aa53 feat(nixos/steam): add GameMode and MangoHud for optimized gaming performance
```
