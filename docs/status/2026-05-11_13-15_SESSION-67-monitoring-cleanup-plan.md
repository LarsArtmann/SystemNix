# Session 67 — Monitoring Fixes, Cleanup & Comprehensive Plan

**Date:** 2026-05-11 13:15
**Branch:** master
**Commit:** d8375175
**Generation:** 313 (not yet deployed)

---

## What Happened

This session continued from a previous interrupted session. The primary deliverable was a comprehensive prioritized execution plan synthesized from 82 project documents (status reports sessions 9-66, planning docs, research docs). After producing the plan, the highest-impact items were executed.

### Plan Produced

A table of 16 prioritized tasks across P0-P2 categories, estimated at ~91 minutes of code changes. The plan was derived from deduplicating 99 actionable items found across all documents into the highest-impact work.

---

## a) FULLY DONE

### Code Changes (committed in this session)

1. **Added upstream DNS (Quad9) health check to Gatus** (`gatus-config.nix`)
   - New endpoint: "Upstream DNS (Quad9)" queries `9.9.9.9` for `google.com` every 5m
   - Detects upstream DNS outages before they cascade (prevents repeat of 3-day DNS outage)

2. **Removed 10 stale commented-out imports from configuration.nix**
   - All services migrated to flake-parts modules in earlier sessions
   - Removed: ssh.nix, default.nix, gitea.nix, sops.nix, immich.nix, caddy.nix, homepage.nix, emeet-pixy comments

3. **Set unbound verbosity to 1** (`dns-blocker-config.nix`)
   - Reduces journal noise from DNS resolver (was default, useful during debugging, unnecessary in production)

### Code Changes (committed in previous session 93e18cf6, verified in this session)

4. **Fixed Caddy health check IPv6 issue** — Changed `localhost` to `127.0.0.1` (Caddy admin API only listens on IPv4)
5. **Fixed Gitea health check 404** — Changed `/api/v1/nodeinfo` to `/api/v1/version`
6. **Extended ComfyUI check interval** — From 60s to 5m (on-demand service, reduces noise)
7. **Removed `amdgpu.deepfl=1` kernel param** — Unknown parameter, ignored by kernel 7.0.1
8. **Reduced coredump limits** — MaxUse from 2G to 1G, added Compress=yes
9. **Added Quad9 fallback nameserver** — `nameservers = ["127.0.0.1" "9.9.9.9"]` prevents DNS outage during rebuilds

### Verification

- `just test-fast` — all checks passed (statix, deadnix, alejandra, flake check)
- Pre-commit hooks all passed (gitleaks, deadnix, statix, alejandra, flake check)
- Git working tree is clean

---

## b) PARTIALLY DONE

### Gatus Alerting
- Investigated Gatus alerting options (ntfy, Discord webhook)
- Found Discord webhook is the best fit (Hermes Discord bot already running)
- **Blocked**: Requires a Discord webhook URL that must be created manually in Discord
- The Gatus config is ready to accept an `alerting.discord` block once the URL is available

### SigNoz Alert Rules
- SigNoz is collecting all metrics (GPU VRAM, disk, niri health, DNS)
- Alert rules must be configured through the SigNoz web UI (not declaratively in Nix)
- **Blocked**: Requires manual UI configuration — no API-driven rule creation available

---

## c) NOT STARTED (from the 99-item backlog)

### High Impact (should do next session)

| # | Task | Category | Why |
|---|------|----------|-----|
| 1 | **Create Discord webhook → wire into Gatus alerting** | Monitoring | Makes 22 endpoints actually alert |
| 2 | **Configure SigNoz alert rules** (GPU >85%, disk >90%, niri down) | Monitoring | Makes metrics actionable |
| 3 | **Reboot system** (16h+ uptime since GPU OOM, fixes deployed but not activated) | Reliability | Activates all kernel param changes |
| 4 | **Kernel update to 7.0.6** (`just update && just switch`) | Security | Dirty Frag CVE unfixed on 7.0.1 |
| 5 | **BIOS investigation** — check AMD CBS/PBS menus for PPT/TDP controls | Performance | 130W ceiling is hardware-limited |
| 6 | **Extract overlays from flake.nix** to `overlays/` directory (200+ lines) | Maintenance | Reduces flake.nix from 798 lines |
| 7 | **Archive stale docs/** — 60+ top-level status files should move to archive/ | Maintenance | Clean docs tree |
| 8 | **Test GPU recovery chain** — simulate DRM zombie, verify auto-reboot | Reliability | Defense-in-depth validation |
| 9 | **Fix ComfyUI CHDIR failure** — comfyui-check-venv fails | Reliability | Service broken |
| 10 | **Fix Polkit KDE agent** — Qt platform plugin init error | Desktop | Annoying popup |

### Medium Impact

| # | Task | Category |
|---|------|----------|
| 11 | Nix flake standardization (67 tasks across 9 Go repos) | DX |
| 12 | Pi 3 DNS failover provisioning | Reliability |
| 13 | Backup verification (test restores) | Reliability |
| 14 | Deer Flow NixOS module | Features |
| 15 | Fix Photomap (podman permissions) | Features |
| 16 | NixOS VM tests for critical services | DX |
| 17 | Centralize firewall ports | Maintenance |
| 18 | Split signoz.nix (738 lines → sub-modules) | Maintenance |
| 19 | Fix fzf.nix hardcoded color `#a6adc8` | Theme |
| 20 | Document bare-metal disaster recovery | Reliability |
| 21 | Add `just validate-scripts` (shellcheck) | DX |
| 22 | Make `do-ip6` a dns-blocker module option | Maintenance |
| 23 | Auto-detect GPU PCI address in gpu-recovery.sh | Reliability |
| 24 | Add power estimation widget to waybar | Desktop |
| 25 | Update FEATURES.md | Maintenance |

---

## d) TOTALLY FUCKED UP

Nothing broken in this session. All changes validated and committed cleanly.

### Known Issues (pre-existing)

| Issue | Status |
|-------|--------|
| ComfyUI check-venv CHDIR failure | Broken since session 59 |
| Polkit KDE agent Qt error | Broken since session 59 |
| Monitor365 disabled (high RAM) | Disabled since session 59 |
| Photomap disabled (podman perms) | Disabled since session 62 |
| 130W power ceiling | Hardware limit, no OS fix |
| Zero alerting on 22 Gatus endpoints | Blocked on Discord webhook |
| Zero SigNoz alert rules | Blocked on UI configuration |

---

## e) WHAT WE SHOULD IMPROVE

1. **Alerting is still zero** — The #1 gap. 22 endpoints monitored, 0 notifications. Every session documents this. Creating a Discord webhook and wiring it into Gatus would take 5 minutes and transform monitoring from passive dashboard to active alerting.

2. **Deploy discipline** — Changes are committed but not deployed. Generation 313 has been active since before the GPU OOM incident. A `just switch` + reboot would activate all the kernel param fixes, DNS changes, and monitoring improvements.

3. **Overlay extraction from flake.nix** — At 798 lines, flake.nix is the biggest file in the project. ~200 lines of overlay definitions should move to `overlays/` directory. Deferred due to risk but should be the next maintenance task.

4. **SigNoz alert rules** — All metrics flow into SigNoz but zero threshold alerts are configured. GPU VRAM, disk space, and niri health should have alert rules that trigger notifications.

---

## f) Top 25 Things We Should Get Done Next

See section c) above — the full prioritized table with rationale.

---

## g) Question I Cannot Figure Out Myself

**How do you want to handle alerting?** The three options are:

1. **Discord webhook** — Create a webhook in your Discord server, paste the URL into Gatus config. Fastest path. Uses existing Hermes bot infrastructure.
2. **ntfy server** — Self-hosted notification service. More private, but requires deploying a new service.
3. **SigNoz-native alerts** — Configure thresholds in SigNoz UI. Best for metric-based alerts but no endpoint-level health check alerts.

Recommendation: Start with Discord webhook for Gatus (immediate value, zero new infrastructure), then configure SigNoz alert rules for metric thresholds.

---

## System State

| Metric | Value |
|--------|-------|
| Kernel | 7.0.1 (stable: 7.0.6) |
| Generation | 313 (not deployed) |
| Uptime | ~16h |
| Root disk | 77% (115G free) |
| Data disk | 70% (309G free) |
| GPU VRAM | 22.5/64 GiB |
| Swap | 10/25 GiB |
| Git | Clean (ahead of origin by 2 commits) |

## Commits This Session

1. `d8375175` — fix(monitoring): add upstream DNS check, clean stale imports, reduce DNS log noise
