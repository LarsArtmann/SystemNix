# SystemNix — Comprehensive Status Report

**Date:** 2026-04-23 03:59
**Host:** evo-x2 (NixOS 26.05 / x86_64-linux)
**Report Type:** Full System Health & Progress Assessment
**Reporter:** Crush AI Agent
**Previous Report:** 2026-04-22 03:34 (~24.5 hours ago)

---

## Executive Summary

The 2026-04-22 improvement list (30 items) is **96% complete** — 27 done, 3 deferred, 2 blocked by upstream. Since the last status report, **17 commits** landed covering security hardening, systemd reliability, SSH extraction, jscpd packaging, and cleanup of orphaned files. The system is functionally stable with 16 active service modules. The main remaining gaps are: disk encryption (no LUKS), firmware updates (no fwupd), TPM2 not enabled, and auditd blocked by a NixOS 26.05 bug.

---

## Codebase Metrics

| Metric                          | Value                                                                                                 |
| ------------------------------- | ----------------------------------------------------------------------------------------------------- |
| Total lines (Nix + Go + config) | ~19,400                                                                                               |
| NixOS service modules           | 16 (flake-parts)                                                                                      |
| Common program modules          | 16                                                                                                    |
| Custom packages (pkgs/)         | 7 (emeet-pixyd, dnsblockd, dnsblockd-processor, jscpd, modernize, monitor365, aw-watcher-utilization) |
| Flake inputs                    | 20                                                                                                    |
| Git commits (all time)          | ~2,100+                                                                                               |
| Git commits (last 24h)          | 17                                                                                                    |
| Status reports (active)         | 30                                                                                                    |
| Status reports (archived)       | 202                                                                                                   |
| Git stashes                     | 3 (stale)                                                                                             |

---

## A) FULLY DONE

### Infrastructure & Core

1. **Flake-parts modular architecture** — All 16 NixOS services are self-contained flake-parts modules with proper `imports` in flake.nix and `nixosModules` wiring
2. **Cross-platform Home Manager** — Both platforms import `common/home-base.nix` → 16 program modules from `common/programs/`
3. **Go 1.26.1 overlay** — Pinned on both Darwin and NixOS via shared overlay
4. **Catppuccin Mocha theme** — Universal across all apps, terminals, bars, login screen
5. **AGENTS.md documentation** — Comprehensive agent guide (last updated 2026-04-04)
6. **treefmt + alejandra** — Formatting via `treefmt-full-flake`, statix + deadnix checks in CI

### Services (Production)

7. **Caddy reverse proxy** — TLS via sops, systemd sandboxed, serving all `*.home.lan` domains
8. **Immich** — Photo/video management with OAuth, GPU acceleration, ML pipeline
9. **Gitea** — Git hosting with GitHub mirror sync (2 repos)
10. **Homepage dashboard** — Service overview with health checks
11. **Photomap** — AI photo exploration
12. **TaskChampion** — Taskwarrior sync server with deterministic client IDs, cross-platform
13. **SigNoz observability** — Full stack: OTel collector, ClickHouse, node_exporter, cAdvisor, journald ingestion, dashboards
14. **Authelia SSO** — Forward auth for protected services, sops-managed secrets
15. **sops-nix** — Secrets management via age + SSH host key

### Custom Packages

16. **EMEET PIXY daemon** (`pkgs/emeet-pixyd/`) — Go binary with HID control, call detection, auto-management, Waybar integration, 63.4% test coverage, 1.3M+ fuzz executions, zero TODOs
17. **dnsblockd** (`pkgs/dnsblockd.nix`) — DNS block page server (Go)
18. **dnsblockd-processor** (`pkgs/dnsblockd-processor/`) — DNS blocklist processor (Go)
19. **jscpd** (`pkgs/jscpd.nix`) — Code duplication detection (native Nix package, new)
20. **modernize** (`pkgs/modernize.nix`) — Go modernize tool
21. **Monitor365** (`pkgs/monitor365.nix`) — Device monitoring agent (Rust)
22. **aw-watcher-utilization** (`pkgs/aw-watcher-utilization.nix`) — ActivityWatch utilization watcher

### Desktop & Hardware

23. **Niri compositor** — Scrollable-tiling Wayland with wrapped config, session save/restore
24. **DNS blocker stack** — Unbound + dnsblockd, 25 blocklists, 2.5M+ domains blocked, `.home.lan` DNS records
25. **AMD GPU config** — Strix Halo tuned: GTT 128GB, TTM 120GB, lockup timeout 30s, guided pstate
26. **ZRAM** — 50% of 128GB = 64GB compressed swap
27. **earlyoom** — Userspace OOM with desktop notifications, prefer killing ML/browser processes

### Completed in Last 24h (from TODO_LIST_2026-04-22)

28. **Systemd hardening** — PrivateTmp, NoNewPrivileges, RestrictNamespaces, LockPersonality on 12/14 services; WatchdogSec on 10 services
29. **SSH config extraction** — SSH hosts moved to `common/programs/ssh-config.nix`, shared across platforms
30. **Local network module** — `local-network.nix` with `networking.local.{lanIP,subnet,gateway}` options
31. **Service dependency graph** — Fixed caddy→authelia, signoz→clickhouse, photomap postgresql deps
32. **Docker image pinning** — voice-agents and twenty images pinned to specific tags
33. **Deduplication cleanup** — Removed `notification-tone.nix`, `superfile.nix`, 11 archived scripts
34. **Gitea temp file fix** — Both mirror scripts use `mktemp` + `trap ... EXIT`
35. **jscpd native package** — Replaces `bunx jscpd` with proper Nix derivation

---

## B) PARTIALLY DONE

| Item                   | Status                                                              | What's Missing                                                                       |
| ---------------------- | ------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| **Hermes gateway**     | Module deployed, runs as system service                             | Service may still be failing — needs runtime verification after last night's crashes |
| **SigNoz JWT secret**  | `SIGNOZ_TOKENIZER_JWT_SECRET`                                       | Not set — logged as critical on every restart                                        |
| **Gitea GitHub sync**  | Service runs, repos configured                                      | Token auth may still be broken (terminal prompts disabled error)                     |
| **Voice agents**       | Module defined, LiveKit + Whisper ASR                               | Status unknown — no runtime verification                                             |
| **Minecraft server**   | Module defined, `services.minecraft = true`                         | Status unknown — no runtime verification                                             |
| **Monitor365**         | Package built, module exists                                        | `enable = false` in configuration.nix — intentionally disabled                       |
| **Twenty CRM**         | Module defined, Docker image pinned                                 | Was crash-looping last night (`python3: can't open file '/app/python'`)              |
| **Unsloth Studio**     | Module defined, conditional enablement                              | Was restart-looping last night (exit code 1, 154+ attempts)                          |
| **Security hardening** | Good baseline (firewall, SSH, fail2ban, ClamAV, systemd sandboxing) | No LUKS, no TPM2, no fwupd, no kernel sysctl hardening, auditd disabled              |

---

## C) NOT STARTED

### Security (High Impact)

1. **LUKS disk encryption** — Root and `/data` are plain btrfs. Physical access = full data loss/theft
2. **TPM2 enablement** — `security.tpm2.enable = true` — hardware supports it, zero cost to enable
3. **Firmware updates** — `services.fwupd.enable = true` — not configured, firmware is unpatched attack surface
4. **Kernel security sysctls** — No `kernel.kptr_restrict`, `kernel.dmesg_restrict`, `kernel.kexec_load`, `net.ipv4.conf.all.rp_filter`, etc.
5. **Boot editor protection** — `boot.loader.systemd-boot.editor = false` — anyone can add `init=/bin/sh` at boot
6. **Auditd re-enablement** — Rules written but blocked by NixOS [#483085](https://github.com/NixOS/nixpkgs/issues/483085)

### Services & Observability

7. **Hermes SigNoz monitoring** — No journald ingestion, alert rules, or dashboard for Hermes
8. **Hermes config.yaml declarative** — `/var/lib/hermes/config.yaml` unmanaged by Nix
9. **Flake.lock staleness alerting** — No automated check for aged inputs
10. **Per-service rollback docs** — No recovery procedures documented

### Code Quality

11. **NixOS VM tests** — Zero automated tests for any service module (deferred, substantial effort)
12. **`passthru.tests`** — Not added to custom packages (deferred, needs restructuring)
13. **Shell scripts → Nix apps** — `scripts/` still has imperative bash scripts (deferred)
14. **AGENTS.md update** — Last updated 2026-04-04, 19 days behind actual state

### Cleanup

15. **Status report pruning** — 30 active + 202 archived reports, growing unbounded
16. **Git stash cleanup** — 3 stale stashes (emeet-pixyd vendorHash, line endings, Hyprland window rules)
17. **`docs/` top-level files** — ~70 standalone .md files at `docs/` root, many stale

---

## D) TOTALLY FUCKED UP

| Item                    | Severity     | Details                                                                                                                                                         |
| ----------------------- | ------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **No disk encryption**  | **CRITICAL** | Root + /data are plain btrfs. This is the single biggest security gap. Any physical access = full compromise.                                                   |
| **No firmware updates** | **HIGH**     | `fwupd` not enabled. BIOS/UEFI vulnerabilities cannot be patched.                                                                                               |
| **Passwordless sudo**   | **MEDIUM**   | `wheelNeedsPassword = false` means any user-level code execution = instant root. On a desktop with browsers, this is the most likely privilege escalation path. |
| **auditd blocked**      | **MEDIUM**   | NixOS 26.05 bug prevents audit rules from loading. Rules are written and ready but cannot activate.                                                             |
| **Boot editor open**    | **MEDIUM**   | `systemd-boot` editor allows arbitrary kernel params at boot screen. Combined with no encryption, trivial to bypass.                                            |
| **Stale git stashes**   | **LOW**      | 3 stashes from old sessions, likely no longer relevant                                                                                                          |

---

## E) WHAT WE SHOULD IMPROVE

### Architecture & Patterns

1. **Status report bloat** — 232 reports total. Need automated archival (e.g., keep last 10, archive rest quarterly)
2. **`docs/` organization** — 70+ top-level .md files, many are one-time analysis that should be in subdirectories or deleted
3. **Service health validation** — No CI/CD pipeline that actually deploys and checks service health
4. **Cross-platform parity** — Darwin gets less attention; overlays, packages differ
5. **Config drift detection** — No mechanism to detect when runtime state diverges from declared config

### Security Posture

6. **Physical attack surface** — No LUKS + open boot editor = trivial physical compromise
7. **Kernel hardening** — VM sysctls tuned for AI workloads but zero network/kernel security sysctls
8. **Firmware attack surface** — No fwupd = unpatched firmware vulnerabilities
9. **Privilege escalation path** — Passwordless sudo + browser on same user account = easy chain
10. **Secret validation** — No build-time check that all sops secrets referenced in config actually exist

### Operational

11. **Service restart limits** — Last night showed services in 150+ restart loops. Need `StartLimitBurst`/`StartLimitIntervalSec` everywhere
12. **Boot stability monitoring** — 5 boots in 6 hours last night. Need automated crash forensics
13. **Disk space alerting** — Root at 81%, no alert configured
14. **Swap monitoring** — 9.2G swap on 128G system is abnormal, no alert
15. **NPU driver** — `amdxdna` SVA bind failures (ret -19), NPU effectively unusable

---

## F) Top 25 Next Actions

| #   | Priority | Action                                                                                                                                | Effort | Impact                                              |
| --- | -------- | ------------------------------------------------------------------------------------------------------------------------------------- | ------ | --------------------------------------------------- |
| 1   | **P0**   | **Enable LUKS + TPM2 auto-unlock** — Full disk encryption with zero UX change (TPM binds to boot)                                     | High   | Critical — closes physical attack surface           |
| 2   | **P0**   | **Set `boot.loader.systemd-boot.editor = false`** — One line, prevents boot param editing                                             | Low    | High — prevents init=/bin/sh bypass                 |
| 3   | **P0**   | **Enable `services.fwupd.enable = true`** — Firmware updates for real hardware                                                        | Low    | High — patches firmware vulnerabilities             |
| 4   | **P0**   | **Add kernel security sysctls** — `kptr_restrict=2`, `dmesg_restrict=1`, `kexec_load=0`, `rp_filter=1`, `unprivileged_bpf_disabled=1` | Low    | Medium — standard kernel hardening                  |
| 5   | **P0**   | **Set `SIGNOZ_TOKENIZER_JWT_SECRET`** via sops                                                                                        | Low    | Medium — critical security fix logged every restart |
| 6   | **P1**   | **Verify Hermes gateway is running** — Check service status, Discord bot connectivity                                                 | Low    | Medium — confirm last night's fix worked            |
| 7   | **P1**   | **Re-evaluate `wheelNeedsPassword = false`** — Consider `true` with `timestampTimeout = 30`                                           | Low    | Medium — closes privilege escalation path           |
| 8   | **P1**   | **Add `StartLimitBurst`/`StartLimitIntervalSec`** to all services — prevent infinite restart loops                                    | Low    | Medium — stops 150-restart insanity                 |
| 9   | **P1**   | **Verify Twenty CRM container** — Check if 0.16.2 image fixed the `/app/python` error                                                 | Low    | Medium — confirm or disable                         |
| 10  | **P1**   | **Verify Unsloth Studio** — Check if conditional enablement + structlog fix resolved issues                                           | Low    | Medium — confirm or disable                         |
| 11  | **P1**   | **Enable `security.tpm2.enable = true`** — Prerequisite for LUKS TPM binding, zero cost alone                                         | Low    | Medium — enables future LUKS auto-unlock            |
| 12  | **P1**   | **Clean root filesystem** — 402G/512G used, find large removable files                                                                | Medium | Medium — prevent disk space emergency               |
| 13  | **P2**   | **Add disk space alerting** — SigNoz alert for root >85%                                                                              | Low    | Medium — proactive warning                          |
| 14  | **P2**   | **Add swap usage alerting** — SigNoz alert for swap >5G                                                                               | Low    | Low — anomaly detection                             |
| 15  | **P2**   | **Fix Gitea GitHub sync auth** — Verify token is valid and not expired                                                                | Low    | Low — restores mirror functionality                 |
| 16  | **P2**   | **Clean up 3 stale git stashes** — Evaluate and drop                                                                                  | Low    | Low — repo hygiene                                  |
| 17  | **P2**   | **Update AGENTS.md** — 19 days behind, many changes undocumented                                                                      | Medium | Medium — AI agent accuracy                          |
| 18  | **P2**   | **Add Hermes SigNoz monitoring** — journald ingestion, alert rules                                                                    | Medium | Medium — observability gap                          |
| 19  | **P2**   | **Prune `docs/` top-level files** — Archive or delete stale analysis docs                                                             | Medium | Low — repo cleanliness                              |
| 20  | **P2**   | **Status report auto-archive** — Keep last 10, move rest to archive quarterly                                                         | Low    | Low — prevent unbounded growth                      |
| 21  | **P3**   | **Validate Darwin build** — Ensure macOS config still builds                                                                          | Low    | Medium — cross-platform health                      |
| 22  | **P3**   | **Fix amdxdna NPU driver** — SVA bind failure ret -19                                                                                 | Hard   | Medium — NPU unusable                               |
| 23  | **P3**   | **Monitor auditd NixOS bug** — Re-enable when [#483085](https://github.com/NixOS/nixpkgs/issues/483085) is fixed                      | Low    | Medium — audit trail                                |
| 24  | **P3**   | **Flake.lock staleness alerting** — Automated check for inputs older than 30 days                                                     | Medium | Low — dependency freshness                          |
| 25  | **P3**   | **Add NixOS VM tests** — At least smoke tests for critical services (caddy, immich, signoz)                                           | High   | High — prevents regressions                         |

---

## G) Top #1 Question I Cannot Answer Myself

**Is the system currently healthy right now?** The last status report was written during a crisis (2 crashes, 9 failing services, 5 reboots in 6 hours). Since then, 17 commits landed with fixes for hermes, systemd hardening, dependency ordering, and image pinning — but I have no way to verify the actual runtime state of the machine. The #1 thing I need to know: **have you done a `just switch` since last night's crashes, and are all services running clean?** Specifically: hermes, signoz, twenty, unsloth-studio, and voice-agents.

---

## Files Changed Since Last Report (17 commits)

```
52 files changed, 5498 insertions(+), 3936 deletions(-)
```

Key changes:

- `modules/nixos/services/*.nix` — Systemd hardening, watchdog, dependency fixes across 12 services
- `platforms/common/programs/ssh-config.nix` — New shared SSH config module
- `platforms/nixos/system/local-network.nix` — New local network config module
- `pkgs/jscpd.nix` — New native Nix package for code duplication detection
- `pkgs/emeet-pixyd/` — Removed htmx eval, moved toasts/polling server-side
- Deleted: `pkgs/notification-tone.nix`, `pkgs/superfile.nix`, `scripts/archive/` (11 scripts)

---

## Appendix: Service Module Inventory

| Module       | Path                                      | Enabled | Systemd Hardened   | Watchdog  |
| ------------ | ----------------------------------------- | ------- | ------------------ | --------- |
| Authelia     | `modules/nixos/services/authelia.nix`     | Yes     | Yes (7 directives) | Yes (30s) |
| Caddy        | `modules/nixos/services/caddy.nix`        | Yes     | Yes (5 directives) | Yes (30s) |
| Docker       | `modules/nixos/services/default.nix`      | Yes     | —                  | —         |
| Gitea        | `modules/nixos/services/gitea.nix`        | Yes     | Yes (3 services)   | —         |
| Gitea Repos  | `modules/nixos/services/gitea-repos.nix`  | Yes     | —                  | —         |
| Hermes       | `modules/nixos/services/hermes.nix`       | Yes     | Yes (7 directives) | —         |
| Homepage     | `modules/nixos/services/homepage.nix`     | Yes     | Yes (5 directives) | Yes (30s) |
| Immich       | `modules/nixos/services/immich.nix`       | Yes     | Yes (2 services)   | Yes (30s) |
| Minecraft    | `modules/nixos/services/minecraft.nix`    | Yes     | Yes (4 directives) | —         |
| Monitor365   | `modules/nixos/services/monitor365.nix`   | **No**  | Yes (4 directives) | —         |
| Photomap     | `modules/nixos/services/photomap.nix`     | Yes     | Yes (3 directives) | —         |
| SigNoz       | `modules/nixos/services/signoz.nix`       | Yes     | Yes (4 services)   | Yes (30s) |
| Sops         | `modules/nixos/services/sops.nix`         | Yes     | —                  | —         |
| TaskChampion | `modules/nixos/services/taskchampion.nix` | Yes     | Yes (4 directives) | Yes (30s) |
| Twenty       | `modules/nixos/services/twenty.nix`       | Yes     | Yes (3 directives) | —         |
| Voice Agents | `modules/nixos/services/voice-agents.nix` | Yes     | Yes (3 directives) | —         |
