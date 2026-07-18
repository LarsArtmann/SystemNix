# Comprehensive Status Report: Dendritic Pattern Migration

**Date:** 2026-03-29 16:53:40 CEST
**System:** evo-x2 | AMD Ryzen AI Max+ 395 | 62 GiB RAM | NixOS 26.05
**Disk:** 512 GB NVMe — 280 GB used (55%)
**Uptime:** 1 day 18h56
**Load:** 3.11 / 3.49 / 3.79

**Commit:** `26312a2` — refactor(nixos): migrate services to dendritic flake-parts modules

---

## A) FULLY DONE ✅

### Dendritic Pattern Migration

Successfully migrated 5 NixOS services from traditional relative imports to self-contained flake-parts modules.

**New Module Architecture:**

```
modules/nixos/services/
├── caddy.nix      # flake.nixosModules.caddy
├── gitea.nix      # flake.nixosModules.gitea
├── grafana.nix    # flake.nixosModules.grafana
├── immich.nix     # flake.nixosModules.immich
├── ssh.nix        # flake.nixosModules.ssh
└── dashboards/
    └── overview.json
```

**Changes Made:**

#### 1. flake.nix

- Added dendritic `imports` section for flake-parts modules
- Wired 5 modules into `nixosModules` flake output
- Removed direct service imports from nixosConfigurations module list

#### 2. modules/nixos/services/immich.nix

- **Self-contained flake-parts module**: `{ inputs, ... }: { flake.nixosModules.immich = ... }`
- Immich photo/video management on port 2283
- PostgreSQL database with daily backup (7-day retention)
- Redis for caching
- Machine learning acceleration support (devices: null for CPU)
- User added to video/render groups for hardware access

#### 3. modules/nixos/services/gitea.nix

- **Self-contained flake-parts module**: `{ inputs, ... }: { flake.nixosModules.gitea = ... }`
- Self-hosted Git service with SQLite database
- Git LFS support enabled
- Weekly automated backups
- GitHub mirroring scripts:
  - `gitea-mirror-github` — mirrors all user repos
  - `gitea-mirror-starred` — mirrors starred repos to "starred" org
  - `gitea-setup` — interactive setup helper
- Systemd timer: syncs every 6 hours

#### 4. modules/nixos/services/caddy.nix

- **Self-contained flake-parts module**: `{ inputs, ... }: { flake.nixosModules.caddy = ... }`
- Reverse proxy with metrics enabled
- Virtual hosts:
  - `immich.lan` → localhost:2283
  - `gitea.lan` → localhost:3000
  - `grafana.lan` → localhost:3001
  - `home.lan` → localhost:8082
- Firewall ports 80/443 opened

#### 5. modules/nixos/services/grafana.nix

- **Self-contained flake-parts module**: `{ inputs, ... }: { flake.nixosModules.grafana = ... }`
- Grafana on `127.0.0.1:3001`
- Auto-provisioned Prometheus datasource
- Auto-provisioned dashboards from `./dashboards/` directory
- Sops-managed admin credentials
- Domain: `grafana.lan`

#### 6. modules/nixos/services/ssh.nix

- **Self-contained flake-parts module**: `{ inputs, ... }: { flake.nixosModules.ssh = ... }`
- Hardened SSH daemon with key-based auth only
- Support for modern (rsa-sha2-256/512) and legacy (ssh-rsa) keys
- Strong ciphers and KEX algorithms
- Access limited to `lars` and `art` users
- Custom SSH banner
- Connection limits and timeouts
- Firewall port 22 opened

#### 7. platforms/nixos/system/configuration.nix

- Commented out old relative imports for migrated services
- Services now loaded via `inputs.self.nixosModules.<name>`

---

## B) PARTIALLY DONE ⚠️

### Dendritic Pattern Adoption

- ✅ Core service modules migrated
- ❌ Common modules (packages, programs) still use relative imports
- ❌ Darwin configuration not yet dendritic
- ❌ No `import-tree` integration for automatic discovery

**Remaining Relative Imports in configuration.nix:**

```nix
imports = [
  ../../common/packages/base.nix      # Still relative
  ../../common/packages/fonts.nix     # Still relative
  ../hardware/hardware-configuration.nix  # Still relative
  ./boot.nix                          # Still relative
  ./networking.nix                    # Still relative
  # ... many more
];
```

### Home Manager Architecture

- ✅ NixOS module integration working
- ❌ Still has dual Darwin/NixOS code paths
- ❌ Not yet migrated to dendritic modules

---

## C) NOT STARTED ⏸️

### Full Dendritic Migration

- [ ] Migrate common packages (`platforms/common/packages/*.nix`)
- [ ] Migrate common programs (`platforms/common/programs/*.nix`)
- [ ] Migrate Darwin configuration (`platforms/darwin/*.nix`)
- [ ] Migrate hardware modules (`platforms/nixos/hardware/*.nix`)
- [ ] Migrate desktop modules (`platforms/nixos/desktop/*.nix`)
- [ ] Migrate remaining services:
  - [ ] monitoring.nix (Prometheus + exporters)
  - [ ] homepage.nix
  - [ ] sops.nix
  - [ ] default.nix
- [ ] Add `import-tree` input for automatic module discovery
- [ ] Create proper `modules/` directory hierarchy:
  ```
  modules/
  ├── nixos/
  │   ├── services/
  │   ├── hardware/
  │   ├── desktop/
  │   └── profiles/
  ├── darwin/
  │   ├── services/
  │   └── profiles/
  └── common/
      ├── packages/
      └── programs/
  ```

### Infrastructure Improvements from Previous Report

- [ ] NixOS firewall (deny-by-default)
- [ ] Immich GPU acceleration (ROCm)
- [ ] Immich media backup
- [ ] Off-disk backup (restic/borg)
- [ ] Automatic Nix GC
- [ ] DNS-over-HTTPS/TLS
- [ ] PostgreSQL tuning

---

## D) TOTALLY FUCKED UP ❌

### Nothing New

The dendritic migration did not introduce any new issues. Previous issues remain:

#### dnsblockd — Still Crash-Looping (Pre-existing)

- **Status:** Port conflict with Caddy (Caddy binds `*:80/443`, dnsblockd needs `127.0.0.2:80/443`)
- **Impact:** DNS blocking works, but block page shows connection errors instead of pretty page
- **Note:** This is NOT caused by dendritic migration — was already broken

#### service-health-check.service — Still Failed (Pre-existing)

- **Status:** `notify-send` requires Wayland display variables not available in systemd context
- **Impact:** No desktop notifications on service failure

---

## E) WHAT WE SHOULD IMPROVE 🎯

### Immediate Wins (Dendritic Migration Phase 2)

1. **Migrate homepage service to dendritic module** (~15 min)
   - Copy `platforms/nixos/services/homepage.nix` → `modules/nixos/services/homepage.nix`
   - Wrap in flake-parts format
   - Add to flake.nix imports

2. **Migrate monitoring service to dendritic module** (~20 min)
   - Copy `platforms/nixos/services/monitoring.nix` → `modules/nixos/services/monitoring.nix`
   - Wrap in flake-parts format
   - Add to flake.nix imports

3. **Migrate common packages** (~30 min)
   - Create `modules/common/packages/base.nix` in flake-parts format
   - Export as `flake.nixosModules.basePackages` and `flake.darwinModules.basePackages`

4. **Add import-tree for automatic discovery** (~45 min)
   - Add `import-tree` input to flake.nix
   - Replace manual imports with `(inputs.import-tree ./modules/nixos/services)`
   - Enables: drop any `.nix` file in `modules/` and it's automatically loaded

### Critical Infrastructure (From Previous Report)

5. **Enable NixOS firewall** (~20 lines, critical security)
6. **Bind Immich to localhost** (2 lines, critical security)
7. **Backup Immich media** (~30 lines, data loss prevention)
8. **Fix dnsblockd port conflict** (~10 lines, broken service)

---

## F) Top 25 Things to Do Next 📋

| #   | Task                                         | Effort     | Impact            | Category      |
| --- | -------------------------------------------- | ---------- | ----------------- | ------------- |
| 1   | Migrate remaining services to dendritic      | ~100 lines | Architecture      | Dendritic     |
| 2   | Add import-tree auto-discovery               | ~10 lines  | Maintainability   | Dendritic     |
| 3   | Migrate common packages to dendritic         | ~50 lines  | Architecture      | Dendritic     |
| 4   | Migrate Darwin config to dendritic           | ~80 lines  | Architecture      | Dendritic     |
| 5   | Enable NixOS firewall (deny-by-default)      | ~20 lines  | Critical security | Security      |
| 6   | Bind Immich to localhost                     | 2 lines    | Critical security | Security      |
| 7   | Backup Immich media to external storage      | ~30 lines  | Data loss         | Backup        |
| 8   | Add off-disk backup (restic/borg)            | ~40 lines  | Data loss         | Backup        |
| 9   | Enable fail2ban for SSH                      | 1 line     | Brute-force       | Security      |
| 10  | Fix dnsblockd port conflict with Caddy       | ~10 lines  | Broken service    | Bugfix        |
| 11  | Enable Immich GPU acceleration (ROCm)        | ~5 lines   | ML performance    | Performance   |
| 12  | Add systemd restart policies                 | ~15 lines  | Reliability       | Reliability   |
| 13  | Enable SSD TRIM                              | 1 line     | SSD health        | Maintenance   |
| 14  | Enable SMART disk monitoring                 | 3 lines    | Disk health       | Maintenance   |
| 15  | Add automatic Nix GC timer                   | 5 lines    | Disk space        | Maintenance   |
| 16  | Remove `max_cstate=1` kernel param           | 1 line     | Power             | Performance   |
| 17  | Fix Hyprland `$mod,G` bind conflict          | 1 line     | UX                | Bugfix        |
| 18  | Delete dead Technitium files                 | 2 files    | Hygiene           | Cleanup       |
| 19  | Deduplicate Go overlay in flake.nix          | ~20 lines  | Maintainability   | Cleanup       |
| 20  | Fix justfile for NixOS platform              | ~50 lines  | DevEx             | Tooling       |
| 21  | Add disk space alerts                        | ~15 lines  | Monitoring        | Observability |
| 22  | Fix `immich.lan` DNS to LAN IP               | 2 lines    | Accessibility     | Bugfix        |
| 23  | Change Gitea ROOT_URL to gitea.lan           | 2 lines    | Proper URLs       | Bugfix        |
| 24  | Tune PostgreSQL for Immich                   | ~10 lines  | Performance       | Performance   |
| 25  | Document dendritic architecture in AGENTS.md | ~50 lines  | Documentation     | Docs          |

---

## G) My #1 Question I Cannot Answer Myself ❓

**Should we continue with manual dendritic migration (explicit imports) or switch to `import-tree` for automatic discovery?**

The current state: I've migrated 5 services to dendritic flake-parts modules using explicit imports in `flake.nix`:

```nix
imports = [
  ./modules/nixos/services/immich.nix
  ./modules/nixos/services/gitea.nix
  ./modules/nixos/services/caddy.nix
  ./modules/nixos/services/grafana.nix
  ./modules/nixos/services/ssh.nix
];
```

**Option A: Continue Manual Migration (Current Approach)**

- Pros: Explicit, predictable, no new dependencies
- Cons: Must update flake.nix for every new module

**Option B: Switch to import-tree Auto-Discovery**

- Pros: Drop any `.nix` file in `modules/` and it's automatically loaded; no flake.nix edits
- Cons: Adds `vic/import-tree` dependency; less explicit (magic)

**Trade-off:**

- Manual: More boilerplate, but crystal clear what's being imported
- import-tree: Less boilerplate, but "magic" happens in the importer

I cannot decide this autonomously because it affects the long-term maintainability philosophy of the project. The AGENTS.md previously noted that `import-tree` "cannot be combined with `mkMerge` in flake-parts outputs" — but the current approach uses `imports` which works fine.

**This decision requires choosing between:**

1. Explicit, verbose, but transparent imports (current)
2. Automatic, concise, but "magical" discovery (import-tree)

---

## System State at Time of Report

| Category              | Status                                           |
| --------------------- | ------------------------------------------------ |
| **Working tree**      | Clean — committed as `26312a2`                   |
| **Branch**            | `master`, ahead of origin by 3 commits           |
| **Dendritic modules** | 5 services migrated                              |
| **Test status**       | ✅ `just test-fast` passes                       |
| **NixOS modules**     | caddy, gitea, grafana, immich, ssh               |
| **Active services**   | 14 of 15 running (dnsblockd still crash-looping) |
| **Failed units**      | 1 (service-health-check.service — pre-existing)  |
| **Disk**              | 55% used (232 GB free)                           |
| **Memory**            | 17/62 GiB used (45 GiB available)                |
| **Monitoring stack**  | Prometheus, Grafana, Homepage all operational    |

---

## Architecture Diagram

```
Before (Traditional):
flake.nix
└── nixosConfigurations.evo-x2
    └── platforms/nixos/system/configuration.nix
        └── imports = [ ../services/immich.nix ]  # Relative import
            └── services.immich.enable = true;

After (Dendritic):
flake.nix
├── imports = [ ./modules/nixos/services/immich.nix ]  # Module loads itself
│   └── flake.nixosModules.immich = { services.immich.enable = true; };
└── nixosConfigurations.evo-x2
    └── modules = [ inputs.self.nixosModules.immich ]  # Self-reference
```

---

_Report generated 2026-03-29 16:53:40 CEST_
_Migration commit: `26312a2`_
