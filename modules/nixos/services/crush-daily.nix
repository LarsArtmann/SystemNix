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
        mkStateDir
        serviceDefaults
        onFailure
        ports
        ;
      primaryUser = config.users.primaryUser;
      crushDbDir = "/home/${primaryUser}/.local/share/crush/.crush";

      # `runAsUser` overrides the upstream module's hardcoded `User = "crush-daily"`.
      #
      # Why this exists: the crush-daily collector shells `crush projects --json`
      # which reads per-user state from the invoking user's $HOME. When the
      # service runs as the `crush-daily` system user, that user has its own
      # empty `~/.local/share/crush/projects.json` — silent empty list returned
      # to the collector, "collect done projects=0" every night, and zero-data
      # reports. Worse, `/home/${primaryUser}` is mode 700 with an ACL mask of
      # `---` so even with SupplementaryGroups = "users" the system user
      # cannot traverse to read the real database.
      #
      # Setting runAsUser = primaryUser makes the service inherit the primary
      # user's permissions directly, dropping the cross-user ACL/mode traversal
      # problem and reading the real per-user crush state.
      #
      # Note: the option is declared in this wrapper (not upstream) because
      # upstream crush-daily doesn't yet expose it. We use `lib.mkOption` here
      # so `nix flake check` recognizes it.
      runAsUserOpt = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Run the service as this user instead of the upstream `crush-daily`
          system user. Required when the collector needs to read per-user
          Crush state from the primary user's $HOME. Defaults to null
          (use upstream's hardcoded system user).
        '';
        example = "lars";
      };

      # Validate: refuse to set runAsUser to anything other than the primary
      # user. Cross-user reads of /home are out of scope for this module.
      validatedRunAsUser =
        if cfg.runAsUser != null && cfg.runAsUser != primaryUser then
          throw ''
            services.crush-daily.runAsUser must be ${primaryUser} (the primary
            user), got "${cfg.runAsUser}". Cross-user /home reads are not
            supported by this module — either grant the crush-daily user
            explicit access to the database dir, or move the database to a
            shared location.
          ''
        else
          cfg.runAsUser;
    in
    {
      options.services.crush-daily = {
        runAsUser = runAsUserOpt;
      };

      config = lib.mkIf cfg.enable {
        services.crush-daily.port = lib.mkDefault ports.crush-daily;

        # When runAsUser is null, the service runs as `crush-daily` and needs
        # ReadOnlyPaths access to the primary user's .crush directory. We
        # chmod-g+rx the path components to enable traversal for group `users`
        # (which the crush-daily user is in via SupplementaryGroups).
        #
        # When runAsUser is the primary user, ReadOnlyPaths is unnecessary
        # (the service IS the data owner).
        systemd.tmpfiles.rules =
          lib.optional (validatedRunAsUser == null) (mkStateDir "/home/${primaryUser}/.local" "0750" primaryUser "users")
          ++ lib.optional (validatedRunAsUser == null) (mkStateDir "/home/${primaryUser}/.local/share" "0750" primaryUser "users")
          ++ lib.optional (validatedRunAsUser == null) (mkStateDir "/home/${primaryUser}/.local/share/crush/.crush" "0750" primaryUser "users");

        systemd.services.crush-daily = {
          inherit onFailure;
          path = [ pkgs.crush ];
          startLimitBurst = 3;
          startLimitIntervalSec = 60;
          # When runAsUser is set, take ownership of the data dir so the new
          # user can read prior reports and write fresh data. The data dir is
          # created by upstream tmpfiles (crush-daily:crush-daily:0750); we
          # chown it idempotently at start. Single-user homelab: safe.
          preStart = lib.mkIf (validatedRunAsUser != null) (
            let
              dataDirEscaped = lib.escapeShellArg cfg.dataDir;
              userEscaped = lib.escapeShellArg validatedRunAsUser;
            in
            ''
              mkdir -p ${dataDirEscaped}
              chown -R ${userEscaped}:users ${dataDirEscaped} 2>/dev/null || true
              find ${dataDirEscaped} -type d -exec chmod 0750 {} \; 2>/dev/null || true
              find ${dataDirEscaped} -type f -exec chmod 0640 {} \; 2>/dev/null || true
            ''
          );

          # --- User/Group override when runAsUser is set ---
          # The upstream module hardcodes User = "crush-daily", Group = "crush-daily".
          # We mkForce only when validatedRunAsUser is set, otherwise upstream wins.
          serviceConfig =
            let
              baseServiceConfig = lib.mkMerge [
                (harden {
                  # When running as system crush-daily user, must read primary
                  # user's Crush DB from /home. Scoped via ReadOnlyPaths — only
                  # the .crush dir is readable.
                  ProtectHome = lib.mkIf (validatedRunAsUser == null) false;
                  ReadOnlyPaths = lib.mkIf (validatedRunAsUser == null) [ crushDbDir ];
                  ReadWritePaths = [
                    cfg.dataDir
                  ];
                  SupplementaryGroups = lib.mkIf (validatedRunAsUser == null) "users";
                })
                (serviceDefaults { })
              ];
              userOverrideServiceConfig = lib.mkIf (validatedRunAsUser != null) {
                # Primary user runs the service: keep the data dir RW but drop
                # the cross-user scoped ReadOnlyPaths. Primary user already has
                # access to their own home.
                # mkForce required: upstream flake.nix hardcodes these values.
                User = lib.mkForce validatedRunAsUser;
                Group = lib.mkForce "users";
                ProtectHome = lib.mkForce false;
              };
            in
            lib.mkMerge [
              baseServiceConfig
              userOverrideServiceConfig
            ];
        };
      };
    };
}
