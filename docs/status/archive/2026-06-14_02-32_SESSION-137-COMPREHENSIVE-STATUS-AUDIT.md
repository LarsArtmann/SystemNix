# SystemNix — Full Comprehensive Status Report

**Date:** 2026-06-14 02:32
**Session:** 137
**Branch:** `master` (clean working tree)
**Build Status:** ✅ `just test-fast` passes (`nix flake check --no-build`)
**Last Commit:** `675cafb2` — feat(niri): restore perceptible spring animations after performance regression

---

## Executive Summary

SystemNix is a mature, cross-platform Nix configuration (macOS + NixOS) with **3 hosts**, **39 NixOS service modules**, **52 flake inputs**, **~16,500 lines of Nix**, and **93 justfile recipes**. The system is functional and eval-clean, but carries significant technical debt: **580+ status report files** bloating the repo, **45 open TODOs** growing faster than they close, **plaintext secrets** in git, several **dead/duplicated modules**, and **zero macOS CI** despite claiming it. The system has never been rebooted since session 130's boot-ordering fixes, meaning several deployed fixes remain unverified in production.

---

## a) FULLY DONE ✅

### Infrastructure & Core Systems

| # | Component | Status | Details |
|---|-----------|--------|---------|
| 1 | **Flake structure** | ✅ Complete | flake-parts, 52 inputs, 3 hosts, auto-discovered modules |
| 2 | **lib/ helpers** | ✅ Complete | 13 helpers: `harden`, `serviceDefaults`, `serviceTypes`, `mkDockerServiceFactory`, `ports`, `images`, `rocm`, `mkSecretCheck`, `mkDesktopNotifyService`, `mkHttpCheck`, `mkStateDir`, `onFailure`, `hardenUser` |
| 3 | **Port registry** | ✅ Complete | 35 named ports with eval-time collision detection (`lib/ports.nix`) |
| 4 | **Systemd hardening** | ✅ Complete | `harden` + `hardenUser` with `mkDefault` semantics, `startLimitBurst` enforcement |
| 5 | **Docker service factory** | ✅ Complete | `mkDockerServiceFactory` — compose, env templates, backups, image pulls, hardening |
| 6 | **Caddy reverse proxy** | ✅ Complete | 15 vhosts, `protectedVHost` helper (oauth2-proxy + Pocket ID forward-auth), TLS via dnsblockd CA |
| 7 | **DNS blocking** | ✅ Complete | Unbound + dnsblockd, blocklist processing at eval time, TLS/DoT, stats API, `tempAllowAll` escape hatch |
| 8 | **Pocket ID (OIDC)** | ✅ Complete | Declarative provisioning: admin user, OIDC clients, avatar, SMTP via Resend |
| 9 | **oauth2-proxy** | ✅ Complete | Forward-auth bridge, cookie secret validation, Pocket ID integration |
| 10 | **Sops-nix secrets** | ✅ Complete | Age via SSH host keys, `optionalAttrs` guards on all service-specific secrets |
| 11 | **SigNoz observability** | ✅ Complete | Built from source (Go 1.25), ClickHouse, OTel collector, alert rules, dashboards, cAdvisor, node exporter |
| 12 | **BTRFS snapshots** | ✅ Complete | Daily via btrbk, auto-pruning (14d + 4w), pre-deploy snapshots, verify timer |
| 13 | **Forgejo** | ✅ Complete | Git forge, GitHub mirror sync, Actions runner, admin provisioning |
| 14 | **Immich** | ✅ Complete | OAuth via Pocket ID, PG backups, VAAPI transcoding, Redis |
| 15 | **Gatus health monitoring** | ✅ Complete | ~20 endpoints, Discord alerts, `mkHttpCheck` helper |

### Desktop & Development

| # | Component | Status | Details |
|---|-----------|--------|---------|
| 16 | **Niri compositor** | ✅ Complete | DRM healthcheck, display watchdog, spring animations, session manager |
| 17 | **Catppuccin theming** | ✅ Complete | nix-colors integration (164 colors), JetBrainsMono, Bibata cursors, Papirus icons |
| 18 | **Terminal hierarchy** | ✅ Complete | Ghostty (primary), Kitty (backup), Foot (sway fallback) |
| 19 | **Shell config** | ✅ Complete | Fish + Zsh + Bash parity, Starship prompt, fzf, tmux |
| 20 | **Home Manager** | ✅ Complete | Cross-platform `home-base.nix`, 16 program modules |
| 21 | **AI stack** | ✅ Complete | Ollama (ROCm), llama.cpp (MFMA), gpu-python wrapper, Jupyter |
| 22 | **Dual-WAN** | ✅ Complete | MPTCP + ECMP, route health monitor, endpoint manager |

### CI/CD & Quality

| # | Component | Status | Details |
|---|-----------|--------|---------|
| 23 | **GitHub Actions CI** | ✅ Partial | `nix-check.yml` (ubuntu-latest): statix, deadnix, nix fmt, flake check --no-build |
| 24 | **Weekly flake updates** | ✅ Complete | `flake-update.yml` — auto PR every Monday |
| 25 | **Pre-commit hooks** | ✅ Complete | 9 hooks: gitleaks, deadnix, statix, alejandra, shellcheck, merge-conflict check |
| 26 | **VM tests** | ✅ Complete | Boot test + DNS blocking test (`tests/default.nix`) |
| 27 | **Exec path validator** | ✅ Complete | `just test-exec-paths` verifies all ExecStart paths exist |

---

## b) PARTIALLY DONE ⚠️

| # | Component | What Works | What's Missing |
|---|-----------|------------|----------------|
| 1 | **Hermes AI Agent** | Service runs, Discord bot active, ROCm configured | OpenAI API key NOT in sops (TODO); SSH deploy key not installed; no fallback model set |
| 2 | **Monitor365** | Agent + server deployed, ActivityWatch integration | Server had DB path crash-loop (fixed in 131c, needs `reset-failed`); 6 Gatus health checks may be stale |
| 3 | **Twenty CRM** | Running via Docker Compose, collation auto-fix | Intermittent 502s (`connection refused` port 3200) — OOM or PG exhaustion suspected |
| 4 | **Darwin (macOS)** | Shell, packages, Homebrew, Chrome policies, keychain | No terminal/editor/theme parity; 7-line HM config; no services; no CI validation |
| 5 | **Pi 3 DNS failover** | Module written (`dns-failover.nix`), rpi3 config exists | Hardware not provisioned; no sops-nix age identity; VRRP password in plaintext |
| 6 | **DNS over QUIC** | dnsblockd supports DoQ | Disabled — Unbound not compiled with ngtcp2. Firefox DoH disabled via policy instead |
| 7 | **Security hardening** | fail2ban (SSH), ClamAV, polkit, 30+ defensive tools | Auditd broken (NixOS 26.05 bug #483085); AppArmor disabled (`mkDefault false`) |
| 8 | **Upstream contributions** | `projects-management-automation` module correctly delegates to upstream flake | 13 upstream contribution TODOs untouched (nixpkgs, HM, Go repos) |
| 9 | **File & Image Renamer** | Service enabled, AI renaming active | Mixed API key conventions (`apiKeyFile` vs `syntheticApiKeyFile`); legacy `watchDirectory` alongside `watchPaths` |
| 10 | **DiscordSync** | Re-enabled (session 128), token regenerated | Had UNIQUE constraint violations; no health monitoring |
| 11 | **Overview (PMA consumer)** | SDK discovery daemon wired (session 135) | Deployed but **unverified** — no reboot since deployment |
| 12 | **Crush Daily** | Module enabled, health check fixed | Added to PATH; Immich health endpoint wired; unverified post-deploy |
| 13 | **Photomap** | Module written | Disabled (`enable = false`) — "podman config permission issue"; uses Podman while everything else uses Docker |
| 14 | **Voice Agents** | Module written (LiveKit + Whisper ROCm) | Disabled — GPU headroom concern, never deployed |
| 15 | **Minecraft** | Full module (server + Prism Launcher client) | Disabled — server not needed; client config exists |

---

## c) NOT STARTED 📋

| # | Item | Priority | Notes |
|---|------|----------|-------|
| 1 | **Reboot evo-x2** | 🔴 CRITICAL | Multiple sessions of fixes unverified: boot ordering, Caddy sops dependency, NVMe APST, SMTP wiring, SDK daemon. Target boot ~35s (was 6m17s) |
| 2 | **ROADMAP.md** | Medium | Requested since session 132; closest equivalent is a static analysis from 2025-10-31 |
| 3 | **CHANGELOG.md** | Medium | 185+ commits, zero changelog |
| 4 | **Status report archival** | Medium | 580+ files across 3 locations (`docs/status/`, `docs/status/archive/`, `docs/archive/status/`). Should reduce to ~30 active |
| 5 | **BTRFS `/data` migration** | Medium | `/data` is BTRFS toplevel (subvolid=5) — cannot be snapshotted. `just snapshot-migrate-data` exists but never run |
| 6 | **Swap investigation** | Low | 8 GiB swap used on 128 GiB RAM system. Stale LSP processes mitigated but root cause not fully resolved |
| 7 | **Auditd enablement** | Blocked | NixOS 26.05 bug #483085 — kernel audit system broken |
| 8 | **AppArmor enablement** | Low | `mkDefault false`; path forward documented but not started |
| 9 | **Monitor365 agent→server auth** | Medium | No authentication — server listens on `0.0.0.0`, LAN-accessible |
| 10 | **Module splitting** | Low | `monitor365` (600+ LOC), `signoz` (700+ LOC), `forgejo` (520+ LOC) are too large |
| 11 | **macOS CI runner** | Medium | CI only runs on `ubuntu-latest`; Darwin config never validated remotely |
| 12 | **Private cloud (Hetzner)** | Long-term | Planning docs exist (`docs/planning/private-cloud-planning/`); no implementation |

---

## d) TOTALLY FUCKED UP! 💥

| # | Issue | Severity | Details |
|---|-------|----------|---------|
| 1 | **Plaintext secrets in git** | 🔴 CRITICAL | `dns-blocker-config.nix` embeds dnsblockd CA certificate in plaintext. VRRP password (`DNSClusterVRRP-evox2`) via `pkgs.writeText`. Both committed to git history. |
| 2 | **580+ status report files** | 🔴 HIGH | `docs/status/` (~50 active), `docs/status/archive/` (374 files), `docs/archive/status/` (160+ files). Massive repo bloat. Status reports should NOT be in git — use a wiki, issue tracker, or external docs. |
| 3 | **Dozzle dead module** | 🟡 MEDIUM | `dozzle.nix` exists as a full module but is bypassed by inline config in `configuration.nix` (lines 121-130). Comment says "Inline config to avoid nix flake check eval issue." Dead code. |
| 4 | **Duplicate pre-commit systems** | 🟡 MEDIUM | Both `.pre-commit-config.yaml` (framework, 9 hooks) and `.githooks/pre-commit` (standalone bash) coexist with different behavior. Potential conflict if both active. |
| 5 | **README CI/CD claims are lies** | 🟡 MEDIUM | README claims "macOS runner" and "Full Darwin build on macOS runner" — neither exists. Only `ubuntu-latest` with `--no-build`. |
| 6 | **`trailing-whitespace` hook hardcoded to NixOS path** | 🟡 MEDIUM | Uses `/run/current-system/sw/bin/sed` — will fail on macOS/darwin where this path doesn't exist. |
| 7 | **`treefmt/` is an empty directory** | 🟢 LOW | `just format` calls bare `treefmt` with no local config — relies entirely on external `treefmt-full-flake`. Works but fragile. |
| 8 | **`pkgs/README.md` references nonexistent `modernize.nix`** | 🟢 LOW | Documents a `modernize` package that doesn't exist in `pkgs/` or flake outputs. |
| 9 | **Forgejo mirror script duplication** | 🟡 MEDIUM | `forgejo.nix` and `forgejo-repos.nix` have overlapping mirror logic — ~280 LOC of duplicated GitHub→Forgejo sync scripts. |
| 10 | **Zed editor config duplicated** | 🟡 MEDIUM | Identical Zed settings in both `platforms/nixos/users/home.nix` and `platforms/darwin/home.nix`. Should be in `common/`. |
| 11 | **`sops.nix` misfiled** | 🟡 MEDIUM | 20+ secret declarations with hardcoded paths to `platforms/nixos/secrets/` — this is configuration, not a reusable service module. Belongs in `platforms/`. |
| 12 | **Pipe operators in sops.nix** | 🟡 MEDIUM | Uses experimental `|>` syntax — requires `extra-experimental-features = ["pipe-operators"]`. Non-standard, may break on Nix updates. |
| 13 | **Hermes hardcoded `getent passwd lars`** | 🟡 MEDIUM | `hermes.nix:159` — hardcoded username lookup instead of using `config.users.primaryUser`. Breaks if username changes. |
| 14 | **Immich hardening bypass** | 🟡 MEDIUM | `ProtectHome = lib.mkForce false` + `ProtectSystem = lib.mkForce false` — significant security bypass for VAAPI access. |

---

## e) WHAT WE SHOULD IMPROVE! 🎯

### Architecture & Design

1. **Extract reusable helpers from personal modules** — `protectedVHost` (Caddy), `mkHttpCheck` (Gatus), pocket-id-oauth integration, `mkDesktopNotifyService` — these are genuinely reusable patterns trapped inside personal config. Extract to `lib/` or publish as standalone flakes.

2. **Push upstream-ready modules to their repos** — `pocket-id.nix` (400 LOC, declarative provisioning), `signoz.nix` (700 LOC, full build), `dns-blocker.nix` (330 LOC), `monitor365.nix` (600 LOC), `hermes.nix` — these are full NixOS modules for specific services that belong in those service repos, not in a personal dotfiles repo.

3. **Centralize ALL secrets in `sops.nix`** — `manifest.nix` and `twenty.nix` declare their own inline. This breaks the "central registry" convention and makes secret auditing harder.

4. **Split oversized modules** — `monitor365` (600+ LOC), `signoz` (700+ LOC), `forgejo` (520+ LOC) are doing too much. Split into sub-modules or extract configuration data.

5. **Move `sops.nix` to `platforms/nixos/`** — It's machine-specific configuration (hardcoded secret paths), not a reusable service module.

### Security

6. **Rotate leaked secrets** — CA cert and VRRP password are in git history. Even after moving to sops, the history contains them. Need rotation + potentially `git filter-repo` cleanup.

7. **Fix Immich hardening bypass** — `ProtectHome = false` + `ProtectSystem = false` is unnecessary with proper `ReadWritePaths` + device access.

8. **Add Monitor365 server auth** — Listening on `0.0.0.0` with no authentication is a security hole on a LAN-accessible service.

9. **Tighten fail2ban `ignoreip`** — Currently includes broad ranges (`10.0.0.0/8`, `172.16.0.0/12`). Should be scoped to actual LAN subnet.

### Quality & Maintenance

10. **Purge status report bloat** — 580+ files is insane. Keep last 10 in `docs/status/`, archive rest to a separate branch or delete entirely. These are not source code.

11. **Fix CI claims** — Either add a macOS runner or update README to reflect reality.

12. **Consolidate pre-commit systems** — Pick one (`.pre-commit-config.yaml` framework OR `.githooks/`), delete the other.

13. **Replace experimental pipe operators** — `sops.nix` uses `|>` which requires experimental features. Use standard `lib.pipe` or `builtins.foldl'` instead.

14. **Kill the Dozzle dead module** — Either use the module or delete `dozzle.nix`. Inline config + dead module is confusing.

15. **Add Darwin CI** — Even `nix flake check --no-build` on aarch64-darwin would catch eval errors.

### Documentation

16. **Create ROADMAP.md** — Long overdue. The 2025-10-31 analysis is stale.

17. **Create CHANGELOG.md** — 185+ commits with no changelog makes release tracking impossible.

18. **Update FEATURES.md** — Last fully audited 2026-05-03; several sessions of changes since.

---

## f) Top #25 Things We Should Get Done Next! 🚀

| # | Task | Impact | Effort | Priority |
|---|------|--------|--------|----------|
| 1 | **Reboot evo-x2** — verify boot time, Caddy ordering, SMTP, SDK daemon, all session 130-135 fixes | 🔴 Critical | 10min | P0 |
| 2 | **Rotate leaked secrets** — dnsblockd CA cert + VRRP password are in plaintext in git | 🔴 Critical | 2h | P0 |
| 3 | **`nix-collect-garbage`** — `/` at 93% (36G free), urgent cleanup needed | 🔴 Critical | 30min | P0 |
| 4 | **Purge 540+ archived status reports** — move to separate branch or delete | 🔴 High | 1h | P0 |
| 5 | **Fix Twenty CRM 502s** — investigate OOM/PG exhaustion on port 3200 | 🔴 High | 2h | P1 |
| 6 | **Add Hermes OpenAI API key** to sops + configure fallback model | 🟡 Medium | 30min | P1 |
| 7 | **Reset Monitor365 failed state** — `systemctl --user reset-failed monitor365-server` | 🟡 Medium | 5min | P1 |
| 8 | **Audit Gatus health checks** — 6 services showing DOWN | 🟡 Medium | 1h | P1 |
| 9 | **Fix plaintext secrets** — move CA cert + VRRP password to sops | 🔴 High | 1h | P1 |
| 10 | **Kill Dozzle dead module** — delete `dozzle.nix`, use inline config or vice versa | 🟡 Medium | 15min | P1 |
| 11 | **Move `sops.nix` to `platforms/nixos/`** — it's configuration, not a module | 🟡 Medium | 30min | P2 |
| 12 | **Consolidate pre-commit systems** — pick one, delete the other | 🟡 Medium | 30min | P2 |
| 13 | **Fix README CI/CD claims** — either add macOS runner or correct docs | 🟡 Medium | 30min | P2 |
| 14 | **Extract `protectedVHost` to `lib/`** — reusable Caddy auth helper | 🟢 High value | 1h | P2 |
| 15 | **Centralize manifest/twenty secrets** in `sops.nix` | 🟡 Medium | 30min | P2 |
| 16 | **Replace pipe operators** in `sops.nix` with `lib.pipe` | 🟡 Medium | 30min | P2 |
| 17 | **Fix Hermes hardcoded `getent passwd lars`** — use `config.users.primaryUser` | 🟡 Medium | 15min | P2 |
| 18 | **BTRFS `/data` migration** — `just snapshot-migrate-data` | 🟡 Medium | 1h | P2 |
| 19 | **Create ROADMAP.md** | 🟡 Medium | 1h | P3 |
| 20 | **Create CHANGELOG.md** | 🟡 Medium | 2h | P3 |
| 21 | **Push pocket-id module upstream** — highest-value upstreamable code | 🟢 High value | 4h | P3 |
| 22 | **Fix Immich hardening bypass** — replace `ProtectHome=false` with proper `ReadWritePaths` | 🟡 Medium | 1h | P3 |
| 23 | **Add Monitor365 server auth** — no auth on `0.0.0.0` listener | 🟡 Medium | 2h | P3 |
| 24 | **Add Darwin CI** — at minimum `nix flake check --no-build` on aarch64-darwin | 🟡 Medium | 2h | P3 |
| 25 | **Split oversized modules** — monitor365, signoz, forgejo into sub-modules | 🟢 Low urgency | 1 day | P4 |

---

## g) Top #1 Question I Cannot Figure Out Myself 🤔

**Why are there 580+ status report files committed to a Nix configuration repository — and should we purge them from git history entirely, or preserve them in a separate archive branch?**

This is the single biggest quality issue in the repo. These files are not source code, not configuration, and not documentation — they are session logs that grow with every AI session. They bloat the repo, slow down clones, make `git log` noisy, and serve no purpose that a wiki or issue tracker couldn't handle better. But they contain historical context that might be valuable for understanding why certain decisions were made.

**I need your decision:** Should I:
- **(A)** Delete all but the last 10 and `git mv` the rest to an `archive` branch?
- **(B)** Delete them all entirely (they're in git history if needed)?
- **(C)** Move them to an external location (wiki, separate repo)?
- **(D)** Leave them as-is?

This decision blocks the repo cleanup work and I cannot make it autonomously because it involves irreversibly deleting historical context.

---

## Metrics Summary

| Metric | Value |
|--------|-------|
| Total Nix LOC | ~16,500 |
| Flake inputs | 52 (24 GitHub, 28 SSH/private) |
| NixOS service modules | 39 (+ 1 dead: Dozzle) |
| Custom packages | 6 local + 20 via overlays |
| lib/ helpers | 13 |
| Port registry entries | 35 |
| Justfile recipes | 93 |
| Pre-commit hooks | 9 (+ 5 duplicate in .githooks) |
| VM tests | 2 (boot, DNS blocking) |
| Status report files | ~580+ across 3 locations |
| Open TODOs | 45 |
| Completed TODOs | 35 |
| Planning docs | 37 |
| ADRs | 8 |
| Hosts | 3 (evo-x2, Lars-MacBook-Air, rpi3-dns) |
| Disabled services | 3 (voice-agents, minecraft, photomap) |
| Known broken services | 3 (Twenty 502s, Monitor365 failed state, Gatus stale checks) |
| Plaintext secrets in git | 2 (CA cert, VRRP password) |
| Disk usage `/` | 93% (36G free) |
| Disk usage `/data` | 77% (238G free) |

---

_Generated by Crush session 137 — 2026-06-14 02:32_
