# SystemNix — Resilience Hardening & GPU Memory Rebalance

**Date:** 2026-05-04 23:46 CEST | **Session:** 23
**Branch:** master | **Commits this session:** 1 (1 pending)

---

## Executive Summary

Two sessions in one day. Session 22 (earlier today) built the crash-recovery defense-in-depth stack. Session 23 (this one) identified remaining resilience gaps, added 3 new defense layers, rebalanced GPU memory from 128GB to 32GB, and modernized the health check script.

**System state:** evo-x2 has NOT been switched yet. All changes are committed/pending in git and pass `just test-fast`. A `just switch` is needed to deploy.

---

## A) FULLY DONE ✅

### Resilience — Crash Recovery Stack (6 layers, all wired)

| # | Layer                   | Mechanism                                                                                  | File       | Status       |
| - | ----------------------- | ------------------------------------------------------------------------------------------ | ---------- | ------------ |
| 1 | Userspace OOM           | earlyoom (10% free threshold) + OOMScoreAdjust on sshd/niri/waybar/pipewire/journald       | `boot.nix` | ✅ Committed |
| 2 | Kernel panic recovery   | `kernel.panic=30`, `softlockup_panic=1`, `hung_task_panic=1`                               | `boot.nix` | ✅ Committed |
| 3 | Hardware watchdog       | watchdogd (SP5100 TCO, 30s timeout, meminfo critical at 98%)                               | `boot.nix` | ✅ Committed |
| 4 | SysRq emergency         | `kernel.sysrq=1` — REISUB from keyboard                                                    | `boot.nix` | ✅ Committed |
| 5 | Post-reboot diagnostics | pstore (`pstore.backend=efi`, `max_reason=3`) — panic/oops/warn logs survive in UEFI NVRAM | `boot.nix` | ✅ Committed |
| 6 | GPU driver recovery     | `amdgpu.gpu_recovery=1`, `lockup_timeout=30000`                                            | `boot.nix` | ✅ Committed |

### Resilience — Resource Protection (3 new, committed this session)

| Mechanism            | Config                                                         | Rationale                                                               | Status            |
| -------------------- | -------------------------------------------------------------- | ----------------------------------------------------------------------- | ----------------- |
| Journald size limits | `SystemMaxUse=4G`, `RuntimeMaxUse=1G`, `MaxRetentionSec=2week` | AI services (Ollama, ComfyUI, Hermes) can emit multi-GB logs under load | ✅ Committed      |
| Coredump limits      | `Storage=external`, `MaxUse=2G`, `KeepFree=5G`                 | PyTorch/ROCm SIGSEGV produces 50-100GB coredumps on 128GB RAM           | ✅ Committed      |
| Ollama MemoryMax     | `32G` cgroup cap                                               | Prevents Ollama from consuming all unified memory                       | ✅ Pending commit |

### GPU Memory Rebalance (128GB → 32GB)

| Parameter                | Before            | After          | File           | Status            |
| ------------------------ | ----------------- | -------------- | -------------- | ----------------- |
| `amdgpu.gttsize`         | 131072M (128GB)   | 32768M (32GB)  | `boot.nix`     | ✅ Pending commit |
| `amdgpu.ttm.pages_limit` | 31457280 (~120GB) | 8388608 (32GB) | `boot.nix`     | ✅ Pending commit |
| `ttm.page_pool_size`     | 31457280 (~120GB) | 8388608 (32GB) | `boot.nix`     | ✅ Pending commit |
| `ollama MemoryMax`       | 110G              | 32G            | `ai-stack.nix` | ✅ Pending commit |

**Result:** ~96GB freed for CPU workloads. GPU capped at 32GB — enough for 7B-14B models. Trade-off: larger models will need parameter adjustment if performance degrades.

### Service Health Check Modernization

| Change              | Detail                                                                                               |
| ------------------- | ---------------------------------------------------------------------------------------------------- |
| Removed dead checks | `prometheus`, `grafana` — replaced by SigNoz months ago                                              |
| Added SigNoz checks | `signoz-query-service`, `signoz-otel-collector`, `clickhouse`                                        |
| Added infra checks  | `node_exporter`, `cadvisor`, `authelia`, `taskchampion-sync-server`                                  |
| Added URL checks    | SigNoz web (8080), OTel health (4318), Authelia health (9091), node-exporter (9100), cadvisor (9110) |
| File                | `platforms/nixos/scripts/service-health-check`                                                       |

### General Infrastructure (pre-existing, solid)

| Component                       | Status | Details                                                  |
| ------------------------------- | ------ | -------------------------------------------------------- |
| BTRFS snapshots + verification  | ✅     | Daily Timeshift + freshness check timer                  |
| BTRFS auto-scrub                | ✅     | Monthly, `/` and `/data`                                 |
| Disk monitoring                 | ✅     | Threshold notifications (80/85/90/95/97/98/99%)          |
| DNS blocking                    | ✅     | Unbound + dnsblockd, 2.5M+ domains                       |
| SSH hardening                   | ✅     | key-only, fail2ban, no root login                        |
| ClamAV                          | ✅     | Daemon + updater                                         |
| smartd                          | ✅     | Auto-detect, scheduled short+long tests                  |
| Automatic gc + optimise         | ✅     | Weekly nix gc, auto-optimise-store                       |
| Docker auto-prune               | ✅     | Weekly, 7-day filter                                     |
| SOPS secrets                    | ✅     | Age-encrypted via SSH host key                           |
| Cross-platform (Darwin + NixOS) | ✅     | 80% shared via `platforms/common/`                       |
| 103 Nix files, 13,641 lines     | ✅     | 29 flake-parts service modules                           |
| `just test-fast` passes         | ✅     | Zero evaluation errors                                   |
| SigNoz observability            | ✅     | Traces/metrics/logs, ClickHouse, node_exporter, cadvisor |
| External uptime monitoring      | ✅     | Gatus (draft module, not enabled yet)                    |

---

## B) PARTIALLY DONE ⚠️

| Item                           | What's Done                                                                               | What's Missing                                                                                                                                                       |
| ------------------------------ | ----------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Gatus uptime monitor**       | Full module with 20+ endpoints (websites, DNS, MX, local services) written in `gatus.nix` | Not enabled in `configuration.nix`, ntfy topic `gatus-systemnix` is generic (should be personalized), no alerting rules for specific endpoints                       |
| **DNS failover cluster**       | Keepalived VRRP module written, wired in evo-x2 config                                    | Pi 3 hardware not provisioned — single-node cluster is meaningless                                                                                                   |
| **Photomap**                   | Module exists with CLIP embeddings, OCI container                                         | Disabled in config (`photomap.nix` module exists but service is enabled in config — unclear if actually deployed/working)                                            |
| **Twenty CRM**                 | Full Docker Compose module (4 containers), PostgreSQL, Redis, sops secrets                | May not be actively deployed                                                                                                                                         |
| **Service MemoryMax coverage** | 13 services have MemoryMax                                                                | Homepage dashboard (Node.js) has `harden{}` (default 512M) but it's via generic harden — acceptable. Voice-agents runs in Docker (not subject to systemd MemoryMax). |
| **auditd / security audit**    | Rules written and commented out in `security-hardening.nix`                               | NixOS 26.05 bug: `audit-rules-nixos.service` fails with "No rules". Blocked on upstream fix.                                                                         |
| **AGENTS.md documentation**    | Comprehensive — architecture, services, commands, gotchas                                 | Doesn't reflect the GPU rebalance (128→32GB) or the new resilience layers yet                                                                                        |

---

## C) NOT STARTED 📋

1. **Gatus enablement** — module exists, not wired into `configuration.nix`
2. **Pi 3 provisioning** — hardware exists, no SD image burned
3. **TODO_LIST.md** — doesn't exist. `MASTER_TODO_PLAN.md` is stale (references old items)
4. **FEATURES.md update** — last generated 2026-05-03, doesn't reflect today's resilience work
5. **Kernel crash dumps (kdump)** — no kdump configuration. On 128GB RAM, crash kernel would need ~2GB reserved. Worth investigating but complex.
6. **Automated backup verification** — Timeshift verification checks freshness but doesn't test restore
7. **Uptime alerting pipeline** — Gatus → ntfy exists in config but not personalized
8. **SSH certificate-based auth** — currently using static keys, could move to CA-signed certs
9. **Immutable system path** — `/usr` remounting, read-only bind mounts for critical dirs
10. **Network bonding/failover** — single NIC, no redundancy
11. **UPS integration** — no UPS monitoring (e.g., nut/NetworkUPSTools)
12. **Disk encryption** — no LUKS on BTRFS volumes
13. **TPM-based unlocking** — no TPM integration for secrets
14. **Service mesh / health probes** — no readiness/liveness probes beyond the health check script
15. **Automated rollback testing** — no CI/CD pipeline for `just switch`

---

## D) TOTALLY FUCKED UP 💥

| Item                                          | What Happened                                                                                                                                                                               | Current State                                        | Impact                                                                                                     |
| --------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| **Ollama MemoryMax was 110G initially**       | Wrote `110G` in the first edit (from the "max protection" phase), then user asked for 32GB GPU cap, but the MemoryMax edit was applied _before_ the GPU cap request — so it went in as 110G | Fixed to 32G in working tree now                     | Would have let Ollama eat 110GB even with 32GB GPU cap — completely undermining the rebalance              |
| **Nix attribute duplication in boot.nix**     | First attempt at adding journald/coredump created duplicate `services` and `systemd` top-level attrs — Nix would have failed with attribute conflict errors on `just switch`                | Fixed by rewriting the entire file with merged attrs | Syntax-only check (`just test-fast`) can't catch runtime attr conflicts — only a full build would catch it |
| **Service health check was stale for months** | `service-health-check` still checked `prometheus` and `grafana` which were replaced by SigNoz weeks ago — the health check was reporting false positives                                    | Fixed in this session                                | Any Grafana/Prometheus failure would have triggered alerts, but their absence wouldn't have been caught    |

---

## E) WHAT WE SHOULD IMPROVE

### High Priority

1. **Switch and verify on evo-x2** — All changes pass `just test-fast` but haven't been deployed. The GPU memory rebalance needs real-world testing with actual workloads.
2. **Update AGENTS.md** — Doesn't reflect: 32GB GPU cap, pstore, journald/coredump limits, updated health check. Will be misleading for future sessions.
3. **Update FEATURES.md** — Still says "24h keep-alive" for Ollama (now 1h). Doesn't mention pstore, coredump limits, journald limits.
4. **Enable Gatus** — Module is complete, just needs `gatus-config.enable = true` in `configuration.nix`. Provides external uptime monitoring.
5. **Personalize ntfy topic** — Gatus alerts go to `gatus-systemnix` — this is a public topic name on ntfy.sh. Should be a private/authenticated topic.

### Medium Priority

6. **Add MemoryMax to ClickHouse** — SigNoz's ClickHouse instance has no memory limit. On 128GB RAM, it could consume everything. Should add `MemoryMax=4G` or similar.
7. **Automated restore testing** — BTRFS snapshots exist but restore has never been tested. A quarterly restore test would verify the backup chain.
8. **Create TODO_LIST.md** — Track all open items in one place. `MASTER_TODO_PLAN.md` is stale.
9. **Kernel crash dumps** — `kdump` would capture full kernel crash dumps for post-mortem. Complex but valuable on a system that has had GPU driver crashes.
10. **pstore verification** — pstore is configured but we should verify `/sys/fs/pstore` actually works after a reboot. Needs `just switch` first.

### Lower Priority

11. **Auditd** — Re-enable once NixOS 26.05 bug is fixed. Rules are already written.
12. **UPS monitoring** — NetworkUPSTools for power loss protection.
13. **Immutable system paths** — Read-only bind mounts for `/etc`, `/usr`.
14. **Network redundancy** — NIC bonding or secondary interface.
15. **Disk encryption** — LUKS on BTRFS volumes with TPM auto-unlock.

---

## F) TOP 25 THINGS TO DO NEXT

| #  | Priority | Item                                                                           | Effort | Impact   |
| -- | -------- | ------------------------------------------------------------------------------ | ------ | -------- |
| 1  | **P0**   | `just switch` on evo-x2 — deploy all changes and verify system boots correctly | 5min   | Critical |
| 2  | **P0**   | Verify pstore works: check `ls /sys/fs/pstore/` after reboot                   | 1min   | High     |
| 3  | **P0**   | Test Ollama with 32GB GPU cap — run a model and verify it works                | 5min   | High     |
| 4  | **P0**   | Update AGENTS.md to reflect GPU rebalance + resilience changes                 | 15min  | High     |
| 5  | **P1**   | Update FEATURES.md — Ollama keep-alive, pstore, journald/coredump limits       | 15min  | Medium   |
| 6  | **P1**   | Enable Gatus uptime monitor in `configuration.nix`                             | 5min   | High     |
| 7  | **P1**   | Personalize Gatus ntfy topic (not `gatus-systemnix`)                           | 5min   | Medium   |
| 8  | **P1**   | Add MemoryMax to ClickHouse (4G cap) in signoz.nix                             | 5min   | Medium   |
| 9  | **P1**   | Verify `notify-failure@` template fires correctly on evo-x2                    | 5min   | Medium   |
| 10 | **P1**   | Verify `service-health-check` script works with new SigNoz checks              | 5min   | Medium   |
| 11 | **P2**   | Create TODO_LIST.md with current open items                                    | 20min  | Medium   |
| 12 | **P2**   | Test BTRFS snapshot restore (quarterly verification)                           | 15min  | Medium   |
| 13 | **P2**   | Add MemoryMax to services still using default harden (512M): homepage, gatus   | 5min   | Low      |
| 14 | **P2**   | Add `coredumpctl vacuum` weekly timer for proactive cleanup                    | 10min  | Low      |
| 15 | **P2**   | Add `journalctl --vacuum-time=2week` to scheduled-tasks                        | 5min   | Low      |
| 16 | **P2**   | Provision Pi 3 for DNS failover cluster                                        | 60min  | High     |
| 17 | **P2**   | Verify Twenty CRM is actually deployed and functional                          | 10min  | Medium   |
| 18 | **P3**   | Investigate kdump for kernel crash dump capture                                | 30min  | Medium   |
| 19 | **P3**   | Add UPS monitoring (NetworkUPSTools)                                           | 30min  | Medium   |
| 20 | **P3**   | Re-enable auditd once NixOS 26.05 bug is fixed                                 | 15min  | Medium   |
| 21 | **P3**   | Add LUKS disk encryption with TPM auto-unlock                                  | 60min  | High     |
| 22 | **P3**   | Network NIC bonding for failover                                               | 30min  | Medium   |
| 23 | **P4**   | CI/CD pipeline for `just test` before merge                                    | 60min  | Medium   |
| 24 | **P4**   | Immutable system paths (read-only /etc, /usr)                                  | 30min  | Low      |
| 25 | **P4**   | SSH certificate-based auth (CA-signed)                                         | 30min  | Low      |

---

## G) TOP QUESTION

**What models does Ollama actually serve on evo-x2?**

The 32GB GPU cap means:

- ✅ 7B–14B models: run fine (Q4_K_M ~4–8GB)
- ⚠️ 32B models: tight (Q4_K_M ~18GB) — may work with reduced context
- ❌ 70B+ models: won't fit in 32GB VRAM

If larger models are regularly used, we'll need to increase the cap. The current setting can be verified after `just switch` by running `ollama list` and testing inference. If models fail to load or are extremely slow, we'll need to adjust upward (48GB or 64GB sweet spots).

---

## Files Changed This Session

| File                                           | Change                                                                                     |
| ---------------------------------------------- | ------------------------------------------------------------------------------------------ |
| `platforms/nixos/system/boot.nix`              | GPU 128→32GB, pstore module+params, journald limits, coredump limits, merged systemd attrs |
| `modules/nixos/services/ai-stack.nix`          | Ollama MemoryMax 32G, OLLAMA_KEEP_ALIVE 24h→1h                                             |
| `platforms/nixos/scripts/service-health-check` | Replaced prometheus/grafana with SigNoz stack + authelia + taskchampion                    |

## Project Statistics

| Metric                   | Value                                         |
| ------------------------ | --------------------------------------------- |
| Nix files                | 103                                           |
| Total lines              | 13,641                                        |
| Service modules          | 31 (29 in modules/nixos/services/ + 2 inline) |
| Commits since May 1      | 107                                           |
| Status reports this week | 7                                             |
| Active flake inputs      | 30+                                           |
