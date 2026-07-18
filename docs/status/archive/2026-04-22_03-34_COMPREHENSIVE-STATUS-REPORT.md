# SystemNix — Comprehensive Status Report

**Date:** 2026-04-22 03:34
**Host:** evo-x2 (NixOS 26.05 / Linux 7.0.0)
**Uptime:** 24 minutes (booted at 03:09 after crash)
**Report Type:** Post-Crash Incident + Full System Health Assessment
**Reporter:** Crush AI Agent

---

## Executive Summary

The system experienced **two crashes in rapid succession** tonight (02:37 and 03:09). The first was a software-triggered reboot via `systemd-logind` following a `sudo` session close. The second was a hard reset with no journal shutdown sequence — potentially hardware-related. The system is now running with **multiple services in failure loops**. 58 commits have been made in the last 48 hours. The Hermes declarative module has been deployed but the service is failing. Several other services need attention.

---

## System State

### Hardware & Resources

| Metric   | Value                                       | Status                       |
| -------- | ------------------------------------------- | ---------------------------- |
| CPU      | AMD RYZEN AI MAX+ 395 w/ Radeon 8060S       | OK                           |
| RAM      | 62 GiB total, 25 GiB used, 36 GiB available | OK                           |
| Swap     | 41 GiB total, 9.2 GiB used, 32 GiB free     | HIGH (9.2G swap used!)       |
| Load     | 5.40 / 7.22 / 5.17                          | Elevated (only 24min uptime) |
| Root (/) | 512G total, 402G used (81%)                 | WARNING                      |
| /data    | 800G total, 522G used (66%)                 | OK                           |
| /boot    | 2.0G total, 270M used (14%)                 | OK                           |

### Boot History (Last 5)

| Boot | Start        | End          | Duration | Notes                            |
| ---- | ------------ | ------------ | -------- | -------------------------------- |
| -4   | Apr 21 21:13 | 21:21        | 8 min    | Short                            |
| -3   | Apr 21 21:21 | 22:01        | 39 min   | Marked "crash"                   |
| -2   | Apr 21 22:01 | Apr 22 02:37 | 4h36m    | Logind-triggered reboot          |
| -1   | Apr 22 02:38 | 03:09        | 31 min   | Hard reset (no journal shutdown) |
| 0    | Apr 22 03:09 | running      | 24 min   | Current                          |

---

## Crash Incident Analysis (Tonight)

### Crash #1 — 02:37 (Boot -2)

- **Type:** Orderly reboot triggered by `systemd-logind`
- **Sequence:**
  1. `waybar` hit `fatal error: newosproc` (Go runtime thread creation failure) at 02:25
  2. `earlyoom` deactivated and restarted at 02:33
  3. `signoz` restart loop — `listen tcp 0.0.0.0:8080: bind: address already in use`
  4. `sudo` session closed at 02:37:32
  5. `systemd-logind: "The system will reboot now!"` at 02:37:34
  6. Clean shutdown sequence completed at 02:37:51
- **Verdict:** Software-triggered, likely by `just switch` or `nixos-rebuild`
- **Root cause candidates:** Config activation requiring reboot, or manual reboot command

### Crash #2 — 03:09 (Boot -1)

- **Type:** Hard reset — NO shutdown sequence in journal
- **Sequence:**
  1. Journal shows normal service operations up to 03:09:00
  2. Journal ends abruptly — no `Shutting down`, no `SIGTERM`, no `Reached target`
  3. New kernel boot at 03:09:51
- **Verdict:** Unknown — possible hardware reset, power loss, or manual hard reset
- **Evidence for hardware/power:** Abrupt journal termination with no software trigger
- **Evidence against OOM:** `earlyoom` reported 74% memory available, swap at 64% free

### Additional Error Context (Both Boots)

- `hermes-gateway` watchdog timeout + Python core dump (SIGABRT in epoll_wait)
- `awww-daemon` panic at `wayland.rs:60:14` — Wayland connection failure, coredump
- `unsloth-studio` continuous restart loop (exit code 1)
- `signoz` restart loop — port 8080 address already in use (port conflict)
- `signoz-provision` repeatedly killed by SIGTERM (every ~16s)
- `amdxdna` kernel errors: `SVA bind device failed, ret -19` (NPU driver issue)
- `timeshift-wrap` segfault in libc.so.6
- Docker container `f0845d09abde` (Twenty CRM?): `python3: can't open file '/app/python'` every 30s

---

## Service Status

### Currently Failing (Boot 0)

| Service                         | State            | Details                                                    |
| ------------------------------- | ---------------- | ---------------------------------------------------------- |
| `signoz.service`                | **Restart loop** | Port 8080 address conflict — restart counter at 111+       |
| `signoz-provision.service`      | **Restart loop** | Killed by SIGTERM every ~16s (orphaned by signoz restarts) |
| `unsloth-studio.service`        | **Restart loop** | Exit code 1, counter at 154+                               |
| `hermes-gateway.service`        | **Failing**      | Exit code 1, repeatedly restarting                         |
| `awww-daemon.service`           | **Core dumping** | Rust panic at wayland.rs:60, repeatedly coredumping        |
| `awww-wallpaper.service`        | **Failed**       | Signal kill                                                |
| `dnsblockd-cert-import.service` | **Failed**       | Exit code 1 (likely timing — certs not ready yet)          |
| `service-health-check.service`  | **Failed**       | "Failed to start Check critical services"                  |
| Docker container (Twenty?)      | **Failing**      | `python3: can't open file '/app/python'` every 30s         |

### Running OK (Partial List)

| Service               | Notes                                      |
| --------------------- | ------------------------------------------ |
| Caddy (reverse proxy) | Serving TLS                                |
| Immich (photos)       | Healthy                                    |
| Gitea                 | Running (GitHub sync failing — auth issue) |
| Photomap              | Healthy                                    |
| Docker/Podman stack   | Running                                    |
| Unbound (DNS)         | Running with blocklists                    |
| Ollama                | Running                                    |
| PostgreSQL            | Running                                    |
| Networking            | Static IP, firewall active                 |

---

## Git & Codebase Status

### Repository

- **Branch:** master (up to date with origin)
- **Working tree:** Clean (no uncommitted changes)
- **Stashes:** 3 (likely stale — emeet-pixyd vendorHash, line endings, Hyprland window rules)
- **Commits this month:** 404
- **Commits last 48h:** 58

### Last 5 Commits

```
4144b42 feat(nixos): soften systemd service dependencies and refine target activation
cd6aba0 feat(nixos/dns-blocker): enhance dnsblockd systemd service reliability
aa2df5f feat(nixos/waybar): display seconds in clock module time format
474f5e3 refactor(nixos): unify module placeholder syntax, reorder oomd kill preference
0e148fd feat(nixos): update GPU memory config, hermes env parsing, and xdg helium entry
```

### Service Modules (19 total)

`authelia`, `caddy`, `default` (Docker), `gitea`, `gitea-repos`, `hermes`, `homepage`, `immich`, `minecraft`, `monitor365`, `photomap`, `signoz`, `sops`, `taskchampion`, `twenty`, `voice-agents`

---

## Work Categories

### A) FULLY DONE

1. **Hermes declarative NixOS module** — Fully coded, committed, integrated as flake-parts module with sops secrets, HM user service, and proper lifecycle management
2. **SigNoz observability pipeline** — Full stack: node_exporter, cAdvisor, journald ingestion, 7 alert rules, GPU metrics, dashboards
3. **EMEET PIXY webcam daemon** — Go daemon with HID control, call detection, auto-management, Waybar integration, systemd watchdog, comprehensive tests
4. **DNS blocker stack** — Unbound + dnsblockd + dnsblockd-processor, 2.5M+ domains blocked
5. **Niri session save/restore** — Crash-recovery system for window/workspace restoration
6. **Taskwarrior + TaskChampion sync** — Cross-platform sync with deterministic client IDs
7. **Monitor365 integration** — Device monitoring agent as flake input
8. **Minecraft server module** — Custom package with JVM tuning
9. **Catppuccin Mocha theme** — Universal across all apps
10. **AGENTS.md documentation** — Comprehensive agent guide with architecture, commands, gotchas
11. **Go overlay** — Go 1.26.1 pinned on both platforms
12. **Status report archive** — 28+ status reports in docs/status/

### B) PARTIALLY DONE

1. **Hermes gateway** — Module deployed but service is **failing on boot**. Needs debugging. Discord bot status unknown.
2. **SigNoz JWT secret** — `SIGNOZ_TOKENIZER_JWT_SECRET` not set (critical security issue logged every restart)
3. **Gitea GitHub sync** — Running but failing auth (`terminal prompts disabled`) — token issue
4. **awww-daemon** — Installed but crashes on Wayland connect, core dumping repeatedly
5. **Unsloth Studio** — Service defined but never successfully runs, exit code 1
6. **Twenty CRM** — Container running but `python3: can't open file '/app/python'` every 30s
7. **Voice agents module** — Present but status unknown
8. **sops-nix ordering** — No explicit `After=` dependency for services depending on sops-rendered secrets

### C) NOT STARTED (From Previous Reports)

1. **Hermes config.yaml declarative** — `~/.hermes/config.yaml` unmanaged by Nix
2. **Hermes SigNoz monitoring** — No alert rules, no log ingestion, no dashboard for Hermes
3. **Hermes healthcheck endpoint** — Unknown if `/health` exists, not wired into systemd
4. **Flake.lock staleness alerting** — No automated alert when flake inputs age out
5. **Darwin build validation** — Not tested recently
6. **Rollback documentation** — No recovery procedures documented per-service
7. **Status report pruning** — 28+ reports accumulating, no archive strategy beyond `archive/` dir
8. **EMEET PIXY CSP hardening** — Still using `unsafe-eval` for htmx

### D) TOTALLY FUCKED UP

1. **System stability** — 5 boots in ~6 hours (21:13 to 03:09), including 2 crashes tonight. Something is wrong.
2. **signoz restart loop** — 111+ restarts in 24 minutes. Port 8080 conflict. Completely broken.
3. **signoz-provision** — Orphaned by signoz restarts, killed every 16 seconds. Pure waste.
4. **hermes-gateway** — Failed after declarative deployment. Not operational.
5. **awww-daemon** — Core dumping on every start. Wayland connect panic. Completely broken.
6. **unsloth-studio** — 154+ restart attempts, never succeeds. Definition of insanity.
7. **Docker container (Twenty?)** — `python3: can't open file '/app/python'` every 30s. Image broken or misconfigured.
8. **9.2 GiB swap usage** — Excessive for 62 GiB RAM system. Possible memory leak.
9. **Root filesystem at 81%** — 402G used of 512G. Needs attention.
10. **3 stale git stashes** — Should be cleaned up.

### E) WHAT WE SHOULD IMPROVE

1. **Service health gating** — Services in infinite restart loops should have max restart limits with notification, not infinite retry
2. **Boot stability** — 5 reboots in 6 hours is unacceptable. Need crash detection + root cause analysis pipeline
3. **Port conflict prevention** — SigNoz on 8080 conflicts should be caught at build time, not runtime
4. **Secret management** — SigNoz JWT secret not set; Hermes sops ordering; secrets should be validated at activate time
5. **Resource monitoring** — 9.2G swap usage on a 62G system is a red flag; no alert configured
6. **Disk space alerting** — Root at 81% with no alert
7. **Container health checks** — Twenty CRM container failing silently with no alert
8. **Service dependency ordering** — SigNoz provision depends on SigNoz but gets orphaned on every restart
9. **NPU driver stability** — `amdxdna` SVA bind errors recurring; NPU unusable
10. **Test coverage** — Most NixOS modules have zero automated tests
11. **Documentation freshness** — AGENTS.md is from Apr 4, many changes since
12. **Stash hygiene** — 3 stale stashes should be evaluated and dropped
13. **Observability coverage** — Hermes, awww-daemon, unsloth-studio have zero SigNoz coverage
14. **Config drift detection** — No mechanism to detect when runtime config diverges from declared config

---

## F) Top 25 Next Actions

| #   | Priority | Action                                                                                 | Effort |
| --- | -------- | -------------------------------------------------------------------------------------- | ------ |
| 1   | **P0**   | **Fix signoz port 8080 conflict** — identify what's holding the port, resolve conflict | Low    |
| 2   | **P0**   | **Debug hermes-gateway failure** — check logs, fix startup, verify Discord bot         | Medium |
| 3   | **P0**   | **Set SIGNOZ_TOKENIZER_JWT_SECRET** — sops-managed secret for SigNoz JWT               | Low    |
| 4   | **P0**   | **Fix or disable awww-daemon** — either fix Wayland connect or mask the service        | Low    |
| 5   | **P0**   | **Fix or disable unsloth-studio** — stop the 154-restart insanity                      | Low    |
| 6   | **P0**   | **Fix Twenty CRM container** — `/app/python` missing, image broken or config wrong     | Medium |
| 7   | **P1**   | **Investigate 9.2G swap usage** — find what's consuming memory/swap on 62G system      | Medium |
| 8   | **P1**   | **Investigate crash #2 (03:09)** — determine if hardware or software; run stress tests | Medium |
| 9   | **P1**   | **Add restart limits to failing services** — `StartLimitBurst`/`StartLimitIntervalSec` | Low    |
| 10  | **P1**   | **Fix Gitea GitHub sync auth** — token expired or misconfigured                        | Low    |
| 11  | **P1**   | **Clean up root filesystem** — 402G/512G used, find and remove large files             | Medium |
| 12  | **P1**   | **Add Hermes SigNoz monitoring** — journald ingestion, alert rules, dashboard          | Medium |
| 13  | **P2**   | **Add disk space alerting** — SigNoz alert for root >85%                               | Low    |
| 14  | **P2**   | **Add swap usage alerting** — SigNoz alert for swap >5G                                | Low    |
| 15  | **P2**   | **Make Hermes config.yaml declarative** — managed by Home Manager                      | Medium |
| 16  | **P2**   | **Fix amdxdna NPU driver** — SVA bind failure, ret -19                                 | Hard   |
| 17  | **P2**   | **Clean up 3 stale git stashes**                                                       | Low    |
| 18  | **P2**   | **Update AGENTS.md** — document all recent changes                                     | Medium |
| 19  | **P2**   | **Add sops ordering dependencies** — `After=` for services needing sops secrets        | Low    |
| 20  | **P3**   | **Validate darwin build** — ensure macOS config still builds                           | Low    |
| 21  | **P3**   | **Prune old status reports** — archive or delete >28 reports                           | Low    |
| 21  | **P3**   | **Add service-level rollback docs** — per-service recovery procedures                  | Medium |
| 23  | **P3**   | **Flake.lock staleness alerting** — automated check for aged inputs                    | Medium |
| 24  | **P3**   | **Harden EMEET PIXY CSP** — remove `unsafe-eval` for htmx                              | Medium |
| 25  | **P3**   | **Add NixOS module tests** — at least smoke tests for critical services                | High   |

---

## G) Top #1 Question I Cannot Answer Myself

**What triggered the 02:37 reboot?** The journal shows a `sudo` session closing at 02:37:32, then `systemd-logind` declaring reboot at 02:37:34. The system had plenty of memory (74% available), no kernel panic, no OOM. This pattern strongly suggests a `just switch` or `systemctl reboot` was run intentionally. **Did you run `just switch` at 02:37, or was this an automated reboot?** If it wasn't you, something is triggering reboots without clear attribution — and that's the #1 thing to figure out before the system is stable.

---

## Files Changed This Session

- `docs/status/2026-04-22_03-34_COMPREHENSIVE-STATUS-REPORT.md` (this file)

---

## Appendix: Service Module Inventory

| Module       | Path                                      | Status                |
| ------------ | ----------------------------------------- | --------------------- |
| Authelia     | `modules/nixos/services/authelia.nix`     | Unknown               |
| Caddy        | `modules/nixos/services/caddy.nix`        | Running               |
| Docker       | `modules/nixos/services/default.nix`      | Running               |
| Gitea        | `modules/nixos/services/gitea.nix`        | Running (sync broken) |
| Hermes       | `modules/nixos/services/hermes.nix`       | **Failing**           |
| Homepage     | `modules/nixos/services/homepage.nix`     | Running               |
| Immich       | `modules/nixos/services/immich.nix`       | Running               |
| Minecraft    | `modules/nixos/services/minecraft.nix`    | Unknown               |
| Monitor365   | `modules/nixos/services/monitor365.nix`   | Unknown               |
| Photomap     | `modules/nixos/services/photomap.nix`     | Running               |
| SigNoz       | `modules/nixos/services/signoz.nix`       | **Restart loop**      |
| Sops         | `modules/nixos/services/sops.nix`         | Running               |
| TaskChampion | `modules/nixos/services/taskchampion.nix` | Running               |
| Twenty       | `modules/nixos/services/twenty.nix`       | **Container broken**  |
| Voice Agents | `modules/nixos/services/voice-agents.nix` | Unknown               |
