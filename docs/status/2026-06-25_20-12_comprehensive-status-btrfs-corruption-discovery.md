# Status Report — 2026-06-25 20:12 CEST

**System:** evo-x2 (NixOS, x86_64-linux, AMD Ryzen AI Max+ 395, 128 GB RAM)
**Uptime:** 2 days 14 hours (since 2026-06-23 BTRFS crisis recovery boot)
**Session:** 153 — Post-DMS-migration self-review, type-safety hardening, disk diagnosis
**Git:** `master`, pushed to origin, clean working tree

---

## Executive Summary

The DMS (DankMaterialShell) migration is **complete and runtime-verified** — zero matugen warnings, all 13 plugins loaded, DMS owns the desktop. A self-review pass delivered 5 commits hardening the systemd type-safety hole that caused the original wallpaper-init crash, plus disk-space pre-deploy protection. However, the session uncovered **CRITICAL BTRFS corruption on `/data`** (4.9M checksum errors) that was previously unknown and demands immediate attention.

### System Health Snapshot

| Metric | Value | Status |
|--------|-------|--------|
| Root disk `/` | 487G / 512G (96%) | 🔴 CRITICAL |
| Data disk `/data` | 631G / 1.0T (62%) | 🟢 OK |
| Memory | 25G / 93G used (68G avail) | 🟢 OK |
| Swap | 7.4G / 9.4G (79%) | 🟡 HIGH |
| BTRFS `/data` corruption | 4,937,521 errors | 🔴 CRITICAL |
| BTRFS `/data` checksum fails (24h) | 21,201 | 🔴 CRITICAL |
| NVMe I/O errors (read/write/flush) | 0 / 0 / 0 | 🟢 OK |
| Docker containers | 8 / 8 running | 🟢 OK |
| DMS desktop shell | Running, 0 warnings | 🟢 OK |
| SigNoz observability | start-limit-hit | 🔴 DOWN |
| Builds dir `/nix/var/nix/builds` | 0 entries (cleaned) | 🟢 OK |

---

## a) FULLY DONE ✅

### DMS Migration (Complete & Runtime-Verified)
- [x] awww wallpaper daemon retired, DMS owns wallpapers natively
- [x] `enableDynamicTheming = false` — Catppuccin Mocha preserved (matugen removed from closure)
- [x] `DMS_DISABLE_MATUGEN=1` env var — eliminates 38+ runtime matugen probe warnings (verified: 0 warnings since deploy)
- [x] `dms-wallpaper-init` service — seeds random wallpaper from `~/.local/share/wallpapers/` on first launch (fixed: `serviceDefaultsUser` crash, `$HOME`→`%h`, `find`→`find -L`)
- [x] Waybar/Swaylock/Wlogout/Dunst/polkit-gnome fully replaced by DMS
- [x] DMS owns DBus: `org.freedesktop.Notifications`, `org.gnome.ScreenSaver`, `org.kde.StatusNotifierWatcher`
- [x] DMS niri module imported for workspace IPC
- [x] 13 SystemNix DMS plugins loaded and verified
- [x] `inputs.nixpkgs.follows` set on DMS input (Qt version alignment)

### Plugin Improvements
- [x] DualWanWidget: auto-detect WAN interfaces (no hardcoded `enp2s0`/`wlp1s0`)
- [x] BtrfsWidget: disk usage % display via `df --output=pcent`
- [x] DnsStatsWidget: 12-point rolling sparkline visualization
- [x] Plugin template created (`_template/` — 3 files for future plugin development)

### Type-Safety & Architecture Hardening (This Session)
- [x] `serviceOneshotDefaults` / `serviceOneshotDefaultsUser` added to `lib/systemd/service-defaults.nix` — defaults `Restart=no` instead of `"always"`, making the oneshot crash **impossible by design**
- [x] `dual-wan.nix` and `forgejo-repos.nix` refactored to use `serviceOneshotDefaults`
- [x] Pre-deploy disk-space check (section 8) — blocks deploy at ≥95%, warns at ≥85%
- [x] `nix-build-cleanup` timer: daily → every 4h + `OnBootSec=5min` (prevents 100+ GB stale sandbox accumulation)

### Documentation
- [x] FEATURES.md overhauled (Waybar→DMS, 13-plugin table, ADR-004 historical)
- [x] ROADMAP.md updated (QuickShell DONE, BTRFS migration plan, service triage)
- [x] TODO_LIST.md updated (session 152)
- [x] AGENTS.md: 8 new gotchas documented (DMS split-brain, `find -L`, `%h` vs `$HOME`, `serviceOneshotDefaults`, BTRFS CoW reclamation, stale build dirs, matugen env var, `DMS_DISABLE_MATUGEN`)
- [x] 197 old status reports archived to `docs/status/archive/`

### Other
- [x] 112 GB stale build sandboxes cleaned (`/nix/var/nix/builds/*`)
- [x] 615 orphaned anonymous Docker volumes pruned
- [x] Pocket ID client-secret desync fixed (dead migration block removed)
- [x] Immich OAuth: password login disabled, auto-launch configured
- [x] Gatus audited: 36/38 endpoints UP, 2 expected DOWN (Ollama, Monitor365)
- [x] Monitor365 root-caused: upstream Rust panic (Axum 0.7 `:param`→`{param}`)

---

## b) PARTIALLY DONE 🟡

### Root Disk Space (96% — CRITICAL)
- **Done:** Identified root cause (112 GB stale build sandboxes from June 22 OOM crashes), cleaned them, hardened the cleanup timer to prevent recurrence
- **Not done:** Space NOT reclaimed yet — BTRFS CoW snapshots hold references to the deleted data. `btrfs filesystem df /` still shows 420G data used. Reclamation happens as btrbk snapshots expire (14d retention). Root remains at 96% (24 GB free).
- **Risk:** Deploying at 96% can trigger emergency shell (now guarded by pre-deploy check)

### DMS Matugen Suppression
- **Done:** `DMS_DISABLE_MATUGEN=1` env var added to `dms.service`, deployed, verified (0 warnings)
- **Not done:** Change is committed and pushed but **the running system is from a generation that predates the `serviceOneshotDefaults` / timer hardening commits** — needs deploy + reboot

### Cloud Backup
- **Not started:** BorgBackup to Hetzner StorageBox planned in ROADMAP.md but no implementation. `/data` corruption makes this URGENT.

---

## c) NOT STARTED ⬜

| Item | Priority | Blocked By |
|------|----------|------------|
| BTRFS `/data` subvolume migration (toplevel → named subvol) | HIGH | Needs downtime window + corruption resolution |
| Reboot evo-x2 | MED | User action (clears stale polkit, applies generation) |
| Swap investigation (7.4G/9.4G = 79% on 128G RAM) | MED | — |
| SigNoz fix (query logger dir creation failure) | MED | — |
| Cloud backup (BorgBackup → Hetzner) | **URGENT** | `/data` corruption makes data loss risk real |
| Pi 3 DNS failover cluster provisioning | LOW | Hardware setup |
| Auditd enablement | LOW | NixOS 26.05 bug #483085 |
| AppArmor enablement | LOW | — |
| Darwin HM parity | LOW | 256 GB SSD 90-95% full |
| Monitor365 agent→server auth | LOW | Upstream Rust panic first |
| Large module splits (monitor365 716L, signoz 705L, forgejo 583L) | LOW | — |
| Firewall deny-by-default | MED | — |
| 7 nixpkgs upstream PRs | LOW | — |
| 3 Home Manager upstream PRs | LOW | — |

---

## d) TOTALLY FUCKED UP! 🔴

### 1. BTRFS `/data` Corruption — CRITICAL, PREVIOUSLY UNKNOWN

**This is the most serious finding of the entire session.**

```
BTRFS device stats for /data (nvme0n1p8, Lexar SSD NQ790 2TB):
  corruption_errs:  4,937,521
  checksum fails:   21,201 in last 24 hours alone
  read/write/flush: 0 / 0 / 0  (NVMe hardware is fine)
```

- The NVMe hardware reports **zero I/O errors** — this is filesystem corruption, not hardware failure
- `/data` is mounted as BTRFS toplevel (`subvolid=5`) — **no snapshot protection**, no rollback possible
- Docker root (`/data/docker`) lives on this corrupted filesystem — all container data is at risk
- Named Docker volumes (`twenty_db-data`, `twenty_server-local-data`, `openseo_data`, `manifest_pgdata`) hold production data on corrupted blocks
- No cloud backup exists — data loss is possible if corruption worsens

**Impact:** Silent data corruption in Docker volumes, container databases, and any file on `/data`. The 4.9M corruption count suggests this has been accumulating for a long time.

**Root cause hypothesis:** BTRFS on a toplevel subvolume with no snapshots, combined with the documented OOM/hard-reset crash chain. Hard resets can corrupt BTRFS metadata. The `discard=async` mount option is valid for BTRFS (not the ext4 trap from AGENTS.md).

### 2. SigNoz DOWN — start-limit-hit

SigNoz failed to start during deploy and hit the start limit. Query logger directory creation failure (pre-existing). The `notify-failure@` handler was triggered. Not caused by this session's changes but blocks observability.

### 3. EGL/Qt Rendering Crash

```
traps: QSGRenderThread[1724176] general protection fault in libEGL.so.1.1.0
```

DMS's Qt Scene Graph render thread crashed with a GP fault in libEGL. DMS auto-restarted (Restart=on-failure). Likely related to AMD GPU driver / Mesa version interaction. Not blocking but indicates GPU driver instability.

---

## e) WHAT WE SHOULD IMPROVE! 🔄

### Architecture & Type Safety
1. **`serviceDefaults` API was a footgun** — `Restart=always` as a silent default crashed `Type=oneshot` services. Fixed with `serviceOneshotDefaults`, but we should audit ALL remaining `serviceDefaults` usages to ensure none are on oneshots (audit showed 0 currently broken, but the trap existed for months)
2. **No disk-space guard before deploy** — we deployed at 96% disk multiple times this week, risking emergency shell. Now guarded, but this should have existed from day one
3. **`nix-build-cleanup` ran daily** — 100+ GB accumulated between daily runs after OOM crashes. Timer was too relaxed for a system that experiences hard resets

### Operational Discipline
4. **I told the user to `rm -rf` without checking if automated cleanup existed** — the `nix-build-cleanup` service was already there. Should have investigated "why didn't the existing cleanup work?" before prescribing manual intervention
5. **BTRFS `/data` on toplevel with no snapshots** — this is an architectural decision that left production data unprotected. The ROADMAP has a migration plan but it should have been done before loading data onto the filesystem
6. **No cloud backup** — relying solely on local BTRFS snapshots (which `/data` doesn't even have) is unacceptable for production data

### Monitoring & Observability
7. **BTRFS corruption went undetected** — no monitoring or alerting on `btrfs device stats`. Should add a Gatus check or systemd timer that alerts when corruption_errs > 0
8. **SigNoz is down** — the observability platform itself is unobservable. Circular dependency
9. **Swap at 79%** — unclear if this is zram normal behavior or a memory leak. No baseline established

### Documentation
10. **AGENTS.md gotcha table is now 30+ rows** — becoming hard to scan. Consider grouping by category (boot, desktop, Docker, BTRFS, sops, etc.)

---

## f) Top 25 Things We Should Get Done Next

Sorted by **impact / effort ratio** (highest first).

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 1 | **BTRFS scrub `/data`** — run `btrfs scrub start /data` to assess full corruption scope | 🔴 CRITICAL | 30min | Data safety |
| 2 | **Cloud backup** — BorgBackup to Hetzner StorageBox, encrypt all `/data` Docker volumes | 🔴 CRITICAL | 2-4h | Data safety |
| 3 | **Assess `/data` corruption** — determine which files/blocks are affected, whether Docker DBs are corrupted | 🔴 CRITICAL | 1-2h | Data safety |
| 4 | **BTRFS `/data` subvolume migration** — convert toplevel to named subvol + enable btrbk snapshots | 🔴 HIGH | 1h downtime | Reliability |
| 5 | **BTRFS corruption monitor** — systemd timer that checks `btrfs device stats` and alerts if corruption_errs growing | 🔴 HIGH | 30min | Monitoring |
| 6 | **Reboot evo-x2** — applies new generation (timer hardening, serviceOneshotDefaults), clears stale polkit-gnome | 🟡 MED | 5min | Operations |
| 7 | **Deploy pending commits** — 5 commits pushed but not yet deployed to running system (disk guard will block at 96%) | 🟡 MED | 10min | Operations |
| 8 | **Reclaim root disk space** — wait for BTRFS snapshots to expire OR manually delete old btrbk snapshots to free the 112G | 🟡 MED | 30min | Operations |
| 9 | **Fix SigNoz** — query logger dir creation failure, start-limit-hit. Restores observability | 🟡 MED | 1h | Monitoring |
| 10 | **BTRFS balance root `/`** — metadata is 34G for 420G data, may reclaim space from CoW fragmentation | 🟡 MED | 1-2h | Disk space |
| 11 | **Swap investigation** — 7.4G/9.4G on 128G RAM. Check if zram-config is normal or if there's a leak | 🟡 MED | 30min | Investigation |
| 12 | **Investigate 3 unexpected Gatus DOWN endpoints** — Crush Daily, Memory Pressure, SigNoz | 🟡 MED | 30min | Monitoring |
| 13 | **Clean orphaned Docker volumes** — 37GB reclaimable (lemonade, deer-flow, code-quality-agent, flm-models) | 🟡 MED | 15min | Disk space |
| 14 | **Firewall deny-by-default** — currently permissive, should lock down exposed ports | 🟡 MED | 2h | Security |
| 15 | **EGL/libEGL crash investigation** — QSGRenderThread GP fault, likely Mesa/AMD driver issue | 🟡 MED | 1-2h | Stability |
| 16 | **Bind Immich to localhost** — currently exposed beyond reverse proxy | 🟡 MED | 15min | Security |
| 17 | **Remove legacy ssh-rsa** — weak crypto still permitted | 🟢 LOW | 15min | Security |
| 18 | **Monitor365 upstream fix** — Axum 0.7 route syntax (`:param`→`{param}`), needs fix in `github:LarsArtmann/monitor365` | 🟢 LOW | 1h | Upstream |
| 19 | **Large module splits** — monitor365 (716L), signoz (705L), forgejo (583L) into smaller focused modules | 🟢 LOW | 3-4h | Code quality |
| 20 | **Extract dnsblockd** — ~930 lines in dns-blocker.nix, should be its own package | 🟢 LOW | 2-3h | Code quality |
| 21 | **Typed NixOS module options** — replace stringly-typed config with proper types | 🟢 LOW | 4h+ | Code quality |
| 22 | **Pi 3 DNS failover** — provision hardware, configure secondary DNS + keepalived | 🟢 LOW | 4h+ | Reliability |
| 23 | **nixpkgs upstream PRs** — 7 items (poetry-core migration, broken tests, new packages) | 🟢 LOW | 8h+ | Upstream |
| 24 | **Auditd/AppArmor** — blocked on NixOS 26.05 bug, revisit after upgrade | 🟢 LOW | — | Security |
| 25 | **Darwin HM parity** — blocked by 256GB SSD disk space, low priority | 🟢 LOW | — | Cross-platform |

---

## g) Top #1 Question I Cannot Figure Out Myself

### The `/data` BTRFS corruption demands a decision I cannot make:

**The `/data` filesystem has 4.9 million corruption errors and zero snapshot protection. Docker (including all production databases) lives on it. There is no cloud backup.**

I can run `btrfs scrub` to assess the damage, but the critical question is:

> **Do we attempt to repair `/data` in-place (risky — `btrfs scrub` may delete corrupted files), or do we evacuate data to a fresh filesystem first (safe — but requires knowing what's still intact and having somewhere to copy 631 GB to)?**

This depends on:
1. Whether the Lexar SSD itself is degrading (SMART data says no I/O errors, but checksum corruption this severe is unusual for healthy hardware)
2. Whether we have 631 GB of free space somewhere to evacuate to
3. Whether the Docker databases (Twenty Postgres, Manifest Postgres, Immich) have already suffered silent data corruption
4. Whether you have a Hetzner StorageBox or other off-site target ready for emergency backup

**I recommend:** Before anything else, run `btrfs scrub start /data` to get the full corruption scope, then immediately set up BorgBackup to get data off this drive. But I need your call on whether scrub-then-evacuate or evacuate-without-scrubbing is the right risk profile.

---

## Session Commits (2026-06-25)

| Commit | Description |
|--------|-------------|
| `0318ebe2` | Pre-deploy disk-space + stale-build checks |
| `00c3e7b0` | `serviceOneshotDefaults` type-safety helper |
| `37a13d52` | Refactor dual-wan + forgejo-repos to use oneshot defaults |
| `c91e958d` | nix-build-cleanup timer: daily → 4h + on-boot |
| `bca5f64e` | AGENTS.md gotchas: stale builds, BTRFS CoW, serviceOneshotDefaults |

All pushed to `origin/master`.

---

_Generated 2026-06-25 20:12 CEST — session 153_
