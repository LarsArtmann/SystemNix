_: {
  flake.nixosModules.dual-wan = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.dual-wan;
    inherit (lib) mkEnableOption mkOption types;
    inherit (import ../../../lib/default.nix lib) harden serviceDefaults;

    inherit (config.networking.local) lanIP gateway;

    routeHealthScript = pkgs.writeShellScript "route-health-monitor" (builtins.readFile ../../../scripts/route-health-monitor.sh);
    mptcpEndpointScript = pkgs.writeShellScript "mptcp-endpoint-manager" (builtins.readFile ../../../scripts/mptcp-endpoint-manager.sh);
  in {
    options.services.dual-wan = {
      enable = mkEnableOption "Dual-WAN with MPTCP and route health monitoring";

      ethernetInterface = mkOption {
        type = types.nonEmptyStr;
        default = "eno1";
        description = "Primary ethernet interface name";
      };

      wifiInterface = mkOption {
        type = types.nonEmptyStr;
        default = "wlp195s0";
        description = "WiFi interface name";
      };

      checkInterval = mkOption {
        type = types.ints.positive;
        default = 5;
        description = "Seconds between health checks";
      };
    };

    config = lib.mkIf cfg.enable {
      boot.kernel.sysctl = {
        "net.mptcp.enabled" = 1;
        "net.mptcp.pm_type" = 0;
        "net.mptcp.add_addr_timeout" = 30;
      };

      networking.defaultGateway = {
        address = gateway;
        interface = cfg.ethernetInterface;
        metric = 100;
      };

      security.polkit.extraConfig = ''
        polkit.addRule(function(action, subject) {
          if (action.id.indexOf("org.freedesktop.NetworkManager.") === 0 &&
              subject.isInGroup("networkmanager")) {
            return polkit.Result.YES;
          }
        });
      '';

      systemd = {
        services = {
          mptcp-endpoint-manager = {
            description = "MPTCP endpoint manager — syncs subflow endpoints with live interfaces";
            wantedBy = ["multi-user.target"];
            after = ["network-online.target"];
            wants = ["network-online.target"];
            path = [
              pkgs.iproute2
              pkgs.util-linux
            ];
            serviceConfig =
              {
                Type = "simple";
                Environment = [
                  "ENO1_IP=${lanIP}"
                  "ENO1_IF=${cfg.ethernetInterface}"
                  "WIFI_IF=${cfg.wifiInterface}"
                ];
                ExecStart = mptcpEndpointScript;
              }
              // harden {
                ProtectHome = false;
                CapabilityBoundingSet = "CAP_NET_ADMIN";
                NoNewPrivileges = false;
              }
              // serviceDefaults {};
          };

          route-health-monitor = {
            description = "Dual-WAN route health monitor — dynamic ECMP failover";
            wantedBy = ["multi-user.target"];
            after = ["network-online.target"];
            wants = ["network-online.target"];
            path = [
              pkgs.iproute2
              pkgs.networkmanager
              pkgs.util-linux
            ];
            serviceConfig =
              {
                Type = "simple";
                Environment = [
                  "ENO1_GW=${gateway}"
                  "WIFI_IF=${cfg.wifiInterface}"
                  "CHECK_INTERVAL=${toString cfg.checkInterval}"
                ];
                ExecStart = routeHealthScript;
              }
              // harden {
                ProtectHome = false;
                CapabilityBoundingSet = "CAP_NET_ADMIN";
                NoNewPrivileges = false;
              }
              // serviceDefaults {};
          };
        };
      };
    };
  };
}
