# crush-daily — SystemNix hardening overlay for the crush-daily service
#
# The upstream crush-daily flake module (flake.nix) now declares
# `services.crush-daily.runAsUser`. SystemNix just wires SystemNix-specific
# hardening: directory traversal permissions and per-host overrides.
_:
{
  flake.nixosModules.crush-daily =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.crush-daily;
      inherit (import ../../../lib/default.nix lib)
        harden
        mkStateDir
        serviceDefaults
        onFailure
        ports
        ;
      primaryUser = config.users.primaryUser;
      crushDbDir = "/home/${primaryUser}/.local/share/crush/.crush";
    in
    {
      config = lib.mkIf cfg.enable {
        services.crush-daily.port = lib.mkDefault ports.crush-daily;

        # When running as the default `crush-daily` system user (no
        # runAsUser override), ensure the system user can traverse the path
        # to the primary user's ~/.local/share/crush/.crush to read the
        # database. tmpfiles `d` type sets mode on existing dirs too.
        systemd.tmpfiles.rules = lib.mkIf (cfg.runAsUser == null) [
          (mkStateDir "/home/${primaryUser}/.local" "0750" primaryUser "users")
          (mkStateDir "/home/${primaryUser}/.local/share" "0750" primaryUser "users")
          (mkStateDir "/home/${primaryUser}/.local/share/crush/.crush" "0750" primaryUser "users")
        ];

        systemd.services.crush-daily = {
          inherit onFailure;
          path = [ pkgs.crush ];
          startLimitBurst = 3;
          startLimitIntervalSec = 60;

          # The upstream module hardcodes User/Group = "crush-daily".
          # SystemNix only ADDS hardening (start limits, onFailure,
          # default port) and never overrides upstream identity — that
          # is now done via the upstream `services.crush-daily.runAsUser`
          # option, which SystemNix sets in configuration.nix.
          serviceConfig = lib.mkMerge [
            (harden {
              ProtectHome = false;
              SupplementaryGroups = lib.mkIf (cfg.runAsUser == null) "users";
              ReadOnlyPaths = lib.mkIf (cfg.runAsUser == null) [ crushDbDir ];
              ReadWritePaths = [ cfg.dataDir ];
            })
            (serviceDefaults { })
          ];
        };
      };
    };
}
