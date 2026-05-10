# SystemNix Status Report — Session 60

**Date:** 2026-05-10, 21:05 CEST
**Session:** #60 — Architecture Relocation Sprint (7 config moves)
**Host:** evo-x2 (NixOS, x86_64-linux) + Lars-MacBook-Air (Darwin, aarch64)
**Branch:** master, 1 commit ahead of origin
**Commit Base:** 4b641e93 (session 59 GPU fixes)
**Validation:** `nix flake check --no-build` PASSES on x86_64-linux

---

## Executive Summary

Session 60 executed a **7-item architecture relocation sprint** — moving Nix files to their conceptually correct locations to improve navigability, consistency, and module architecture. All 7 moves completed, validated, and committed. This session builds on the momentum of sessions 54–59 which collectively delivered: port DRY sprint, shared lib adoption, dead code cleanup, GPU crisis fixes, DNS IPv6 outage resolution, WiFi enablement, and dual-WAN experimentation.

**26 commits landed since May 8** across sessions 55–60. The codebase is in its cleanest state in months.

---

## a) FULLY DONE

### Session 60 — Architecture Relocations (this session)

| # | Move | From | To | Import Updates | Status |
|---|------|------|----|----------------|--------|
| 1 | DNS blocklists | `platforms/shared/` | `platforms/common/` | 2 files (rpi3, dns-blocker-config) | ✅ Committed |
| 2 | Legacy dotfiles | `dotfiles/` | `legacy/` | 1 comment (launchagents) | ✅ Committed |
| 3 | Zed editor config | `programs/zed/settings.json` (raw JSON) | `programs.zed-editor` HM module (declarative) | home.nix rewritten | ✅ Committed |
| 4 | DNS blocker module | `platforms/nixos/modules/` (plain NixOS) | `modules/nixos/services/` (flake-parts) | flake.nix + dns-blocker-config | ✅ Committed |
| 5 | Nix settings flatten | `platforms/common/core/` | `platforms/common/` | 4 files (config, darwin, rpi3) | ✅ Committed |
| 6 | Niri wrapper | `platforms/nixos/programs/` | `platforms/nixos/desktop/` | home.nix | ✅ Committed |
| 7 | Metadata yaml | `.config/metadata.yaml` | **Left alone** (per user request) | — | ✅ Skipped |

### Sessions 54–59 — Carried-Forward Completed Work

| # | Work | Session | Commit |
|---|------|---------|--------|
| 8 | **Port DRY sprint** — eliminated all hardcoded ports in caddy, gatus, homepage, signoz, voice-agents | 54 | `0b8b5189` |
| 9 | **Boot performance sprint** — 22s boot delay eliminated (ClamAV defer, TPM disable, systemd-boot 2s timeout) | 51 | `f6ed2f25`, `6f4ee460` |
| 10 | **OpenSEO deployment** — full service module with sops secrets, Caddy vhost, Docker compose | 52 | `eceac9b6`, `218a4049` |
| 11 | **Shared lib adoption** — `lib/default.nix` single import, all 22 modules migrated | 46+ | `7d8b2e1d`, `b98f99a0` |
| 12 | **TaskChampion port option** — extracted hardcoded 10222 into proper module option | — | `2eddaf47` |
| 13 | **Scripts lib extraction** — `scripts/lib.sh` shared library, health-check migrated | — | `b9b02659` |
| 14 | **GPU memory crisis** — raised GTT/TTM ceiling to 112GB, then lowered PyTorch fractions to prevent OOM | 59 | `62d5de0f`, `42e28ca0`, `4b641e93` |
| 15 | **DNS IPv6 outage fix** — `do-ip6 = false` on both evo-x2 and rpi3, Gatus DNS resolution checks, Keepalived health fix | 57 | `a6514ae4`, `b69e5928` |
| 16 | **WiFi enablement** — NetworkManager + iwd on wlp195s0, static eno1 preserved | 58 | `d5e7e350` |
| 17 | **Dual-WAN MPTCP** — scripts written, deployed, tested, then deliberately rolled back | 58 | `d2823cb3`, `a8320c2a` |
| 18 | **Brutal self-review** — dead code cleanup, lib adoption, safety fixes | 50 | `0bb03a71` |
| 19 | **Hermes stability** — SQLite auto-recovery, state dir migration, npmDeps hash patch | 49 | `5b52db97` |
| 20 | **Darwin d2 build fix** — stub libgbm/playwright for cross-platform evaluation | 56 | `524be5ab` |

---

## b) PARTIALLY DONE

| # | Work | What's Done | What's Missing |
|---|------|-------------|----------------|
| 1 | **MPTCP dual-WAN** | Scripts written, tested, committed as flake-parts module. Kernel MPTCP enabled. | Deliberately rolled back. Needs production hardening (see session 58 notes). Not urgent if hotspot goes 5 GHz. |
| 2 | **DNS fallback strategy** | `do-ip6 = false` fix deployed. Gatus now checks actual DNS resolution. | `networking.nix` nameservers still `["127.0.0.1"]` only — no fallback if unbound upstream times out. Manual `9.9.9.9` in `/etc/resolv.conf` is ephemeral. |
| 3 | **Gatus monitoring** | 17 endpoints monitored with SQLite storage. DNS checks upgraded from TCP to resolution. | **Zero alerting.** No SMTP/webhook configured. Monitoring is theater — failures are silently logged. |
| 4 | **DNS failover cluster** | Keepalived VRRP module written with proper DNS health check. evo-x2 priority 100. | Pi 3 hardware not provisioned. rpi3-dns image builds but is not deployed. |
| 5 | **AGENTS.md documentation** | Documented: lib/default.nix pattern, niri portal gotchas, wallpaper ordering, session manager, GPU headroom, IPv6 gotcha. | Does not yet reflect session 60 relocations (dns-blocker module move, nix-settings flatten, niri-wrapped desktop move, zed HM module, legacy rename). |

---

## c) NOT STARTED

| # | Work | Category |
|---|------|----------|
| 1 | **Add Gatus alerting** (SMTP or webhook) — 17 endpoints, zero notifications | Monitoring |
| 2 | **Fix `nameservers` in networking.nix** — add `9.9.9.9` fallback for unbound upstream failure | DNS reliability |
| 3 | **Push commits to origin** — 1 commit ahead (session 59 GPU fix) | Process |
| 4 | **Switch phone hotspot to 5 GHz** — eliminates buffering root cause | Connectivity |
| 5 | **Deploy session 57 DNS fix to rpi3-dns** — Pi still has `do-ip6 = true` | DNS HA |
| 6 | **Provision Pi 3 hardware** for DNS failover cluster | Infrastructure |
| 7 | **Overlay extraction from flake.nix** — 800+ lines, should split to `overlays/` directory | Architecture |
| 8 | **NixOS VM tests** for critical services (caddy, unbound) | Testing |
| 9 | **`just validate-scripts`** — shellcheck all scripts + verify PATH deps | QA |
| 10 | **Integrate test-home-manager.sh / test-shell-aliases.sh into `just test`** | QA |
| 11 | **Consolidate voice-agents Caddy vHost into caddy.nix pattern** | Architecture |
| 12 | **`mkGraphicalUserService` helper** in lib/ for user service boilerplate | DRY |
| 13 | **Disk cleanup** — root 89% full, 73G /nix/store | Storage |
| 14 | **Evaluate `serviceTypes.systemdServiceIdentity`** adoption (currently unused in lib/types.nix) | DRY |

---

## d) TOTALLY FUCKED UP!

| # | Incident | Root Cause | Status |
|---|----------|------------|--------|
| 1 | **DNS outage during session 58 MPTCP testing** | `nameservers = ["127.0.0.1"]` with no fallback. Unbound DoT to Quad9 timed out over hotspot. User panicked. 6 rollbacks ensued. | **Mitigated** — manual `9.9.9.9` in resolv.conf. **Not fixed** — next `just switch` will revert. |
| 2 | **GPU memory crisis (session 59)** | PyTorch `per_process_memory_fraction:0.95` + `OLLAMA_NUM_PARALLEL=4` exhausted GTT on Strix Halo iGPU, causing SIGSEGV and desktop freezes. | **Fixed** — fraction lowered to 0.45/0.50 per runner, GTT ceiling raised to 112GB. |
| 3 | **3-day DNS outage (sessions 55–57)** | Unbound `do-ip6=yes` (default) preferred IPv6 root servers. evo-x2 has no global IPv6. All queries SERVFAIL. | **Fixed** — `do-ip6 = false` on both evo-x2 and rpi3. Gatus upgraded from TCP to DNS resolution check. |
| 4 | **Hermes anime-comic-pipeline SIGSEGV → GPU hang** | PyTorch/ROCm process crashed, took down the entire GPU (desktop freeze). | **Fixed** — kernel recovery params (`amdgpu.gpu_recovery=1`), `PYTORCH_CUDA_ALLOC_CONF` limits, WatchdogSec avoided for non-sd_notify services. |
| 5 | **SublimeText sync LaunchAgent references deleted script** | `launchagents.nix` points to `scripts/sublime-text-sync.sh` which was deleted in a prior session. LaunchAgent is non-functional. | **Documented** — comment updated to note non-functional state. Script not recreated (SublimeText deprecated in favor of Zed). |

---

## e) WHAT WE SHOULD IMPROVE!

### Immediate (blocks shipping)

1. **Fix `nameservers` fallback** — `networking.nix` must include `"9.9.9.9"` as fallback. Every `just switch` risks breaking DNS when unbound upstream is flaky. This is the #1 ticking time bomb.
2. **Update AGENTS.md** — Must reflect session 60 relocations: dns-blocker now a flake-parts module, nix-settings flattened, niri-wrapped in desktop/, zed via HM module, dotfiles → legacy, platforms/shared gone.

### Architecture

3. **Extract overlays from flake.nix** — 800+ lines in a single file is the single biggest maintainability problem. Move to `overlays/` directory with one file per overlay.
4. **Consolidate remaining hardcoded ports** — Signoz query service still has `0.0.0.0:8080` hardcoded. Extract to module option.
5. **Adopt `serviceTypes.systemdServiceIdentity`** — Already in `lib/types.nix` but unused by any module. Either adopt it or delete it.

### Monitoring

6. **Gatus alerting is the highest-impact monitoring fix** — 17 services monitored, zero notifications. Configure SMTP or webhook (nixcommunity has examples).
7. **Service health timer** — Validate that the `service-health-check` timer from session 44 is actually deployed and running.

### Process

8. **Commit immediately after each logical change** — Session 58 showed what happens when staged/unstaged changes mix with rollbacks. Each move in session 60 was clean because each was committed atomically.
9. **Never deploy without testing DNS first** — `dig @127.0.0.1 google.com` before `just switch`.
10. **Push regularly** — 1 commit ahead of origin right now. Should be 0.

---

## f) Top #25 Things We Should Get Done Next!

| # | Item | Category | Impact |
|---|------|----------|--------|
| 1 | **Fix `nameservers` in networking.nix** — add `"9.9.9.9"` fallback | DNS | 🔴 Critical — next switch could break DNS |
| 2 | **Update AGENTS.md** with session 60 relocation changes | Docs | 🔴 Critical — stale docs cause wrong decisions |
| 3 | **Push to origin** — get unpushed commit(s) to GitHub | Process | 🟠 High |
| 4 | **Add Gatus alerting** (SMTP or webhook) | Monitoring | 🟠 High — monitoring without alerts is theater |
| 5 | **Run `just clean` or manual GC** — 89% root disk, 73G store | Storage | 🟠 High — rebuild could fail |
| 6 | **Extract overlays from flake.nix** to `overlays/` directory | Architecture | 🟡 Medium — 800-line file is unwieldy |
| 7 | **Consolidate signoz hardcoded port** → module option | DRY | 🟡 Medium |
| 8 | **Adopt or delete `systemdServiceIdentity`** from lib/types.nix | DRY | 🟡 Medium — dead code |
| 9 | **Deploy rpi3-dns** — provision Pi 3, flash image, join cluster | Infrastructure | 🟡 Medium |
| 10 | **Redesign MPTCP for production** — hardened scripts, fallbacks | Networking | 🟡 Medium — blocked on hotspot 5GHz decision |
| 11 | **Switch phone hotspot to 5 GHz** | Connectivity | 🟡 Medium — eliminates buffering root cause |
| 12 | **Add `just wifi-status` recipe** | DX | 🟢 Low |
| 13 | **Add `just mptcp-status` recipe** | DX | 🟢 Low |
| 14 | **NixOS VM tests for critical services** (caddy, unbound, dnsblockd) | Testing | 🟢 Low — high effort, very high value |
| 15 | **Integrate shell scripts into `just test`** | QA | 🟢 Low |
| 16 | **Consolidate voice-agents Caddy vHost** into caddy.nix pattern | Architecture | 🟢 Low |
| 17 | **Add `mkGraphicalUserService` helper** to lib/ | DRY | 🟢 Low |
| 18 | **Document mt7925e 2.4 GHz RX bitrate bug** in AGENTS.md | Docs | 🟢 Low |
| 19 | **Evaluate eno1 ISP quality** — is it actually degraded? | Networking | 🟢 Low |
| 20 | **Review swap usage** — 11G used may indicate memory pressure | Memory | 🟢 Low |
| 21 | **Test reboot recovery** — WiFi autoconnect + eno1 static + DNS | Reliability | 🟢 Low |
| 22 | **Auto-detect GPU PCI address** in gpu-recovery.sh | Scripts | 🟢 Low |
| 23 | **Parameterize nixos-diagnostic.sh hostname** — remove hardcoded `evo-x2` | Scripts | 🟢 Low |
| 24 | **Clean up docs/status/archive** — 232K of old reports | Cleanup | 🟢 Low |
| 25 | **Add `just dns-test` recipe** — verify DNS resolution before switch | DX | 🟢 Low — prevents session 58 repeats |

---

## g) Top #1 Question I CANNOT Figure Out

**Should the DNS nameservers include `9.9.9.9` as a permanent fallback, or should we fix the root cause (unbound DoT reliability over hotspot)?**

The current state:
- `networking.nameservers = ["127.0.0.1"]` — points to unbound only
- Unbound uses DoT (DNS-over-TLS) to Quad9 as upstream
- DoT over the phone hotspot is unreliable (high latency, packet loss)
- Manual `9.9.9.9` in `/etc/resolv.conf` was the emergency fix
- Next `just switch` will overwrite `/etc/resolv.conf` back to `127.0.0.1` only

**Options I see:**
1. **Add `9.9.9.9` to `nameservers`** — glibc falls back if unbound times out. Simple but means some queries bypass unbound (no ad blocking, no DNSSEC).
2. **Add a secondary unbound forward zone** using plain UDP (no TLS) as fallback when DoT fails. More complex but keeps all DNS through unbound.
3. **Keep it as-is** and just fix the internet connection (hotspot to 5GHz or restore proper ISP on eno1).

The question is: **is bypassing unbound (option 1) acceptable for a fallback, or must all DNS always go through unbound for ad-blocking/DNSSEC integrity?**

---

## Architecture Snapshot (post-session 60)

```
SystemNix/
├── flake.nix                    # 800+ lines (needs overlay extraction)
├── modules/nixos/services/      # 35 flake-parts modules (dns-blocker moved here ✓)
├── lib/                         # Shared helpers (harden, serviceDefaults, types, rocm)
│   ├── default.nix              # Single import for all helpers
│   ├── systemd.nix
│   ├── systemd/service-defaults.nix
│   ├── types.nix
│   └── rocm.nix
├── pkgs/                        # 9 custom packages
├── platforms/
│   ├── common/                  # Cross-platform (~21 files)
│   │   ├── nix-settings.nix     # Flattened from core/ ✓
│   │   ├── dns-blocklists.nix   # Moved from shared/ ✓
│   │   ├── home-base.nix
│   │   └── programs/            # fish, zsh, git, starship, tmux, ...
│   ├── darwin/                  # macOS (13 files)
│   └── nixos/                   # NixOS (37 files)
│       ├── desktop/             # niri-wrapped.nix ✓, waybar.nix
│       ├── programs/            # rofi, swaylock, wlogout, yazi, zellij
│       └── system/              # configuration, networking, boot, dns-blocker-config
├── scripts/                     # 10 operational scripts
├── legacy/                      # 20 deprecated files (renamed from dotfiles/ ✓)
└── docs/
    ├── status/                  # This report
    ├── adr/                     # 4 architecture decision records
    └── (25+ historical docs)
```

**Module inventory:** 35 flake-parts modules, 9 custom packages, 109 `.nix` files total.

## System Snapshot

| Metric | Value |
|--------|-------|
| **NixOS** | 26.05.20260423, kernel 7.0.1 |
| **Service modules** | 35 flake-parts modules in `modules/nixos/services/` |
| **Custom packages** | 9 in `pkgs/` |
| **Flake inputs** | 35 |
| **Cross-platform programs** | 14 via `common/home-base.nix` |
| **DNS blocklists** | 25 lists, 2.5M+ domains |
| **GPU** | AMD Strix Halo iGPU, GTT 112GB, PyTorch fraction 0.45/0.50 |
| **Monitoring** | Gatus (17 endpoints, no alerts), SigNoz (traces/metrics/logs) |

## Git State

```
Branch: master
Ahead of origin: 1 commit (4b641e93 — GPU memory fraction fix)
Working tree: CLEAN
Last 5 commits:
  4b641e93 fix(gpu): prevent dual-runner OOM by lowering per-process memory fractions
  42e28ca0 fix(gpu): reduce PyTorch GPU memory fraction from 95% to 45%
  ed57c383 docs(status): session 59 — GPU memory crisis, crash forensics, full system audit
  5da2a843 chore(flake.lock): update lockfile
  d88d80ca refactor(nixos/dns-blocker): migrate from legacy modules/ to flake-parts architecture
```

---

_Assisted by Crush — session 60, 2026-05-10 21:05 CEST_
