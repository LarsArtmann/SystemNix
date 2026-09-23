# Restic deduplicating repository on the HDD pool for the app-dump
# backups (T17 backlog item): the per-service dump units (forgejo zips,
# pocket-id/miniflux/paperless/cv/... dumps) share ~0 extents — each
# nightly archive is a fresh full copy. This module mirrors those dump
# dirs into ONE chunk-dedup restic repo with bounded retention, layered
# ON TOP of the per-service dumps (freshness of the SOURCES stays owned
# by their own backup-coordination rows).
#
# Repo password is a machine-local random value (searxng-secret-key
# pattern) — the repo is pool-local until the offsite Borg leg exists,
# so no sops secret is needed; losing the host loses the repo, which is
# already true for everything on the pool.
_: {
  flake.nixosModules.restic-app-dumps =
    {
      config,
      options,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (import ../../../lib/default.nix lib) onFailure harden ioTier;
      cfg = config.services.restic-app-dumps;

      repoPath = "/mnt/pool/backups/restic-app-dumps";
      passwordFile = "/var/lib/restic-app-dumps/password";
      markerFile = "${repoPath}/.last_success";

      passwordSetup = pkgs.writeShellApplication {
        name = "restic-app-dumps-password-setup";
        runtimeInputs = [ pkgs.coreutils ];
        text = ''
          # 44-char base64 password, 0600 (umask 077) — created once; the
          # repo at ${repoPath} is only readable with it.
          if [ ! -s "${passwordFile}" ]; then
            head -c 32 /dev/urandom | base64 > "${passwordFile}"
          fi
        '';
      };
    in
    {
      options.services.restic-app-dumps = {
        enable = lib.mkEnableOption "restic dedup repo on the pool for the app-dump backups";

        paths = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          description = "App-dump directories (under /mnt/pool/backups) to mirror into the restic repo.";
          default = [
            "/mnt/pool/backups/browser-history"
            "/mnt/pool/backups/clickhouse"
            "/mnt/pool/backups/cv"
            "/mnt/pool/backups/forgejo"
            "/mnt/pool/backups/geometrikks"
            "/mnt/pool/backups/inboxclean"
            "/mnt/pool/backups/manifest"
            "/mnt/pool/backups/miniflux"
            "/mnt/pool/backups/paperless"
            "/mnt/pool/backups/pocket-id"
            "/mnt/pool/backups/signal-backups"
            "/mnt/pool/backups/twenty"
          ];
        };
      };

      config = lib.mkIf cfg.enable {
        # nixpkgs restic module owns the backup unit + timer (incl. the
        # `restic init` preStart when the repo is missing — a lost pool
        # re-initializes on the first run after the dir is recreated).
        services.restic.backups.app-dumps = {
          inherit passwordFile;
          repository = repoPath;
          initialize = true;
          inherit (cfg) paths;
          extraBackupArgs = [
            "--tag"
            "app-dumps"
          ];
          # Bounded growth: the pool carries root receives forever, the
          # restic repo must not grow unbounded on top of them.
          pruneOpts = [
            "--keep-daily"
            "14"
            "--keep-weekly"
            "8"
          ];
          # After the 05:15 geometrikks dump; 12h ceiling covers the one-time
          # first seed of ~tens of GB onto the HDD pool.
          timerConfig = {
            OnCalendar = "*-*-* 05:45:00";
            Persistent = true;
            RandomizedDelaySec = "10m";
          };
        };

        # One-time repo password bootstrap — re-run by deploy.sh's
        # provisioner loop (idempotent).
        systemd.services.restic-app-dumps-setup = {
          description = "Ensure the restic app-dumps repo password exists";
          wantedBy = [ "multi-user.target" ];
          inherit onFailure;
          serviceConfig = lib.mkMerge [
            (harden { })
            {
              Type = "oneshot";
              RemainAfterExit = true;
              StateDirectory = "restic-app-dumps";
              UMask = "0077";
              ExecStart = lib.getExe passwordSetup;
            }
          ];
        };

        systemd.services."restic-backups-app-dumps" = {
          description = "restic dedup backup of the app dumps to the HDD pool";
          inherit onFailure;
          after = [ "restic-app-dumps-setup.service" ];
          wants = [ "restic-app-dumps-setup.service" ];
          unitConfig.RequiresMountsFor = [ "/mnt/pool" ];
          serviceConfig = lib.mkMerge [
            ioTier.background
            {
              MemoryMax = "4G";
              TimeoutStartSec = "12h";
              # Freshness marker for backup-coordination — runs only when
              # backup + forget + prune all succeeded.
              ExecStartPost = "${pkgs.coreutils}/bin/touch ${markerFile}";
            }
          ];
        };

        # Registry fan-out: freshness row (backup-coordination metric + the
        # aggregate "All Backups Healthy" Gatus check). No vHost/port — this
        # is pool-side backup infra, layer "none".
        services.integration = lib.optionalAttrs (options ? services.integration) {
          restic-app-dumps = {
            vHost.layer = "none";
            backup = {
              directory = repoPath;
              filePattern = ".last_success";
              maxAgeHours = 25;
            };
          };
        };
      };
    };
}
