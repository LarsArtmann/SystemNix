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
| `mkHttpCheck { name = "..."; group = "..."; url = "..."; }` | Gatus endpoint definition helper. |

---

## Patterns

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

---

## See Also

- `flake.nix` — auto-discovery logic and service module wiring
- `lib/default.nix` — helper imports
- `lib/types.nix` — reusable option constructors
- `lib/ports.nix` — centralized port registry
- `lib/docker.nix` — `mkDockerService` implementation
- `modules/nixos/services/caddy.nix` — reverse proxy and `protectedVHost`
- `platforms/nixos/system/configuration.nix` — where services are enabled
