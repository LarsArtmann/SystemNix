lib: let
  harden = import ./systemd.nix {inherit lib;};
  inherit (import ./systemd/service-defaults.nix lib) serviceDefaults serviceDefaultsUser onFailure;
in {
  inherit harden;
  hardenUser = args: harden (args // {mode = "user";});
  inherit serviceDefaults serviceDefaultsUser onFailure;
  serviceTypes = import ./types.nix lib;
  mkDockerServiceFactory = {pkgs}: import ./docker.nix {inherit pkgs lib harden serviceDefaults onFailure;};

  mkStateDir = path: mode: user: group: "d ${path} ${mode} ${user} ${group} -";

  mkSecretCheck = pkgs: {
    name,
    secretPath,
    message,
    extraCheck ? "",
  }:
    pkgs.writeShellApplication {
      name = "check-${name}";
      runtimeInputs = [pkgs.coreutils];
      text = ''
        secret_path="${secretPath}"
        if [ ! -s "$secret_path" ]; then
          echo "${message}" >&2
          exit 1
        fi
        ${extraCheck}
      '';
    };

  mkDesktopNotifyService = pkgs: {
    name,
    description,
    checkScript,
    runtimeInputs,
    user,
    uid,
    interval ? "5min",
    bootDelay ? "2min",
    hardenFn ? harden,
    extraHarden ? {},
    extraServiceConfig ? {},
  }: let
    script = pkgs.writeShellApplication {
      name = "${name}-check";
      inherit runtimeInputs;
      text = checkScript;
    };
  in {
    timer = {
      description = "Periodic ${description}";
      timerConfig = {
        OnBootSec = bootDelay;
        OnUnitActiveSec = interval;
        Persistent = true;
      };
      wantedBy = ["timers.target"];
    };

    service = {
      inherit description onFailure;
      serviceConfig =
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
        // hardenFn ({
            ProtectHome = false;
            NoNewPrivileges = false;
          }
          // extraHarden)
        // extraServiceConfig;
    };
  };

  mkHttpCheck = {
    name,
    group,
    url,
    interval ? "30s",
    conditions ? ["[STATUS] == 200"],
    alerts ? [],
  }: {
    inherit name group url interval conditions alerts;
  };

  ports = let
    raw = (import ./ports.nix).ports;
    byValue = builtins.groupBy (name: toString raw.${name}) (builtins.attrNames raw);
    dupes = builtins.filter (v: builtins.length byValue.${v} > 1) (builtins.attrNames byValue);
    dupeMsg = builtins.concatStringsSep "; " (map (
        v: "port ${v} used by: ${builtins.concatStringsSep ", " byValue.${v}}"
      )
      dupes);
  in
    if dupes == []
    then raw
    else builtins.throw "Port collision: ${dupeMsg}";

  images = import ./images.nix;

  rocm = import ./rocm.nix;

  mkFilesystem = import ./filesystems.nix lib;
}
