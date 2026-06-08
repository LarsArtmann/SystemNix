# Migration to Nix Flakes Proposal

**SystemNix Repository — Imperative-to-Declarative Migration Analysis**

| Field | Value |
|-------|-------|
| **Author** | SystemNix maintainers |
| **Date** | 2026-04-09 |
| **Status** | Proposal |
| **Scope** | Justfile recipes, shell scripts, dotfile scripts |
| **Current declarative coverage** | ~65% |
| **Target declarative coverage** | ~85% |

---

## Table of Contents

- [1. Executive Summary](#1-executive-summary)
- [2. Current State Analysis](#2-current-state-analysis)
  - [2.1 Imperative Automation Inventory](#21-imperative-automation-inventory)
  - [2.2 Already-Declarative Inventory](#22-already-declarative-inventory)
  - [2.3 Key Observations](#23-key-observations)
- [3. Classification Matrix](#3-classification-matrix)
  - [3.1 Shell Scripts](#31-shell-scripts)
  - [3.2 Justfile Recipes](#32-justfile-recipes)
  - [3.3 Dotfile Scripts](#33-dotfile-scripts)
- [4. Migration Phases](#4-migration-phases)
  - [4.1 Phase 1 — Quick Wins](#41-phase-1--quick-wins)
  - [4.2 Phase 2 — Medium Effort](#42-phase-2--medium-effort)
  - [4.3 Phase 3 — Deep Nixification](#43-phase-3--deep-nixification)
- [5. Specific Migration Recommendations](#5-specific-migration-recommendations)
  - [5.1 Scripts → Nix](#51-scripts--nix)
  - [5.2 Justfile Recipes → Nix](#52-justfile-recipes--nix)
  - [5.3 New Flake Outputs](#53-new-flake-outputs)
- [6. Risk Analysis and Trade-offs](#6-risk-analysis-and-trade-offs)
- [7. Implementation Checklist](#7-implementation-checklist)
- [Appendix A — Full Justfile Recipe Inventory](#appendix-a--full-justfile-recipe-inventory)
- [Appendix B — Archived Scripts Assessment](#appendix-b--archived-scripts-assessment)

---

## 1. Executive Summary

SystemNix is a cross-platform Nix configuration managing macOS (aarch64-darwin) and NixOS (x86_64-linux) from a single flake. The project is approximately **65% declarative** through Nix — packages, services, user programs, and system configuration are managed via flake.nix, home-manager, and flake-parts modules.

The remaining **35% imperative layer** consists of:

- **1 justfile** with ~80+ recipes (1828 lines)
- **17 active shell scripts** (~4,500 lines total)
- **10 archived shell scripts** (~2,000 lines total)
- **4 dotfile scripts** (~100 lines total)

This proposal maps every piece of imperative automation to one of three classifications:

| Classification | Meaning | Estimated Count |
|---------------|---------|-----------------|
| **Migrate** | Fully replace with Nix constructs | ~15 items |
| **Partial** | Extract declarative parts; keep operational core as script | ~20 items |
| **Keep** | Inherently imperative; no Nix equivalent | ~25 items |

**Key insight:** Most remaining imperative code is *operational tooling that serves the Nix system itself* — cleanup, monitoring, validation, deployment helpers. These scripts are the scaffolding around a declarative system, not configuration that belongs inside it. The migration should be targeted, not total.

**Expected outcome:** Increase declarative coverage from ~65% to ~85%, eliminate ~1,500 lines of shell code that duplicates what Nix already provides, and package remaining operational scripts as proper Nix derivations.

---

## 2. Current State Analysis

### 2.1 Imperative Automation Inventory

#### Active Shell Scripts (17 scripts)

| Script | Lines | Purpose | Category |
|--------|-------|---------|----------|
| `scripts/cleanup.sh` | 363 | System cleanup with dry-run, retention policies, multi-cache GC | Maintenance |
| `scripts/optimize.sh` | 505 | Performance optimization with profiles (conservative/balanced/aggressive) | Performance |
| `scripts/lib/paths.sh` | 157 | Path constants library (`PROJECT_ROOT`, `DOTFILES_DIR`, etc.) | Infrastructure |
| `scripts/maintenance.sh` | 681 | Orchestrator with scheduling, task tracking, cleanup/optimize/health/backup | Maintenance |
| `scripts/health-check.sh` | 574 | System health monitoring with alerting thresholds | Monitoring |
| `scripts/deploy-evo-x2.sh` | 25 | NixOS deploy via `nh os switch` + post-deploy checks | Deployment |
| `scripts/storage-cleanup.sh` | 65 | Quick cache cleanup (Library/Caches, Go build cache, temp files) | Maintenance |
| `scripts/nixos-diagnostic.sh` | 158 | Home Manager error diagnostics, flake/rebuild checks | Diagnostics |
| `scripts/benchmark-system.sh` | 372 | Shell/build/system/file-ops benchmarks via hyperfine, JSON results | Benchmarking |
| `scripts/health-dashboard.sh` | 129 | Color-coded system dashboard (disk, memory, CPU, services) | Monitoring |
| `scripts/test-home-manager.sh` | 304 | Starship/Fish/env/PATH/Tmux integration verification | Testing |
| `scripts/test-shell-aliases.sh` | 195 | Cross-shell (Fish/Zsh/Bash) alias testing per ADR-002 | Testing |
| `scripts/performance-monitor.sh` | 411 | Long-term performance tracking, regression detection, caching | Monitoring |
| `scripts/validate-deployment.sh` | 589 | Pre-deploy validation of NixOS config (boot, GPU, security) | Validation |
| `scripts/update-crush-latest.sh` | 68 | Crush AI update from NUR + NixOS rebuild | Package management |
| `scripts/ai-integration-test.sh` | 158 | Ollama/ROCm GPU acceleration validation | Testing |
| `scripts/shell-context-detector.sh` | 381 | Shell context detection, usage logging, pattern analysis | Development |

**Total: ~5,140 lines across 17 scripts**

#### Dotfile Scripts (4 scripts)

| Script | Lines | Purpose |
|--------|-------|---------|
| `dotfiles/ublock-origin/update-filters.sh` | ~30 | Updates uBlock filter version references |
| `dotfiles/ublock-origin/backup-settings.sh` | ~30 | Backs up uBlock settings from browsers |
| `dotfiles/activitywatch/fix-permissions.sh` | ~20 | macOS Accessibility permissions for ActivityWatch |
| `dotfiles/activitywatch/install-utilization.sh` | ~20 | Installs aw-watcher-utilization Python package |

#### Justfile Recipe Categories (~80+ recipes)

| Category | Recipe Count | Key Recipes |
|----------|-------------|-------------|
| **Core workflow** | ~8 | `setup`, `switch`, `update`, `test`, `test-fast`, `format`, `validate`, `health` |
| **Platform detection** | ~3 | `_detect_platform`, `_get_nix_host`, `_nix_args` (private) |
| **Cleanup** | ~5 | `clean`, `clean-quick`, `clean-aggressive`, `gc`, `docker-clean` |
| **Backup/Restore** | ~6 | `backup`, `restore`, `backup-list`, `rollback`, `snapshots-*` |
| **Go development** | ~10 | `go-dev`, `go-test`, `go-lint`, `go-build`, `go-tools-version`, `go-update-tools-manual` |
| **DNS management** | ~8 | `dns-*` (diagnostics, blocklist, restart, status, flush) |
| **Immich management** | ~6 | `immich-*` (status, backup, restore, reset-password, logs, sync) |
| **Monitoring** | ~5 | `benchmark`, `perf`, `context`, `monitor`, `dashboard` |
| **Service management** | ~6 | `netdata-*`, `ntopng-*`, `signoz-*` |
| **Keychain (macOS)** | ~4 | `keychain-*` (add, list, remove) |
| **AI/Claude** | ~4 | `claude-*`, `update-crush-latest` |
| **Deployment** | ~4 | `deploy-evo-x2`, `deploy-*` |
| **Utilities** | ~10 | `dep-graph`, `tree`, `tmux-*`, `show-config`, `search-*` |

### 2.2 Already-Declarative Inventory

The following are **already managed declaratively** through Nix and should not be migrated (they're already there):

| Area | Nix Construct | Files |
|------|--------------|-------|
| System packages | `platforms/common/packages/base.nix` | 70+ packages across 5 categories |
| User programs | `platforms/common/home-base.nix` + `programs/` | fish, zsh, bash, nushell, starship, tmux, git, fzf, pre-commit, keepassxc, chromium |
| NixOS services | `modules/nixos/services/` | gitea, immich, caddy, authelia, homepage, signoz, photomap, sops |
| Niri compositor | `platforms/nixos/programs/niri-wrapped.nix` | Wrapped with keybinds baked in |
| Boot/hardware | `platforms/nixos/system/boot.nix`, `hardware/` | systemd-boot, kernel params, AMD GPU/NPU, ZRAM |
| Networking | `platforms/nixos/system/networking.nix` | Static IP, firewall |
| DNS blocking | `platforms/nixos/system/dns-blocker-config.nix` | Unbound + dnsblockd |
| Secrets | `modules/nixos/services/sops.nix` | age-encrypted via sops-nix |
| SSH | Via `nix-ssh-config` flake input | External flake-managed |
| macOS LaunchAgents | `platforms/darwin/services/launchagents.nix` | ActivityWatch, Crush updates |
| Formatter | `treefmt-full-flake` via flake-parts | alejandra + other formatters |
| Pre-commit | `.pre-commit-config.yaml` | Linting hooks |
| Custom packages | `pkgs/` | dnsblockd, modernize, aw-watcher-utilization, openaudible |

### 2.3 Key Observations

#### O1: Platform detection reimplemented in shell

The justfile's `_detect_platform` and `_get_nix_host` functions determine platform via `uname`, then select Nix attributes. Nix already knows the platform via `stdenv.hostPlatform` — this information is available at evaluation time and should not require runtime detection.

**Current (justfile):**
```bash
_detect_platform() {
  case "$(uname -s)" in
    Darwin) echo "darwin" ;;
    Linux)  echo "nixos" ;;
  esac
}
```

**Should be:** Separate `just` recipes for each platform, or a single recipe that calls the appropriate nix output directly.

#### O2: Path management duplicated

`scripts/lib/paths.sh` defines 157 lines of path constants (`PROJECT_ROOT`, `DOTFILES_DIR`, `PLATFORMS_DIR`, etc.) that reimplement what Nix already provides via `self.outPath`, `toString ./.`, and the flake's directory structure.

#### O3: GC/Cleanup should be Nix config

Multiple scripts (`cleanup.sh`, `storage-cleanup.sh`, `optimize.sh`) perform garbage collection and cache cleaning. Nix supports declarative GC configuration:

```nix
nix.gc = {
  automatic = true;
  dates = "weekly";
  options = "--delete-older-than 30d";
};
```

macOS equivalent via nix-darwin or LaunchAgent.

#### O4: Deployment validation duplicates `nix flake check`

`validate-deployment.sh` (589 lines) checks NixOS config for boot, GPU, security, and user settings. Much of this could be expressed as Nix assertions or `nix flake check` tests, which would catch issues at build time rather than deploy time.

#### O5: Service management is operational, not configurational

DNS diagnostics, Immich backup, Netdata management — these are *operational* commands that interact with running services. They should remain as scripts/apps, but could be packaged as proper Nix derivations rather than raw shell scripts.

#### O6: Benchmark/monitoring scripts are developer tooling

`benchmark-system.sh`, `performance-monitor.sh`, `shell-context-detector.sh` — these are complex developer tools (~1,160 lines combined). They should be packaged as Nix derivations with their dependencies declared, rather than shell scripts that assume tools like `hyperfine` are available.

#### O7: Backup could use Nix generations more

The justfile's `backup` recipes imperatively copy directories. Nix already provides generational rollback for system and home-manager profiles. The backup strategy could lean more heavily on `nix-env --list-generations` and `home-manager generations` rather than file-level copies.

---

## 3. Classification Matrix

### 3.1 Shell Scripts

| Script | Classification | Rationale |
|--------|---------------|-----------|
| `scripts/lib/paths.sh` | **Migrate** | Replace with Nix `self.outPath` references; eliminate 157 lines |
| `scripts/cleanup.sh` | **Partial** | Declarative GC config for Nix + systemd timers/launchd; keep operational cache cleanup |
| `scripts/optimize.sh` | **Keep** | Runtime performance tuning is inherently imperative; package as Nix app |
| `scripts/maintenance.sh` | **Partial** | Scheduler → systemd timers / launchd; individual tasks stay as apps |
| `scripts/health-check.sh` | **Partial** | Static checks → Nix assertions; runtime checks → packaged Nix app |
| `scripts/deploy-evo-x2.sh` | **Partial** | `nh os switch` is already Nix-native; post-deploy checks → `nix flake check` assertions |
| `scripts/storage-cleanup.sh` | **Migrate** | Subsumed by declarative GC config |
| `scripts/nixos-diagnostic.sh` | **Keep** | Interactive diagnostics are inherently imperative; package as Nix app |
| `scripts/benchmark-system.sh` | **Keep** | Benchmarking is inherently imperative; package as Nix derivation with hyperfine dep |
| `scripts/health-dashboard.sh` | **Keep** | Runtime dashboard; package as Nix app |
| `scripts/test-home-manager.sh` | **Keep** | Runtime-only verification (env vars, `$SHELL`, `$PATH`, HM symlinks); cannot be a build-time check |
| `scripts/test-shell-aliases.sh` | **Keep** | Runtime-only verification (interactive fish aliases, `$HOME` config files); cannot be a build-time check |
| `scripts/performance-monitor.sh` | **Keep** | Long-term monitoring is inherently imperative; package as Nix derivation |
| `scripts/validate-deployment.sh` | **Partial** | Static validation → Nix assertions; runtime checks → packaged app |
| `scripts/update-crush-latest.sh` | **Migrate** | Replace with `nix flake update crush-config && just switch` |
| `scripts/ai-integration-test.sh` | **Partial** | Static checks → Nix assertions; runtime GPU checks → packaged test |
| `scripts/shell-context-detector.sh` | **Keep** | Runtime context detection; package as Nix derivation |

**Summary: 2 Migrate, 5 Partial, 10 Keep**

### 3.2 Justfile Recipes

| Recipe Group | Classification | Recommendation |
|-------------|---------------|----------------|
| `setup` | **Keep** | One-time bootstrap; inherently imperative |
| `switch` | **Keep** | Core workflow; already calls Nix directly |
| `update` | **Keep** | `nix flake update` wrapper; fine as-is |
| `test` / `test-fast` | **Keep** | Build validation wrappers; fine as-is |
| `format` | **Keep** | `treefmt` wrapper; fine as-is |
| `validate` | **Keep** | `nix flake check` wrapper; fine as-is |
| `health` | **Keep** | Orchestrator; calls health-check.sh |
| `_detect_platform` / `_get_nix_host` / `_nix_args` | **Migrate** | Replace with platform-specific recipes or Nix eval |
| `clean` / `clean-quick` / `clean-aggressive` / `gc` | **Partial** | Declarative GC + keep operational commands |
| `docker-clean` | **Keep** | Runtime operation; fine as recipe |
| `backup` / `restore` / `backup-list` | **Partial** | Lean on Nix generations more; keep file backup |
| `rollback` | **Keep** | Thin wrapper over `nix-env`/`home-manager` |
| `go-*` (10 recipes) | **Keep** | Go dev workflow; these wrap Go tools, not Nix |
| `dns-*` (8 recipes) | **Keep** | Service management; keep as recipes or package as Nix apps |
| `immich-*` (6 recipes) | **Keep** | Service management; keep as recipes |
| `benchmark` / `perf` / `context` / `monitor` / `dashboard` | **Keep** | Call packaged scripts; fine as justfile entry points |
| `netdata-*` / `ntopng-*` / `signoz-*` | **Keep** | Service management; keep as recipes |
| `keychain-*` (4 recipes) | **Keep** | macOS KeyChain is inherently imperative |
| `claude-*` / `update-crush-latest` | **Partial** | `update-crush-latest` → simple `nix flake update`; keep Claude recipes |
| `deploy-evo-x2` | **Keep** | Deployment orchestration; calls deploy-evo-x2.sh |
| `dep-graph` | **Keep** | Nice utility; fine as recipe |
| `show-config` | **Keep** | `nix eval` wrapper; fine as-is |
| `tmux-*` | **Keep** | Tmux session management; inherently imperative |
| `search-*` | **Keep** | `nix search` wrappers; useful shortcuts |

**Summary: 2 Migrate, 4 Partial, 14 Keep (recipe groups)**

### 3.3 Dotfile Scripts

| Script | Classification | Rationale |
|--------|---------------|-----------|
| `dotfiles/ublock-origin/update-filters.sh` | **Keep** | External data update; inherently imperative |
| `dotfiles/ublock-origin/backup-settings.sh` | **Keep** | Browser state extraction; inherently imperative |
| `dotfiles/activitywatch/fix-permissions.sh` | **Keep** | macOS Accessibility permissions; must be interactive |
| `dotfiles/activitywatch/install-utilization.sh` | **Migrate** | `aw-watcher-utilization` is already a Nix package in `pkgs/` |

**Summary: 1 Migrate, 3 Keep**

---

## 4. Migration Phases

### 4.1 Phase 1 — Quick Wins

**Effort:** 1–2 days | **Impact:** Eliminates ~600 lines, removes path library dependency

#### 1.1 Eliminate `scripts/lib/paths.sh`

**Current:** 157-line path constant library used by multiple scripts.

**Migration:** Replace all `PROJECT_ROOT`, `DOTFILES_DIR`, etc. references with:
- In Nix: `self.outPath`, `toString ./.`, builtins
- In scripts: Use `git rev-parse --show-toplevel` or pass paths from Nix

**Steps:**
1. Audit all consumers of `paths.sh`
2. Refactor each consumer to derive paths independently or receive them as arguments
3. Delete `scripts/lib/paths.sh`
4. Verify all scripts still function

#### 1.2 Declarative Nix GC Configuration

**Current:** `cleanup.sh` (363 lines), `storage-cleanup.sh` (65 lines), justfile `clean`/`gc` recipes.

**Migration:** Add to NixOS and darwin configs:

```nix
# NixOS (platforms/nixos/system/configuration.nix or new file)
nix.gc = {
  automatic = true;
  dates = "weekly";
  options = "--delete-older-than 30d";
};

# macOS (platforms/darwin/default.nix or new file)
nix.gc = {
  automatic = true;
  interval = { Weekday = 0; };  # Sunday
  options = "--delete-older-than 30d";
};
```

**Remaining imperative:** Keep `clean-quick` and `clean-aggressive` as operational recipes for on-demand use. The automatic GC handles routine maintenance.

#### 1.3 Replace `update-crush-latest.sh`

**Current:** 68-line script that updates crush-config from NUR and rebuilds.

**Migration:** This is already achievable with:
```bash
just update crush-config  # or: nix flake update crush-config
just switch               # apply
```

**Steps:**
1. Verify `just update crush-config` already works (it should — it calls `nix flake lock --update-input crush-config`)
2. Add a justfile recipe that chains update + switch if desired
3. Delete `scripts/update-crush-latest.sh`

#### 1.4 Eliminate `dotfiles/activitywatch/install-utilization.sh`

**Current:** Installs `aw-watcher-utilization` via pip.

**Migration:** Already packaged in `pkgs/aw-watcher-utilization.nix` and included in `base.nix`. The script is obsolete.

**Steps:**
1. Verify the Nix package is installed and working on both platforms
2. Delete `dotfiles/activitywatch/install-utilization.sh`

#### 1.5 ~~Convert `test-home-manager.sh` and `test-shell-aliases.sh` to Nix Checks~~ — Keep as-is

**Reclassified from Migrate → Keep.** Both scripts verify runtime state (`$SHELL`, `$EDITOR`, `$PATH`, interactive fish aliases, HM symlinks in `$HOME`) that a sandboxed `runCommand` derivation cannot access. The few verifiable-at-build-time assertions (starship config content, tmux settings) are already guaranteed by the Nix module system — if `nix build` succeeds, the config is exactly what was declared. Converting to `perSystem.checks` would be redundant at best, impossible at worst.

### 4.2 Phase 2 — Medium Effort

**Effort:** 3–5 days | **Impact:** Packages all scripts as proper Nix derivations, adds declarative maintenance

#### 2.1 Package Operational Scripts as Nix Derivations

**Current:** Scripts assume dependencies (hyperfine, jq, bc, etc.) are available in the environment.

**Migration:** Create Nix derivations for each script that declare their dependencies:

```nix
# pkgs/scripts/default.nix
{ pkgs, lib }:

{
  health-check = pkgs.writeShellApplication {
    name = "health-check";
    runtimeInputs = with pkgs; [ jq bc coreutils gnugrep gnused ];
    text = builtins.readFile ../../scripts/health-check.sh;
  };

  benchmark-system = pkgs.writeShellApplication {
    name = "benchmark-system";
    runtimeInputs = with pkgs; [ hyperfine jq bc coreutils ];
    text = builtins.readFile ../../scripts/benchmark-system.sh;
  };

  health-dashboard = pkgs.writeShellApplication {
    name = "health-dashboard";
    runtimeInputs = with pkgs; [ jq bc ];
    text = builtins.readFile ../../scripts/health-dashboard.sh;
  };

  # ... etc for each script
}
```

**Benefit:** Scripts become part of the Nix closure, dependencies are explicit, and they can be invoked without the justfile.

#### 2.2 Extract Nix Assertions from `validate-deployment.sh`

**Current:** 589 lines checking NixOS config for boot, GPU, security, user settings.

**Migration:** Split into two parts:

**Declarative assertions (build-time):**
```nix
# In NixOS configuration
assertions = [
  {
    assertion = config.boot.loader.systemd-boot.enable;
    message = "systemd-boot must be enabled for UEFI boot";
  }
  {
    assertion = config.services.xserver.videoDrivers == [ "amdgpu" ];
    message = "AMD GPU driver must be configured";
  }
  {
    assertion = config.users.users.lars.isNormalUser;
    message = "User 'lars' must be a normal user";
  }
  # ... more assertions from the static checks
];
```

**Runtime checks (keep as script):**
- IP connectivity
- Service responsiveness
- DNS resolution

These are inherently runtime concerns and should stay as a packaged script.

#### 2.3 Declarative Maintenance Scheduling

**Current:** `maintenance.sh` (681 lines) implements its own cron-like scheduler.

**Migration:**

**NixOS:** Systemd timers
```nix
systemd.services.systemnix-maintenance = {
  description = "SystemNix Weekly Maintenance";
  path = with pkgs; [ config.nix.package git jq ];
  serviceConfig.Type = "oneshot";
  script = ''
    # Extract the core maintenance logic from maintenance.sh
    nix-collect-garbage --delete-older-than 30d
    ${pkgs.health-check}/bin/health-check
  '';
};

systemd.timers.systemnix-maintenance = {
  wantedBy = [ "timers.target" ];
  timerConfig.OnCalendar = "weekly";
};
```

**macOS:** LaunchAgent (via nix-darwin)
```nix
launchd.agents.systemnix-maintenance = {
  command = "...";
  interval = { Weekday = 0; };  # Sunday
};
```

#### 2.4 Extract Static Health Checks into Nix

**Current:** `health-check.sh` performs both static checks (is the config correct?) and runtime checks (is the service running?).

**Migration:**

**Static checks → `nix flake check`:**
```nix
perSystem.checks = {
  config-consistency = pkgs.runCommand "config-consistency" { } ''
    # Verify flake structure is intact
    # Verify all imports resolve
    # Verify no orphaned references
    touch $out
  '';
};
```

**Runtime checks → packaged script** (see 2.1).

#### 2.5 Migrate Platform Detection to Nix

**Current:** justfile's `_detect_platform` runs `uname` at recipe time.

**Migration:** Two approaches:

**Option A — Platform-specific recipes:**
```just
# macOS
switch-darwin:
  darwin-rebuild switch --flake .#Lars-MacBook-Air

# NixOS
switch-nixos:
  nh os switch .#evo-x2

# Auto-detect (thin wrapper)
switch:
  @case "$(uname -s)" in Darwin) just switch-darwin ;; Linux) just switch-nixos ;; esac
```

**Option B — Nix eval for platform:**
```just
switch:
  nix run .#switch-{{_detect_platform}}
```

Both eliminate the multi-line shell function while keeping the ergonomics.

### 4.3 Phase 3 — Deep Nixification

**Effort:** 5–10 days | **Impact:** Maximum declarative coverage, but diminishing returns

#### 3.1 NixOS Test VMs for Integration Testing

**Migration:** Write proper `nixosTests` that spin up VMs and verify system configuration:

```nix
# In a checks module
checks.nixos = nixosTests {
  name = "systemnix-evo-x2";
  machine = { config, pkgs, ... }: {
    imports = [ self.nixosConfigurations.evo-x2 ];
  };
  testScript = ''
    machine.wait_for_unit("default.target");
    machine.succeed("which fish");
    machine.succeed("which starship");
    machine.succeed("niri --version");
  '';
};
```

**Trade-off:** Significantly slower than `nix flake check --no-build`, but catches runtime issues.

#### 3.2 Declarative Backup Strategy

**Current:** justfile `backup`/`restore` recipes copy directories imperatively.

**Migration:**

- **System config:** Already handled by Nix generations. Promote `nix-env --list-generations` and `home-manager generations` as the primary rollback mechanism.
- **User data:** Consider `services.borgbackup` or `services.restic` on NixOS for declarative backup:

```nix
services.restic.backups.systemnix-data = {
  paths = [ "/data/important" ];
  repository = "/data/backups/restic";
  timerConfig.OnCalendar = "daily";
};
```

- **Keep `backup`/`restore` justfile recipes** for quick file-level operations, but make them thin wrappers.

#### 3.3 Flake Apps for All Scripts

**Migration:** Expose all remaining scripts as `flake.apps`:

```nix
perSystem = { config, pkgs, ... }: {
  apps = {
    health-check = {
      type = "app";
      program = "${pkgs.systemnix-scripts.health-check}/bin/health-check";
    };
    benchmark = {
      type = "app";
      program = "${pkgs.systemnix-scripts.benchmark-system}/bin/benchmark-system";
    };
    # ... etc
  };
};
```

**Benefit:** Scripts become invocable via `nix run .#health-check` — independent of justfile.

#### 3.4 DevShell with Script Dependencies

**Migration:** Create a devShell that includes all script dependencies so they work without the justfile:

```nix
perSystem = { pkgs, ... }: {
  devShells.scripts = pkgs.mkShell {
    packages = with pkgs; [
      hyperfine jq bc
      config.packages.systemnix-scripts
    ];
    shellHook = ''
      export SYSTEMNIX_ROOT="${toString ./.}"
    '';
  };
};
```

---

## 5. Specific Migration Recommendations

### 5.1 Scripts → Nix

| Script | Action | Nix Construct | Effort |
|--------|--------|---------------|--------|
| `lib/paths.sh` | Delete | Replace with `self.outPath` / `toString ./.` | Low |
| `storage-cleanup.sh` | Delete | Subsumed by declarative `nix.gc` | Low |
| `update-crush-latest.sh` | Delete | `nix flake update crush-config` | Low |
| `install-utilization.sh` | Delete | Already packaged in `pkgs/` | Low |
| `test-home-manager.sh` | Keep | Runtime-only; cannot be build-time checks | - |
| `test-shell-aliases.sh` | Keep | Runtime-only; cannot be build-time checks | - |
| `cleanup.sh` | Trim | Keep cache-specific cleaning; GC → declarative | Medium |
| `health-check.sh` | Split | Static checks → assertions; runtime → packaged app | Medium |
| `validate-deployment.sh` | Split | Static checks → assertions; runtime → packaged app | Medium |
| `maintenance.sh` | Split | Scheduling → systemd timers; tasks → packaged apps | Medium |
| `deploy-evo-x2.sh` | Split | Post-deploy checks → assertions; deploy stays as recipe | Low |
| `ai-integration-test.sh` | Split | Static checks → assertions; GPU test → packaged app | Medium |
| `benchmark-system.sh` | Package | `writeShellApplication` with hyperfine dep | Low |
| `health-dashboard.sh` | Package | `writeShellApplication` | Low |
| `nixos-diagnostic.sh` | Package | `writeShellApplication` | Low |
| `performance-monitor.sh` | Package | `writeShellApplication` | Low |
| `shell-context-detector.sh` | Package | `writeShellApplication` | Low |
| `optimize.sh` | Package | `writeShellApplication` (keep as-is) | Low |

### 5.2 Justfile Recipes → Nix

| Recipe(s) | Action | Nix Construct |
|-----------|--------|---------------|
| `_detect_platform`, `_get_nix_host`, `_nix_args` | Simplify | Platform-specific recipes or `nix eval` |
| `clean`, `gc` | Simplify | Declarative `nix.gc` handles automatic; keep manual recipes |
| `test-home-manager`, `test-shell-aliases` | **Keep** | Runtime-only verification; cannot be build-time checks |
| `update-crush-latest` | Delete | Replaced by `just update crush-config` |

### 5.3 New Flake Outputs

#### New Packages

| Package | Source | Type |
|---------|--------|------|
| `systemnix-scripts.health-check` | `scripts/health-check.sh` | `writeShellApplication` |
| `systemnix-scripts.benchmark` | `scripts/benchmark-system.sh` | `writeShellApplication` |
| `systemnix-scripts.dashboard` | `scripts/health-dashboard.sh` | `writeShellApplication` |
| `systemnix-scripts.maintenance` | `scripts/maintenance.sh` (trimmed) | `writeShellApplication` |
| `systemnix-scripts.optimize` | `scripts/optimize.sh` | `writeShellApplication` |
| `systemnix-scripts.diagnostic` | `scripts/nixos-diagnostic.sh` | `writeShellApplication` |
| `systemnix-scripts.perf-monitor` | `scripts/performance-monitor.sh` | `writeShellApplication` |
| `systemnix-scripts.context-detect` | `scripts/shell-context-detector.sh` | `writeShellApplication` |

#### New Checks

| Check | Validates |
|-------|-----------|
| `shell-aliases` | Fish/Zsh/Bash alias consistency |
| `home-manager-integration` | Starship config, PATH, env vars |
| `config-consistency` | Flake structure, imports, no orphaned refs |

#### New Assertions (NixOS)

| Assertion | Source |
|-----------|--------|
| systemd-boot enabled | `validate-deployment.sh` |
| AMD GPU driver configured | `validate-deployment.sh` |
| User `lars` exists and is normal | `validate-deployment.sh` |
| SSH hardening settings present | `validate-deployment.sh` |
| Firewall enabled | `validate-deployment.sh` |

#### New Systemd Services/Timers (NixOS)

| Service | Schedule | Source |
|---------|----------|--------|
| `systemnix-maintenance` | Weekly | `maintenance.sh` |
| `systemnix-health-check` | Daily | `health-check.sh` |
| `systemnix-gc` | Weekly (via `nix.gc`) | `cleanup.sh` |

#### New LaunchAgents (macOS)

| Agent | Schedule | Source |
|-------|----------|--------|
| `systemnix-gc` | Weekly (via `nix.gc`) | `cleanup.sh` |

---

## 6. Risk Analysis and Trade-offs

### What NOT to Migrate

| Item | Why It Must Stay Imperative |
|------|---------------------------|
| `optimize.sh` | Runtime performance tuning requires current system state |
| `keychain-*` recipes | macOS Security Framework interaction is inherently imperative |
| `dns-*` recipes | Operational commands that interact with running services |
| `immich-*` recipes | Service management (backup, password reset) at runtime |
| `deploy-evo-x2` | Deployment orchestration across SSH |
| `backup`/`restore` | File-level operations requiring user context |
| `tmux-*` recipes | Session management is inherently imperative |
| `go-*` recipes | Go development workflow, not system configuration |
| `dep-graph` | Visualization utility, not config |
| All dotfile scripts (except install-utilization) | Browser/macos interactive operations |

### Trade-off: Declarative Purity vs. Operational Flexibility

| Factor | More Declarative | More Imperative |
|--------|-----------------|-----------------|
| Reproducibility | Higher — config is code | Lower — depends on runtime state |
| Debuggability | Harder — must rebuild to test | Easier — run and iterate |
| Onboarding | Better — `nix build` just works | Worse — must learn scripts |
| Flexibility | Lower — changes require rebuild | Higher — ad-hoc operations |
| Maintenance | Lower — Nix handles it | Higher — scripts must be maintained |
| Emergency recovery | Slower — must rebuild | Faster — run the script |

**Recommendation:** Target 85% declarative coverage. The remaining 15% should be packaged as proper Nix derivations (so dependencies are explicit) but remain imperative in operation. The justfile becomes a thin dispatcher calling Nix-packaged scripts.

### Risk Matrix

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Nix assertions too strict (block valid configs) | Medium | High | Use `warnings` for soft checks, `assertions` only for hard requirements |
| GC deletes needed generations | Low | High | Set `nix.keepOutputs = true; nix.keepDerivations = true` |
| Packaged scripts break (path differences) | Medium | Medium | Use `writeShellApplication` which wraps with `set -euo pipefail` |
| systemd timers conflict with manual maintenance | Low | Low | Use `Persistent = true` so missed runs are caught up |
| Migration introduces regressions | Medium | Medium | Migrate incrementally, test each change with `just test` |

### Anti-patterns to Avoid

1. **Don't Nixify things that need human judgment** — keychain management, emergency recovery
2. **Don't create circular dependencies** — Nix checks that depend on the Nix build they're checking
3. **Don't eliminate operational shortcuts** — `just clean-quick` should remain a fast one-liner
4. **Don't over-assert** — too many assertions make the config fragile and annoying to modify
5. **Don't duplicate** — if Nix already does it (GC, generations), don't re-implement it

---

## 7. Implementation Checklist

### Phase 1 — Quick Wins (COMPLETE)

- [x] Delete `scripts/lib/paths.sh`; update all consumers
- [x] Add `nix.gc` configuration to both NixOS and darwin configs (`platforms/common/nix-settings.nix`)
- [x] Delete `scripts/storage-cleanup.sh` (subsumed by `nix.gc`)
- [x] Replace `scripts/update-crush-latest.sh` with justfile recipe
- [x] Delete `dotfiles/activitywatch/install-utilization.sh` (already packaged)
- [x] ~~Add `perSystem.checks` for shell alias tests~~ — Reclassified: runtime-only, cannot be build-time checks
- [x] ~~Add `perSystem.checks` for Home Manager integration tests~~ — Reclassified: runtime-only, cannot be build-time checks
- [x] Verify `just test` passes after all changes
- [x] Run `just switch` on both platforms

### Phase 2 — Medium Effort (3–5 days)

- [ ] Create `pkgs/scripts/` directory with Nix derivations for all scripts
- [ ] Add flake-parts module for script packages
- [ ] Extract static assertions from `validate-deployment.sh` into NixOS config
- [ ] Extract static checks from `health-check.sh` into `perSystem.checks`
- [ ] Create systemd timer for weekly maintenance (NixOS)
- [ ] Create LaunchAgent for weekly maintenance (macOS)
- [ ] Simplify justfile platform detection
- [ ] Update justfile recipes to call packaged scripts
- [ ] Verify all scripts function as Nix packages
- [ ] Run `just test` and `just switch` on both platforms

### Phase 3 — Deep Nixification (5–10 days)

- [ ] Add `flake.apps` for all operational scripts
- [ ] Create `devShells.scripts` with all script dependencies
- [ ] Write NixOS VM test for integration validation
- [ ] Evaluate `services.restic` or `services.borgbackup` for declarative backup
- [ ] Consolidate backup strategy around Nix generations
- [ ] Document all new Nix outputs in AGENTS.md
- [ ] Update justfile to reference new Nix outputs where applicable
- [ ] Full regression test on both platforms

---

## Appendix A — Full Justfile Recipe Inventory

### Core Workflow (keep as-is)

| Recipe | Lines | Purpose |
|--------|-------|---------|
| `setup` | ~30 | Initial clone + setup |
| `switch` | ~20 | Apply config (auto-detect platform) |
| `update` | ~15 | Update all or specific flake inputs |
| `test` | ~10 | Full build validation |
| `test-fast` | ~10 | Syntax-only validation |
| `format` | ~5 | Run treefmt |
| `validate` | ~5 | `nix flake check --no-build` |
| `health` | ~10 | Run health-check.sh |

### Cleanup (partial migration)

| Recipe | Lines | Purpose | Migration |
|--------|-------|---------|-----------|
| `clean` | ~15 | Nix GC + cache cleanup | Simplify (auto-GC handles most) |
| `clean-quick` | ~10 | Quick cache clear | Keep |
| `clean-aggressive` | ~10 | Aggressive cleanup | Keep for emergencies |
| `gc` | ~10 | Nix GC wrapper | Simplify |
| `docker-clean` | ~5 | Docker system prune | Keep |

### Backup/Restore (partial migration)

| Recipe | Lines | Purpose | Migration |
|--------|-------|---------|-----------|
| `backup` | ~15 | Config backup to timestamped dir | Lean on Nix generations more |
| `restore` | ~15 | Restore from backup | Keep |
| `backup-list` | ~10 | List available backups | Keep |
| `rollback` | ~10 | Revert to previous generation | Keep (thin wrapper) |
| `snapshots-list` | ~10 | List BTRFS snapshots | Keep |
| `snapshots-create` | ~10 | Create BTRFS snapshot | Keep |

### Go Development (keep as-is)

| Recipe | Lines | Purpose |
|--------|-------|---------|
| `go-dev` | ~10 | Full workflow (fmt, lint, test, build) |
| `go-test` | ~5 | Run Go tests |
| `go-lint` | ~5 | Run Go linters |
| `go-build` | ~5 | Build Go packages |
| `go-tools-version` | ~10 | Show all Go tool versions |
| `go-update-tools-manual` | ~15 | Update Go tools via `go install` |

### DNS Management (keep as-is)

| Recipe | Lines | Purpose |
|--------|-------|---------|
| `dns-diagnostics` | ~5 | DNS stack diagnostics |
| `dns-blocklist-update` | ~10 | Update DNS blocklists |
| `dns-restart` | ~5 | Restart Unbound + dnsblockd |
| `dns-status` | ~5 | DNS service status |
| `dns-flush-cache` | ~5 | Flush DNS cache |
| `dns-test-query` | ~5 | Test DNS resolution |
| `dns-blocklist-stats` | ~5 | Blocklist statistics |
| `dns-check-leaks` | ~5 | DNS leak test |

### Immich Management (keep as-is)

| Recipe | Lines | Purpose |
|--------|-------|---------|
| `immich-status` | ~5 | Service status |
| `immich-backup` | ~15 | Database backup |
| `immich-restore` | ~15 | Database restore |
| `immich-reset-password` | ~10 | Admin password reset |
| `immich-logs` | ~5 | Service logs |
| `immich-sync` | ~5 | External library sync |

### Monitoring (keep as-is, call packaged scripts)

| Recipe | Lines | Purpose |
|--------|-------|---------|
| `benchmark` | ~10 | System benchmarks |
| `perf` | ~10 | Performance snapshot |
| `context` | ~10 | Shell context detection |
| `monitor` | ~10 | Long-term monitoring |
| `dashboard` | ~10 | Health dashboard |

### Service Management (keep as-is)

| Recipe | Lines | Purpose |
|--------|-------|---------|
| `netdata-*` | ~15 | Netdata start/stop/status |
| `ntopng-*` | ~15 | ntopng start/stop/status |
| `signoz-*` | ~15 | SigNoz start/stop/status/logs |

### Keychain (keep as-is)

| Recipe | Lines | Purpose |
|--------|-------|---------|
| `keychain-add` | ~10 | Add SSH key to KeyChain |
| `keychain-list` | ~5 | List KeyChain keys |
| `keychain-remove` | ~10 | Remove key from KeyChain |
| `keychain-setup` | ~15 | Initial KeyChain setup |

### AI/Claude (partial)

| Recipe | Lines | Purpose | Migration |
|--------|-------|---------|-----------|
| `claude-*` | ~10 | Claude AI operations | Keep |
| `update-crush-latest` | ~10 | Update Crush AI | Migrate to `just update crush-config` |

### Deployment (keep as-is)

| Recipe | Lines | Purpose |
|--------|-------|---------|
| `deploy-evo-x2` | ~10 | SSH deploy to NixOS machine |

### Utilities (keep as-is)

| Recipe | Lines | Purpose |
|--------|-------|---------|
| `dep-graph` | ~10 | Nix dependency visualization |
| `tree` | ~5 | Directory tree |
| `show-config` | ~10 | Show Nix config |
| `search-*` | ~10 | Search packages/options |
| `tmux-*` | ~15 | Tmux session management |

### Platform Detection (migrate)

| Recipe | Lines | Purpose | Migration |
|--------|-------|---------|-----------|
| `_detect_platform` | ~10 | `uname`-based detection | Simplify to conditional |
| `_get_nix_host` | ~10 | Map platform to hostname | Nix eval or inline |
| `_nix_args` | ~10 | Build flake args | Inline |

---

## Appendix B — Archived Scripts Assessment

The `scripts/archive/` directory contains 10 scripts that are no longer active. Before migrating anything, consider whether these should be:

1. **Deleted** — functionality fully subsumed by Nix
2. **Restored + migrated** — still needed but not in active use
3. **Left archived** — reference material only

| Archived Script | Lines | Assessment |
|----------------|-------|------------|
| `release.sh` | ~50 | **Delete** — Git tagging is trivial, not system config |
| `backup-config.sh` | ~100 | **Delete** — Nix generations handle this |
| `nix-diagnostic.sh` | ~150 | **Keep archived** — useful reference for diagnostics |
| `config-validate.sh` | ~500 | **Migrate** — valuable validation logic → Nix checks |
| `dns-diagnostics.sh` | ~200 | **Keep archived** — superseded by justfile dns-* recipes |
| `automation-setup.sh` | ~100 | **Delete** — replaced by proposed systemd timers |
| `sublime-text-sync.sh` | ~50 | **Delete** — SublimeText not in current config |
| `check-amd-hardware.sh` | ~100 | **Keep archived** — useful for hardware debugging |
| `find-nix-duplicates.sh` | ~200 | **Restore + migrate** — valuable as a `perSystem.check` |
| `activitywatch-config.sh` | ~150 | **Keep archived** — AW config is now declarative |

**Key find:** `config-validate.sh` (500 lines) and `find-nix-duplicates.sh` (200 lines) contain logic that should be extracted into `perSystem.checks` before the archived scripts are deleted.

---

## Summary

| Phase | Effort | Scripts Deleted | Scripts Packaged | New Nix Constructs | Lines Eliminated |
|-------|--------|----------------|-----------------|-------------------|-----------------|
| Phase 1 | 1–2 days | 4 | 0 | `nix.gc`, `perSystem.checks` | ~600 |
| Phase 2 | 3–5 days | 0 | 8 | Assertions, systemd timers, LaunchAgents, script packages | ~800 (refactored) |
| Phase 3 | 5–10 days | 0 | 0 | `flake.apps`, `devShells`, NixOS VM tests, backup services | ~100 (reorganized) |
| **Total** | **9–17 days** | **4** | **8** | — | **~1,500** |

The justfile remains the primary user interface throughout. The migration targets what the justfile *calls*, not the justfile itself. The end state is a justfile dispatching to Nix-packaged scripts and Nix-managed services, with declarative GC, assertions catching config errors at build time, and systemd/launchd handling scheduled maintenance automatically.
