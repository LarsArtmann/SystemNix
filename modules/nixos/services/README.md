# modules/nixos/services/

Flake-parts NixOS service modules. Each file that declares `flake.nixosModules.<name>` is auto-discovered by the root `flake.nix` — no manual registry to update.

---

## Table of Contents

- [Auto-Discovery](#auto-discovery)
- [Anatomy of a Service Module](#anatomy-of-a-service-module)
- [Adding a New Service (Checklist)](#adding-a-new-service-checklist)
- [lib/ Helpers](#lib-helpers)
- [Patterns](#patterns)
  - [Native NixOS Service](#native-nixos-service)
  - [Docker Service](#docker-service)
  - [Auth-Protected Service](#auth-protected-service)
- [Non-Module Helpers](#non-module-helpers)
- [Common Gotchas](#common-gotchas)

---

## Auto-Discovery

The root `flake.nix` scans this directory at eval time:

- It reads every `*.nix` file.
- It looks for a line containing `flake.nixosModules.<name>`.
- The captured `<name>` must match the filename (without `.nix`).
- Files without `flake.nixosModules.*` (e.g., `signoz-alerts.nix`, helper patches) are skipped automatically.

**Therefore:**

- `forgejo.nix` → must contain `flake.nixosModules.forgejo`
- `gatus-config.nix` → must contain `flake.nixosModules.gatus-config`
- `signoz-alerts.nix` → no `flake.nixosModules.*` line → ignored by auto-discovery

---

## Anatomy of a Service Module

Every module follows this skeleton:

```nix
# One-line description of what the service does
_: {
  flake.nixosModules.servicename = {
    config,
    pkgs,
    lib,
    ...
  }: let
    cfg = config.services.servicename;
    inherit (import ../../../lib/default.nix lib)
      harden serviceDefaults onFailure serviceTypes;
  in {
    options.services.servicename = {
      enable = lib.mkEnableOption "human-readable description";
      port = serviceTypes.servicePort 8080 "Port for the service";
    };

    config = lib.mkIf cfg.enable {
      # service implementation
    };
  };
}
```

**Key conventions:**

- Top-level argument is `_:` (ignores `inputs`) unless the module needs flake inputs.
- `cfg = config.services.<name>` — always bind the config subtree.
- Import `lib/default.nix` via `import ../../../lib/default.nix lib`.
- Use `lib.mkIf cfg.enable` to guard all config.

### Module Naming

Use `services.<name>` when the module wraps or configures an upstream NixOS service with the same name (e.g., `services.forgejo`, `services.immich`).

Use `services.<name>-config` when the module provides its own standalone option namespace to avoid collision with upstream (e.g., `services.pocket-id-config`, `services.oauth2-proxy-config`, `services.gatus-config`).

### Inputs

Only use `{ inputs, ... }` when the module needs access to flake inputs:

```nix
# Needs inputs — e.g., for upstream overlays or source packages
{ inputs, ... }: {
  flake.nixosModules.hermes = { ... }: let
    hermesPkg = inputs.hermes-agent.overlays.default;
  in { ... };
}
```

Use `_:` when the module is self-contained:

```nix
# No inputs needed
_: {
  flake.nixosModules.foo = { ... }: { ... };
}
```

---

## Adding a New Service (Checklist)

1. **Create `modules/nixos/services/<name>.nix`**
   - Filename must match `flake.nixosModules.<name>`.
2. **Declare options** under `options.services.<name>`
   - Always include `enable = lib.mkEnableOption "..."`.
   - If the service exposes a port, declare it with `serviceTypes.servicePort`.
3. **Implement config** under `config = lib.mkIf cfg.enable { ... }`
4. **If behind Caddy:**
   - Define a `port` option in your module.
   - Add a `protectedVHost` entry in `caddy.nix` referencing `config.services.<name>.port`.
   - Never hardcode ports in `caddy.nix`.
5. **Register the port** in `lib/ports.nix` (collision-protected).
6. **Enable the service** in `platforms/nixos/system/configuration.nix`:
   ```nix
   services.<name>.enable = true;
   ```
7. **Run `just test-fast`** for syntax validation, then `just test` for full build.

---

## lib/ Helpers

Import pattern (always use this exact path):

```nix
inherit (import ../../../lib/default.nix lib)
  harden serviceDefaults onFailure serviceTypes mkStateDir mkDockerServiceFactory ports;
```

| Helper | Purpose |
|--------|---------|
| `harden { MemoryMax = "512M"; }` | Systemd security hardening (`ProtectSystem`, `NoNewPrivileges`, `MemoryMax`, etc.). Pass `mode = "user"` for user services. |
| `serviceDefaults {}` | Common daemon defaults: `Restart = "always"`, `RestartSec = "5s"`. Uses `lib.mkForce`. |
| `serviceDefaultsUser {}` | Same as `serviceDefaults` but without `mkForce` — required for Home Manager user services. |
| `onFailure` | Constant `["notify-failure@%n.service"]` — route failures to the notify template. |
| `serviceTypes.systemdServiceIdentity { defaultUser = "..."; }` | Generates `user`, `group`, `stateDir` options with defaults. |
| `serviceTypes.servicePort 8080 "..."` | Port option with collision checking. |
| `serviceTypes.dockerImageTag "1.2.3"` | Docker tag option that rejects `"latest"` at eval time. |
| `serviceTypes.restartDelay "5"` | Restart delay option (string, seconds). |
| `serviceTypes.stopTimeout "120"` | Stop timeout option (string, seconds). |
| `mkStateDir "/var/lib/foo" "0755" "foo" "foo"` | Generates a `systemd.tmpfiles` rule string. |
| `mkDockerServiceFactory { inherit pkgs; }` | Returns `mkDockerService` for Docker Compose systemd wrappers. |
| `ports.<name>` | Centralized port registry — use for well-known ports. |
| `images.<name>.ref` | Pinned Docker image references (with optional digest). |
| `mkSecretCheck pkgs { name = "..."; secretPath = "..."; message = "..."; }` | Pre-start secret validation script generator. Supports `extraCheck` for custom validation. |
| `mkDesktopNotifyService pkgs { name = "..."; description = "..."; checkScript = "..."; runtimeInputs = [...]; user = "..."; uid = "..."; }` | Generates timer + oneshot service for desktop notifications. Defaults to `harden`; override with `hardenFn` for user services. |
| `mkHttpCheck { name = "..."; group = "..."; url = "..."; }` | Gatus endpoint definition helper. |

---

## Patterns

### Secrets

**Central registry (preferred):** Most sops secrets are declared in `sops.nix` to keep secrets in one place:

```nix
# In sops.nix
sops.secrets.myapp_key = {
  sopsFile = ./../../../platforms/nixos/secrets/myapp.yaml;
  restartUnits = ["myapp.service"];
};
```

**Inline (acceptable for self-contained modules):** Modules with many secrets may declare them inline:

```nix
# In myapp.nix
sops.secrets.myapp_db_password = {
  sopsFile = secretsDir + "/myapp.yaml";
  restartUnits = ["myapp.service"];
};
```

**Env templates:** Docker services commonly use sops templates for `.env` files:

```nix
sops.templates."myapp-env" = {
  content = ''
    DB_PASSWORD=${config.sops.placeholder.myapp_db_password}
    API_KEY=${config.sops.placeholder.myapp_api_key}
  '';
};
```

**Pre-start validation:** Services that fail cryptically without secrets should validate them in `ExecStartPre`:

```nix
systemd.services.myapp.serviceConfig = {
  ExecStartPre = "+${lib.getExe (pkgs.writeShellApplication {
    name = "check-myapp-secrets";
    runtimeInputs = [pkgs.coreutils];
    text = ''
      if [ ! -s '${config.sops.secrets.myapp_key.path}' ]; then
        echo 'myapp: secret missing' >&2
        exit 1
      fi
    '';
  })}";
};
```

### Timers

Standard timer for periodic tasks:

```nix
systemd.timers.myapp-sync = {
  description = "Periodic MyApp sync";
  timerConfig = {
    OnBootSec = "2min";
    OnUnitActiveSec = cfg.interval;
    Persistent = true;
  };
  wantedBy = ["timers.target"];
};

systemd.services.myapp-sync = {
  description = "MyApp sync task";
  inherit onFailure;
  serviceConfig = {
    Type = "oneshot";
    ExecStart = lib.getExe syncScript;
  } // harden {};
};
```

### Custom User Creation

Create a dedicated system user when the service needs specific permissions or isolation:

```nix
users.groups.myapp = {};
users.users.myapp = {
  isSystemUser = true;
  group = "myapp";
  home = "/var/lib/myapp";
  createHome = true;
  description = "MyApp service user";
};
```

For user-configurable services, default to `config.users.primaryUser`:

```nix
options.services.myapp.user = lib.mkOption {
  type = lib.types.str;
  default = config.users.primaryUser;
  description = "User to run myapp as";
};
```

Use `serviceTypes.systemdServiceIdentity` when you need all three (user, group, stateDir) with sensible defaults:

```nix
options.services.myapp = {
  enable = lib.mkEnableOption "MyApp";
  inherit (serviceTypes.systemdServiceIdentity {
    defaultUser = "myapp";
    defaultStateDir = "/var/lib/myapp";
  }) user group stateDir;
};
```

### Desktop Notification Services

Services that send desktop notifications need the user's graphical session environment:

```nix
let
  uid = builtins.toString config.users.users.${cfg.user}.uid;
in {
  systemd.services.myapp-notify.serviceConfig = {
    User = cfg.user;
    Environment = [
      "DISPLAY=:0"
      "WAYLAND_DISPLAY=wayland-1"
      "XDG_RUNTIME_DIR=/run/user/${uid}"
    ];
  } // harden {
    ProtectHome = false;
    NoNewPrivileges = false;
  };
}
```

Use `hardenUser` (which sets `mode = "user"`) instead of `harden` for user services managed by Home Manager.

### Native NixOS Service

Minimal example wrapping an upstream NixOS module:

```nix
# Foo daemon: lightweight metrics exporter
_: {
  flake.nixosModules.foo = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.foo;
    inherit (import ../../../lib/default.nix lib)
      harden serviceDefaults onFailure serviceTypes;
    fooPort = cfg.port;
  in {
    options.services.foo = {
      enable = lib.mkEnableOption "Foo metrics exporter";
      port = serviceTypes.servicePort 9099 "HTTP port for Foo metrics";
    };

    config = lib.mkIf cfg.enable {
      services.foo-daemon = {
        enable = true;
        settings.port = fooPort;
      };

      systemd.services.foo-daemon = {
        inherit onFailure;
        serviceConfig =
          harden { MemoryMax = "256M"; }
          // serviceDefaults {}
          // {
            ExecStartPost = "${lib.getExe pkgs.curl} -sf http://127.0.0.1:${toString fooPort}/health";
          };
      };
    };
  };
}
```

### Docker Service

Use `mkDockerService` for Docker Compose workloads:

```nix
# Bar dashboard: Node.js app with Postgres
_: {
  flake.nixosModules.bar = {
    config,
    pkgs,
    lib,
    ...
  }: let
    cfg = config.services.bar;
    libHelpers = import ../../../lib/default.nix lib;
    inherit (libHelpers) serviceTypes images;
    inherit (libHelpers.mkDockerServiceFactory { inherit pkgs; }) mkDockerService;

    barPort = cfg.port;

    composeFile = pkgs.writeText "bar-docker-compose.yml" ''
      name: bar
      services:
        app:
          image: ${images.bar.ref}
          ports:
            - "127.0.0.1:${toString barPort}:${toString barPort}"
          environment:
            PORT: "${toString barPort}"
    '';

    docker = mkDockerService {
      name = "bar";
      inherit composeFile;
      envTemplate = config.sops.templates."bar-env".path;
      memoryMax = "1G";
    };
  in {
    options.services.bar = {
      enable = lib.mkEnableOption "Bar dashboard";
      port = serviceTypes.servicePort 2100 "Host port for Bar";
      imageTag = serviceTypes.dockerImageTag images.bar.tag;
    };

    config = lib.mkIf cfg.enable {
      sops = {
        secrets.bar_db_password = {
          sopsFile = ./../../../platforms/nixos/secrets/bar.yaml;
          restartUnits = ["bar.service"];
        };
        templates."bar-env".content = ''
          DB_PASSWORD=${config.sops.placeholder.bar_db_password}
        '';
      };

      systemd = {
        tmpfiles.rules = docker.tmpfiles;
        services = docker.services;
      };
    };
  };
}
```

**Docker service rules:**

- All Docker/container services target `multi-user.target` (NOT `graphical.target`).
- `mkDockerService` handles `preStart`, `ExecStart`, `ExecStop`, and `harden` automatically.
- Use `extraServiceConfig` for overrides like `{ RestartSec = "10s"; }`.
- Use `backup = { execStart = "..."; schedule = "daily"; }` for DB backups.
- Use `imagePull = "ghcr.io/owner/image:tag"` to add a pre-start image pull service.

### Auth-Protected Service

Most web services sit behind Caddy with forward-auth via oauth2-proxy + Pocket ID.

In your module, expose the port:

```nix
options.services.myapp = {
  enable = lib.mkEnableOption "MyApp";
  port = serviceTypes.servicePort 8080 "HTTP port";
};
```

In `caddy.nix`, add a `protectedVHost`:

```nix
"myapp.${domain}" = protectedVHost "myapp" config.services.myapp.port;
```

`protectedVHost` applies:

- TLS termination
- Forward-auth for external IPs
- Direct proxy for LAN/local access

**Never** define `services.caddy.virtualHosts` in any module other than `caddy.nix`.

### Home Manager Integration

Some services need per-user configuration (e.g., client settings, user systemd services):

```nix
config = lib.mkIf cfg.enable {
  home-manager.users.${cfg.user} = {
    systemd.user.services.myapp = {
      Unit.Description = "MyApp user service";
      Service.ExecStart = "${lib.getExe pkgs.myapp}";
    };
  };
};
```

Use `serviceDefaultsUser {}` (not `serviceDefaults {}`) for Home Manager user services — it omits `lib.mkForce` which Home Manager does not support.

---

## Non-Module Helpers

Files that do **not** declare `flake.nixosModules.*` are ignored by auto-discovery. Use this for:

- Alert rule generators (`signoz-alerts.nix`)
- Patch files (`immich-bull-board.patch`)
- Dashboard JSON (`dashboards/*.json`)
- Setup guides (`twenty-POST-SETUP.md`)

These can be imported by modules that need them.

---

## Common Gotchas

| Issue | Rule |
|-------|------|
| **Module not discovered** | Filename must exactly match `flake.nixosModules.<name>`. |
| **Port collisions** | Always register ports in `lib/ports.nix`. The registry throws on duplicates. |
| **Caddy vHost in wrong file** | ALL virtual hosts live in `caddy.nix`. No other module touches `services.caddy.virtualHosts`. |
| **WatchdogSec misuse** | Only set `WatchdogSec` on services that send periodic `WATCHDOG=1` via `sd_notify()`. Do NOT use on Python, Node.js, or Go/Rust services without explicit sd_notify keepalives. |
| **`handle_path` vs `handle`** | `handle_path /prefix/*` **strips** the prefix before proxying. Use `handle` (not `handle_path`) when the backend expects the full path (e.g., oauth2-proxy callbacks). |
| **Docker service target** | Use `multi-user.target`. Desktop must not wait for containers. |
| **Home Manager `mkForce`** | `serviceDefaults` uses `mkForce`. For HM user services, use `serviceDefaultsUser` instead. |
| **sops secret path** | Use `config.sops.placeholder.<name>` in templates, `config.sops.secrets.<name>.path` in service config. |
| **Config-derived URLs** | Never hardcode `localhost:PORT`. Derive from `config.services.<name>.port` or equivalent. |
| **User service hardening** | Use `hardenUser` (not `harden`) for Home Manager user services — it sets `mode = "user"`. |
| **Primary user default** | User-configurable services should default to `config.users.primaryUser`. |
| **Docker import pattern** | Always use `libHelpers.mkDockerServiceFactory { inherit pkgs; }` — do not import `lib/docker.nix` directly. |
| **`-config` suffix** | Use when avoiding namespace collision with upstream NixOS services (e.g., `pocket-id-config`). |
| **Image digests** | Pin Docker images with digests in `lib/images.nix` for reproducibility. |

---

## See Also

- `flake.nix` — auto-discovery logic and service module wiring
- `lib/default.nix` — helper imports
- `lib/types.nix` — reusable option constructors
- `lib/ports.nix` — centralized port registry
- `lib/docker.nix` — `mkDockerService` implementation
- `modules/nixos/services/caddy.nix` — reverse proxy and `protectedVHost`
- `platforms/nixos/system/configuration.nix` — where services are enabled
