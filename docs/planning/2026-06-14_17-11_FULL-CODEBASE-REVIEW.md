# Full Codebase Review — 2026-06-14

## Executive Summary

**Scope:** 121 `.nix` files (16,924 lines), 30+ shell scripts, 5 custom packages, 3 NixOS hosts, 1 Darwin host, 2 CI workflows, 922 tracked markdown files (15MB docs/).

**Build status:** `just test-fast` passes. `statix` clean. `deadnix` clean.

| Severity | Count | Themes |
|----------|-------|--------|
| 🔴 Critical | 3 | Undefined systemd target, secret in nix store, misnested sops template |
| 🟠 High | 10 | Hardcoded secrets/domains, dead code in overlay helper, massive doc bloat, cross-platform duplication |
| 🟡 Medium | 18 | Missing hardening/onFailure/startLimits, large files, hardcoded values, stale code |
| 🟢 Low | 12 | Dead scripts, IDE files in git, minor inconsistencies |

---

## 🔴 Critical Issues

### C1: `signoz.target` is never defined — services won't auto-start at boot

**File:** `modules/nixos/services/signoz.nix:257,559,581`

Three services use `wantedBy = ["signoz.target"]` (signoz, cadvisor, signoz-collector) but `systemd.targets.signoz` is defined **nowhere** in the entire codebase. Without the target unit being pulled into the boot chain, these services will NOT start automatically.

```nix
# MISSING — needs to be added:
systemd.targets.signoz = {
  description = "SigNoz observability stack";
  wantedBy = [ "multi-user.target" ];
};
```

### C2: VRRP auth password in world-readable nix store path

**Files:** `platforms/nixos/system/dns-blocker-config.nix:69`, `platforms/nixos/rpi3/default.nix:144`

```nix
passwordFile = pkgs.writeText "keepalived-vrrp-env" "VRRP_AUTH_PASSWORD=DNSClusterVRRP-evox2";
```

`pkgs.writeText` creates a **world-readable** file in `/nix/store`. The VRRP auth password is exposed to any local user. The `dns-failover.nix` module already documents the correct approach (sops template) but the consumers bypass it.

### C3: `pma-env` sops template incorrectly nested inside `hermes.enable`

**File:** `modules/nixos/services/sops.nix:177-184`

The `pma-env` template (for `projects-management-automation.service`) is inside `lib.optionalAttrs config.services.hermes.enable {}`. If PMA is enabled without Hermes, the env file is never created and PMA fails silently.

---

## 🟠 High Issues

### H1: Dead code in `mkPackageOverlay` — both if/else branches are identical

**File:** `overlays/default.nix:10-14`

```nix
${name} =
  if overrides == {}
  then pkg
  else if builtins.isFunction overrides
  then pkg.overrideAttrs overrides   # ← same as below
  else pkg.overrideAttrs overrides;   # ← same as above
```

Both arms of the inner `if` do `pkg.overrideAttrs overrides`. The `isFunction` check is dead code. Should be simplified to `if overrides == {} then pkg else pkg.overrideAttrs overrides`.

### H2: 922 markdown files vs 121 Nix files (7.6:1 doc-to-code ratio)

**Repo bloat:** `docs/` is 15MB. `docs/status/` alone has 565 session logs (374 already in `archive/`). `.git/` is 90MB. These files are tracked in git, slow down clones, and bury useful information.

**Recommendation:** Move pre-2026 status reports to `git` history only (delete from working tree). Keep only the last 10-20 status reports. Archive old planning docs.

### H3: Duplicate Zed editor config (~70 lines copy-pasted)

**Files:** `platforms/nixos/users/home.nix:127-199`, `platforms/darwin/home.nix:22-93`

The entire `zed-editor.userSettings` block is duplicated. Should be extracted to `platforms/common/programs/zed.nix`.

### H4: Darwin imports from `nixos/` directory (wrong layering)

**File:** `platforms/darwin/home.nix:15-16`

```nix
../nixos/programs/zellij.nix
../nixos/programs/yazi.nix
```

Darwin should only import from `common/`. These modules already have cross-platform logic (`stdenv.isDarwin` checks) so they belong in `common/programs/`.

### H5: `monitor365.nix` port collision — reuses SigNoz cAdvisor port

**File:** `modules/nixos/services/monitor365.nix:472`

```nix
default = "127.0.0.1:${toString ports.signoz-cadvisor}";
```

Monitor365 metrics binds to port 9190, the same port cAdvisor uses. If both enabled, they collide. Monitor365 needs its own port in `lib/ports.nix`.

### H6: Forgejo admin password visible in process listing

**File:** `modules/nixos/services/forgejo.nix:245-270`

Admin password is passed via CLI arg `--password "$ADMIN_PASS"`, visible via `ps aux`. Should use stdin or an environment file.

### H7: `sops.nix` — `gatus-env` template gated on `signoz.enable` instead of `gatus-config.enable`

**File:** `modules/nixos/services/sops.nix:218-227`

The Discord webhook env for Gatus is only created when SigNoz is enabled. If Gatus runs without SigNoz, alerting breaks.

### H8: `discordsync.nix` — `Restart = "on-failure"` silently overridden to `"always"`

**File:** `modules/nixos/services/discordsync.nix:103,112`

Inline `Restart = "on-failure"` (line 103) is overridden by `serviceDefaults {}` (line 112) which sets `Restart = mkForce "always"`. The intent of `on-failure` is lost.

### H9: Pocket-ID hardcoded SMTP server and personal email domain

**File:** `modules/nixos/services/pocket-id.nix:410-413`

`SMTP_HOST = "smtp.resend.com"`, `SMTP_USER = "resend"`, `SMTP_FROM = "noreply@cloud.larsartmann.com"` are hardcoded with no options to override.

### H10: Dead scripts with hardcoded nix store paths

**Files:** `scripts/check-firewall.sh:3`, `scripts/check-mullvad-nft.sh:2`, `scripts/diagnose-mullvad.sh:51`

```bash
/nix/store/a7sf90yc74dha1bcj2wx6hh3w10qf19z-nftables-1.1.6/bin/nft
```

These store paths break on any rebuild. The scripts themselves are dead code (not referenced by justfile, flake.nix, or systemd).

---

## 🟡 Medium Issues

### M1-M7: Missing systemd hardening/onFailure/startLimits

| Service | Missing | File |
|---------|---------|------|
| `dnsblockd` | `onFailure` | `dns-blocker.nix:249` |
| `mptcp-endpoint-manager` | `onFailure`, `startLimitBurst` | `dual-wan.nix:132` |
| `route-health-monitor` | `onFailure`, `startLimitBurst` | `dual-wan.nix:155` |
| `immich-server` | `onFailure` | `immich.nix:66` |
| `immich-machine-learning` | `onFailure` | `immich.nix:75` |
| `clickhouse` | `startLimitBurst` | `signoz.nix:240` |
| `signoz-provision` | `harden`, runs as root | `signoz.nix:286` |
| `gitea-runner-*` | `harden` | `forgejo.nix:559` |

### M8: Files over 350 lines that should be split

| File | Lines | Recommendation |
|------|-------|----------------|
| `flake.nix` | 769 | Extract input declarations to `flake/inputs.nix` |
| `monitor365.nix` | 716 | Split config/options/systemd |
| `signoz.nix` | 705 | Split package builds/options/provisioning |
| `forgejo.nix` | 583 | Extract scripts to separate files |
| `home.nix` (nixos) | 544 | Split terminals/zed/dunst/GTK |
| `niri-wrapped.nix` | 520 | Split keybinds/window-rules/services |
| `waybar.nix` | 474 | Split into modules per bar section |
| `pocket-id.nix` | 474 | Extract provisioning script |
| `scheduled-tasks.nix` | 466 | Extract inline scripts to files |
| `minecraft.nix` | 453 | Extract 250 lines of options.txt to data |
| `yazi.nix` | 446 | Extract init.lua to separate file |

### M9: Hardcoded values that should be options or shared constants

- `time.timeZone = "Europe/Berlin"` duplicated in `networking.nix:79` and `rpi3/default.nix:92`
- `system.stateVersion = "25.11"` duplicated in `configuration.nix:190` and `rpi3/default.nix:59`
- `domain = "home.lan"` duplicated in `networking.nix:10` and `rpi3/default.nix:11`
- DNS local-data subdomain lists diverge between evo-x2 and rpi3 (evo-x2 has `manifest`, rpi3 has `photomap`)

### M10: `home.stateVersion` mismatch

**Files:** `home-base.nix:64` (`"24.05"`), `configuration.nix:190` (`"25.11"`)

HM state version is significantly behind system version. May cause HM schema warnings.

### M11: Hardcoded image SHAs bypass `lib/images.nix` registry

- `voice-agents.nix:19` — `beecave/insanely-fast-whisper-rocm@sha256:...`
- `photomap.nix:37` — `lstein/photomapai@sha256:...`

### M12: `commit-tag-push.py` uses `--no-verify` (bypasses pre-commit hooks)

**File:** `scripts/commit-tag-push.py:92`

Bypasses secret scanning, formatting, and linting.

### M13: Port import bypasses collision detection

**File:** `platforms/nixos/desktop/waybar.nix:9`

```nix
dnsStatsPort = (import ../../../lib/ports.nix).ports.dns-blocker-stats;
```

Direct import of `ports.nix` bypasses the collision detection in `lib/default.nix:96-107`.

### M14: `EDITOR` / `VISUAL` inconsistency

- `environment/variables.nix:9`: `EDITOR = "micro"`
- `home-base.nix:50`: `VISUAL = "code --wait"`
- `git.nix:26`: `core.editor = "code --wait"`

Programs checking `$VISUAL` use VS Code; those checking `$EDITOR` use micro.

### M15: Deprecated test framework

**File:** `tests/default.nix:8`

Uses deprecated `make-test-python.nix`. Since nixpkgs 24.11, `make-test.nix` defaults to Python.

### M16: CI doesn't build packages

**File:** `.github/workflows/nix-check.yml`

Only runs `nix flake check --no-build`. No package builds, no cross-platform matrix.

### M17: DNS local-data lists diverge between failover nodes

**Files:** `dns-blocker-config.nix:59`, `rpi3/default.nix:130`

evo-x2: `[..., "manifest", ...]` vs rpi3: `[..., "photomap", ...]`. Should be a shared constant.

### M18: Test coverage gaps

Only 2 test cases exist (boot, dns-blocking). 0 tests for any of the 30+ custom service modules.

---

## 🟢 Low Issues

### L1: `legacy/` directory — 20 dead files (100KB)
Old dotfiles, iTerm2 profile, Chrome plugins list, sublime config. None referenced by Nix config.

### L2: `.idea/` directory — 11 files tracked in git
IDE-specific config. Should be fully gitignored, not partially.

### L3: Empty `reports/` directory
Created but never used.

### L4: Dead scripts (10+ files)
`check-firewall.sh`, `check-mullvad-nft.sh`, `diagnose-mullvad.sh`, `disk-diagnostic.sh`, `usb-diagnostic.sh`, `commit-tag-push.py`, `fix-versions.py`, `prefetch-crates.py`, `update-vendor-hash.sh` — none wired into justfile/flake/systemd.

### L5: Stale TODO in `sops.nix:110`
```nix
# hermes_openai_api_key = "openai_api_key"; # TODO: add openai_api_key to hermes.yaml sops secret
```

### L6: `security-hardening.nix:57` — hardcoded `onFailure` literal
Duplicates `["notify-failure@%n.service"]` instead of importing from lib.

### L7: `monitor365.nix:529` — misleading `pkgs.monitor365-server or pkgs.monitor365`
`pkgs.monitor365-server` doesn't exist in nixpkgs. Always falls back.

### L8: Template uses anti-pattern it warns about
`templates/go-flake-parts/flake.nix:51` uses `self.shortRev or self.dirtyRev or "dev"`.

### L9: `auto-optimise-store` set redundantly in rpi3
`rpi3/default.nix:199` duplicates setting from imported `nix-settings.nix:34`.

### L10: Package duplication (HM `programs.*.enable` + explicit package list)
- `zellij` — enabled in module AND in `base.nix:261`
- `yazi` — enabled in module AND in `home.nix:289`
- `rofi-calc`/`rofi-emoji` — used as plugins AND standalone packages

### L11: Hardcoded nix store path in scripts
3 scripts reference `/nix/store/a7sf90yc74dha1bcj2wx6hh3w10qf19z-nftables-1.1.6/bin/nft`.

### L12: `darwinConfig` path stale
`darwin/system/activation.nix:61` points to `~/.nixpkgs/darwin-configuration.nix` but flake is at `~/projects/SystemNix`.

---

## Strengths (What's Done Well)

- **Excellent lib/ abstraction layer** — `harden`, `serviceDefaults`, `mkDockerServiceFactory`, `ports` (with collision detection), `serviceTypes` — clean, composable, well-documented
- **Port centralization** with runtime collision detection (`lib/default.nix:96-107`) is genuinely innovative
- **Consistent overlay architecture** — `mkPackageOverlay` is platform-safe, follows `final: _prev:` convention
- **`follows` chains are thorough** — every shared input properly followed to avoid duplicate instances
- **Statix and deadnix pass clean** — code is well-formed
- **BTRFS snapshot integration** — pre-deploy snapshots, auto-pruning, verification timer
- **Comprehensive systemd hardening** — most services use `harden {} // serviceDefaults {}`
- **Auto-discovery of service modules** — no manual import lists to maintain
- **Well-maintained AGENTS.md** — comprehensive project context for AI sessions

---

## Pareto-Prioritized Action Plan

### 🔴 1% → 51% Impact (Do First)

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 1 | Define `systemd.targets.signoz` in signoz.nix | 2min | Services auto-start |
| 2 | Move VRRP password to sops secret | 15min | Security fix |
| 3 | Fix `pma-env` sops template nesting | 5min | PMA works without Hermes |
| 4 | Fix `mkPackageOverlay` dead code | 2min | Code clarity |
| 5 | Fix `gatus-env` sops gate (signoz→gatus-config) | 5min | Gatus works without SigNoz |
| 6 | Fix `discordsync.nix` Restart override | 5min | Correct restart behavior |

### 🟠 4% → 64% Impact (Do Second)

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 7 | Move zellij.nix, yazi.nix to `common/programs/` | 20min | Correct layering |
| 8 | Extract Zed config to `common/programs/zed.nix` | 20min | Remove 70-line duplication |
| 9 | Add `monitor365` port to `ports.nix` | 10min | Fix port collision |
| 10 | Add missing `onFailure` to 6 services | 30min | Failure notifications |
| 11 | Add missing `startLimitBurst` to 3 services | 10min | Prevent crash loops |
| 12 | Delete old status reports (keep last 20) | 15min | -14MB repo bloat |
| 13 | Move `legacy/` to git history (delete) | 5min | Remove dead code |
| 14 | Add `.idea/` to `.gitignore`, untrack | 5min | Remove IDE noise |
| 15 | Delete dead scripts | 10min | Remove confusion |

### 🟡 20% → 80% Impact (Do Third)

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 16 | Extract shared constants (timezone, domain, stateVersion) | 30min | DRY config |
| 17 | Make Pocket-ID SMTP configurable | 20min | Flexibility |
| 18 | Harden `signoz-provision` and `gitea-runner` | 30min | Security |
| 19 | Move hardcoded image SHAs to `lib/images.nix` | 15min | Centralized pinning |
| 20 | Fix `home.stateVersion` mismatch | 5min | Consistency |
| 21 | Add `harden` to `twenty-fix-collation` | 5min | Security |
| 22 | Migrate tests to `make-test.nix` | 10min | Future-proof |
| 23 | Add package build to CI | 30min | Catch build breaks |
| 24 | Fix `EDITOR`/`VISUAL` inconsistency | 5min | Consistency |
| 25 | Unify DNS subdomain lists between failover nodes | 15min | Correct failover |

---

## D2 Execution Graph

```
┌─────────────────────────────────────────────────────────────┐
│                    PHASE 1: Critical (1h)                     │
├─────────────────────────────────────────────────────────────┤
│  signoz.target ──► VRRP sops ──► pma-env fix ──► overlay fix │
│  gatus-env fix ──────────────► discordsync Restart fix       │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│               PHASE 2: High Impact (2-3h)                    │
├─────────────────────────────────────────────────────────────┤
│  Module relocation ──► Zed dedup ──► Port collision fix      │
│  onFailure sweep ──► startLimit sweep ──► Doc cleanup        │
│  legacy/ removal ──► .idea untrack ──► Dead script removal   │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              PHASE 3: Consistency (3-4h)                     │
├─────────────────────────────────────────────────────────────┤
│  Shared constants ──► SMTP options ──► Service hardening     │
│  Image registry ──► stateVersion ──► CI improvements         │
│  Test framework ──► EDITOR/VISUAL ──► DNS failover sync      │
└─────────────────────────────────────────────────────────────┘
```
