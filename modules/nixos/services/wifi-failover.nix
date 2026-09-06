# WiFi standby failover — carrier-based default-route guard for eno1.
#
# PROBLEM (why a desktop with connected WiFi still loses connectivity when the
# ethernet cable is pulled): the eno1 default route is STATIC (metric 0, set by
# networking.interfaces). The kernel does NOT remove routes on carrier loss —
# only on admin down. With the cable out, the metric-0 default stays in the
# table and blackholes ALL traffic while the NetworkManager WiFi route
# (metric 100) sits idle. NetworkManager cannot help: eno1 is deliberately
# unmanaged (static IP stability for services).
#
# SOLUTION: a tiny daemon watches /sys/class/net/eno1/carrier. On carrier loss
# it deletes the pinned eno1 default routes (v4+v6) — the NM fallback route
# takes over instantly. On carrier return it re-adds `default via
# networking.local.gateway dev eno1` (metric 0 beats the fallback's metric 100
# again). The fallback route is NEVER touched — it stays up as hot standby.
#
# WHY NOT services.dual-wan: that module is probe-based ECMP+MPTCP (it failover'd
# on transient ISP blips and got disabled, see configuration.nix) and would
# split packets over a metered phone hotspot. This module is standby-only and
# carrier-based; an eval-time assertion rejects enabling both.
_: {
  flake.nixosModules.wifi-failover =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.wifi-failover;
      inherit (lib) mkEnableOption mkOption types;
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceDefaults
        onFailure
        ;

      inherit (config.networking.local) gateway;

      eno1Device = "sys-subsystem-net-devices-${cfg.ethernetInterface}.device";

      wifiFailoverScript = pkgs.writeShellApplication {
        name = "wifi-failover-watch";
        runtimeInputs = [
          pkgs.iproute2
          pkgs.gnugrep
          pkgs.coreutils
        ];
        text = builtins.readFile ../../../scripts/wifi-failover-watch.sh;
      };
    in
    {
      options.services.wifi-failover = {
        enable = mkEnableOption "carrier-based standby failover from static ethernet to NetworkManager WiFi";

        ethernetInterface = mkOption {
          type = types.nonEmptyStr;
          default = "eno1";
          description = "Primary ethernet interface (static IP, NixOS-managed)";
        };

        fallbackInterface = mkOption {
          type = types.nonEmptyStr;
          default = "wlan0";
          description = "WiFi fallback interface (NetworkManager-managed hot standby)";
        };

        pollIntervalSeconds = mkOption {
          type = types.ints.positive;
          default = 1;
          description = "Seconds between carrier checks (cable pull is detected within one poll)";
        };

        trustFallbackInterface = mkOption {
          type = types.bool;
          default = true;
          description = ''
            Add the fallback interface to networking.firewall.trustedInterfaces so
            LAN-equivalent service access survives failover (the fallback is the
            user's own hotspot — same trust model as the LAN). Disable to keep it
            filtered down to the globally allowed ports.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            # `or false`: the isolated-VM eval of this module has no dual-wan
            # module imported — the option tree simply lacks the attribute.
            assertion = !(cfg.enable && (config.services.dual-wan.enable or false));
            message = ''
              services.wifi-failover conflicts with services.dual-wan — both manage
              the ${cfg.ethernetInterface}/fallback default route. dual-wan is
              probe-based ECMP+MPTCP (active-active), wifi-failover is carrier-based
              standby (active-passive). Enable exactly one.
            '';
          }
        ];

        networking.firewall.trustedInterfaces = lib.optionals cfg.trustFallbackInterface [
          cfg.fallbackInterface
        ];

        systemd.services.wifi-failover = {
          description = "WiFi standby failover — carrier-based ${cfg.ethernetInterface} default-route guard";
          wantedBy = [ "multi-user.target" ];
          after = [
            eno1Device
            "network.target"
          ];
          wants = [
            eno1Device
            "network.target"
          ];
          inherit onFailure;
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          serviceConfig = lib.mkMerge [
            {
              Type = "simple";
              Environment = [
                "ENO1_IF=${cfg.ethernetInterface}"
                "FALLBACK_IF=${cfg.fallbackInterface}"
                "GW=${gateway}"
                "POLL_INTERVAL=${toString cfg.pollIntervalSeconds}"
              ];
              ExecStart = lib.getExe wifiFailoverScript;
            }
            (harden {
              ProtectHome = false;
              CapabilityBoundingSet = "CAP_NET_ADMIN";
              NoNewPrivileges = false;
              MemoryMax = "64M";
            })
            (serviceDefaults { })
          ];
        };
      };
    };
}
