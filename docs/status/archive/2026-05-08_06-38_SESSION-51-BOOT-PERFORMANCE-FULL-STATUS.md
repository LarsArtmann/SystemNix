# Session 51: Boot Performance Sprint + Full System Status

**Date:** 2026-05-08 06:38
**Type:** Performance Optimization + Full System Audit
**Previous Session:** Session 50 (Brutal Self-Review & Dead Code Cleanup)
**Uptime:** 1 day 23h 54m

---

## Executive Summary

Three boot performance optimizations applied: ClamAV deferred from critical path (~17s saved), TPM disabled (~4.3s I/O reduction), unnecessary `network-online.target` dependencies removed (~1-2s). Boot timeout set to 2s. Estimated boot time: 36s → ~19s pending `just switch`. Root partition at 95% capacity — needs attention. `service-health-check` timer failing every ~15m (systemctl rate-limited from Crush context, needs investigation with user privileges).

---

## a) FULLY DONE ✅

| # | Change | Files | Impact |
|---|--------|-------|--------|
| 1 | **ClamAV: socket-only activation** | `security-hardening.nix` | Removed from `multi-user.target` — no longer sole blocker of `graphical.target`. Saves ~17s boot time. Daemon still activates on-demand via socket; `freshclam` timer keeps signatures current |
| 2 | **TPM disabled** | `boot.nix` | `tpm.disabled=1` kernel param — saves ~4.3s device enumeration. Comment documents re-enable conditions (systemd-cryptenroll, measured boot, UKI signing) |
| 3 | **Removed `network-online.target` from local-only services** | `photomap.nix`, `ai-stack.nix` | Photomap only talks to local immich/postgres; unsloth-setup is a one-shot installer. Both no longer wait for full network-online |
| 4 | **Boot menu timeout set to 2s** | `boot.nix` | `boot.loader.timeout = 2` — menu still accessible for generation selection but auto-boots quickly |
| 5 | **Boot performance analysis doc** | `docs/boot-performance-analysis.md` | Full analysis with critical chain, blame, timeline, all 5 optimization recommendations |

### Carried Forward from Previous Sessions (Still Done)

| # | Item | Session |
|---|------|---------|
| 6 | Dead code removal (go.mod, go-test.yml, blocklist-hash-updater) | 50 |
| 7 | Dangerous `rm -rf` in diagnostic script replaced | 50 |
| 8 | `serviceDefaultsUser` adopted in monitor365 + file-and-image-renamer | 50 |
| 9 | `services.default-services.enable` option added | 50 |
| 10 | Gatus health check monitoring (18 endpoints) | 44 |
| 11 | Shared lib adoption across 17 service modules (`harden{}`, `serviceDefaults{}`) | 46 |
| 12 | DNS CA trust system-wide via `security.pki.certificates` | 46 |
| 13 | Hermes v2026.4.30 upgrade + SQLite auto-recovery + permission fix | 49 |
| 14 | GPU headroom for niri (PYTORCH per-process memory fraction) | 42 |
| 15 | Niri BindsTo→Wants patch (survives `just switch`) | Earlier |
| 16 | ADR-004 (PartOf vs BindsTo for wallpaper) | Earlier |
| 17 | 29 flake-parts service modules fully modularized | Ongoing |
| 18 | Pre-commit hooks: gitleaks, deadnix, statix, alejandra, shellcheck, flake check | Ongoing |

---

## b) PARTIALLY DONE ⚠️

| Item | Status | What's Left |
|------|--------|-------------|
| Boot performance optimization | 4 of 5 recommendations implemented | #5 (move heavy services post-login) deferred — optional, doesn't affect critical path |
| Hardcoded port references | Convention established in caddy.nix | ~20 locations in signoz, homepage, gatus, gitea, ai-stack, voice-agents still hardcode ports |
| `serviceDefaultsUser` adoption | 2 of ~4 user services adopted | emeet-pixyd (external flake) and niri-drm-healthcheck still use inline patterns |
| `service-health-check` reliability | Timer fires every 15m, keeps failing | Script uses `systemctl is-active` which may hit rate limits; output not visible from Crush context |
| Root partition disk usage | At 95% (29GB free of 512GB) | Nix GC runs weekly; may need `just clean` or more aggressive retention |

---

## c) NOT STARTED ❌

| # | Item | Effort | Impact | Priority |
|---|------|--------|--------|----------|
| 1 | **Unsloth Studio missing `harden{}`** — `ai-stack.nix` | 5 min | High | P1 |
| 2 | **`gpu-recovery` service missing `harden{}` + `serviceDefaults{}`** — `niri-config.nix` | 5 min | High | P1 |
| 3 | **Fix `service-health-check` failing every 15m** — investigate which service is reporting down | 15 min | High | P1 |
| 4 | **Root partition cleanup** — 95% full, only 29GB free | 15 min | High | P1 |
| 5 | **Signoz scrape targets hardcoded** — 6 targets use raw IPs | 30 min | High | P2 |
| 6 | **Homepage dashboard hardcoded ports** — 7 URLs | 30 min | Medium | P2 |
| 7 | **Gatus endpoints hardcoded ports** — 7 URLs | 30 min | Medium | P2 |
| 8 | **Signoz port options use inline mkOption** — should use `serviceTypes.servicePort` | 15 min | Medium | P2 |
| 9 | **NixOS VM tests** — no `nixosTests` in flake | 2 hr | High | P2 |
| 10 | **Shell config dedup** — extract common carapace/starship/nixAliases | 1 hr | Medium | P3 |
| 11 | **Darwin CI** — CI runs ubuntu-latest; Darwin never built | 1 hr | Medium | P3 |
| 12 | **Outdated test scripts** — not in CI or justfile | 30 min | Low | P4 |
| 13 | **Raspberry Pi 3 DNS failover cluster** — hardware not provisioned | Hardware | High | P3 |
| 14 | **`photomap.nix`** — disabled but still imported in flake.nix | 2 min | Low | P4 |

---

## d) TOTALLY FUCKED UP 💥

| # | Issue | Severity | Status |
|---|-------|----------|--------|
| 1 | **`service-health-check` timer fails every ~15m** | Medium | ❌ Needs investigation — script exits with code 1 but stdout/stderr not captured in journal. Likely one of the 27 monitored services is down, or `systemctl` is rate-limited. The `%i` in the notify-failure template is not interpolated correctly (shows literal `%i` in journal). |
| 2 | **Root partition 95% full (29GB free of 512GB)** | High | ⚠️ Nix GC runs weekly but may not be enough. `/data` at 83% (140GB free of 800GB) — healthier. |
| 3 | **Boot time still 36s on current boot** | Low | ✅ Fixes applied but not yet deployed — pending `just switch`. Estimated → ~19s. |
| 4 | **Load average: 10.28 on a 16-core system** | Low | ⚠️ System is busy — 42GB RAM used of 62GB visible, 9.1GB swap used. AI workloads likely active. |
| 5 | **`notify-failure@%n` template has `%i` interpolation bug** | Low | The `ExecStart` shows `%i` literally in journal output instead of the actual service name. Template may need ` %i` → `%n` or `-%i` fix. |

---

## e) WHAT WE SHOULD IMPROVE 📈

### Immediate (This Session or Next)

1. **Root partition at 95%** — Run `just clean` or manual `nix-collect-garbage -d` + `nix store optimise`. 512GB root should not be this full with weekly GC. Check for large files: `du -sh /nix/var/nix/db/` and old generations.

2. **`service-health-check` reliability** — The script's stdout is not visible in journal (`StandardOutput=journal` but `Type=oneshot` swallows output). Need to either: (a) add explicit `echo` logging, or (b) run the script manually to see which service is failing. The 15m failure cadence is spamming the error log.

3. **Deploy boot optimizations** — `just switch` hasn't been run yet. All changes are committed but not active.

### Architecture

4. **Hardcoded port references** — ~20 locations across signoz, homepage, gatus, gitea, ai-stack, voice-agents, and authelia still hardcode ports. This violates the stated rule in AGENTS.md. Should systematically replace with `config.services.*` references.

5. **No NixOS VM tests** — Only static analysis (statix, deadnix, alejandra). Services like caddy, authelia, immich, DNS stack would benefit from integration tests verifying they actually start and respond.

6. **Health check script needs stdout logging** — Currently `Type=oneshot` with journal output, but the actual failure message (which service is down) is not captured. Add `echo` before `exit 1` or use `LOG_LEVEL` environment.

7. **`notify-failure` template** — The `%i` specifier shows literally in journal. Investigate if the template unit file is correct.

### Documentation

8. **AGENTS.md boot section** — Should document the ClamAV socket-only activation pattern and TPM disabled state so future sessions don't re-enable without understanding the tradeoff.

9. **FEATURES.md** — Should update ClamAV entry to note socket-only activation (not boot-blocking).

10. **Boot analysis doc** — `docs/boot-performance-analysis.md` exists but will need updated numbers after `just switch`.

---

## f) Top 25 Things We Should Get Done Next

### P0 — Do Now

| # | Task | Effort | Why |
|---|------|--------|-----|
| 1 | **Deploy boot optimizations** (`just switch`) | 5 min | All changes committed but not active |
| 2 | **Fix root partition (95%)** — `just clean` + investigate large files | 15 min | Risk of filling up, breaks builds |
| 3 | **Investigate `service-health-check` failures** — run script manually | 15 min | Spamming error log every 15m |

### P1 — High Impact, Low Effort

| # | Task | Effort | Why |
|---|------|--------|-----|
| 4 | **Add `harden{}` to Unsloth Studio** — `ai-stack.nix` | 5 min | Security gap in AI service |
| 5 | **Add `harden{}` + `serviceDefaults{}` to gpu-recovery** — `niri-config.nix` | 5 min | Security gap in system service |
| 6 | **Fix `notify-failure` template `%i` bug** — `scheduled-tasks.nix` | 5 min | Error messages are gibberish |
| 7 | **Add stdout logging to `service-health-check`** — echo which service failed | 5 min | Currently impossible to debug from journal |
| 8 | **Update AGENTS.md** — document ClamAV socket-only, TPM disabled | 5 min | Future sessions need context |
| 9 | **Update FEATURES.md** — ClamAV status update | 2 min | Accuracy |

### P2 — High Impact, Medium Effort

| # | Task | Effort | Why |
|---|------|--------|-----|
| 10 | **Replace hardcoded ports in SigNoz scrape targets** (6 targets) | 30 min | AGENTS.md convention violation |
| 11 | **Replace hardcoded ports in Homepage** (7 URLs) | 30 min | Same convention |
| 12 | **Replace hardcoded ports in Gatus** (7 endpoints) | 30 min | Same convention |
| 13 | **Convert SigNoz inline port options to `serviceTypes.servicePort`** | 15 min | Shared lib consistency |
| 14 | **Add basic NixOS VM test** for caddy + authelia | 2 hr | Zero integration test coverage |
| 15 | **Verify boot time after `just switch`** — update analysis doc | 5 min | Confirm ~19s estimate |

### P3 — Nice to Have

| # | Task | Effort | Why |
|---|------|--------|-----|
| 16 | **Deduplicate shell config** — extract common carapace/starship/nixAliases | 1 hr | DRY between darwin/nixos |
| 17 | **Add Darwin CI runner** (macOS GitHub Actions) | 1 hr | Cross-platform reliability |
| 18 | **Provision Raspberry Pi 3** for DNS failover cluster | Hardware | High-availability DNS |
| 19 | **Convert test scripts to justfile recipes** | 30 min | Discoverability |
| 20 | **Extract `photomap.nix` from flake.nix** if permanently disabled | 2 min | Reduce eval overhead |

### P4 — Polish

| # | Task | Effort | Why |
|---|------|--------|-----|
| 21 | **Add `MemoryMax` to emeet-pixyd** user service | 5 min | Safety |
| 22 | **Add BTRFS scrub results to SigNoz** | 30 min | Observability |
| 23 | **Archive old `docs/planning/` files** (>30 days) | 10 min | Clean docs |
| 24 | **Add `dockerPruneDates` option** to default-services | 5 min | Configurability |
| 25 | **Consider `nix-fast-build` for CI** | 2 hr | CI speed |

---

## g) Top #1 Question I Cannot Figure Out Myself

**Which service is the `service-health-check` script reporting as down?**

The script checks 27 services (22 system + 5 user) and exits 1 on any failure, but its stdout is not captured in the journal. The `systemd-analyze dump` is rate-limited from the Crush context. I need to either:

1. Run the health check script manually as user `lars` to see the output
2. Or add explicit `journalctl -t` tagging to the script so future failures are debuggable

The fix is trivial once we know which service is down — but without the output, I'm guessing.

---

## System State Snapshot

### Hardware

| Metric | Value |
|--------|-------|
| CPU | AMD Ryzen AI Max+ 395 (16C/32T) |
| RAM | 128GB total (62GB visible to OS, 42GB used, 19GB available) |
| Swap | 41GB (9.1GB used) — ZRAM compressed |
| Load | 10.28 / 10.58 / 10.36 |
| Uptime | 1 day 23h 54m |

### Disk

| Mount | Size | Used | Free | Use% |
|-------|------|------|------|------|
| `/` (BTRFS zstd) | 512G | 469G | 29G | **95%** ⚠️ |
| `/data` (BTRFS zstd:3) | 800G | 661G | 140G | 83% |

### Boot (Current — Before Deploy)

| Phase | Time |
|-------|------|
| Firmware | 5.3s |
| Loader | 5.8s |
| Kernel | 1.8s |
| Initrd | 4.2s |
| Userspace | 19.0s |
| **Total** | **36.0s** |
| Critical path blocker | `clamav-daemon.service` (sole blocker of graphical.target) |

### Boot (Expected After `just switch`)

| Phase | Estimated |
|-------|-----------|
| Firmware | ~5.3s (UEFI, not configurable) |
| Loader | ~2.0s (timeout reduced to 2s) |
| Kernel | ~1.8s |
| Initrd | ~4.2s |
| Userspace | ~2.0s (ClamAV no longer blocking) |
| **Total** | **~15s** |

### Services Monitored by Health Check

22 system + 5 user = 27 total. Script exits 1 on any failure but doesn't log which one.

### Active Fleet

| System | Status |
|--------|--------|
| evo-x2 (NixOS desktop) | ✅ Running |
| Lars-MacBook-Air (macOS) | ✅ Managed by same flake |
| rpi3-dns (Raspberry Pi 3) | 📋 Planned — hardware not provisioned |

### Codebase Stats

| Metric | Value |
|--------|-------|
| Service modules | 29 |
| Custom packages | 13 |
| Cross-platform programs | 20+ |
| Justfile commands | 90+ |
| ADRs | 4 |
| Pre-commit hooks | 6 (gitleaks, deadnix, statix, alejandra, shellcheck, flake check) |

---

## Session Timeline (Sessions 42–51)

| Session | Date | What |
|---------|------|------|
| 42 | May 6 12:00 | GPU headroom for niri (PYTORCH memory fraction) |
| 43 | May 7 06:00 | Hermes docs, health check investigation |
| 44 | May 7 18:00 | Gatus health check monitoring + service-health-check fix |
| 45 | May 7 18:55 | Build fixes, lint hardening |
| 46 | May 7 20:30 | Shared lib adoption across all service modules |
| 47 | May 8 00:23 | go-output sub-module build fix |
| 48 | May 8 00:49 | Hardening sprint — Gatus coverage, GC timer, ADRs |
| 49 | May 8 02:04 | Hermes stability fix, full system audit |
| 50 | May 8 03:25 | Brutal self-review — dead code removal, lib adoption |
| **51** | **May 8 06:38** | **Boot performance sprint (ClamAV, TPM, network deps, timeout)** |
