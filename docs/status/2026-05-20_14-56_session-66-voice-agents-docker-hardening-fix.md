# Session 66 — Voice-Agents Docker Hardening Fix + Comprehensive System Status

**Date:** 2026-05-20 14:56 CEST (Wednesday)
**Session:** 66
**Branch:** master
**Platform:** evo-x2 (AMD Ryzen AI Max+ 395, 128 GB, NixOS)

---

## Executive Summary

Applied Docker-specific hardening fixes to `voice-agents.nix` from the deployed system version (`/home/hermes/voice-agents.nix`). The deployed system had been running with `RestrictNamespaces = lib.mkForce false`, `NoNewPrivileges = lib.mkForce false`, and `SupplementaryGroups = ["docker"]` — all required for Docker container management to work under systemd hardening. The repo version was missing these overrides, causing the whisper-asr service to fail at mount namespace creation.

This is a **surgical fix** to align the repo with the running system. It does NOT resolve the underlying crash loop — whisper-asr still needs `/var/lib/whisper-asr` state directory creation (either via tmpfiles or manual).

---

## a) FULLY DONE

### Infrastructure & Core
- **Cross-platform Nix flake** — Darwin + NixOS + rpi3-dns, 80% shared via `platforms/common/`
- **Overlay system** — 12 shared + 6 Linux-only overlays, all using `mkPackageOverlay` helper
- **Secrets management** — sops-nix with age encryption, 4 sops files, auto-restart per secret
- **DNS stack** — Unbound resolver + dnsblockd (2.5M+ domains), Quad9 DoT upstream, `.home.lan` records
- **Reverse proxy** — Caddy with TLS via sops, forward auth via Authelia, 10+ virtual hosts
- **Observability** — SigNoz full stack (ClickHouse + OTel Collector), Gatus (26+ endpoints), node_exporter, cAdvisor
- **Git forge** — Forgejo fully migrated from Gitea (runner, mirrors, DNS, Caddy, Authelia all updated)
- **GPU defense in depth** — `OLLAMA_MAX_LOADED_MODELS=1`, 8 GiB overhead, per-runner fraction 0.45, niri DRM healthcheck, GPU recovery script
- **System reliability** — earlyoom, systemd watchdog (properly limited to sd_notify services), BTRFS snapshots, ZRAM swap

### Desktop
- **Niri** — running, stable (current uptime ~10h since last resume)
- **Waybar** — running with 15+ modules
- **EMEET PIXY** — camera daemon with auto-tracking, privacy mode, call detection
- **Session manager** — niri-session-manager for window save/restore
- **Wallpaper** — awww daemon with self-healing (PartOf pattern, not BindsTo)
- **Catppuccin Mocha** — universal theme across all apps

### Session 66 Specific
- **voice-agents.nix Docker hardening alignment** — Applied deployed-system fixes to repo:
  - `RestrictNamespaces = lib.mkForce false` — Docker needs namespace creation
  - `NoNewPrivileges = lib.mkForce false` — Docker needs privilege escalation for containers
  - `SupplementaryGroups = ["docker"]` — Grants systemd service access to Docker socket
- **Syntax validation passed** — `nix-instantiate --parse` confirms valid Nix syntax

### Recent Sessions (58-65)
- **Session 58-60** — Complete Gitea→Forgejo migration (all subsystems)
- **Session 61** — Runner root cause fix (escapeSystemdPath, inline token generation)
- **Session 62** — Flake update + dual-platform build fixes
- **Session 63** — vendorHash cascade fix across 7+ upstream repos
- **Session 64** — Pi 3 first boot undervoltage diagnosis
- **Session 65** — `/tmp` disk exhaustion diagnosis + `boot.tmp.cleanOnBoot` + Ollama `wantedBy = []`

---

## b) PARTIALLY DONE

| Item | Status | What's Missing |
|------|--------|----------------|
| **rpi3-dns cluster** | Config exists, Pi 3 imaged | Hardware not at remote site; needs sops + age enrollment; VRRP untested |
| **Dual-WAN failover** | Module + scripts complete | WiFi naming fixed (`wlan0`); not stress-tested under real ISP failure |
| **DNS failover (VRRP)** | Module written | Two-node cluster can't be tested until Pi 3 deployed |
| **Lockfile dedup** | 123→93 nodes (24.4% reduction) | 23 remaining duplicate Go private repo nodes (require upstream `follows` changes) |
| **~/go cleanup** | Tools moved to Nix overlays | `~/go` still 11 GB — stale module caches, GOPATH remnants |
| **Monitor365** | Package + overlay + module exists | Service in crash loop (broken env var name in module) |
| **voice-agents** | Docker hardening now correct | Still missing `/var/lib/whisper-asr` state dir — service won't start until directory exists |
| **Hermes** | Module + secrets + activation scripts | Failed to start on last boot; root cause not investigated in this session |
| **`/tmp` cleanup** | `boot.tmp.cleanOnBoot = true` committed | Fix only applies on **next boot** — 62 GB still present on running system |
| **Ollama wantedBy** | `lib.mkForce []` committed | Not deployed yet — next `just switch` required |

---

## c) NOT STARTED

1. **Create `/var/lib/whisper-asr` state directory** — Either add tmpfiles rule to voice-agents.nix or create manually
2. **Fix monitor365 env var bug** — `XDG_RUNTIME_DIR/monitor365/config.toml` is not a valid systemd env var name; needs `Environment = ["CFG_PATH=..."]` pattern instead
3. **Investigate Hermes startup failure** — Discord bot offline since last boot; check `journalctl -u hermes`
4. **Fix dnsblockd-cert-import user service** — NSS cert import failing since boot
5. **Manual `/tmp` cleanup** — Don't wait for reboot; 62 GB of stale `go-build*` and `nix-shell.*` dirs still present
6. **`~/.cache` audit** — 52 GB, likely stale HuggingFace / Go / browser caches
7. **`~/go` audit and cleanup** — 11 GB, should be mostly empty now that Go tools are Nix-managed
8. **Consolidate `/data/models` vs `/data/ai/models`** — 461 GB at `/data/models` + 119 GB at `/data/ai/` — unclear if migration was complete
9. **Lockfile remaining dedup** — 23 duplicate nodes from Go private repo transitive deps
10. **Pi 3 remote provisioning** — Hardware ready, needs physical deployment + sops enrollment
11. **Status report archive cleanup** — 100+ status reports in `docs/status/`, many duplicates from same session
12. **Deploy pending changes** — `just switch` to activate `boot.tmp.cleanOnBoot` + Ollama `wantedBy = []`
13. **AGENTS.md update** — Add whisper-asr/monitor365/hermes crash loop findings
14. **Docker storage audit** — Verify all Docker data is on `/data/docker`, not root partition
15. **Add disk space monitoring** — Gatus check or systemd timer for root disk > 85%

---

## d) TOTALLY FUCKED UP

| Issue | Severity | Details | Since |
|-------|----------|---------|-------|
| **whisper-asr 10s crash loop** | **CRITICAL** | Missing `/var/lib/whisper-asr` → mount namespacing fails → systemd retries every 10s → **spamming journal with errors every 10 seconds**. This is actively degrading system performance and filling logs. Even with Docker hardening fix applied, the service will NOT start without the state directory. | Boot (Session 65) |
| **Swap at 75% (9.9/13 GiB)** | **HIGH** | With 128 GB RAM, 75% swap usage means extreme memory pressure. Likely Docker containers + AI workloads + ComfyUI/Ollama remnants. Combined with disk I/O from `/tmp`, this is the root cause of sluggishness. | Ongoing |
| **Load average 25.83** | **HIGH** | On a 16-core CPU, this means significant queuing. The whisper-asr crash loop, disk I/O, and swap thrashing are all contributing. | Ongoing |
| **Root disk 88% (436/512G)** | **HIGH** | `/tmp` eating 62 GB + `/nix/store` at 88 GB + `~/.cache` at 52 GB. Without cleanup, will hit 100% within days. | Ongoing |
| **Hermes offline** | **HIGH** | Discord bot (messaging gateway) failed to start on boot. No investigation done yet. | Boot (Session 65) |
| **Monitor365 crash loop** | **MEDIUM** | Broken env var name in systemd service config. Service restarts repeatedly. | Boot (Session 65) |
| **Ollama wantedBy fix not deployed** | **MEDIUM** | Fix is in repo but system still has old generation. Next `just switch` needed. | Session 65 |
| **boot.tmp.cleanOnBoot not active** | **MEDIUM** | Fix committed but not deployed. `/tmp` still at 62 GB. | Session 65 |

---

## e) WHAT WE SHOULD IMPROVE

### Critical (Do Immediately)

1. **Fix whisper-asr state directory** — Add `tmpfiles` rule or `StateDirectory=whisper-asr` to create `/var/lib/whisper-asr`. The Docker hardening fix is necessary but not sufficient. The 10s crash loop is the #1 system degrader right now.
2. **Clean `/tmp` NOW** — Don't wait for next boot. Run: `sudo find /tmp -maxdepth 1 \( -name "go-build*" -o -name "nix-shell.*" -o -name "pma-test*" \) -type d -exec rm -rf {} + 2>/dev/null || true`
3. **Deploy all pending changes** — `just switch` to activate `boot.tmp.cleanOnBoot` + Ollama `wantedBy = []`

### High Priority

4. **Fix monitor365 env var** — The systemd `Environment` list contains an invalid variable name. Change from implicit path to explicit `CFG_PATH` variable.
5. **Investigate Hermes startup failure** — Check `journalctl -u hermes --since today`, fix root cause.
6. **Audit `~/go` (11 GB)** — `~/go/bin` should be empty (all tools in Nix). Remove stale module caches: `rm -rf ~/go/pkg ~/go/cache`
7. **Audit `~/.cache` (52 GB)** — Clean HuggingFace hub cache, Go test cache, browser caches.
8. **Fix dnsblockd-cert-import** — NSS cert import user service failing since boot.

### Medium Priority

9. **Consolidate AI model storage** — Determine if `/data/models` (461 GB) + `/data/llamacpp-models` (165 GB) are post-migration leftovers or active datasets. **Requires human confirmation before deletion.**
10. **Archive old status reports** — 100+ files in `docs/status/`, many duplicates per session. Move pre-session-60 to `archive/`.
11. **Add disk space gatus check** — Alert when root disk > 85%.
12. **Docker storage audit** — Verify `/data/docker` is actually used, root partition not leaking Docker data.

### Long Term / Strategic

13. **Lockfile dedup phase 3** — 23 remaining duplicate Go private repo nodes. Requires upstream repos to accept shared library inputs via `follows`.
14. **Evaluate `/tmp` as tmpfs** — With 128 GB RAM, a 32 GB tmpfs would be faster and self-cleaning. Need to evaluate nix build space requirements.
15. **Automated vendor hash updates** — Script to detect stale vendorHashes across all flake inputs and update them.
16. **Pi 3 remote provisioning** — Physical deployment + sops enrollment for DNS failover cluster.

---

## f) Top 25 Things We Should Get Done Next

### Immediate (This Session — Next 30 Minutes)

| # | Task | Impact | Effort | Blockers |
|---|------|--------|--------|----------|
| 1 | **Clean `/tmp` now** — remove 62 GB stale build caches | Frees 12% root disk instantly, reduces I/O pressure | 1 min | None |
| 2 | **Fix whisper-asr state dir** — add tmpfiles rule for `/var/lib/whisper-asr` | Stops journal spam, reduces load average | 5 min | None |
| 3 | **Deploy pending changes** — `just switch` for cleanOnBoot + ollama wantedBy | Fixes take effect immediately | 5 min | None |
| 4 | **Fix monitor365 env var** — correct broken `XDG_RUNTIME_DIR` config path | Service stops crashing | 10 min | None |
| 5 | **Investigate Hermes startup** — check logs, identify root cause | Discord bot comes back online | 15 min | None |

### Short Term (Next Session)

| # | Task | Impact | Effort | Blockers |
|---|------|--------|--------|----------|
| 6 | **Clean `~/go` (11 GB)** — audit and remove stale GOPATH/module caches | Recovers disk space | 10 min | None |
| 7 | **Audit `~/.cache` (52 GB)** — clean HuggingFace, Go, browser caches | Major space recovery | 15 min | None |
| 8 | **Fix dnsblockd-cert-import** — NSS cert import user service | Browser trust for `*.home.lan` | 10 min | None |
| 9 | **Consolidate `/data/models` → `/data/ai/models`** | Eliminates potential duplication (626 GB) | 30 min | **Requires human confirmation** |
| 10 | **Add disk space monitoring** — gatus check for root disk > 85% | Early warning before exhaustion | 15 min | None |

### Medium Term (This Week)

| # | Task | Impact | Effort | Blockers |
|---|------|--------|--------|----------|
| 11 | **Provision Pi 3 at remote site** — physical deployment + sops enrollment | DNS failover cluster goes live | 1-2 hours on-site | Hardware transport |
| 12 | **Lockfile dedup phase 3** — upstream changes for Go private repo shared inputs | 23 fewer lock nodes, faster eval | Requires upstream PRs | Upstream cooperation |
| 13 | **Archive old status reports** — move pre-session-60 to `archive/` | Cleaner docs directory | 5 min | None |
| 14 | **Evaluate `/tmp` as tmpfs** — benchmark nix build performance | Faster builds, automatic cleanup | 1 hour testing | None |
| 15 | **Docker storage audit** — verify all Docker data is on `/data/docker` | Prevent root disk surprises | 15 min | None |
| 16 | **Automated vendor hash updates** — script to detect and update stale hashes | Reduces manual cascade fixing | 2 hours | None |
| 17 | **AGENTS.md update** — add crash loop findings from sessions 65-66 | Future sessions avoid same debugging | 10 min | None |
| 18 | **Service dependency graph** — document service interdependencies | Troubleshooting, startup ordering | 2 hours | None |

### Longer Term / Strategic

| # | Task | Impact | Effort | Blockers |
|---|------|--------|--------|----------|
| 19 | **Cross-remote builds** — Darwin offloads to evo-x2 | Solves MacBook Air disk exhaustion | 3 hours setup | None |
| 20 | **Unified backup strategy** — automated BTRFS snapshots for critical data | Disaster recovery | 4 hours | None |
| 21 | **IPv6 support** — evo-x2 has link-local only | Future-proof networking | 2 hours | ISP support |
| 22 | **Secrets rotation** — rotate sops keys, age identities | Security hygiene | 1 hour | None |
| 23 | **Test rpi3-dns build** — verify `nixosConfigurations.rpi3-dns` still builds | Ensure Pi 3 image is current | 10 min | None |
| 24 | **Performance baseline** — record boot time, service start times, eval time | Detect regressions | 1 hour | None |
| 25 | **Consider ComfyUI removal cleanup** — module disabled but data may remain | Reclaim GPU VRAM / disk | 30 min | None |

---

## g) Top #1 Question I Cannot Figure Out Myself

**Did the `ai-migrate` script complete successfully, or is `/data/models` (461 GB) + `/data/llamacpp-models` (165 GB) leftover from before the migration that should now be deleted?**

The `ai-models` module expects everything under `/data/ai/` (119 GB), but there are separate directories:
- `/data/models/` — 461 GB
- `/data/llamacpp-models/` — 165 GB
- `/data/ai/` — 119 GB (the new centralized structure)

The AGENTS.md says `just ai-migrate` moves `/data/{models,cache} → /data/ai/`, but these directories still exist with massive content. If the migration was partial, deleting them would be catastrophic (626 GB of AI models potentially lost). If they're fully migrated duplicates, that's 626 GB of recoverable space on an 88%-full root partition.

**This requires human confirmation before any action. I need the user to verify whether `/data/models` and `/data/llamacpp-models` are safe to delete or if they contain active, unmigrated data.**

---

## Git Status

```
On branch master
Your branch is up to date with 'origin/master'.

Changes not staged for commit:
  modified:   modules/nixos/services/voice-agents.nix

no changes added to commit
```

### Diff Summary
```
modules/nixos/services/voice-agents.nix | 11 +++++++++--
 1 file changed, 9 insertions(+), 2 deletions(-)
```

### Changes Detail
- `extraHarden`: Added `RestrictNamespaces = lib.mkForce false` and `NoNewPrivileges = lib.mkForce false` (Docker runtime requirements for container namespace creation and privilege management)
- `extraServiceConfig`: Added `SupplementaryGroups = ["docker"]` (grants systemd service access to Docker socket)
- These fixes align the repo with the deployed system version at `/home/hermes/voice-agents.nix`

---

## System Context

| Metric | Value | Status |
|--------|-------|--------|
| Root disk `/` | 436G / 512G (88%) | **WARNING** — /tmp eating 62 GB |
| Data disk `/data` | 827G / 1.0T (81%) | OK |
| `/boot` | 165M / 2.0G (9%) | OK |
| RAM | 48G used / 62G total | High — 77% |
| Swap | 9.9G used / 13G total | **WARNING** — 75% |
| Load avg | 25.83 / 22.06 / 18.97 | **ELEVATED** |
| `/tmp` | 62 GB (2017 go-build dirs) | **CRITICAL** |
| Niri uptime | ~10h since last resume | OK |

### Services in Crash Loop (Unchanged from Session 65)

| Service | Error | Severity |
|---------|-------|----------|
| **whisper-asr** | Missing `/var/lib/whisper-asr` | **CRITICAL** |
| **monitor365** | Invalid env var name | MEDIUM |
| **hermes** | Failed to start | HIGH |
| **dnsblockd-cert-import** | NSS cert import failed | LOW |

### Recent Commits (Last 10)

```
b9c01cde docs(status): Session 65 — /tmp disk exhaustion + niri crash diagnosis + service audit
df410cdc fix(ai-stack): disable ollama auto-start at boot via wantedBy
65feb2e0 fix(boot): enable boot.tmp.cleanOnBoot to prevent /tmp disk exhaustion
a4d873dc docs(status): Session 64 — Pi 3 first boot undervoltage diagnosis
1e8fd2cc docs(status): Session 63 — vendorHash cascade fix comprehensive status report
60318ae8 refactor(overlays): enhance mkPackageOverlay with overrideAttrs support
d1ab93bb fix: resolve dual-platform build breakage from nix flake update
dd9ba72a fix(forgejo): runner token — eliminate separate service, fix escapeSystemdPath mismatch
255900c4 fix(forgejo): use RuntimeDirectory for runner token — fix permission and hardening conflict
7bbba62e fix(forgejo): write runner token to /run/ for DynamicUser compatibility
```

---

## Module Statistics

| Metric | Count |
|--------|-------|
| NixOS service modules | 29 |
| Custom packages | 13 |
| Cross-platform programs | 20+ |
| Justfile commands | 79 |
| Lines of Nix in modules/ | ~6,789 |
| Flake lock nodes | 93 (down from 123) |
| ADRs | 5 |
| Status reports in docs/status/ | 100+ |

---

_Generated by comprehensive codebase audit — modules, services, scripts, and system state evaluated._
