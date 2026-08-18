# crush-daily — SystemNix hardening overlay for the crush-daily service
#
# The upstream crush-daily flake module (flake.nix) now declares
# `services.crush-daily.runAsUser`. SystemNix just wires SystemNix-specific
# hardening: directory traversal permissions and per-host overrides.
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

          # OTel traces → local SigNoz OTLP/HTTP collector. Uses go-cqrs-lite
          # otel package which auto-initializes from this env var (noop tracer
          # when unset). See docs/service-integration-ideas.md appendix.
          environment = {
            OTEL_EXPORTER_OTLP_ENDPOINT = lib.mkDefault "localhost:${toString ports.signoz-otlp-http}";
          };

          # When runAsUser is set, take ownership of the existing data dir so
          # the new user can write the SQLite DB and read prior reports. The
          # dir is owned by `crush-daily:crush-daily` from historical runs
          # under the system user. systemd's StateDirectory only creates the
          # dir on first run — it does not chown existing data.
          #
          # The migration MUST run with the ExecStartPre "+" (full-privilege)
          # prefix: as the service User it SIGSYS'd at every boot (upstream
          # SystemCallFilter ~@privileged blocks fchownat; verified 2026-08-18
          # "Bad system call" core dumps) and even unfiltered, a non-root user
          # cannot chown files owned by another user (silent EPERM).
          serviceConfig = lib.mkMerge [
            (lib.mkIf (cfg.runAsUser != null) {
              ExecStartPre = [
                "+${
                  pkgs.writeShellApplication {
                    name = "crush-daily-migrate-ownership";
                    runtimeInputs = [
                      pkgs.coreutils
                      pkgs.findutils
                    ];
                    text = ''
                      mkdir -p ${lib.escapeShellArg cfg.dataDir}
                      chown -R ${lib.escapeShellArg cfg.runAsUser} ${lib.escapeShellArg cfg.dataDir}
                      find ${lib.escapeShellArg cfg.dataDir} -type d -exec chmod 0750 {} \;
                      find ${lib.escapeShellArg cfg.dataDir} -type f -exec chmod 0640 {} \;
                    '';
                  }
                }/bin/crush-daily-migrate-ownership"
              ];
            })
            (harden {
              MemoryMax = "1G";
              # ReadOnlyPaths / SupplementaryGroups only needed when running
              # as the default system user (the primary user's /home is
              # mode 750 + ACL mask; supplementary group `users` is required
              # for traversal). When runAsUser is set, the service IS the
              # primary user and has access to /home/<user> directly.
              SupplementaryGroups = lib.mkIf (cfg.runAsUser == null) "users";
              ReadOnlyPaths = lib.mkIf (cfg.runAsUser == null) [ crushDbDir ];
              ReadWritePaths = [ cfg.dataDir ];
            })
            (serviceDefaults { })
            {
              TimeoutStartSec = "3min";
              Environment = [ "GOMEMLIMIT=768MiB" ];
            }
          ];
        };
      };
    };
}
