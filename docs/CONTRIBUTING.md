# Contributing to SystemNix

Cross-platform Nix configuration managing macOS (nix-darwin) and NixOS via a single flake.

## Quick Start

```bash
nix flake check --no-build   # Syntax check before committing
nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel  # Quick eval
nix run .#deploy             # Apply config (auto-detects platform via deploy.sh)
nix fmt                      # Auto-format all Nix files
scripts/health-check.sh      # System health check
nix run .#pre-deploy-check   # Catch boot-breaking issues before switch
```

**Note:** SystemNix used a `justfile` in the past. It has been removed; use the Nix flake apps and scripts above instead.

## Architecture

```
SystemNix/
├── flake.nix                    # Entry point (flake-parts)
├── modules/nixos/services/     # 35 NixOS service modules (flake-parts, auto-discovered)
├── modules/nixos/desktop/      # 6 desktop-environment modules (flake-parts, auto-discovered)
├── pkgs/                        # Custom package derivations + dms-plugins/
├── overlays/                    # Shared + Linux-only overlays
├── lib/                         # 10 helper files (harden, ports, systemd defaults, ...)
├── platforms/
│   ├── common/                  # Shared config (~80%), imported by both platforms
│   ├── darwin/                  # macOS (nix-darwin, user: larsartmann)
│   └── nixos/                   # NixOS (user: lars)
├── scripts/                     # 36 operational scripts (shell + Python)
└── docs/                        # Architecture decisions, status reports, runbooks
```

## Code Style

### Nix

- **2-space indentation** (enforced by alejandra)
- **Unused parameters**: Use `_:` when a function takes no arguments (satisfies both deadnix and statix)
- **Legitimate inputs**: Keep `{inputs, ...}:` when the module actually uses `inputs` (e.g., hermes.nix, signoz.nix)
- **Module options**: Every `mkOption` must have a `description` field
- **No inline secrets**: Use sops-nix for all sensitive values

### Go (custom packages in `pkgs/`)

- **Tab indentation** (per .editorconfig)
- Follow standard Go conventions

### General

- **LF line endings**, UTF-8, final newline enforced
- **Python**: 4-space indent
- **Shell scripts**: `set -euo pipefail`, use `lib.sh` helpers

## Pre-commit Hooks

Installed via `pre-commit install`. All hooks must pass before merge:

| Hook                  | Purpose                                                     |
| --------------------- | ----------------------------------------------------------- |
| gitleaks              | Detect committed secrets                                    |
| trailing-whitespace   | Clean trailing spaces                                       |
| deadnix               | Find dead/unused Nix code                                   |
| statix                | Detect Nix antipatterns (20+ rules)                         |
| alejandra             | Enforce Nix formatting                                      |
| nix-check             | Full `nix flake check --no-build`                           |
| flake-lock-validate   | Validate lockfile integrity                                 |
| shellcheck            | Shell script linting                                        |
| check-merge-conflicts | Catch unresolved markers                                    |
| protect-home-audit    | Warn when `harden {}` + `/home` lacks `ProtectHome = false` |

### Auto-fix Commands

```bash
nix fmt                              # Format all Nix files with alejandra
statix fix .                         # Auto-fix linting issues
deadnix --fail --no-lambda-pattern-names .  # Check for dead code
```

## Adding a New NixOS Service

Services are self-contained flake-parts modules in `modules/nixos/services/` (or `modules/nixos/desktop/` for desktop environment config):

1. Create `modules/nixos/services/<name>.nix` as a flake-parts module. The filename becomes the module name, so it must be unique across both `services/` and `desktop/`.
2. Import helpers via `import ../../../lib/default.nix lib` (required for standalone `nix flake check`).
3. Enable in `platforms/nixos/system/configuration.nix`.
4. Add a Caddy vHost in `modules/nixos/services/caddy.nix` if the service is web-facing.
5. Add a Gatus health check in `modules/nixos/services/gatus-config.nix`.
6. Add a Homepage tile in `modules/nixos/services/homepage.nix` if user-facing.
7. See `AGENTS.md` for the full service-adding checklist and non-obvious gotchas.

Module template:

```nix
_: {
  flake.nixosModules.my-service = {
    config,
    lib,
    pkgs,
    ...
  }:
  let
    inherit (import ../../../lib/default.nix lib) harden serviceDefaults onFailure ports;
    cfg = config.services.my-service;
  in
  {
    options.services.my-service = {
      enable = lib.mkEnableOption "My Service";
      port = lib.mkOption {
        type = lib.types.port;
        default = 8080;
        description = "Port for the service";
      };
    };

    config = lib.mkIf cfg.enable {
      systemd.services.my-service = {
        wantedBy = [ "multi-user.target" ];
        serviceConfig =
          harden {
            MemoryMax = "512M";
          }
          // serviceDefaults {}
          // {
            ExecStart = "${pkgs.my-service}/bin/my-service --port ${toString cfg.port}";
          };
      };
    };
  };
}
```

## Shared Configuration

Place cross-platform config in `platforms/common/`. Both platforms import `common/home-base.nix`, which pulls in program modules from `common/programs/`.

Platform differences use:

```nix
if pkgs.stdenv.isLinux then "..." else "..."
```

Only override in platform dirs for things that genuinely differ.

## Verification

```bash
nix flake check --no-build     # Fast syntax-only check
nix run .#pre-deploy-check     # Pre-deploy validation
nix run .#post-deploy-check    # Post-deploy smoke test
scripts/health-check.sh        # System health check
scripts/verify-deployment.sh   # Deployment readiness validator
```

## Key Patterns to Know

### Infinite Recursion Avoidance

Never wrap config in `lib.mkIf config.services.<nixpkg-option>.enable` AND set attributes under `services.<nixpkg-option>` inside the same `mkIf`. Create a separate custom option instead.

### Systemd Hardening

Use the shared `lib/systemd.nix` harden function for consistent security:

```nix
serviceConfig =
  harden {
    PrivateTmp = true;
    MemoryMax = "512M";
  }
  // serviceDefaults {};
```

### Secrets

All secrets managed via sops-nix with age encryption. See `modules/nixos/services/sops.nix` and `AGENTS.md` for the Sops + Age workflow.

### Native OIDC vs Forward-Auth

SystemNix has two SSO layers:

- **Layer 1 — Native OIDC**: Apps integrate directly with Pocket ID (Forgejo, Immich, Gatus). Caddy uses plain `reverse_proxy`.
- **Layer 2 — oauth2-proxy forward-auth**: Apps without native auth; Caddy uses `protectedVHost`.

Never put a native-OIDC service behind `protectedVHost` — it causes a double-auth redirect loop. See `AGENTS.md` for the full SSO architecture.

## Documentation

When you learn something non-obvious, update the relevant doc immediately:

- `AGENTS.md` — AI assistant guide, conventions, gotchas
- `FEATURES.md` — Feature inventory and status
- `ROADMAP.md` — Long-term direction
- `TODO_LIST.md` — Actionable short/mid-term work
- `docs/adr/` or `docs/architecture/` — Architecture decisions

See `AGENTS.md` → "Project Documentation Files" for the full ownership table.
