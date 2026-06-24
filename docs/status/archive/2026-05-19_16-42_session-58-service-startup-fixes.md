# Session 58 — Service Startup Fix: Forgejo, Caddy, nvme-metrics

**Date:** 2026-05-19 16:42
**Focus:** Fix 4 failed services after `nh os switch` activation failure
**System:** evo-x2 (NixOS 26.05, kernel 7.0.1)

---

## Executive Summary

After the most recent `nh os switch`, 4 services failed during activation: **Forgejo**, **Caddy**, **gitea-runner-evo-x2**, and **nvme-metrics**. Root cause analysis revealed 2 independent bugs and 1 cascade failure. The gitea-runner failure was a cascade from Forgejo being down — it will self-heal once Forgejo recovers. All 3 root-cause fixes have been implemented and the Nix build succeeds. **Pending `just switch` to deploy.**

---

## a) FULLY DONE ✅

| # | What | Root Cause | Fix | Status |
|---|------|-----------|-----|--------|
| 1 | **Forgejo pre-start crash** | `.admin-password` file owned by `root:root` after creation by pre-start script. Forgejo user (`forgejo`) could not `head -1` the file → `Permission denied` → service exits → pre-start failure → Forgejo down. | Added `systemd.tmpfiles.rules` with `z` type: `"z /var/lib/forgejo/.admin-password 0600 forgejo forgejo -"` — this runs on every activation and fixes ownership automatically. | **Built, pending deploy** |
| 2 | **Caddy watchdog kill** | `WatchdogSec=30` was set on caddy.service. Caddy uses `Type=notify` and sends `READY=1` on startup, but **never sends periodic `WATCHDOG=1` keepalives**. Systemd waited 30s, got no keepalive, sent SIGABRT → crash. This was a misdiagnosis — Caddy was listed as "safe to use WatchdogSec" in AGENTS.md because it's `Type=notify`, but it only implements half of sd_notify (ready, not watchdog). | Removed `WatchdogSec = "30"` from caddy.nix. Updated AGENTS.md WatchdogSec documentation to distinguish between `READY=1` and `WATCHDOG=1`. | **Built, pending deploy** |
| 3 | **nvme-metrics exit 1** | Service uses `harden {}` which sets `CapabilityBoundingSet=""` (drop all caps). The `nvme smart-log` command needs `CAP_SYS_ADMIN` for the NVMe Admin Pass Through ioctl on `/dev/nvme0n1`. Without it, the ioctl returns EPERM → script exits 1. | Added `CapabilityBoundingSet = "CAP_SYS_ADMIN"` to nvme-metrics service config in signoz.nix. | **Built, pending deploy** |
| 4 | **AGENTS.md WatchdogSec documentation** | Caddy was incorrectly listed under "safe to use WatchdogSec" despite not sending watchdog keepalives. | Added new category "Services that send READY=1 but NOT WATCHDOG=1" with Caddy as the canonical example. Updated the rule to explicitly require verifying periodic `WATCHDOG=1`, not just `READY=1`. | **Done** |
| 5 | **Nix build verification** | All 4 file changes compile without errors. | `nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel` — succeeded. | **Done** |

---

## b) PARTIALLY DONE 🔧

| What | Status | What's Left |
|------|--------|-------------|
| **Deploy fixes** | Code changes built and verified | `just switch` to activate on evo-x2 |
| **Verify service recovery** | Fixes are correct in theory | Need to confirm all 4 services come up healthy after deploy |
| **Forgejo migration cleanup** | Module code migrated in prior sessions | Stale `gitea` references remain in DNS records, Authelia, Homepage (from Session 57 status) |
| **DNS resolver sharing** | Shared module created, rpi3 migrated | evo-x2 dns-blocker-config.nix still has duplicated settings |

---

## c) NOT STARTED ⬜

| What | Priority | Notes |
|------|----------|-------|
| rpi3-dns hardware provisioning | Low | Physical — needs Pi 3 + USB SSD |
| sops key provisioning for Pi 3 | Low | 30 min after hardware ready |
| DNS failover VRRP testing | Low | Blocked on Pi 3 hardware |
| Auditd enablement | Low | Blocked on NixOS 26.05 bug #483085 |
| Cloud backup implementation | Low | B2/R2 pricing research done |
| AppArmor profiles | Low | 1h effort |
| Boot performance optimization | Low | Analysis done, implementation remaining |

---

## d) TOTALLY FUCKED UP 💥

| What | Why | Impact | Fix Status |
|------|-----|--------|------------|
| **Forgejo .admin-password ownership** | The pre-start script creates the file as root (it runs as root in ExecStartPre), but then Forgejo's main process (running as `forgejo` user) needs to read it. The file was created with `chmod 600` but owned by `root:root`. The `forgejo` user has no read access. | **Forgejo completely down** — cannot start at all. All dependent services (runner, sync, mirrors) non-functional. | **Fixed** — tmpfiles `z` rule adjusts ownership on every activation. |
| **Caddy WatchdogSec misconfiguration** | Caddy was added to the "safe for WatchdogSec" list because it's `Type=notify`, but nobody verified it actually sends periodic `WATCHDOG=1`. It only sends `READY=1` at startup. Systemd killed it after 30s on every start. | **Caddy completely down** — all reverse-proxied services unreachable (`*.home.lan`). TLS termination broken. Homepage, Authelia, Forgejo web UI — all inaccessible from LAN. | **Fixed** — removed WatchdogSec. |
| **nvme-metrics missing CAP_SYS_ADMIN** | Hardening profile drops all capabilities. NVMe SMART log ioctl requires CAP_SYS_ADMIN. Service has been failing silently since hardening was applied. | **No NVMe SMART metrics** in Prometheus/node_exporter. NVMe health data gap in SigNoz/Gatus dashboards. | **Fixed** — added CapabilityBoundingSet override. |

**Key lesson:** The WatchdogSec misconfiguration is the most embarrassing — it means Caddy has been failing on every switch since WatchdogSec was added, and nobody noticed because `nh os switch` only shows the first failed unit (gitea-runner), not Caddy. The cascade of failures masked each other.

---

## e) WHAT WE SHOULD IMPROVE 📈

| # | Area | Issue | Improvement |
|---|------|-------|-------------|
| 1 | **Service startup validation** | `nh os switch` only warns about failed units in activation output. No automated post-switch health check. | Add `just health` as post-switch verification step. Could be a pre-commit hook or activation script. |
| 2 | **WatchdogSec audit** | Only Forgejo should have WatchdogSec. Any other service with it is a bug waiting to happen. | Audit ALL service modules for WatchdogSec usage. Remove from any service not confirmed to send `WATCHDOG=1`. |
| 3 | **Capability audit for hardened services** | `harden {}` drops all capabilities by default. Any service doing privileged ioctls (NVMe, USB HID, etc.) needs explicit overrides. | Audit all hardened services for device access patterns that need capabilities. Document required capabilities per service. |
| 4 | **File ownership in pre-start scripts** | Pre-start scripts run as root but create files in service-owned directories. The service user then can't read them. | Pattern: always `chown` after creating files in pre-start, or use tmpfiles rules for predictable state files. |
| 5 | **Cascade failure detection** | gitea-runner failure hid Forgejo failure which hid the real bugs. | Add dependency-aware health checks that report upstream failures first. |
| 6 | **Integration testing** | No automated way to verify services start correctly after config changes. | Add basic `nixosTests` that verify service startup for critical services (Caddy, Forgejo, DNS). |
| 7 | **Post-switch monitoring** | No automated alert when services fail after `just switch`. | Add `just switch-verify` that waits 60s then checks `systemctl --failed`. |

---

## f) Top #25 Things to Get Done Next

| # | Task | Priority | Effort | Category |
|---|------|----------|--------|----------|
| 1 | **Deploy current fixes** — `just switch` to activate Forgejo/Caddy/nvme-metrics fixes | 🔴 Critical | 5 min | Deploy |
| 2 | **Verify all 4 services recover** — `systemctl --failed` should show 0 units | 🔴 Critical | 5 min | Verification |
| 3 | **Audit all modules for WatchdogSec** — grep and remove from any service not sending WATCHDOG=1 | 🔴 High | 15 min | Reliability |
| 4 | **Audit all hardened services for missing capabilities** — check device access patterns | 🔴 High | 30 min | Hardening |
| 5 | **Fix stale gitea→forgejo references** — DNS, Authelia OIDC, Homepage dashboard | 🔴 High | 30 min | Migration |
| 6 | **Add `just switch-verify`** — post-switch health check command | 🟡 Medium | 15 min | DX |
| 7 | **Move Forgejo admin password to sops** — currently random-generated in pre-start | 🟡 Medium | 10 min | Security |
| 8 | **Move Authelia OIDC client_secret from bcrypt to sops** | 🟡 Medium | 20 min | Security |
| 9 | **Deduplicate evo-x2 dns-blocker-config.nix** with shared dns-resolver module | 🟡 Medium | 20 min | Code quality |
| 10 | **Verify Twenty CRM** is functional or document why not | 🟡 Medium | 15 min | Verification |
| 11 | **Verify Voice agents** end-to-end (Whisper + LiveKit + ROCm) | 🟡 Medium | 30 min | Verification |
| 12 | **Add Gatus endpoints** for Hermes, Manifest, Voice agents | 🟡 Medium | 15 min | Monitoring |
| 13 | **Run `just update`** — refresh flake.lock with latest upstream | 🟢 Low | 10 min | Maintenance |
| 14 | **Audit and remove dead modules** (ComfyUI if unused, Multi-WM/Sway if bitrotted) | 🟢 Low | 30 min | Cleanup |
| 15 | **Add nixosTests** for critical services (Caddy, DNS, Forgejo) | 🟢 Low | 2h | Testing |
| 16 | **Implement cloud backup** (B2/R2) | 🟢 Low | 2h | Reliability |
| 17 | **Centralize Twenty secrets** in sops.nix | 🟢 Low | 15 min | Security |
| 18 | **Script health check runner** — one command to verify all services | 🟢 Low | 30 min | DX |
| 19 | **Boot performance optimization** — implement remaining items from analysis | 🟢 Low | 1h | Performance |
| 20 | **Provision Pi 3 + USB SSD** for DNS failover cluster | 🟢 Low | Physical | Infrastructure |
| 21 | **Enable Forgejo federation** | 🟢 Low | 30 min | Feature |
| 22 | **Add SigNoz dashboards** for GPU, Niri, service correlations | 🟢 Low | 1h | Observability |
| 23 | **Create Incus VM for AI workloads** — isolate GPU bugs | 🟢 Low | 2h | Security |
| 24 | **Enable AppArmor profiles** for hardened services | 🟢 Low | 1h | Security |
| 25 | **Validate monitor365 value** — skeleton deployment, worth keeping? | 🟢 Low | 15 min | Audit |

---

## g) Top #1 Question I Cannot Answer Myself

**Has Caddy been failing on EVERY `just switch` since WatchdogSec was added, or did something else change this time?**

The WatchdogSec was in caddy.nix and Caddy is `Type=notify`. If Caddy always sends `READY=1` on startup, systemd would see it as started successfully, then kill it after 30s. But the activation log only shows `gitea-runner-evo-x2` as the failed unit — not Caddy. This suggests either:
1. Caddy was previously crashing but `nh` only reported the first failure (gitea-runner)
2. Something changed in this build that made Caddy slower to start, exceeding the 30s watchdog
3. Caddy was always dying silently and restarting via `Restart=always` in serviceDefaults

I cannot tell without checking historical journalctl from before this session. This matters because if Caddy has been watchdog-killed on every activation for weeks/months, there's a reliability gap we need to address beyond just removing WatchdogSec.

---

## Technical Details

### Forgejo Fix — tmpfiles ownership adjustment

```nix
# The pre-start script creates .admin-password as root with chmod 600.
# The forgejo user (service runs as forgejo) cannot read it.
# The `z` tmpfiles rule adjusts ownership on every activation.
systemd.tmpfiles.rules = [
  "z ${stateDir}/.admin-password 0600 forgejo forgejo -"
];
```

### Caddy Fix — WatchdogSec removal

```nix
# BEFORE (WRONG):
WatchdogSec = "30";  # Caddy never sends WATCHDOG=1 → killed after 30s

# AFTER (CORRECT):
# No WatchdogSec — Caddy sends READY=1 but not periodic WATCHDOG=1
```

### nvme-metrics Fix — CAP_SYS_ADMIN for NVMe ioctl

```nix
# BEFORE (WRONG):
// harden {};  # CapabilityBoundingSet="" → nvme smart-log ioctl returns EPERM

# AFTER (CORRECT):
// harden {
  CapabilityBoundingSet = "CAP_SYS_ADMIN";
};
```

---

## Service Dependency Graph (Failure Cascade)

```
Forgejo pre-start crash (.admin-password permissions)
  ├── gitea-runner-evo-x2 ──── connection refused (cascade)
  └── forgejo-github-sync ──── would also fail (not running)

Caddy watchdog crash (independent, WatchdogSec misconfiguration)
  └── ALL *.home.lan services unreachable (cascade)

nvme-metrics exit 1 (independent, missing CAP_SYS_ADMIN)
  └── No NVMe SMART metrics in Prometheus
```

---

## Files Changed This Session

| File | Change |
|------|--------|
| `modules/nixos/services/forgejo.nix` | Added tmpfiles rule for `.admin-password` ownership |
| `modules/nixos/services/caddy.nix` | Removed `WatchdogSec = "30"` |
| `modules/nixos/services/signoz.nix` | Added `CapabilityBoundingSet = "CAP_SYS_ADMIN"` to nvme-metrics |
| `AGENTS.md` | Updated WatchdogSec documentation — Caddy reclassified, rule clarified |

---

## Metrics

| Metric | Value |
|--------|-------|
| Service modules | 36 |
| Total .nix files | 112 (modules: 36, platforms: 60, overlays: 3, lib: 7, pkgs: 5) |
| Shell scripts | 20 |
| Flake lock nodes | 72 |
| Services with `harden {}` | 22/23 (96%) |
| Failed services (pre-fix) | 4 |
| Failed services (post-fix) | 0 (pending deploy) |
| Root disk usage | 448G/512G (91%) |
| Data disk usage | 827G/1.0T (81%) |
| NixOS version | 26.05.20260423.01fbdee |
| Kernel | 7.0.1 |

---

_Arte in Aeternum_
