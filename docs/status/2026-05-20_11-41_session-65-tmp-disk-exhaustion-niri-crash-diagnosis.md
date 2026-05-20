# Session 65 — System Stability: /tmp Disk Exhaustion + Niri Crash Diagnosis

**Date:** 2026-05-20 11:41 CEST
**Boot:** 7fda3058c1ba416d8f932e6f481a6e91 (booted at ~05:01)
**Compositor:** niri unstable 2026-05-15 (cd5ac3e5)
**Platform:** evo-x2 (AMD Ryzen AI Max+ 395, 128 GB, NixOS)

---

## Executive Summary

Niri crashed twice within ~15 minutes. Root cause: **`/tmp` disk exhaustion** — 59 GB of stale nix build caches (2011 `go-build*` directories + hundreds of `nix-shell.*` dirs) filled the root partition to 88%, causing I/O contention that destabilized the compositor. Additionally, **three services are in crash loops** since the last reboot: whisper-asr (missing `/var/lib/whisper-asr`), monitor365 (broken env var), and hermes (failed to start). Swap is at 75% utilization (9.9/13 GiB), and system load is elevated (25.83).

Two fixes committed and pushed:
1. `boot.tmp.cleanOnBoot = true` — wipes `/tmp` on every boot
2. `ollama.wantedBy = lib.mkForce []` — prevents Ollama from auto-starting at boot (eliminates unnecessary GPU VRAM reservation)

**Critical: `/tmp` has NOT been cleaned yet** — still at 62 GB, 2017 go-build dirs. The fix takes effect on next boot. Manual cleanup recommended immediately.

---

## System Health

### Resources

| Metric | Value | Status |
|--------|-------|--------|
| Root disk `/` | 436G / 512G (88%) | **WARNING** — /tmp eating 62 GB |
| Data disk `/data` | 827G / 1.0T (81%) | OK |
| `/boot` | 165M / 2.0G (9%) | OK |
| RAM | 48G used / 62G total | High — 77% |
| Swap | 9.9G used / 13G total | **WARNING** — 75% swap |
| Load avg | 25.83 / 22.06 / 18.97 | **ELEVATED** |
| Processes | 7004 | High |
| `/tmp` | 62 GB (2017 go-build dirs) | **CRITICAL** |

### Major Space Consumers

| Path | Size | Notes |
|------|------|-------|
| `/nix/store` | 88 GB | Normal for this config |
| `/tmp` | 62 GB | **Stale build caches — needs cleanup** |
| `~/projects` | 90 GB | Development work |
| `~/.cache` | 52 GB | HuggingFace, Go, browser caches |
| `~/go` | 11 GB | GOPATH (should be mostly empty — Go tools moved to Nix) |
| `~/.npm` | 1.5 GB | Node.js caches |
| `~/.cargo` | 1.7 GB | Rust caches |
| `~/.local/share/Trash` | 1.6 GB | Pending trash |
| `/data/models` | 461 GB | AI models (persistent) |
| `/data/llamacpp-models` | 165 GB | llama.cpp models |
| `/data/ai` | 119 GB | Centralized AI storage |
| `/data/SteamLibrary` | 99 GB | Games |

### Services in Crash Loop (Since Boot)

| Service | Error | Impact | Severity |
|---------|-------|--------|----------|
| **whisper-asr** | `/var/lib/whisper-asr: No such file or directory` — mount namespacing fails | ASR unavailable, **10s crash loop spamming journal** | **HIGH** — retrying every 10s |
| **monitor365** | `Invalid environment variable name: XDG_RUNTIME_DIR/monitor365/config.toml` | Monitoring agent down | MEDIUM |
| **hermes** | Failed to start (messaging gateway) | Discord bot offline | HIGH |
| **dnsblockd-cert-import** | Failed (user service) | NSS cert import failed | LOW |

### Niri Crash Timeline

| Time | Event |
|------|-------|
| 04:53:48 | Niri received SIGTERM (previous boot, ran 1d 9h 12m) |
| 04:55:35 | System rebooted, niri started fresh |
| 04:56:01 | swayidle inhibit lock expired → system suspended |
| 05:01:26 | System resumed (from suspend), niri restarted |
| ~05:08 | User reports niri "crashed again" — likely the accumulated /tmp pressure |

The niri "crashes" were NOT GPU/DRM failures (no amdgpu errors, no OOM kills). They were SIGTERM-driven stops caused by system suspend/reboot cycles, exacerbated by disk I/O from the 62 GB `/tmp` cache.

---

## a) FULLY DONE

### Infrastructure & Core Services
- **NixOS config** — 35 service modules registered in `serviceModules`, all imported unconditionally
- **Cross-platform flake** — Darwin + NixOS + rpi3-dns, shared via `platforms/common/`
- **Overlay system** — 12 shared + 6 Linux-only overlays, all using `mkPackageOverlay` helper
- **Secrets management** — sops-nix with age encryption, all services wired
- **DNS stack** — Unbound resolver + dnsblockd (2.5M+ domains blocked), Quad9 DoT upstream
- **Observability** — SigNoz (ClickHouse + OTel Collector), Gatus (26+ endpoints), node_exporter, cAdvisor
- **Reverse proxy** — Caddy with TLS via sops, all port references derived from service config options
- **Git forge** — Forgejo fully migrated from Gitea (runner, mirrors, DNS, Caddy, Authelia all updated)
- **GPU defense** — Multi-layer: `OLLAMA_MAX_LOADED_MODELS=1`, GPU overhead reservation, OOM priorities, niri DRM healthcheck, GPU recovery script

### Session 65 Specific
- **`boot.tmp.cleanOnBoot = true`** committed and pushed — wipes `/tmp` on every boot
- **`ollama.wantedBy = lib.mkForce []`** committed and pushed — no more Ollama auto-start
- **Niri crash diagnosis** — confirmed SIGTERM (not GPU/DRM), traced to suspend cycle + disk I/O

### Desktop
- **Niri** — running, stable (current uptime ~6h 40m)
- **Waybar** — running
- **EMEET PIXY** — camera daemon with auto-tracking, privacy mode, call detection
- **Session manager** — niri-session-manager for window save/restore
- **Wallpaper** — awww daemon with self-healing (PartOf pattern)
- **Catppuccin Mocha** — universal theme across all apps

### Recent Sessions (58-64)
- **Session 58-60** — Complete Gitea→Forgejo migration (DNS, Caddy, Authelia, runner, password, WatchdogSec bugs all fixed)
- **Session 61** — Forgejo runner root cause fix (escapeSystemdPath, inline token generation)
- **Session 62** — Flake update + dual-platform build fixes
- **Session 63** — vendorHash cascade fix across ecosystem
- **Session 64** — Pi 3 first boot undervoltage diagnosis

---

## b) PARTIALLY DONE

| Item | Status | What's Missing |
|------|--------|----------------|
| **rpi3-dns cluster** | Config exists, Pi 3 imaged | Pi not provisioned at remote site; needs sops + age identity; VRRP not tested live |
| **Dual-WAN failover** | Module + scripts complete, works on evo-x2 | WiFi interface naming was buggy (now fixed); not stress-tested under real ISP failure |
| **DNS failover (VRRP)** | Module written, keepalived config ready | Two-node cluster can't be tested until Pi 3 is provisioned |
| **Lockfile dedup** | 123→93 nodes (24.4% reduction) | 23 remaining duplicate Go private repo nodes (require upstream changes) |
| **~/go cleanup** | Go tools moved to Nix overlays | `~/go` still 11 GB — likely stale module caches, GOPATH remnants |
| **Monitor365** | Package + overlay + module exists | Service in crash loop (broken XDG_RUNTIME_DIR env var in module) |

---

## c) NOT STARTED

- **whisper-asr missing state dir** — `/var/lib/whisper-asr` doesn't exist, needs tmpfiles rule or manual creation
- **Monitor365 env var fix** — `XDG_RUNTIME_DIR/monitor365/config.toml` is not a valid env var name, needs module fix
- **Hermes startup failure** — Failed to start on last boot, root cause unknown (didn't investigate)
- **dnsblockd-cert-import user service** — Failing since boot, NSS cert import broken
- **`/tmp` manual cleanup** — 62 GB still present, fix only applies on next boot
- **`~/.cache` audit** — 52 GB, likely has stale HuggingFace / Go / browser caches
- **`~/go` audit and cleanup** — 11 GB, Go tools moved to Nix but old GOPATH may have stale artifacts
- **`/data/models` vs `/data/ai/models` consolidation** — 461 GB at `/data/models` + 119 GB at `/data/ai/` suggests incomplete migration
- **Lockfile remaining dedup** — 23 duplicate nodes from Go private repo transitive deps
- **Pi 3 remote provisioning** — Hardware ready, needs physical deployment + sops enrollment
- **status report archive cleanup** — 100+ status reports in `docs/status/`, many from same session

---

## d) TOTALLY FUCKED UP

| Issue | Severity | Details |
|-------|----------|---------|
| **whisper-asr 10s crash loop** | **CRITICAL** | Missing `/var/lib/whisper-asr` → mount namespacing fails → systemd retries every 10s → **spamming journal with errors every 10 seconds**. This is actively degrading system performance and filling logs. Needs immediate tmpfiles rule or service disable. |
| **Swap at 75%** | **HIGH** | 9.9 GB of 13 GB swap used. With 128 GB RAM, this means memory pressure is extreme. Likely from Docker containers + AI workloads + CompyUI/Ollama remnants. Combined with disk I/O from `/tmp`, this is the root cause of sluggishness. |
| **Load average 25.83** | **HIGH** | On a 16-core CPU, this means significant queuing. The whisper-asr crash loop, disk I/O, and swap thrashing are all contributing. |
| **Ollama `wantedBy = []` pushed but NOT deployed** | **MEDIUM** | The fix is in the repo but not active on the running system. Next `just switch` will apply it. |

---

## e) WHAT WE SHOULD IMPROVE

### Critical (Do This Session)

1. **Fix whisper-asr crash loop** — Either add `StateDirectory=whisper-asr` to the service or add a tmpfiles rule for `/var/lib/whisper-asr`. The 10s retry loop is killing disk I/O and journal space.
2. **Clean `/tmp` NOW** — Don't wait for next boot. Run: `find /tmp -maxdepth 1 \( -name "go-build*" -o -name "nix-shell.*" -o -name "pma-test*" \) -type d -exec rm -rf {} +`
3. **Fix monitor365 env var** — The `XDG_RUNTIME_DIR/monitor365/config.toml` is a broken env var name. Needs module fix.

### High Priority

4. **Investigate Hermes startup failure** — Discord bot has been offline since last boot.
5. **Audit `~/go` (11 GB)** — Go tools are all in Nix overlays now. `~/go` should be mostly empty. Clean stale module caches.
6. **Audit `~/.cache` (52 GB)** — Likely stale HuggingFace caches, Go test caches, browser caches. `~/.cache/go-build` alone can be huge.
7. **Consolidate `/data/models` and `/data/ai/models`** — The `ai-models` migration may be incomplete. 461 GB at `/data/models` + 119 GB at `/data/ai/` suggests duplication or leftover pre-migration data.

### Medium Priority

8. **Archive old status reports** — 100+ files in `docs/status/`, most from May 11-20. Move pre-session-60 to `archive/`.
9. **Lockfile dedup** — 23 remaining duplicate nodes from Go private repos. Requires upstream changes to accept shared library inputs.
10. **Status report format standardization** — Mix of SCREAMING_SNAKE and lowercase filenames. Should adopt consistent convention.

### Long Term

11. **Consider `/tmp` as tmpfs** — With 128 GB RAM, a 32 GB tmpfs for `/tmp` would be faster and self-cleaning on reboot. But nix builds can be large — need to evaluate.
12. **Docker storage on `/data`** — Confirmed in AGENTS.md (`/data/docker`), but verify Docker data is actually there and not leaking to root.
13. **Automated disk space monitoring** — Add a gatus check or systemd timer that alerts when root disk > 85%.

---

## f) Top 25 Things We Should Get Done Next

### Immediate (This Session)

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 1 | **Clean `/tmp` now** — remove 62 GB stale build caches | Frees 12% root disk instantly | 1 min |
| 2 | **Fix whisper-asr crash loop** — add tmpfiles rule for `/var/lib/whisper-asr` | Stops journal spam, reduces I/O | 5 min |
| 3 | **Fix monitor365 env var** — correct the broken `XDG_RUNTIME_DIR` config path | Service stops crashing | 10 min |
| 4 | **Investigate Hermes startup failure** — check logs, fix root cause | Discord bot comes back online | 15 min |
| 5 | **Deploy pending changes** — `just switch` to activate boot.tmp.cleanOnBoot + ollama wantedBy | Both fixes take effect | 5 min |

### Short Term (Next Session)

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 6 | **Clean `~/go` (11 GB)** — audit and remove stale GOPATH/module caches | Recovers disk space | 10 min |
| 7 | **Audit `~/.cache` (52 GB)** — clean HuggingFace, Go, browser caches | Major space recovery | 15 min |
| 8 | **Consolidate `/data/models` → `/data/ai/models`** — check if ai-migrate was run | Eliminates potential duplication (461+119 GB) | 30 min |
| 9 | **Fix dnsblockd-cert-import user service** — NSS cert import failing since boot | Browser trust for *.home.lan | 10 min |
| 10 | **Add disk space monitoring** — gatus check for root disk > 85% | Early warning before exhaustion | 15 min |

### Medium Term

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 11 | **Provision Pi 3 at remote site** — physical deployment + sops enrollment | DNS failover cluster goes live | 1-2 hours on-site |
| 12 | **Lockfile dedup phase 3** — upstream changes for Go private repo shared inputs | 23 fewer lock nodes, faster eval | Requires upstream PRs |
| 13 | **Archive old status reports** — move pre-session-60 to `archive/` | Cleaner docs directory | 5 min |
| 14 | **Evaluate `/tmp` as tmpfs** — benchmark nix build performance on tmpfs vs disk | Faster builds, automatic cleanup | 1 hour testing |
| 15 | **Docker storage audit** — verify all Docker data is on `/data/docker`, not root | Prevent root disk surprises | 15 min |
| 16 | **Automated vendor hash updates** — script that detects stale hashes and updates | Reduces manual cascade fixing | 2 hours |
| 17 | **whisper-asr module hardening** — add proper StateDirectory, Restart=on-failure with delay | Prevents future crash loops | 20 min |
| 18 | **AGENTS.md update** — add whisper-asr/monitor365/hermes crash loop findings | Future sessions avoid same debugging | 10 min |

### Longer Term / Strategic

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 19 | **Cross-remote builds** — Darwin offloads to evo-x2 | Solves MacBook Air disk exhaustion | 3 hours setup |
| 20 | **Unified backup strategy** — automated BTRFS snapshots for critical data | Disaster recovery | 4 hours |
| 21 | **IPv6 support** — evo-x2 has link-local only, Unbound `do-ip6=false` workaround in place | Future-proof networking | 2 hours |
| 22 | **Secrets rotation** — rotate sops keys, age identities | Security hygiene | 1 hour |
| 23 | **Test rpi3-dns build** — verify `nixosConfigurations.rpi3-dns` still builds | Ensure Pi 3 image is current | 10 min |
| 24 | **Service dependency graph** — document which services depend on which | Troubleshooting, startup ordering | 2 hours |
| 25 | **Performance baseline** — record boot time, service start times, eval time | Detect regressions | 1 hour |

---

## g) Top #1 Question I Cannot Answer Myself

**Did the `ai-migrate` script complete successfully, or is `/data/models` (461 GB) a leftover from before the migration that should now be deleted?**

The `ai-models` module expects everything under `/data/ai/` (119 GB), but there's a separate `/data/models/` (461 GB) and `/data/llamacpp-models/` (165 GB) still on disk. The AGENTS.md says `just ai-migrate` moves `/data/{models,cache} → /data/ai/`, but these directories still exist with significant content. If the migration was partial or if these are separate datasets, deleting them would be catastrophic (745 GB of AI models). If they're fully migrated duplicates, that's 745 GB of recoverable space.

**This requires human confirmation before any action.**

---

## Git Log (Last 30 Commits)

```
df410cdc fix(ai-stack): disable ollama auto-start at boot via wantedBy
65feb2e0 fix(boot): enable boot.tmp.cleanOnBoot to prevent /tmp disk exhaustion
a4d873dc docs(status): Session 64 — Pi 3 first boot undervoltage diagnosis
1e8fd2cc docs(status): Session 63 — vendorHash cascade fix comprehensive status report
60318ae8 refactor(overlays): enhance mkPackageOverlay with overrideAttrs support
d1ab93bb fix: resolve dual-platform build breakage from nix flake update
dd9ba72a fix(forgejo): runner token — eliminate separate service, fix escapeSystemdPath mismatch
255900c4 fix(forgejo): use RuntimeDirectory for runner token — fix permission and hardening conflict
7bbba62e fix(forgejo): write runner token to /run/ for DynamicUser compatibility
6cbae086 docs(status): Session 60 final status report — comprehensive post-migration audit
e0728ece fix(forgejo): always regenerate runner registration token on boot
b22abfe7 fix(health-check): update service-health-check for post-Forgejo migration
5943d171 docs(status): Session 60 — Forgejo WatchdogSec bug fix + comprehensive project audit
b63ceca0 fix(forgejo): remove dangerous WatchdogSec and clean up stale Gitea references
44d02671 fix(forgejo): switch runner package from gitea-actions-runner to forgejo-runner
daf242d8 chore(rpi3-dns): migrate SSH authorized keys to nix-ssh-config and update lockfile
c1632618 fix(forgejo): add Nix-managed state dir ownership via tmpfiles Z rule
a4423572 docs(status): Session 59 — comprehensive status: Forgejo down + password fix
4b59f143 fix(forgejo): fix admin-password ownership with root ExecStartPre
45690068 docs(status): Session 58 — final status: service fixes + complete Forgejo migration
04e9cced feat(forgejo): complete Gitea→Forgejo migration — rename all subdomain references
a99a1c7a docs(status): Session 58 — service startup fixes for Forgejo, Caddy, nvme-metrics
949191b9 fix(services): correct WatchdogSec usage and improve service hardening
4cc0a208 docs(status): Session 57 — comprehensive status after unsloth removal
e69fe17e fix(dns): extract shared DNS resolver module — eliminate config drift between evo-x2 and rpi3-dns
629a61d6 docs(status): Session 56 — art-dupl stats bug fix, branch migration, 253/253 BDD
df13983a chore(flake): migrate art-dupl from fork branch to master
c376e9ce docs(usb-verification): add SanDisk Ultra Fit 128GB verification report for Pi 3 DNS node
09447925 chore(scripts): track usb-diagnostic.sh for SanDisk USB stick diagnostics
04f0d813 fix(overlays): fix all 5 broken overlay packages — 13/13 now build
```

---

## Session 65 Commits

| Commit | Description |
|--------|-------------|
| `65feb2e0` | `fix(boot): enable boot.tmp.cleanOnBoot to prevent /tmp disk exhaustion` |
| `df410cdc` | `fix(ai-stack): disable ollama auto-start at boot via wantedBy` |
