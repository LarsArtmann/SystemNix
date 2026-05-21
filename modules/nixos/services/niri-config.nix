# Niri Wayland compositor: DRM health checks, GPU recovery, metrics
_: {
  flake.nixosModules.niri-config = {
    config,
    pkgs,
    lib,
    ...
  }: let
    cfg = config.services.niri-desktop;
    niriPkg = pkgs.niri-unstable;
    inherit (import ../../../lib/default.nix lib) harden hardenUser serviceDefaults onFailure mkStateDir;
    drmHealthcheck = pkgs.writeShellApplication {
      name = "niri-drm-healthcheck";
      runtimeInputs = with pkgs; [procps systemd];
      text = builtins.readFile ../../../scripts/niri-drm-healthcheck.sh;
    };
    gpuRecovery = pkgs.writeShellApplication {
      name = "gpu-recovery";
      runtimeInputs = with pkgs; [procps systemd gawk];
      text = builtins.readFile ../../../scripts/gpu-recovery.sh;
    };
    displayWatchdog = pkgs.writeShellApplication {
      name = "display-watchdog";
      runtimeInputs = with pkgs; [procps systemd kbd];
      text = builtins.readFile ../../../scripts/display-watchdog.sh;
    };
  in {
    options.services.niri-desktop = {
      enable = lib.mkEnableOption "Niri Wayland compositor with XWayland support";
    };

    config = lib.mkIf cfg.enable {
      programs.niri = {
        enable = true;
        package = niriPkg;
      };

      systemd.tmpfiles.rules = [
        (mkStateDir "/var/lib/niri-drm-healthcheck" "0755" config.users.primaryUser "users")
        (mkStateDir "/var/lib/display-watchdog" "0755" "root" "root")
        (mkStateDir "/var/lib/prometheus-node-exporter/textfile_collectors" "1777" "root" "root")
      ];

      systemd = {
        user = {
          units = let
            unitFiles = builtins.readDir "${niriPkg}/lib/systemd/user";
            mkUnit = name: let
              baseText = builtins.readFile "${niriPkg}/lib/systemd/user/${name}";
              text =
                if name == "niri.service"
                then let
                  noBindsTo =
                    builtins.replaceStrings
                    ["BindsTo=graphical-session.target"]
                    ["Wants=graphical-session.target"]
                    baseText;
                  unitLimits =
                    builtins.replaceStrings
                    ["[Unit]"]
                    [
                      ''                          [Unit]
                        StartLimitBurst=3
                        StartLimitIntervalSec=60''
                    ]
                    noBindsTo;
                in
                  unitLimits
                  + "\nRestart=always\nRestartSec=2s\nOOMScoreAdjust=-1000\nLimitNPROC=infinity\nLimitNOFILE=524288\n"
                  + "\n[Install]\nWantedBy=graphical-session.target\n"
                else baseText;
            in {inherit text;};
          in
            lib.listToAttrs (map (name: {
                inherit name;
                value = mkUnit name;
              }) (lib.filter (name: lib.hasSuffix ".service" name || lib.hasSuffix ".target" name)
                (builtins.attrNames unitFiles)));

          services.niri-drm-healthcheck = {
            description = "Detect niri DRM zombie state and restart niri";
            serviceConfig =
              hardenUser {MemoryMax = "256M";}
              // {
                Type = "oneshot";
                ExecStart = "${drmHealthcheck}/bin/niri-drm-healthcheck";
              };
          };

          timers.niri-drm-healthcheck = {
            description = "Check niri DRM health every 60 seconds";
            wantedBy = ["timers.target"];
            timerConfig = {
              OnBootSec = "60s";
              OnUnitActiveSec = "60s";
              AccuracySec = "10s";
            };
          };
        };

        services = {
          gpu-recovery = {
            description = "GPU driver recovery — rebinds amdgpu to fix DRM corruption (DISABLED — kernel amdgpu.gpu_recovery=1 handles this)";
            path = with pkgs; [procps systemd gawk];
            inherit onFailure;
            wantedBy = lib.mkForce [];
            serviceConfig =
              {
                Type = "oneshot";
                ExecStart = "${gpuRecovery}/bin/gpu-recovery";
                OOMScoreAdjust = -1000;
              }
              // harden {
                MemoryMax = "2G";
                ReadWritePaths = ["/sys" "/dev"];
              }
              // serviceDefaults {Restart = "no";};
          };

          display-watchdog = {
            description = "Detect dead display (connected but no signal) and recover";
            path = with pkgs; [kbd];
            inherit onFailure;
            serviceConfig =
              {
                Type = "oneshot";
                ExecStart = "${displayWatchdog}/bin/display-watchdog";
                OOMScoreAdjust = -500;
              }
              // harden {
                MemoryMax = "512M";
                ReadWritePaths = ["/sys/class/drm" "/var/lib/display-watchdog"];
              };
          };

          niri-health-metrics = {
            description = "Niri compositor health metrics for node_exporter textfile";
            path = with pkgs; [systemd gawk];
            serviceConfig =
              {
                Type = "oneshot";
                ExecStart = pkgs.writeShellScript "niri-health-metrics" ''
                  set -euo pipefail
                  OUT="/var/lib/prometheus-node-exporter/textfile_collectors/niri.prom"
                  TMP="''${OUT}.tmp"
                  TEXTFILE_DIR="/var/lib/prometheus-node-exporter/textfile_collectors"
                  mkdir -p "$TEXTFILE_DIR"

                  running=$(${pkgs.procps}/bin/pgrep -x niri >/dev/null 2>&1 && echo 1 || echo 0)
                  restarts=$(journalctl --user -u niri --no-pager --since "10 min" 2>/dev/null | grep -c "Started niri" || true)
                  drm_errors=$(journalctl --user -u niri --no-pager -n 20 --since "30 sec ago" 2>/dev/null | grep -cE "Permission denied|DeviceMissing" || true)

                  {
                    echo "niri_running $running"
                    echo "niri_restarts_10m $restarts"
                    echo "niri_drm_errors_30s $drm_errors"
                  } > "$TMP"

                  mv "$TMP" "$OUT"
                '';
              }
              // harden {
                ReadWritePaths = ["/var/lib/prometheus-node-exporter/textfile_collectors"];
              };
          };
        };

        timers = {
          display-watchdog = {
            description = "Check for dead display every 30 seconds";
            wantedBy = ["timers.target"];
            timerConfig = {
              OnBootSec = "30s";
              OnUnitActiveSec = "30s";
              AccuracySec = "5s";
            };
          };

          niri-health-metrics = {
            description = "Collect niri health metrics every 30s";
            wantedBy = ["timers.target"];
            timerConfig = {
              OnBootSec = "30s";
              OnUnitActiveSec = "30s";
            };
          };
        };
      };

      environment.systemPackages = with pkgs; [
        xwayland-satellite
      ];
    };
  };
}
