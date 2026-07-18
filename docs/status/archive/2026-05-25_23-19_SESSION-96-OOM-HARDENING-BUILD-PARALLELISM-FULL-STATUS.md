# SystemNix — Session 96: Post-OOM Hardening, Build Parallelism Fix, Full Status

**Date:** 2026-05-25 23:19 CEST
**Host:** evo-x2 (AMD Ryzen AI MAX+ 395 w/ Radeon 8060S, 64 GiB unified DDR5)
**Previous:** Session 95 (oauth2-proxy cookie secret blocker)

---

## 🔴 Incident: OOM Hard Crash (2026-05-25 20:40:48)

### What Happened

At 20:40:48, process `compile` (PID 637607, UID 1000) invoked `oom-killer`. The kernel OOM killer terminated processes in `user@1000.service`, killing the niri compositor and forcing a hard power-off.

### Root Cause Chain

1. **`just switch` triggered nix-daemon build** — nix accepted connections from pid 603845/603895 at 20:39:27
2. **Nix build parallelism was unbounded** — `max-jobs = auto` (= 32 cores), `cores = 0` (unlimited threads per job)
3. **Rust compilation is memory-hungry** — each `rustc` codegen thread uses 2-4 GiB; cargo defaults to `j$(nproc)` = 32 threads
4. **32 jobs × 32 threads = up to 1024 parallel rustc processes** — theoretical demand of 2-4 TiB RAM
5. **Unified memory APU** — GPU and CPU share the same 64 GiB DDR5. With GPU VRAM at 64 GiB and GTT at 112 GiB, AI workloads and build processes compete for the same physical RAM
6. **`vm.swappiness = 1`** — kernel barely used the 16 GiB swap, preferring to OOM-kill user processes
7. **systemd-oomd PSI monitoring** — designed for sustained pressure, not sudden allocation spikes from nix builds

### Contributing Factor

The `boot.nix` comment said **"128GB unified memory"** — this was the SoC's max SKU config, not the actual 64 GiB DIMMs. This caused all VM tuning to be calibrated for double the available RAM:

- `vm.dirty_ratio = 10` → comment said "~13GB" → actually ~6.4 GiB
- ZRAM 10% → comment said "~12.8GB" → actually ~6.4 GiB
- `swappiness = 1` → justified by "128GB makes swap unnecessary" → false at 64 GiB

### Fix Applied (This Session)

| Setting          | Before                 | After                                        | Impact                              |
| ---------------- | ---------------------- | -------------------------------------------- | ----------------------------------- |
| `build-max-jobs` | `auto` (32)            | `4`                                          | Max 4 derivations in parallel       |
| `cores`          | `0` (unlimited)        | `8`                                          | Max 8 threads per build job         |
| `vm.swappiness`  | `1`                    | `10`                                         | Kernel uses swap before OOM-killing |
| Comments         | "128GB unified memory" | "AMD Ryzen AI MAX+ 395 — 64 GB unified DDR5" | Factual accuracy                    |
| ZRAM comment     | "~12.8GB on 128GB"     | "~6.4 GB on 64 GB unified DDR5"              | Accurate sizing                     |

**Worst case now:** 4 jobs × 8 rustc = 32 parallel processes × ~2 GiB = ~64 GiB peak. With swap (16 GiB) and swappiness=10, this fits without OOM.

**Files changed:** `platforms/common/nix-settings.nix`, `platforms/nixos/system/boot.nix`

**Status:** Committed, awaiting `just switch` to apply.

---

## ✅ A) FULLY DONE

### Infrastructure & Core Services

- [x] **NixOS build & deployment pipeline** — `just test-fast` passes, `just switch` works
- [x] **32 service modules** registered in `serviceModules` list (flake.nix)
- [x] **42 port assignments** in centralized `lib/ports.nix` registry
- [x] **Caddy reverse proxy** — all services behind `protectedVHost` or public vHosts
- [x] **Pocket ID** — OIDC provider running, admin configured
- [x] **Forgejo** — Git forge with automated repo sync, token management
- [x] **SigNoz observability** — Otel collector, ClickHouse, dashboards, alert rules
- [x] **Gatus status page** — endpoint monitoring for all services
- [x] **DNS infrastructure** — Unbound + dnsblockd + route-health-monitor
- [x] **BTRFS snapshots** — daily root snapshots via btrbk, auto-pruning (14d + 4w), verify timer
- [x] **SOPS secrets** — age-encrypted secrets via SSH host key
- [x] **systemd-oomd** — PSI-based monitoring (root/user/system slices)
- [x] **Dual-WAN** — MPTCP endpoint manager, route health monitoring
- [x] **ZRAM swap** — 10% of RAM as compressed swap buffer
- [x] **GPU memory management** — TTM pool limits, GPU mem fractions per AI service
- [x] **Home Manager** — cross-platform (NixOS + Darwin) with shared base

### Private Go Ecosystem (Overlays)

- [x] **8 Go repos fixed and pushed** (session 94) — go-output, cmdguard, go-auto-upgrade, mr-sync, go-structure-linter, BuildFlow, projects-management-automation, golangci-lint-auto-configure
- [x] **Overlay architecture** — `overlays/default.nix` (mkPackageOverlay), `shared.nix`, `linux.nix`
- [x] **Versioning convention** — hardcoded semver, no `self.rev`/`self.shortRev`
- [x] **mkPreparedSource centralized** — extracted to `go-nix-helpers` repo

### Security & Hardening

- [x] **systemd service hardening** — `harden {}` / `hardenUser {}` wrappers with MemoryMax/MemoryHigh
- [x] **OOM score adjustments** — sshd (-1000), journald/dbus/logind/udevd (-500), waybar/pipewire (-500)
- [x] **BFQ I/O scheduler** — configured for NVMe + block devices
- [x] **SSH server hardening** — sops GPG key import fix (no 2min initrd hang)
- [x] **Coredump limits** — 1 GiB max, prevents AI crash dumps from filling disk

### Documentation

- [x] **8 ADRs** in `docs/adr/`
- [x] **FEATURES.md** — 50+ features catalogued with statuses
- [x] **TODO_LIST.md** — prioritized task list (last updated session 75)
- [x] **AGENTS.md** — comprehensive agent guide with patterns, gotchas, build commands
- [x] **95+ session status reports** in `docs/status/`

---

## 🔶 B) PARTIALLY DONE

1. **oauth2-proxy cookie secret** — Root cause identified (21-byte secret needs 16/24/32 for AES). Fix prepared but **blocked on root/sudo** to edit sops file. All `protectedVHost` services are inaccessible without this.
2. **Service health check script** — Still references `whisper-asr` and `livekit` (removed in session 89). Fails every ~15 minutes with `exit-code=1`. Needs cleanup.
3. **AGENTS.md RAM documentation** — Updated with OOM crash chain, but the "128GB" reference in comments was wrong for months. Now fixed in boot.nix/nix-settings.nix but AGENTS.md "GPU Compute Headroom" section still references old numbers.
4. **Hermes extra deps** — `firecrawl`, `edge-tts`, `fal`, `exa` added to overlay but deployment not verified (blocked on oauth2-proxy).
5. **Boot time optimization** — Target ~35s, not yet verified with current generation.

---

## ❌ C) NOT STARTED

1. **Deploy session 96 OOM fix** — `just switch` not yet run (requires user action)
2. **Fix oauth2-proxy cookie secret** — needs `sudo sops platforms/nixos/secrets/pocket-id.yaml`
3. **Fix service-health-check script** — remove `whisper-asr` / `livekit` references
4. **Darwin (`Lars-MacBook-Air`) build verification**
5. **`rpi3-dns` build verification**
6. **`just test` full build check** — only `just test-fast` (syntax) was run
7. **`/data` BTRFS subvolume migration** — 89% full (906/1024 GiB), cannot be snapshotted as toplevel
8. **Secondary LLM for Hermes** — OpenRouter/OpenAI fallback for GLM-5.1
9. **Hermes git remote access** — SSH deploy key for sandbox
10. **Deploy Dozzle** — Docker container log viewer at `logs.home.lan`
11. **nix-colors integration** — migrate 17+ hardcoded colors to Home Manager theme
12. **Flake inputs audit** — 47 inputs, some may be stale/unused
13. **Memory/swap alerting** — SigNoz/Gatus rules for RAM pressure
14. **Per-threshold SigNoz channel routing** — critical→Discord, warning→log
15. **`just status` command** — automated status report generation
16. **Pi 3 DNS failover cluster** — hardware provisioning + wiring

---

## 💀 D) TOTALLY FUCKED UP

1. **The "128GB" lie** — `boot.nix` comment claimed "128GB unified memory" for months. The Ryzen AI MAX+ 395 _supports_ up to 128 GiB, but this system has **64 GiB DDR5**. Every VM tuning calculation was wrong by 2x. This directly contributed to the OOM crash by creating false confidence that swap was unnecessary.

2. **Nix build parallelism was a loaded gun** — `max-jobs = auto` (= 32) + `cores = 0` (unlimited) on a unified memory APU with AI workloads was a disaster waiting to happen. The system survived this long only because most builds hit binary caches instead of compiling from source.

3. **service-health-check has been failing every 15 minutes since session 89** — `whisper-asr` and `livekit` were removed but the health check script was never updated. That's been logging failures continuously for days, training you to ignore health check alerts.

4. **oauth2-proxy has been down for 2 sessions** — All services behind forward-auth are inaccessible. The cookie secret fix has been identified but requires sudo/root access that agent sessions don't have.

---

## 🛠️ E) WHAT WE SHOULD IMPROVE

1. **Stop lying in comments** — Every magic number should have its derivation. If a comment says "~13GB", include the math: `10% × 64 GiB = 6.4 GiB`. Wrong comments are worse than no comments.
2. **Health check script must track reality** — When services are removed, the health check must be updated in the same commit. The current split (service modules vs health check script in different files) creates drift.
3. **Nix build resource limits should account for unified memory** — On APUs, GPU VRAM comes from the same pool. `max-jobs` and `cores` must be set conservatively because `MemAvailable` overstates what's safe for builds.
4. **Flake inputs are at 47 and growing** — Need an audit. Some inputs may be stale, duplicated, or only used on one platform.
5. **`/data` at 89% capacity** — 118 GiB free out of 1 TiB. No snapshots possible (BTRFS toplevel). Needs migration to `@data` subvolume before it becomes an emergency.
6. **TODO_LIST.md is stale** — Last updated session 75 (4 sessions ago). Multiple items are done but unchecked.
7. **Status reports are accumulating** — 95+ reports in `docs/status/` with no archival hygiene. The `archive/` directory exists but current reports aren't being rotated.
8. **No automated memory alerting** — systemd-oomd kills processes silently. There's no Gatus/SigNoz alert for "system is under memory pressure" before it becomes an OOM kill.
9. **Darwin platform untested** — No build verification for `Lars-MacBook-Air` in recent sessions.
10. **Overlays add packages but don't install them** — The `mkPackageOverlay` pattern makes packages available as `pkgs.<name>` but separate step needed in `home.packages`. Easy to forget.

---

## 🎯 F) Top 25 Things to Do Next

### Critical (Do First)

1. **`just switch`** — Deploy the OOM fix (build parallelism + swappiness)
2. **Fix oauth2-proxy cookie secret** — `sudo sops ...`, set 32-byte secret, `just switch`
3. **Fix service-health-check script** — Remove `whisper-asr` / `livekit` references
4. **Verify all services healthy** after deploying fixes above

### High Priority

5. **Update TODO_LIST.md** — Mark completed items, add new ones from this session
6. **Update AGENTS.md GPU section** — Fix headroom numbers for actual 64 GiB (not 128)
7. **Add memory pressure alerting** — Gatus check for MemAvailable < 8 GiB
8. **`/data` BTRFS migration** — Convert from toplevel to `@data` subvolume for snapshots
9. **Run `just test`** — Full build validation (not just syntax)
10. **Verify boot time** — Target ~35s after all optimizations

### Medium Priority

11. **Flake inputs audit** — Identify stale/unused inputs among 47
12. **Secondary LLM for Hermes** — OpenRouter/OpenAI fallback
13. **Deploy Dozzle** — Container log viewer
14. **Hermes git remote access** — SSH deploy key
15. **Per-threshold SigNoz channel routing** — critical→Discord, warning→log
16. **Status report archival** — Move sessions 66-90 to `archive/`
17. **Darwin build verification** — `nix build .#darwinConfigurations.Lars-MacBook-Air`
18. **Create `just status` command** — Automated status report generation
19. **Consolidate voice-agents Caddy vHost** into caddy.nix pattern

### Lower Priority

20. **nix-colors integration** — Migrate 17+ hardcoded colors to theme
21. **Pi 3 DNS failover** — Provision and wire as secondary DNS
22. **Investigate swap usage patterns** — 7 gopls instances observed eating ~7.4 GiB RSS
23. **Overlay install audit** — Ensure all overlay packages are in `home.packages`
24. **Health check auto-sync** — Generate service list from enabled services, not hardcoded
25. **Consider `nix.settings.max-jobs` per-platform** — Darwin (8 cores) may want different limits

---

## ❓ G) Top #1 Question I Cannot Answer

**What is the actual physical RAM configuration?**

`/proc/meminfo` reports 62.4 GiB (65,465,648 kB), but the Ryzen AI MAX+ 395 supports 64 or 128 GiB. The 1.6 GiB gap (64 - 62.4) could be:

- Hardware-reserved memory (BIOS/firmware)
- GPU carve-out at boot (amdgpu VRAM reservation)
- Memory mapped to PCIe BAR space

The TTM `pages_limit = 29360128` (112 GiB) and `vis_vram_total = 64 GiB` suggest the GPU can address all of RAM. But the 1.6 GiB discrepancy between "64 GiB DIMMs" and "62.4 GiB MemTotal" matters for OOM calculations. If this is actually a 64 GiB DIMM config with 1.6 GiB hardware-reserved, the effective headroom is even less than I calculated.

**Can you confirm: is this 2×32 GiB DIMMs, or a different configuration?**

---

## System State Summary

| Metric               | Value                                                 |
| -------------------- | ----------------------------------------------------- |
| **Platform**         | AMD Ryzen AI MAX+ 395 w/ Radeon 8060S                 |
| **CPU**              | 32 threads (16C/32T)                                  |
| **RAM**              | 64 GiB unified DDR5 (62.4 GiB visible)                |
| **GPU VRAM**         | 64 GiB (shared with CPU via GTT, 112 GiB aperture)    |
| **GPU VRAM used**    | 1.56 GiB                                              |
| **Swap**             | 16.2 GiB (6.2 GiB ZRAM + 10 GiB partition), 5.1% used |
| **Disk /**           | 304/512 GiB used (61%)                                |
| **Disk /data**       | 906/1024 GiB used (89%) — ⚠️ no snapshots             |
| **NixOS generation** | system-364                                            |
| **Service modules**  | 32 registered                                         |
| **Flake inputs**     | 47                                                    |
| **Kernel**           | 7.0.9 (NixOS, PREEMPT lazy)                           |
| **Compositor**       | Niri (Wayland)                                        |
| **Session**          | 96                                                    |
