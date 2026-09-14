# SystemNix — Comprehensive Status Report

**Date:** 2026-05-03 12:54
**Session:** 19
**Branch:** master
**Last commit:** `a4c4128 fix(dns): use config.services.unbound.package instead of pkgs.unbound for unbound-control path`

---

## A) FULLY DONE ✅

### Infrastructure & Core

| Component                       | Status | Details                                                                                                 |
| ------------------------------- | ------ | ------------------------------------------------------------------------------------------------------- |
| **Flake architecture**          | ✅     | flake-parts, 27 inputs, 3 system configs, 12 overlays, no `path:` inputs                                |
| **Cross-platform Home Manager** | ✅     | 13 shared program modules in `common/`, both platforms import `home-base.nix`                           |
| **Catppuccin Mocha theming**    | ✅     | Universal across terminals, bars, login, GTK/Qt, icons, cursor — single source in `theme.nix`           |
| **Secrets (sops-nix)**          | ✅     | age-encrypted via SSH host key, 4 secret files, templates for hermes/gitea env                          |
| **Nix settings**                | ✅     | Flakes, sandbox, GC, substituters, unfree allowlist, cross-platform                                     |
| **Justfile**                    | ✅     | ~80 recipes across all domains                                                                          |
| **Lib helpers**                 | ✅     | `lib/systemd.nix` (harden), `lib/systemd/service-defaults.nix` (defaults), `lib/rocm.nix` (shared ROCm) |
| **Local network module**        | ✅     | `networking.local` options — single place for IP/subnet/gateway/VIP/Pi IP                               |

### NixOS Services (Active & Working)

| Service                  | Module                       | Key Features                                                                                                                  |
| ------------------------ | ---------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| **Unbound DNS**          | `dns-blocker.nix`            | Full recursive resolution (root hints), 25 blocklists, 2.5M+ domains, DNSSEC, block page via dnsblockd                        |
| **Caddy**                | `caddy.nix`                  | Reverse proxy, TLS via dnsblockd CA, Authelia forward_auth, 8 protected + 2 unprotected vhosts, metrics                       |
| **Gitea**                | `gitea.nix`                  | SQLite, Git LFS, OIDC via Authelia, GitHub mirror (30m cron + 6h timer), Actions runner, declarative admin                    |
| **Immich**               | `immich.nix`                 | PostgreSQL+Redis+ML, OAuth, 2G/4G memory limits, daily DB backup, dnsblockd CA trust                                          |
| **Authelia SSO**         | `authelia.nix`               | File-based auth, TOTP+WebAuthn, 2FA required, OIDC provider (Immich+Gitea), regulation, metrics                               |
| **SigNoz**               | `signoz.nix`                 | Full stack from source (query, collector, ClickHouse+Keeper, node_exporter, cAdvisor), alert rules, AMD GPU metrics, journald |
| **TaskChampion**         | `taskchampion.nix`           | Sync server, 100 snapshots/14d, systemd hardened                                                                              |
| **Homepage**             | `homepage.nix`               | Dashboard, 5 service groups, health checks, resource widgets, Catppuccin CSS                                                  |
| **Hermes**               | `hermes.nix`                 | AI gateway (Discord bot), sops env, dedicated system user, SIGUSR1 reload, auto-migration                                     |
| **Voice agents**         | `voice-agents.nix`           | LiveKit server, Whisper ASR (ROCm Docker), OpenAI-compatible API, Gradio UI                                                   |
| **ComfyUI**              | `comfyui.nix`                | Mutable install, ROCm, bf16, 8G limit, render+video groups                                                                    |
| **Twenty CRM**           | `twenty.nix`                 | Docker Compose (server+worker+postgres+redis), sops secrets, daily DB backup                                                  |
| **Docker**               | `default.nix`                | overlay2, `/data/docker`, weekly prune, user in docker group                                                                  |
| **EMEET PIXY**           | `emeet-pixyd` input          | Full daemon, auto call detection, HID state sync, Waybar integration                                                          |
| **Niri**                 | `niri-config.nix`            | Wayland compositor, XWayland, BindsTo→PartOf patch, OOM protection                                                            |
| **Session save/restore** | `niri-wrapped.nix`           | 60s timer, workspace-aware restore, floating/column width, dedup, fallback apps                                               |
| **SDDM**                 | `display-manager.nix`        | silentSDDM + Catppuccin Mocha, niri default session                                                                           |
| **PipeWire**             | `audio.nix`                  | ALSA 32-bit, PulseAudio compat, JACK, rtkit                                                                                   |
| **Security**             | `security-hardening.nix`     | polkit, swaylock PAM, fail2ban (SSH aggressive), ClamAV, security tools suite                                                 |
| **Disk monitor**         | `disk-monitor.nix`           | `/` + `/data`, 7 threshold levels, desktop notifications                                                                      |
| **File renamer**         | `file-and-image-renamer.nix` | Watches Desktop, AI renaming via ZAI API, user service                                                                        |
| **Gitea repos**          | `gitea-repos.nix`            | Declarative repos, daily sync, sops token                                                                                     |
| **Minecraft**            | `minecraft.nix`              | MC 26.1.2, JDK 25, ZGC, whitelist, Prism client config                                                                        |
| **Steam**                | `steam.nix`                  | Proton, gamemode, gamescope, mangohud                                                                                         |
| **Chromium policies**    | `chromium-policies.nix`      | YouTube Shorts Blocker, OneTab extensions                                                                                     |

### Hardware & Boot

| Component                | Status | Details                                                                            |
| ------------------------ | ------ | ---------------------------------------------------------------------------------- |
| **AMD GPU (Strix Halo)** | ✅     | amdgpu, Mesa, ROCm, VA-API, DPM high, monitoring tools                             |
| **AMD NPU**              | ✅     | XDNA via nix-amd-npu, XRT runtime, Boost workaround                                |
| **Bluetooth**            | ✅     | Google Nest Audio, Blueman, auto-connect                                           |
| **Boot**                 | ✅     | systemd-boot, latest kernel, GTT 128GB, IOMMU on, ZRAM 50%, earlyoom, nproc raised |
| **BTRFS snapshots**      | ✅     | Timeshift daily timer, auto-scrub monthly, freshness check                         |

### Custom Packages (12 total)

| Package                        | Language | Status                         |
| ------------------------------ | -------- | ------------------------------ |
| `aw-watcher-utilization`       | Python   | ✅ v1.2.2                      |
| `dnsblockd`                    | Go       | ✅ via flake input             |
| `emeet-pixyd`                  | Go       | ✅ via flake input             |
| `file-and-image-renamer`       | Go       | ✅ v0.1.0                      |
| `golangci-lint-auto-configure` | Go       | ✅ v0.1.0                      |
| `jscpd`                        | Node.js  | ✅ v4.0.9                      |
| `modernize`                    | Go       | ✅ unstable                    |
| `monitor365`                   | Rust     | ✅ v0.1.0 (disabled: high RAM) |
| `mr-sync`                      | Go       | ✅ v0.0.0                      |
| `netwatch`                     | Rust     | ✅ v14.1                       |
| `openaudible`                  | AppImage | ✅ v4.7.4                      |
| `todo-list-ai`                 | Go       | ✅ via flake input             |

---

## B) PARTIALLY DONE 🔧

| Component                | What's Done                                                              | What's Missing                                                                                                  |
| ------------------------ | ------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------- |
| **DNS failover cluster** | Module exists, VRRP config, health check, RPi3 config built              | `services.dns-failover.enable` not set in configuration.nix — requires `virtualIP`, `interface`, `authPassword` |
| **RPi3 DNS backup**      | Full unbound+dnsblockd config, VRRP priority 50, shared blocklists       | **`root-hints = ":"`** is broken — needs real root hints file; hardcoded VRRP auth password (should use sops)   |
| **Unsloth Studio**       | Module exists (`ai-stack.nix`), full setup script, ROCm, venv            | `services.unslothStudio.enable` not set in configuration.nix                                                    |
| **DNSTAP**               | `unbound-full` supports it; discussed in session                         | No consumer daemon, no OTel bridge, not enabled                                                                 |
| **DNS-over-QUIC**        | `quic-port = 853` in unbound config, overlay code exists (commented out) | `unboundDoQOverlay` disabled — would invalidate binary cache for 1000+ packages                                 |
| **Auditd**               | Module in `security-hardening.nix`                                       | Commented out due to NixOS 26.05 bug (#483085)                                                                  |
| **Darwin Go overlay**    | Works on macOS                                                           | Re-applies Go 1.26.1 overlay that was removed from flake.nix (cache invalidation risk)                          |
| **Scheduled tasks**      | 5 timers working                                                         | `notify-failure@` hardcodes `WAYLAND_DISPLAY=wayland-1` and `DISPLAY=:0` — fragile                              |
| **Session restore**      | Working (save + restore + fallback)                                      | 200-line inline bash script — hard to test/maintain                                                             |
| **Photomap**             | OCI container configured                                                 | Service named `podman-photomap` but system uses Docker — potential mismatch                                     |

---

## C) NOT STARTED ❌

| Item                                  | Description                                                                                  | Priority               |
| ------------------------------------- | -------------------------------------------------------------------------------------------- | ---------------------- |
| **DNSTAP → SigNoz pipeline**          | Go service to decode dnstap protobuf → OTel logs/traces                                      | Low                    |
| **Unbound DoQ support**               | Needs libngtcp2/libnghttp3 in nixpkgs unbound package                                        | Low (blocked upstream) |
| **Pi 3 hardware provisioning**        | Physical Pi 3 not set up yet for DNS failover                                                | Medium                 |
| **AppArmor**                          | Explicitly disabled in security-hardening.nix                                                | Low                    |
| **Monitor365 RAM optimization**       | Disabled for high RAM; no investigation into tuning                                          | Low                    |
| **Darwin Go overlay removal**         | Should remove Go 1.26.1 overlay from darwin/default.nix to match flake.nix approach          | Medium                 |
| **Justfile ghost recipes**            | `benchmark`, `perf`, `context`, `health-dashboard`, `clean-storage` referenced but undefined | Low                    |
| **Hardware-configuration.nix header** | Stale auto-generated comment at top                                                          | Trivial                |

---

## D) TOTALLY FUCKED UP 💥

| Issue                                          | Severity       | Impact                                                                                           | Location                                              |
| ---------------------------------------------- | -------------- | ------------------------------------------------------------------------------------------------ | ----------------------------------------------------- |
| **`root-hints = ":"`** in RPi3 config          | 🔴 Critical    | Full recursive resolution broken on Pi — unbound won't resolve anything without valid root hints | `platforms/nixos/rpi3/default.nix:135`                |
| **Hardcoded VRRP auth password**               | 🔴 Security    | Plaintext `"DNSClusterVRRP-evox2"` in version control — should be in sops-nix                    | `platforms/nixos/rpi3/default.nix:161`                |
| **Darwin Go overlay invalidates binary cache** | 🟡 Significant | All Go packages build from source on macOS, wasting hours of build time                          | `platforms/darwin/default.nix:67-83`                  |
| **NixOS 26.05 auditd bug**                     | 🟡 Significant | No kernel audit logging — AppArmor + auditd both disabled                                        | `modules/nixos/services/security-hardening.nix:29-51` |
| **Photomap Docker vs Podman naming**           | 🟡 Medium      | Service name mismatch if using Docker backend                                                    | `modules/nixos/services/photomap.nix`                 |

---

## E) WHAT WE SHOULD IMPROVE 📈

### Architecture

1. **Extract niri-session-restore** from inline bash to a standalone Nix package or at least a separate script file — 200 lines of bash in a Nix string is untestable
2. **Remove Darwin Go overlay** — same pattern explicitly removed from flake.nix for cache invalidation; use nixpkgs Go directly
3. **Move VRRP auth to sops-nix** — plaintext passwords in Nix configs defeat the purpose of secrets management
4. **Fix `root-hints` on RPi3** — use `${pkgs.unbound}/etc/unbound/root.hints` or the NixOS default
5. **Verify photomap OCI backend** — ensure Docker/Podman service name matches the configured backend

### Security

6. **Re-enable auditd** after NixOS 26.05 bug is fixed — track nixpkgs#483085
7. **Consider AppArmor** for high-value services (Caddy, Gitea, Authelia)
8. **Remove passwordless sudo** for wheel — replace with `timeout` or `targetpw`
9. **Audit `NoNewPrivileges = false`** in Caddy — intentional but should be documented with ADR

### Observability

10. **DNSTAP → OTel bridge** — pipe DNS query logs into SigNoz for correlation with service health
11. **Monitor365 investigation** — profile RAM usage, consider lighter collectors or config tuning
12. **Centralize display env vars** — `WAYLAND_DISPLAY` and `DISPLAY` hardcoded in multiple places

### Code Quality

13. **Clean up justfile** — remove or define ghost recipes (`benchmark`, `perf`, `context`, `health-dashboard`, `clean-storage`)
14. **Remove commented-out code** — 15+ blocks of commented Nix code across the repo
15. **Fix hardware-configuration.nix header** — update stale auto-generated comment
16. **Archive old status docs** — 200+ status files in `docs/status/` and `docs/archive/status/`; most are stale

### DNS

17. **DNS-over-QUIC** — track nixpkgs for libngtcp2 support in unbound package
18. **Blocklist hash auto-update** — the `blocklist-hash-updater` script exists but could be more robust
19. **DNS failover testing** — once Pi 3 is provisioned, test actual VRRP failover

---

## F) TOP 25 THINGS TO GET DONE NEXT 🎯

| #  | Task                                                                                          | Impact   | Effort           | Category       |
| -- | --------------------------------------------------------------------------------------------- | -------- | ---------------- | -------------- |
| 1  | **Fix `root-hints = ":"`** in RPi3 config                                                     | Critical | 5 min            | Bug            |
| 2  | **Move VRRP auth password to sops-nix**                                                       | Critical | 15 min           | Security       |
| 3  | **Remove Darwin Go overlay** (match flake.nix approach)                                       | High     | 10 min           | Performance    |
| 4  | **Extract niri-session-restore to standalone script**                                         | High     | 1 hr             | Architecture   |
| 5  | **Clean up justfile ghost recipes**                                                           | Medium   | 15 min           | Code Quality   |
| 6  | **Archive old status docs** (200+ stale files)                                                | Medium   | 10 min           | Housekeeping   |
| 7  | **Remove commented-out code blocks** (15+ locations)                                          | Medium   | 30 min           | Code Quality   |
| 8  | **Verify photomap OCI backend naming**                                                        | Medium   | 10 min           | Bug            |
| 9  | **Fix hardware-configuration.nix stale header**                                               | Low      | 2 min            | Housekeeping   |
| 10 | **Centralize WAYLAND_DISPLAY/DISPLAY env vars**                                               | Medium   | 20 min           | Robustness     |
| 11 | **Track nixpkgs#483085** for auditd re-enable                                                 | High     | N/A (blocked)    | Security       |
| 12 | **Provision Pi 3 hardware** for DNS failover                                                  | High     | Manual           | Infrastructure |
| 13 | **Enable DNS failover in configuration.nix**                                                  | High     | 5 min (after Pi) | Infrastructure |
| 14 | **DNSTAP → OTel bridge** (Go microservice)                                                    | Medium   | 4-6 hr           | Observability  |
| 15 | **Profile Monitor365 RAM** and tune config                                                    | Medium   | 2 hr             | Performance    |
| 16 | **Add Caddy `NoNewPrivileges=false` ADR**                                                     | Low      | 10 min           | Documentation  |
| 17 | **Re-evaluate AppArmor** for key services                                                     | Medium   | Research         | Security       |
| 18 | **Update AGENTS.md** with session 19 findings                                                 | Medium   | 15 min           | Documentation  |
| 19 | **Test `just switch`** with current changes                                                   | High     | 10 min           | Validation     |
| 20 | **Unbound package consistency audit** — ensure all refs use `config.services.unbound.package` | Medium   | 15 min           | Consistency    |
| 21 | **Flake lock update** — commit pending `flake.lock` + `dns-blocklists.nix` hash updates       | Low      | 5 min            | Maintenance    |
| 22 | **Consider `unbound-full` for DNSTAP** when pipeline is ready                                 | Low      | 2 min            | Future         |
| 23 | **Add health checks** for services missing them (homepage dashboard gaps)                     | Medium   | 30 min           | Reliability    |
| 24 | **Document Darwin-specific quirks** in AGENTS.md                                              | Low      | 10 min           | Documentation  |
| 25 | **Remove or replace `signal-desktop-bin`** unfree classification comment                      | Trivial  | 2 min            | Cleanup        |

---

## G) TOP #1 QUESTION 🤔

**Is the RPi3 DNS backup actually running in production right now?**

The config exists with `root-hints = ":"` which would break recursive resolution entirely. If the Pi is live, it's serving broken DNS. If it's not provisioned yet (as noted in AGENTS.md), this is a latent bug. This determines whether item #1 is an emergency fix or a pre-deployment cleanup.

---

## Uncommitted Changes

| File                                      | Change                                                                                          |
| ----------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `platforms/nixos/modules/dns-blocker.nix` | Fixed `unbound-control` path to use `config.services.unbound.package` instead of `pkgs.unbound` |
| `flake.lock`                              | Updated input hashes (NUR, homebrew-cask)                                                       |
| `platforms/shared/dns-blocklists.nix`     | Updated 25 blocklist SRI hashes (upstream list updates)                                         |

---

_Session 19 — 2026-05-03_
