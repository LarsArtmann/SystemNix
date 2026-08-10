lib:
let
  harden = import ./systemd.nix { inherit lib; };
  inherit (import ./systemd/service-defaults.nix lib)
    serviceDefaults
    serviceDefaultsUser
    serviceOneshotDefaults
    serviceOneshotDefaultsUser
    onFailure
    ;
in
{
  inherit harden;
  hardenUser = args: harden (args // { mode = "user"; });
  inherit
    serviceDefaults
    serviceDefaultsUser
    serviceOneshotDefaults
    serviceOneshotDefaultsUser
    onFailure
    ;
  serviceTypes = import ./types.nix lib;
  mkDockerServiceFactory =
    { pkgs }:
    import ./docker.nix {
      inherit
        pkgs
        lib
        harden
        serviceDefaults
        onFailure
        ;
    };

  mkStateDir =
    path: mode: user: group:
    "d ${path} ${mode} ${user} ${group} -";

  mkSecretCheck =
    pkgs:
    {
      name,
      secretPath,
      message,
      extraCheck ? "",
    }:
    pkgs.writeShellApplication {
      name = "check-${name}";
      runtimeInputs = [ pkgs.coreutils ];
      text = ''
        secret_path="${secretPath}"
        if [ ! -s "$secret_path" ]; then
          echo "${message}" >&2
          exit 1
        fi
        ${extraCheck}
      '';
    };

  mkDesktopNotifyService =
    pkgs:
    {
      name,
      description,
      checkScript,
      runtimeInputs,
      user,
      uid,
      interval ? "5min",
      bootDelay ? "2min",
      hardenFn ? harden,
      extraHarden ? { },
      extraServiceConfig ? { },
    }:
    let
      script = pkgs.writeShellApplication {
        name = "${name}-check";
        inherit runtimeInputs;
        text = checkScript;
      };
    in
    {
      timer = {
        description = "Periodic ${description}";
        timerConfig = {
          OnBootSec = bootDelay;
          OnUnitActiveSec = interval;
          Persistent = true;
        };
        wantedBy = [ "timers.target" ];
      };

      service = {
        inherit description onFailure;
        serviceConfig = lib.mkMerge [
          {
            Type = "oneshot";
            User = user;
            Environment = [
              "DISPLAY=:0"
              "WAYLAND_DISPLAY=wayland-1"
              "XDG_RUNTIME_DIR=/run/user/${uid}"
            ];
            ExecStart = lib.getExe script;
            StandardOutput = "journal";
            StandardError = "journal";
          }
          (hardenFn (
            lib.mkMerge [
              {
                ProtectHome = false;
                NoNewPrivileges = false;
              }
              extraHarden
            ]
          ))
          extraServiceConfig
        ];
      };
    };

  mkHttpCheck =
    {
      name,
      group,
      url,
      interval ? "30s",
      conditions ? [ "[STATUS] == 200" ],
      alerts ? [ ],
      client ? { },
    }:
    {
      inherit
        name
        group
        url
        interval
        conditions
        alerts
        ;
    }
    // lib.optionalAttrs (client != { }) { inherit client; };

  ports =
    let
      raw = (import ./ports.nix).ports;
      byValue = builtins.groupBy (name: toString raw.${name}) (builtins.attrNames raw);
      dupes = builtins.filter (v: builtins.length byValue.${v} > 1) (builtins.attrNames byValue);
      dupeMsg = builtins.concatStringsSep "; " (
        map (v: "port ${v} used by: ${builtins.concatStringsSep ", " byValue.${v}}") dupes
      );
    in
    if dupes == [ ] then raw else builtins.throw "Port collision: ${dupeMsg}";

  # BFQ I/O priority tiers for the evo-x2 QLC NVMe. Each helper returns a
  # systemd serviceConfig fragment — merge with `mkMerge` alongside `harden {}`.
  #
  # Tier philosophy: lower BE priority = higher I/O precedence. SSH (BE/1) always
  # gets I/O before builds (BE/7). Maintenance (idle) only runs when nothing else
  # needs I/O. This prevents build storms from freezing SSH sessions.
  #
  # Usage: `serviceConfig = lib.mkMerge [ (harden {}) (ioTier.build) ];`
  ioTier = {
    # BE/1 — SSH and critical remote access. Highest priority below realtime.
    interactive = {
      IOSchedulingClass = "best-effort";
      IOSchedulingPriority = 1;
    };
    # BE/3 — Desktop session (compositor, shell, audio). Must stay responsive.
    desktop = {
      IOSchedulingClass = "best-effort";
      IOSchedulingPriority = 3;
    };
    # BE/4 — Default for unclassified services. Most services sit here implicitly.
    service = {
      IOSchedulingClass = "best-effort";
      IOSchedulingPriority = 4;
    };
    # BE/5 — Latency-sensitive databases needing consistent I/O without
    # starving interactive/desktop workloads (clickhouse, monitor365).
    heavyDB = {
      IOSchedulingClass = "best-effort";
      IOSchedulingPriority = 5;
    };
    # BE/6 — Standard background daemons tolerating I/O latency
    # (signoz, discordsync, browser-history, ollama, attic).
    background = {
      IOSchedulingClass = "best-effort";
      IOSchedulingPriority = 6;
    };
    # BE/7 — Batch builds and CI. Lowest BE priority + CPU Nice=10.
    # Nix builds, automated commits, git runners.
    build = {
      IOSchedulingClass = "best-effort";
      IOSchedulingPriority = 7;
      Nice = 10;
    };
    # idle — Maintenance tasks using I/O only when nothing else needs it.
    # BFQ serves these last. Pairs with CPU Nice=10 (fstrim, clamav).
    maintenance = {
      IOSchedulingClass = "idle";
      Nice = 10;
    };
  };

  images = import ./images.nix;

  rocm = import ./rocm.nix;

  mkFilesystem = import ./filesystems.nix lib;

  # wrapWithMemoryLimit: creates a wrapper script that runs a command under a
  # systemd transient user scope with a cgroup MemoryMax limit. Prevents
  # memory-hungry dev/test commands (cargo test, go test, pnpm) from consuming
  # all system RAM on memory-constrained hosts like evo-x2 (Strix Halo with
  # chronic GPUActive memory pressure).
  #
  # Returns a writeShellApplication derivation. NOT for use inside Nix build
  # sandboxes (systemd-run is unavailable there). Use in devShells or
  # system/user packages.
  #
  # Example:
  #   wrapWithMemoryLimit pkgs {
  #     name = "go-test";
  #     maxMemory = "4G";
  #     command = lib.getExe pkgs.go;
  #     extraArgs = ["test"];
  #   }
  #   → produces a `go-test-memlimit` script that runs `go test "$@"`
  wrapWithMemoryLimit =
    pkgs:
    {
      name,
      maxMemory,
      command,
      extraArgs ? [ ],
    }:
    pkgs.writeShellApplication {
      name = "${name}-memlimit";
      runtimeInputs = [ pkgs.systemd ];
      text = ''
        exec systemd-run \
          --user --collect --wait \
          --same-dir \
          --setenv="*" \
          -p MemoryMax=${maxMemory} \
          -- ${command} ${lib.escapeShellArgs extraArgs} "$@"
      '';
    };
}
