# crush-daily — SystemNix hardening overlay for the crush-daily service
_: {
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

        # Ensure the crush-daily user can traverse the directory chain to the
        # Crush database. Three dirs default to 700 (lars:users), which blocks
        # the crush-daily system user even with SupplementaryGroups = "users".
        system.activationScripts."crush-daily-perms" = lib.stringAfter [ "users" ] ''
          for dir in \
            /home/${primaryUser}/.local \
            /home/${primaryUser}/.local/share \
            /home/${primaryUser}/.local/share/crush/.crush; do
            if [ -d "$dir" ]; then
              chmod g+rx "$dir"
            fi
          done
        '';

        systemd.services.crush-daily = {
          inherit onFailure;
          path = [ pkgs.crush ];
          startLimitBurst = 3;
          startLimitIntervalSec = 60;
          serviceConfig = lib.mkMerge [
            (harden {
              # Must read the primary user's Crush database from /home.
              # Scoped via ReadOnlyPaths — only the .crush dir is readable.
              ProtectHome = false;
              ReadOnlyPaths = [ crushDbDir ];
              ReadWritePaths = [ cfg.dataDir ];
              SupplementaryGroups = "users";
            })
            (serviceDefaults { })
          ];
        };
      };
    };
}
