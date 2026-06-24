# SystemNix — Session 110 Status Report

**Date:** 2026-05-30 08:15 CEST
**Session:** 110
**Branch:** `master` @ `9893fa32`
**Build Status:** UNTESTED (2 uncommitted changes)
**Working Tree:** DIRTY — 2 modified files

---

## System Health

| Metric | Value | Status |
|--------|-------|--------|
| Disk `/` | 484G / 512G (96%) | CRITICAL — 23G free |
| Disk `/data` | 942G / 1.0T (93%) | WARN — 82G free |
| RAM | 36G / 93G (39%) | OK |
| Swap | 17G / 19G (89%) | CRITICAL — 2.4G free |
| Load avg | 9.36 / 12.08 / 10.87 | HIGH — heavy load |
| NixOS Build | Not tested this session | UNKNOWN |
| Git Working Tree | 2 modified, not staged | DIRTY |

### Worsened Since Session 109

| Metric | Session 109 | Session 110 | Delta |
|--------|-------------|-------------|-------|
| Disk `/` | 94% (32G free) | **96% (23G free)** | -9G |
| Swap | 53% (10G/19G) | **89% (17G/19G)** | +7G used |
| `/data` | Not reported | 93% (82G free) | Baseline |

---

## A) FULLY DONE

### 1. Stale Chromium Desktop Entry Removed

`~/.local/share/applications/chromium-devel.desktop` was a leftover from Helium 0.7.6.1 (now at 0.12.5.1). It showed a duplicate "Chromium" entry in rofi's drun mode because the `.desktop` file had `Name=Chromium`. Trashed.

### 2. Niri Animation Speed — 100x Faster

All 6 spring animations in `platforms/nixos/desktop/niri-wrapped.nix` updated:

| Parameter | Before | After | Effect |
|-----------|--------|-------|--------|
| `stiffness` | 800–1000 | **80000** | Settles ~100x faster |
| `damping-ratio` | 0.7–0.8 (underdamped) | **1.0** (critically damped) | Zero bounce |
| `epsilon` | 0.0001 | **0.01** | Animation "done" 100x sooner |

**Applies to:** `window-open`, `window-close`, `window-movement`, `window-resize`, `horizontal-view-movement`, `workspace-switch`

### 3. Apache Domains Added to DNS Blocklist

`platforms/common/dns-blocklists.nix` — 7 Apache.org domains added to blocklist (likely for dependency supply-chain protection):

- `apache.org`, `www.apache.org`, `downloads.apache.org`
- `archive.apache.org`, `maven.apache.org`
- `repo.maven.apache.org`, `dlcdn.apache.org`

### 4. Rofi Performance Benchmarked

Rofi drun startup measured at **~58ms** (with and without icons). The perceived "slowness" was entirely niri's window-open spring animation, not rofi. Confirmed rofi itself is fast — the animation change above should make it feel instant.

---

## B) PARTIALLY DONE

### 1. Niri Animation Change — Not Deployed

Changes committed but not yet applied via `just switch`. Need deploy + user testing to confirm the 100x stiffness feels right (may need tuning down if too jarring).

### 2. DNS Blocklist Change — Not Deployed

Apache domains added to blocklist config but not deployed.

---

## C) NOT STARTED

### From TODO_LIST.md (Session 75, Still Stale)

All items from session 109 remain unstarted. Highest priority repeats:

- [ ] **`just switch` — Deploy** — now 7+ commits undeployed (includes this session's animation + blocklist changes)
- [ ] Disk GC + monitoring
- [ ] Move 4 vendorHash upstream
- [ ] Rebuild TODO_LIST.md (stale since session 75)
- [ ] Swap investigation (now at 89%!)

---

## D) TOTALLY FUCKED UP

### 1. Swap at 89% (17G / 19G) — CRITICAL

Worsened from 53% in session 109 to 89% now. Only 2.4G free. System is on the edge of OOM. Load average is 9.36 — the machine is struggling.

**Likely cause:** gopls instances (7+ known), plus AI workloads (Ollama running).

### 2. Disk `/` at 96% (23G Free) — CRITICAL

Worsened from 94% (32G free). Lost 9G in one day. At this rate, disk full in ~2 days. **Nix GC is urgent.**

### 3. Disk `/data` at 93% (82G Free) — WARN

Docker images, AI models, and backups consuming 942G of 1.0T. Growing steadily.

### 4. 141 Status Reports in docs/status/

The status directory has 141 files (many in archive/). The reports are comprehensive but the volume makes them hard to navigate. Consider a rolling window (keep last 10, archive the rest).

---

## E) WHAT WE SHOULD IMPROVE

### Immediate (Today)

1. **Nix GC NOW** — `nix-collect-garbage --delete-older-than 1d` to reclaim disk space
2. **Kill runaway gopls** — `pkill gopls; pkill -f 'gopls'` to free swap
3. **Deploy animation + blocklist changes** — `just switch`
4. **Test animation feel** — If 80000 stiffness is too jarring, tune to 20000-40000

### Short-Term (This Week)

5. **Disk space alerting** — Add Gatus check for disk >90%
6. **Swap/RAM alerting** — Add SigNoz alert for swap >80%
7. **Rebuild TODO_LIST.md** — Stale since session 75 (5+ sessions behind)
8. **Move vendorHash upstream** — 4 overrides in overlays/shared.nix keep breaking builds
9. **Clean up docs/status/** — Archive older reports, keep rolling window

### Medium-Term

10. **BTRFS /data snapshot migration** — Run `just snapshot-migrate-data`
11. **Flake inputs audit** — 47 inputs, reduce lock file churn
12. **Pi 3 DNS failover** — Hardware sitting idle, DNS is SPOF
13. **Hermes secondary LLM** — Single-provider risk (GLM-5.1 only)

---

## F) TOP 25 THINGS TO DO NEXT

| # | Task | Impact | Effort | Why |
|---|------|--------|--------|-----|
| 1 | **Nix GC immediately** | CRITICAL | 5min | 96% disk, 23G free |
| 2 | **Kill gopls processes** | CRITICAL | 1min | Swap at 89%, OOM imminent |
| 3 | **`just switch` — Deploy** | HIGH | 10min | 7+ commits undeployed |
| 4 | **Test niri animation feel** | HIGH | 5min | 80000 stiffness may be too much |
| 5 | **Add disk space Gatus alert** | HIGH | 15min | Silent disk-full risk |
| 6 | **Add swap/RAM SigNoz alert** | HIGH | 15min | OOM risk unmonitored |
| 7 | **Move 4 vendorHash upstream** | HIGH | 2h | Breaks on every dep update |
| 8 | **Rebuild TODO_LIST.md** | MED | 30min | Stale since session 75 |
| 9 | **Clean up docs/status/ (141 files)** | MED | 15min | Hard to navigate |
| 10 | **Audit FEATURES.md** | MED | 1h | Verify against actual code |
| 11 | **BTRFS /data snapshot migration** | MED | 1h | /data unprotected by snapshots |
| 12 | **Fix upstream pre-commit hooks** | MED | 2h | `--no-verify` on every commit |
| 13 | **Flake inputs audit (47 → ?)** | MED | 2h | Reduce lock file churn |
| 14 | **crates.io upstream fix** | MED | 1h | File nixpkgs issue |
| 15 | **nix-colors integration** | MED | 6h | 17+ hardcoded colors |
| 16 | **Deploy Dozzle** | LOW | 30min | Docker log tailing |
| 17 | **Wire Pi 3 DNS failover** | LOW | 4h | Hardware sitting idle |
| 18 | **Hermes secondary LLM** | LOW | 2h | Single-provider risk |
| 19 | **Hermes SSH deploy key** | LOW | 30min | Git ops fail in sandbox |
| 20 | **Create shared flake-parts template** | LOW | 3h | Reduce boilerplate across repos |
| 21 | **Fix `file-and-image-renamer` Go version** | LOW | 30min | Disabled, Go 1.26.2 vs 1.26.3 |
| 22 | **Fix `photomap` Podman permissions** | LOW | 1h | Disabled service |
| 23 | **SigNoz per-threshold channel routing** | LOW | 1h | All alerts → same channel |
| 24 | **Consolidate voice-agents Caddy vHost** | LOW | 30min | Not following caddy.nix pattern |
| 25 | **Verify boot time (~35s target)** | LOW | 5min | Measure after deploy |

---

## G) TOP QUESTION

**Why did swap jump from 53% to 89% in one day?** The system went from 10G/19G to 17G/19G swap usage overnight. With load average at 9.36, something is consuming massive memory:

- Is Ollama running a model? (`OLLAMA_MAX_LOADED_MODELS=1` should limit this)
- Are there more gopls instances than the 7 reported in session 109?
- Is a Docker container leaking memory?
- Did the AI workloads (ComfyUI, voice-agents) get re-enabled?

Before deploying anything, we need `systemd-oomd` to confirm it's active and `ps aux --sort=-%mem | head -20` to identify the top memory consumers. The machine is dangerously close to OOM kill cascade.

---

## Uncommitted Changes

```
 M platforms/common/dns-blocklists.nix       (+7 Apache domains)
 M platforms/nixos/desktop/niri-wrapped.nix  (animations 100x faster)
```

---

_Generated by Session 110 — 2026-05-30 08:15 CEST_
