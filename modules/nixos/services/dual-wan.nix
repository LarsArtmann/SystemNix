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

    mptcpizeWrapper = pkgs.writeShellScriptBin "mptcpize-run" ''
      exec ${pkgs.mptcpd}/bin/mptcpize run "$@"
    '';
  in {
    options.services.dual-wan = {
      enable = mkEnableOption "Dual-WAN ECMP failover with MPTCP packet-level redundancy";

      ethernetInterface = mkOption {
        type = types.nonEmptyStr;
        default = "eno1";
        description = "Primary ethernet interface name";
      };

      wifiInterface = mkOption {
        type = types.nonEmptyStr;
        default = "wlan0";
        description = "WiFi interface name (auto-detected if this one doesn't exist)";
      };

      checkInterval = mkOption {
        type = types.ints.positive;
        default = 2;
        description = "Seconds between ISP health checks (lower = faster failover)";
      };

      failoverThreshold = mkOption {
        type = types.ints.positive;
        default = 2;
        description = "Consecutive ISP failures before shifting traffic to WiFi";
      };

      failbackThreshold = mkOption {
        type = types.ints.positive;
        default = 5;
        description = "Consecutive ISP recoveries before restoring ECMP with eno1 preferred";
      };
    };

    config = lib.mkIf cfg.enable {
      boot.kernel.sysctl = {
        "net.mptcp.enabled" = 1;
        "net.mptcp.pm_type" = 0;
        "net.mptcp.add_addr_timeout" = 30;

        "net.ipv4.tcp_retries1" = 2;
        "net.ipv4.tcp_retries2" = 8;
        "net.ipv4.tcp_fin_timeout" = 10;
        "net.ipv4.tcp_keepalive_time" = 30;
        "net.ipv4.tcp_keepalive_intvl" = 10;
        "net.ipv4.tcp_keepalive_probes" = 3;
        "net.ipv4.tcp_orphan_retries" = 1;
      };

      networking.defaultGateway = {
        address = gateway;
        interface = cfg.ethernetInterface;
        metric = 100;
      };

      environment.systemPackages = [pkgs.mptcpd mptcpizeWrapper];

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
            description = "ECMP+MPTCP WAN failover — eno1 primary, WiFi fallback";
            wantedBy = ["multi-user.target"];
            after = ["network-online.target"];
            wants = ["network-online.target"];
            path = [
              pkgs.curl
              pkgs.iproute2
              pkgs.networkmanager
              pkgs.util-linux
            ];
            serviceConfig =
              {
                Type = "simple";
                Environment = [
                  "ENO1_GW=${gateway}"
                  "ENO1_IF=${cfg.ethernetInterface}"
                  "WIFI_IF=${cfg.wifiInterface}"
                  "CHECK_INTERVAL=${toString cfg.checkInterval}"
                  "FAILOVER_THRESHOLD=${toString cfg.failoverThreshold}"
                  "FAILBACK_THRESHOLD=${toString cfg.failbackThreshold}"
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
