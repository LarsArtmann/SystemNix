# Session 146 — Emergency Shell Recovery, Docker Rebuild, Prevention Systems

**Date:** 2026-06-23 18:15 CEST
**System:** evo-x2 (x86_64-linux, kernel 7.1.0)
**Status:** ✅ Operational — 0 failed units, all critical services active

---

## Executive Summary

A routine `nh os switch` triggered an **emergency shell** requiring two reboots and a rollback. Root cause: a BTRFS-only mount option (`discard=async`) was used on an ext4 filesystem, causing mount failure → `local-fs.target` failure → emergency mode. A secondary issue (malformed systemd unit from a `harden()` function silently swallowing arguments) compounded the failure.

During recovery, **four additional cascading failures** were discovered and fixed: Docker containerd bbolt corruption, Docker 29.x `userland-proxy-path` nixpkgs gap, Docker/Podman split-brain, and dnsblockd SQLite path resolution. Two prevention systems were built: `mkFilesystem` eval-time validation and a pre-deploy check script.

---

## A) FULLY DONE ✅ (12 tasks)

### Root Cause Fixes

| # | Fix | File(s) | Impact |
|---|-----|---------|--------|
| 1 | **ext4 `discard=async` → `discard` + `nofail`** | `hardware-configuration.nix:46` | 🔴 Primary cause of emergency shell. BTRFS-only option on ext4 → mount fails → `local-fs.target` fails → emergency |
| 2 | **`harden()` passthrough fix** | `lib/systemd.nix` | 🔴 `harden {}` silently discarded `ExecStart`/`Type`/`RemainAfterExit` via `...` rest args. Now passes through extra arguments |
| 3 | **`twenty-fix-collation` ExecStart** | `modules/nixos/services/twenty.nix:170` | 🟡 Moved `ExecStart`/`Type` outside `harden()`, merged with `//` |
| 4 | **dnsblockd WorkingDirectory** | `modules/nixos/services/dns-blocker.nix:333` | 🟡 SQLite CANTOPEN under `ProtectSystem=strict` — added `WorkingDirectory = "/var/lib/dnsblockd"` |
| 5 | **Docker 29.x userland-proxy** | `modules/nixos/services/default-services.nix` | 🔴 Docker daemon couldn't start — `docker-proxy` moved to internal moby derivation. Set `userland-proxy = false` |
| 6 | **Eliminate Podman/Docker split-brain** | `platforms/nixos/system/configuration.nix:123` | 🟡 `oci-containers.backend` defaulted to `"podman"`, running two container runtimes. Set `backend = "docker"` |

### Prevention Systems

| # | Feature | File(s) | Impact |
|---|---------|---------|--------|
| 7 | **`mkFilesystem` helper** | `lib/filesystems.nix` (new) | 🔴 Validates mount options at eval time. Catches `discard=async` on ext4, `subvol` on non-btrfs, etc. |
| 8 | **mkFilesystem test suite** | `tests/test-mkFilesystem.nix` (new) | 🟡 7 tests covering all cross-fs contamination scenarios |
| 9 | **Refactored all 4 mounts** | `hardware-configuration.nix` | 🟡 `/`, `/data`, `/boot`, `/rust-cache` now use `mkFilesystem` |
| 10 | **Pre-deploy validation script** | `scripts/pre-deploy-check.sh` (new) | 🟡 Checks flake, mounts, units, container backend, harden usage before switch |
| 11 | **Deploy script with pre-check** | `scripts/deploy.sh` + `flake.nix` | 🟡 `nix run .#deploy` now runs validation before `nh os switch` |
| 12 | **AGENTS.md gotchas** | `AGENTS.md` | 📚 6 new entries for all discovered issues + recovery procedures |

### Runtime Recovery (manual, not committed)

- Docker containerd bbolt `meta.db` corruption from OOM hard reset → moved corrupted file, containerd rebuilt fresh
- Stuck containerd shims (zombie containers from crash) → killed all, purged container/network/buildkit state (volumes+images preserved)
- Stale swap UUID `4fe73a15-...` from rolled-back generation → resolved on deploy

---

## B) PARTIALLY DONE ⚠️

| Item | Status | What's left |
|------|--------|-------------|
| Docker containers | Running but some restarting | `twenty-db-1` and `openseo-openseo-1` are restart-looping (PostgreSQL checkpoint corruption from OOM). Need database recovery or re-init |
| Pre-deploy validation | Script works but not battle-tested | Needs to be run on a real deploy to verify all checks fire correctly |
| `mkFilesystem` adoption | Only `hardware-configuration.nix` uses it | `snapshots.nix` cache mounts (btrfs subvols) still use raw attrsets — could use `mkFilesystem` but they're btrfs-on-btrfs (no cross-fs risk) |
| `overview.service` warning | Diagnosed | `StartLimitIntervalSec` in `[Service]` instead of `[Unit]` — cosmetic warning from external overview repo. Fix belongs there, not in SystemNix |

---

## C) NOT STARTED ⬜

| Item | Why it matters |
|------|----------------|
| Twenty CRM PostgreSQL recovery | `twenty-db-1` has corrupted checkpoint record from OOM crash. Needs `pg_resetwal` or full re-init |
| OpenSEO container recovery | Same restart-loop pattern, likely same cause |
| Automated container health monitoring | `service-health-check` exists but doesn't alert on Docker container restart loops |
| BTRFS scrub after corruption | Should run `btrfs scrub start /data` to verify filesystem integrity after the OOM crash |
| flake.lock commit | `flake.lock` is dirty (42 insertions/deletions) — pre-existing from session start, not committed |

---

## D) TOTALLY FUCKED UP 💥

| Item | What happened | Impact |
|------|---------------|--------|
| Docker state wipe | Had to purge `/data/docker/containers/`, `containerd/`, `network/`, `buildkit/` to recover from corruption. All container state was lost. Volumes and images preserved. | Twenty CRM and OpenSEO databases may be corrupted (PostgreSQL PANIC: could not locate a valid checkpoint record) |
| First deploy attempt | `nh os switch` completed activation but SSH connection timed out (`192.168.1.150: Operation timed out`). The deploy triggered a reboot or network reconfiguration. | Had to physically reboot machine |
| Boot -1 (05:48-05:49) | 1-minute boot → emergency shell → reboot → boot -0 → still broken → rollback | User experienced two failed boots |

---

## E) WHAT WE SHOULD IMPROVE 🎯

### Architecture

1. **Single container runtime** — DONE this session. Should audit quarterly to prevent regression.
2. **`mkFilesystem` should be the ONLY way to define mounts** — currently optional. Could enforce via module system or linting.
3. **Container data should live on a more resilient filesystem** — Twenty/OpenSEO PostgreSQL on Docker overlay2 over BTRFS is fragile. Consider dedicated volumes or ZFS.
4. **OOM kill chain is still the root cause of everything** — The OOM hard reset corrupted Docker state. The `boot.nix` memory limits help but don't prevent all scenarios.
5. **Pre-deploy checks should include `nix build` dry-run** — Currently only evaluates, doesn't build. A build would catch more issues.

### Process

6. **Always snapshot before deploy** — `btrfs subvolume snapshot /mnt/btrfs-root/@ /mnt/btrfs-root/@-pre-deploy-$(date +%s)` before every `nh os switch`.
7. **Container restart-loop detection** — The `service-health-check` should monitor `docker ps` for restart counts >3.
8. **PostgreSQL backup verification** — Twenty CRM backups exist but we don't verify they're restorable.
9. **Disk usage alerting** — Root is at 94% (35G free). The `nix-build-cleanup` timer helps but we need alerting before it hits 95%+.
10. **Test the rollback path** — We relied on rollback this session. Should verify it works on every deploy.

---

## F) Top 25 Things to Get Done Next

### P0 — Critical (do this week)

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 1 | **Fix Twenty CRM PostgreSQL** — `pg_resetwal` or re-init database | 🔴 CRM is down | 30m |
| 2 | **Fix OpenSEO container** — same checkpoint corruption pattern | 🟡 Service down | 15m |
| 3 | **Run BTRFS scrub on /data** — verify integrity after OOM corruption | 🔴 Silent data corruption risk | 5m + scrub time |
| 4 | **Deploy latest config** (mkFilesystem + pre-deploy-check) and verify clean reboot | 🔴 Current generation doesn't have the prevention systems | 20m |
| 5 | **Commit flake.lock** — it's been dirty since session start | 🟡 Hygiene | 1m |

### P1 — High value (do this sprint)

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 6 | **Snapshot before deploy** — add `btrfs subvolume snapshot` to deploy script | 🔴 Instant rollback capability | 15m |
| 7 | **Container restart-loop alerting** — add Docker health check to `service-health-check` | 🟡 Early warning for crashes | 30m |
| 8 | **PostgreSQL backup restore test** — verify Twenty CRM backups work | 🔴 Data safety | 30m |
| 9 | **Disk alerting at 92%** — add to `disk-monitor` or `service-health-check` | 🟡 Prevent disk-full boot loops | 20m |
| 10 | **Pre-deploy check: build dry-run** — add `nix build --dry-run` to validation | 🟡 Catches build failures before switch | 15m |

### P2 — Architecture improvements (do this month)

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 11 | **Enforce `mkFilesystem` everywhere** — refactor `snapshots.nix` cache mounts | 🟡 Consistency | 15m |
| 12 | **Docker Compose health checks** — add restart-limit + healthcheck to all compose services | 🟡 Prevents infinite restart loops | 45m |
| 13 | **Container volume backup automation** — automated pg_dump for all database containers | 🔴 Data safety | 45m |
| 14 | **OOM playbook** — document the full OOM kill chain + recovery steps in AGENTS.md | 🟡 Runbook | 30m |
| 15 | **Memory pressure dashboard** — PSI metrics exist but no visualization | 🟢 Observability | 45m |
| 16 | **Migrate Docker data-root to dedicated partition** — Docker on BTRFS toplevel is fragile | 🟡 Stability | 2h |
| 17 | **Audit all systemd services for `startLimitBurst`** — some have no limit, causing infinite restart loops | 🟡 Stability | 30m |
| 18 | **Network namespace cleanup** — stale `run-docker-netns-*` mounts after container purges | 🟢 Hygiene | 15m |
| 19 | **sigstore/cosign image verification** — verify container image signatures before running | 🟢 Security | 1h |

### P3 — Quality of life

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 20 | **`overview.service` fix upstream** — move StartLimitIntervalSec to [Unit] in overview repo | 🟢 Clean boot logs | 10m |
| 21 | **`nix fmt` pre-commit hook coverage** — ensure all .nix files formatted | 🟢 Consistency | 10m |
| 22 | **Flake lock automated updates** — schedule weekly `nix flake update` via timer | 🟢 Fresh deps | 30m |
| 23 | **Status dashboard** — the existing status HTML could be auto-generated weekly | 🟢 Observability | 1h |
| 24 | **Service dependency graph** — D2 diagram of all services + dependencies | 🟢 Onboarding | 45m |
| 25 | **Emergency recovery cheatsheet** — one-page runbook for emergency shell recovery | 🟡 Operational resilience | 20m |

---

## G) Top Question I Cannot Answer

**Should Twenty CRM's PostgreSQL database be recovered (`pg_resetwal`) or re-initialized from scratch?**

The PostgreSQL instance inside `twenty-db-1` has a corrupted checkpoint record (`PANIC: could not locate a valid checkpoint record`). This happened because the OOM hard reset killed the container mid-write.

- **`pg_resetwal`** is fast but risks data inconsistency — some committed transactions may be lost, and referential integrity could be violated.
- **Re-init from backup** is safe but the backup may be stale (the `twenty-db-backup.service` runs daily, so up to 24h of data could be lost).
- **The backup volume is at `/data/docker/volumes/`** — we preserved volumes during the Docker state purge, so backups should be intact.

I don't know how mission-critical the Twenty CRM data is. If it's a personal CRM with no critical data, re-init is safer. If it has customer data, `pg_resetwal` + immediate `pg_dump` + inspect is the path.

---

## Current System Snapshot

```
Kernel:      7.1.0
Generation:  jp3ybjnbgsiyzlqy6fwjhp9y35d3ssll (gen ~428)
Boot target: default (latest)
Uptime:      ~13 hours since rollback boot
Failed units: 0

Memory:      27G used / 93G total (66G available)
Root disk:   471G/512G used (94%) ⚠️
Data disk:   630G/1T used (62%)
Boot disk:   239M/2G used (12%)

Docker:      5 containers (2 healthy, 2 restarting, 1 starting)
Podman:      eliminated (socket stopped, backend switched to docker)
DNS:         unbound + dnsblockd active
Caddy:       active
```

---

## Commits This Session (7)

```
84ac926f docs: add gotchas for Docker recovery, oci-containers, mkFilesystem
9f1c8474 feat: add pre-deploy validation script and wire into deploy
60b282bf feat: add mkFilesystem helper with cross-fs option validation
3e4ea158 fix: unify OCI containers on Docker backend, eliminate Podman
e865b275 fix: disable Docker userland-proxy (broken in Docker 29.x)
b09f6352 fix: set WorkingDirectory for dnsblockd to resolve SQLite db path
53f5c4f5 fix: prevent emergency shell from ext4 mount failure and malformed systemd unit
```

All pushed to `master`.

---

_Arte in Aeternum_
