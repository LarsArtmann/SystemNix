# SystemNix — Comprehensive Status Report

**Date:** 2026-05-21 17:34 (Session 74)
**Machine:** evo-x2 (GMKtec NucBox, AMD Ryzen AI 9 HX 370, 64GB RAM, Lexar 2TB NVMe)
**Platform:** NixOS 26.05 (unstable), kernel 7.0.8, systemd 260.1
**Branch:** master — **1 commit ahead of origin**

---

## Executive Summary

Boot performance reduced from **2m 13s → 58s** (deployed, verified). Additional fixes committed but **NOT deployed** should bring boot to **~35s**. A mass restructuring of service startup targets moved all user-facing services to `graphical.target`. ComfyUI module deleted entirely. The system is **functional but under memory pressure**: swap is 13Gi/13Gi full, load average 23/19/14, and Nix store GC is overdue (7,848 paths eligible, disk at 86%).

**Critical action needed:** Deploy committed changes and reboot to verify the full boot optimization stack.

---

## A) FULLY DONE ✅

### Boot Performance Crisis (Sessions 71–73)

| What | Before | After | Savings |
|------|--------|-------|---------|
| `systemd-tmpfiles-setup` | 44.9s | 303ms | **44.6s** |
| Total boot time | 2m 13s | 58s (deployed) | **75s** |
| Unbound preStart (committed) | ~4s | ~0s | **4s** |
| Hermes fixPermissions (committed) | ~18s | ~0s (fast-path) | **18s** |
| **Expected final boot** | **2m 13s** | **~35s** | **~98s** |

**Root cause:** `/tmp` on BTRFS accumulated stale Chromium/SDDM sockets. `systemd-tmpfiles-setup` traversed all of them serially on every boot.

**Fixes applied:**
1. `boot.tmp.useTmpfs = true` — `/tmp` is now tmpfs, fresh every boot (**deployed, verified**)
2. `systemd.services.unbound.preStart` override — skip `unbound-anchor` network fetch (**committed, not deployed**)
3. Hermes `fixPermissionsScript` fast-path — check top-level dir owner/mode before expensive recursive chown (**committed, not deployed**)

### Service Target Restructuring (Session 73)

Moved from `multi-user.target` → `graphical.target`:
- `hermes` (AI assistant)
- `homepage-dashboard` (web dashboard)
- `dnsblockd` (DNS blocker)
- `signoz`, `signoz-otel-collector`, `cadvisor` (monitoring)
- All Docker containers via `mkDockerServiceFactory` (twenty, manifest, openseo, voice-agents, etc.)
- `docker` daemon itself

**NOT moved** (correctly kept on `multi-user.target`):
- `dual-wan` (network infrastructure)
- `unbound` (DNS resolver)
- Other network-critical services

### ComfyUI Deletion (Session 73)

- Deleted `modules/nixos/services/comfyui.nix` (112 lines)
- Removed from `serviceModules` in `flake.nix`
- Removed `comfyui.enable = false` from `configuration.nix`
- Disabled since Session 38, confirmed dead

### Other Completed Work (Sessions 67–70)

- Nixpkgs migrated to unstable channel
- Hermes upgraded to v2026.5.16
- Self.rev anti-pattern eliminated across 29 repos
- `update-vendor-hash.sh` script added for automated Go vendorHash fixes
- Voice-agents docker.tmpfiles wired into systemd (whisper-asr crash-loop fix)
- AGENTS.md stripped to agent-critical knowledge only

### Flake Validation

`just test-fast` passes clean — all 35 NixOS modules evaluate correctly.

---

## B) PARTIALLY DONE ⚠️

### Boot Optimization Stack

| Fix | Status | Deployed? |
|-----|--------|-----------|
| `/tmp` as tmpfs | ✅ Committed & deployed | ✅ Yes |
| Unbound preStart override | ✅ Committed | ❌ No |
| Hermes fast-path perms | ✅ Committed | ❌ No |
| Service target restructuring | ✅ Committed | ❌ No |
| ComfyUI deletion | ✅ Committed | ❌ No |

**All code is correct and committed. Just needs `just switch` + reboot.**

### TODO_LIST.md

Updated in Session 73 but already stale — doesn't reflect Session 74 work, still references "7,479 paths eligible" (now 7,848), swap was 9.2Gi (now 13Gi full).

### Nix Store GC

Identified as needed since Session 72. Still not run. Disk has gone from 82% → 86%.

---

## C) NOT STARTED 📋

### Hermes Python Dependencies

From TODO_LIST.md Priority 0 — NOT addressed:
- `firecrawl` for web_search tool (pip unavailable in Nix)
- `edge-tts` for TTS
- `fal` for image generation
- `exa` for web search alt backend
- Secondary LLM provider configuration (OpenRouter/OpenAI fallback)
- SSH deploy key for Hermes git sandbox access

### Documentation & Tooling
- `nix-colors` integration (wire to Home Manager, migrate 17+ hardcoded colors)
- Deploy Dozzle for Docker log tailing at `logs.home.lan`
- Create `just status` command for automated status generation

### External Repos
- Convert `go-auto-upgrade` `path:` inputs to SSH URLs
- Create shared flake-parts template (mkGoPackage, checks, devshells)
- Flake inputs audit (47 inputs, some may be stale/unused)

### Hardware
- Provision Pi 3 for DNS failover cluster
- Wire Pi 3 as secondary DNS

---

## D) TOTALLY FUCKED UP 💀

### System Memory Pressure — CRITICAL

| Metric | Value | Status |
|--------|-------|--------|
| **Swap usage** | 13Gi / 13Gi (99.3%) | 🔴 FULL |
| **Load average** | 23.12 / 19.43 / 14.35 | 🔴 CRITICAL |
| **RAM used** | 35Gi / 62Gi (56%) | 🟡 Moderate |
| **Disk** | 425Gi / 512Gi (86%) | 🟡 High |
| **Nix GC eligible** | 7,848 paths | 🟡 Overdue |

The swap being 99.3% full with load average 23 on a 16-core machine means something is aggressively consuming memory. This has worsened from 9.2Gi swap (Session 72) to 13Gi (now). **Root cause unknown — needs investigation.**

Likely culprits:
- Ollama GPU model holding system RAM fallback
- Docker containers (voice-agents, twenty, etc.) leaking memory
- SigNoz ClickHouse consuming growing memory
- Browser tabs (Chromium) consuming swap

### `nh os switch` Broken in Direnv

`nh` crashes inside nix-shell/direnv with `Failed to resolve base output path to store path: No such file or directory`. The temp directory `/tmp/nix-shell.*/nh-os*/result` gets cleaned up before `nh` resolves the symlink. Workaround: use `sudo /nix/store/.../bin/switch-to-configuration switch` directly. This blocks clean deploys.

---

## E) WHAT WE SHOULD IMPROVE 🔧

1. **Deploy discipline** — We've had committed-but-undeployed changes for hours. The `nh` bug makes deploys painful. Fix: document the workaround in AGENTS.md or add a `just deploy` recipe.
2. **Memory monitoring** — No automated alerting on swap exhaustion. SigNoz is deployed but alert routing (critical→Discord) is not configured.
3. **GC automation** — Nix store should auto-GC. 7,848 stale paths and growing. Add `nix.gc` to configuration.
4. **TODO_LIST.md freshness** — Updated Session 73 but already stale. Needs update after every deploy.
5. **Swap pressure** — 13Gi swap full is a system health crisis. This should be Priority 0 after deploy.
6. **Status report bloat** — 97 status reports in `docs/status/`. Many from the same session with near-duplicate content. Needs consolidation or archiving.
7. **Service module count** — 35 modules with 47 flake inputs. Some inputs may be unused (e.g., comfyui's input was already removed, but others may be stale).
8. **Boot target** — 35s is good but not great for NVMe + 16 cores. Further analysis possible after deploy.
9. **Darwin parity** — Most work focuses on NixOS. Darwin config may have drift.
10. **Test coverage** — `just test-fast` only checks Nix evaluation. No integration or service-level tests.

---

## F) TOP 25 THINGS TO DO NEXT

| # | Task | Impact | Effort | Status |
|---|------|--------|--------|--------|
| 1 | **Deploy committed changes + reboot** | 🔴 Critical | 5min | Committed |
| 2 | **Verify boot time drops to ~35s** | 🔴 Critical | 2min | Waiting |
| 3 | **Run Nix store GC** (`nix store gc`) | 🔴 High | 5min | Ready |
| 4 | **Investigate swap exhaustion** (13Gi/13Gi) | 🔴 High | 30min | Not started |
| 5 | **Git push 1 commit to origin** | 🟡 Medium | 1min | Ready |
| 6 | **Identify memory hogs** (`smem`, `ps --sort=-rss`) | 🔴 High | 15min | Not started |
| 7 | **Configure `nix.gc` automatic** | 🟡 Medium | 10min | Not started |
| 8 | **Add `just deploy` recipe** (nh workaround) | 🟡 Medium | 10min | Not started |
| 9 | **Fix Hermes Python deps** (firecrawl, edge-tts, fal) | 🟡 Medium | 1h | Not started |
| 10 | **Verify unbound preStart** (no anchor fetch in journal) | 🟡 Medium | 2min | Waiting |
| 11 | **Verify hermes fast-path** (no perms fix in journal) | 🟡 Medium | 2min | Waiting |
| 12 | **Configure SigNoz alert routing** (critical→Discord) | 🟡 Medium | 30min | Not started |
| 13 | **Test Discord alert channel** | 🟡 Medium | 5min | Not started |
| 14 | **Check SigNoz provision logs** (dashboards, rules) | 🟡 Medium | 5min | Not started |
| 15 | **Verify Gatus endpoints** (status.home.lan) | 🟡 Medium | 5min | Not started |
| 16 | **Update TODO_LIST.md** (10+ days stale) | 🟢 Low | 15min | Not started |
| 17 | **Audit flake inputs** (47 inputs, find stale ones) | 🟢 Low | 1h | Not started |
| 18 | **Consolidate status reports** (97 files → archive old) | 🟢 Low | 15min | Not started |
| 19 | **Deploy Dozzle** (Docker log tailing) | 🟢 Low | 30min | Planned |
| 20 | **Integrate nix-colors** (17+ hardcoded colors) | 🟢 Low | 6h | Not started |
| 21 | **Provision Pi 3 DNS failover** | 🟢 Low | 2h | Not started |
| 22 | **Add memory/swap alerting** to SigNoz/Gatus | 🟡 Medium | 30min | Not started |
| 23 | **Audit Docker container memory** limits | 🟡 Medium | 20min | Not started |
| 24 | **Create `just status` command** | 🟢 Low | 30min | Not started |
| 25 | **Convert go-auto-upgrade path: inputs to SSH** | 🟢 Low | 15min | Not started |

---

## G) TOP #1 QUESTION I CANNOT FIGURE OUT MYSELF 🤔

**What is consuming 13Gi of swap space?**

The system has 62Gi RAM with only 35Gi used (56%), yet swap is completely full at 13Gi/13Gi. This doesn't make sense with normal memory behavior — something is either:
1. Allocating huge amounts and getting swapped out
2. Memory fragmentation preventing pages from being reclaimed
3. A GPU workload (Ollama/ROCm) pinning system RAM

I cannot run `systemctl`, `htop`, or process inspection tools from this environment. This requires interactive terminal access to diagnose with `smem -t`, `ps aux --sort=-rss | head -20`, or `cat /proc/*/smaps | grep Swap`.

**Recommended investigation:**
```bash
smem -t -s swap          # Sort processes by swap usage
ps aux --sort=-rss | head -20  # Top memory consumers
docker stats --no-stream      # Docker container memory
```

---

## Repository State

| Metric | Value |
|--------|-------|
| Branch | `master` |
| Ahead of origin | 1 commit |
| Uncommitted changes | None (clean) |
| `just test-fast` | ✅ PASS |
| Service modules | 35 |
| Flake inputs | 47 |
| `.nix` files | 112 files, 14,949 lines |
| Disk usage | 86% (425Gi/512Gi) |
| Nix GC eligible | 7,848 paths |
| Swap | 99.3% full (13Gi/13Gi) |
| Load average | 23.12 / 19.43 / 14.35 |

## Commit History (May 20–21)

```
0192833b refactor(boot): mass-move user-facing services to graphical.target + delete ComfyUI
1b69769b docs(status): Session 73 — Hermes graphical.target fix + comprehensive system audit
9d4bb569 docs(status): Session 73 — Hermes emergency fix + comprehensive system audit
5328769f fix(hermes): move from multi-user.target to graphical.target
a77e4004 docs(status): Session 72 — boot speed fixes committed, awaiting deploy + system health crisis
dc9eaf87 fix(boot): eliminate unbound-anchor fetch + skip hermes perms when correct
50d9e43b docs(status): Session 71 — boot performance crisis FIXED, tmpfs verified post-reboot
3c8a70aa chore(deps): update flake.lock with upstream revisions + tmpfs boot option
51add720 fix(versioning): eliminate self.rev anti-pattern across 29 repos + automation
57c3e422 feat(scripts): add update-vendor-hash.sh — automated vendorHash fix for Go buildGoModule projects
ea2ea258 docs(status): Session 69 — comprehensive status + whisper-asr tmpfiles fix
ebe2e541 fix(voice-agents): wire docker.tmpfiles into systemd — fix whisper-asr crash-loop
343c5e27 docs(status): Session 68 — flake update vendorHash cascade fix
d9a9028d chore: update private Go dependencies + disable file-and-image-renamer (Go 1.26.3 required)
3226b87c docs(status): Session 67 — nixpkgs unstable migration + Hermes upgrade + AGENTS.md strip
```
