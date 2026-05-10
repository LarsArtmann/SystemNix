_: {
  flake.nixosModules.dns-failover = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.dns-failover;
    inherit (lib) mkEnableOption mkOption types;
  in {
    options.services.dns-failover = {
      enable = mkEnableOption "DNS failover via Keepalived VRRP";

      virtualIP = mkOption {
        type = types.nonEmptyStr;
        description = "Virtual IP address shared between DNS nodes (clients point to this)";
      };

      interface = mkOption {
        type = types.nonEmptyStr;
        description = "Network interface for VRRP advertisements and virtual IP";
      };

      priority = mkOption {
        type = types.ints.between 0 255;
        default = 100;
        description = "VRRP priority (higher = preferred master). Use 100 for primary, 50 for backup.";
      };

      routerID = mkOption {
        type = types.ints.between 0 255;
        default = 53;
        description = "VRRP router ID (must match on all nodes in the cluster)";
      };

      subnetPrefix = mkOption {
        type = types.ints.between 0 32;
        default = 24;
        description = "Subnet prefix length for the virtual IP";
      };

      authPassword = mkOption {
        type = types.nonEmptyStr;
        description = "VRRP authentication password. REQUIRED — must be set per-node. Use sops for production.";
      };
    };

    config = lib.mkIf cfg.enable {
      services.keepalived = {
        enable = true;
        openFirewall = true;

        vrrpScripts.chk_unbound = {
          script = "${pkgs.bind.dnsutils}/bin/host google.com 127.0.0.1 > /dev/null 2>&1";
          interval = 5;
          fall = 3;
          rise = 2;
        };

        vrrpInstances.VI_DNS = {
          state =
            if cfg.priority >= 100
            then "MASTER"
            else "BACKUP";
          inherit (cfg) interface priority;
          virtualRouterId = cfg.routerID;
          noPreempt = cfg.priority < 100;

          virtualIps = [
            {addr = "${cfg.virtualIP}/${toString cfg.subnetPrefix}";}
          ];

          trackScripts = ["chk_unbound"];

          extraConfig = ''
            authentication {
              auth_type PASS
              auth_pass ${cfg.authPassword}
            }
          '';
        };

        extraGlobalDefs = ''
          vrrp_garp_master_refresh 30
          vrrp_garp_master_refresh_repeat 2
        '';
      };
    };
  };
}
