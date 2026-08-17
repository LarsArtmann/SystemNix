# Google Drive → HDD pool mirror (rclone).
#
# Continuous one-way sync of Google Drive to /mnt/pool/backups/google-drive,
# semantically equivalent to Google Drive Desktop "Mirror" mode — local is an
# exact copy of the cloud, remote deletions propagate locally after a grace
# window. Unlike Drive Desktop, cloud-side deletions are NOT applied
# instantly: they land in a dated grace directory (google-drive-deleted/)
# for retentionDays before expiring, so ransomware or a fat-fingered cloud
# delete never silently destroys the only local copy.
#
# Why rclone + timer instead of a daemon: the Drive API has no push channel
# rclone supports, so "streaming" is polling anyway. A 5-minute oneshot per
# tick is more robust than a long-running process (no state to corrupt,
# journal per run, systemd timer persistence across reboots).
#
# Google Photos note: the Photos Library API cannot serve originals for
# third-party apps since 2025-03-31 (rclone Tier 5, gphotos-sync archived).
# If a scheduled Google Takeout export is enabled with "Add to Drive"
# delivery, its archives land inside this mirror automatically — nothing
# extra to configure here.
_: {
  flake.nixosModules.google-sync =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceOneshotDefaults
        ioTier
        onFailure
        mkDnsGate
        ;

      cfg = config.services.google-sync;

      destination = "/mnt/pool/backups/google-drive";
      # Grace dir MUST live outside the synced tree — rclone sync deletes local
      # paths that are absent on the remote, and a nested backup-dir would be
      # deleted by its own sync run (rclone also refuses it).
      graceDir = "/mnt/pool/backups/google-drive-deleted";
      stateDir = "/var/lib/google-sync";

      dnsGate = mkDnsGate {
        inherit pkgs;
        serviceName = "google-sync";
        hostname = "www.googleapis.com";
      };

      syncScript = pkgs.writeShellApplication {
        name = "google-sync-run";
        runtimeInputs = [
          pkgs.rclone
          pkgs.coreutils
          pkgs.findutils
        ];
        text = ''
          set -euo pipefail

          stamp="$(date +%Y%m%d_%H%M%S)"

          # --fast-list: mandatory for large trees (39k files: 22min → 4min listing).
          # --checksum: Drive returns md5 in listings, so verification is free.
          # --drive-skip-checksum-gphotos: photos stored IN Drive can have
          #   blank/mutating md5s (Google re-encodes without updating checksums) —
          #   without this flag those files re-download on every run.
          # --drive-export-formats: Google-native docs (Docs/Sheets/Slides) are
          #   exported as real files; pdf is the archive-faithful render.
          # --backup-dir + --suffix: remote deletions/overwrites are parked here
          #   instead of vanishing; timestamped suffix avoids name collisions
          #   when the same filename is deleted in multiple runs.
          rclone sync "gdrive:" "${destination}" \
            --config "''${RCLONE_CONFIG_PATH}" \
            --fast-list \
            --checksum \
            --drive-skip-checksum-gphotos \
            --drive-export-formats "${cfg.exportFormats}" \
            --backup-dir "${graceDir}" \
            --suffix ".del_''${stamp}" \
            --transfers 8 \
            --checkers 32 \
            --retries 3 \
            --low-level-retries 10 \
            --stats-one-line \
            --log-level INFO

          # Expire grace entries past the retention window, then drop empty date
          # dirs. rm (not trash) is deliberate: this is rebuildable grace data on
          # the pool, trashing it would write it back to the NVMe.
          find "${graceDir}" -type f -mtime +${toString cfg.retentionDays} -delete
          find "${graceDir}" -depth -mindepth 1 -type d -empty -delete

          # Freshness sentinel for backup-coordination (Gatus alerts via the
          # global backup_all_healthy check when this goes stale).
          touch "${stateDir}/last_success"
          echo "google-sync: mirror converged at $stamp"
        '';
      };
    in
    {
      options.services.google-sync = {
        enable = lib.mkEnableOption "Google Drive → HDD pool mirror via rclone" // { default = true; };

        interval = lib.mkOption {
          type = lib.types.str;
          default = "*:0/5";
          description = "OnCalendar for the sync timer (default: every 5 minutes).";
        };

        exportFormats = lib.mkOption {
          type = lib.types.str;
          default = "pdf";
          description = "rclone --drive-export-formats for Google-native documents (pdf = archive-faithful, docx,xlsx,pptx,svg = editable).";
        };

        retentionDays = lib.mkOption {
          type = lib.types.int;
          default = 30;
          description = "Days a cloud-side deletion stays recoverable in the grace directory.";
        };
      };

      config = lib.mkIf cfg.enable {
        sops.secrets = {
          # Full rclone.conf INI (type/client_id/client_secret/scope/token).
          # A file (not env vars) because the token blob is JSON — systemd
          # EnvironmentFile quoting of embedded double quotes is a footgun.
          # Read-only at runtime: rclone refreshes the access token in memory.
          # The refresh token persists ONLY if the Google OAuth client is in
          # production ("In production" publishing status) — testing-mode
          # clients expire refresh tokens after 7 days.
          google_sync_rclone_config = {
            restartUnits = [ "google-sync.service" ];
          };
        };

        systemd.services.google-sync = {
          description = "Google Drive → HDD pool mirror (rclone sync)";
          inherit (dnsGate) after wants;
          inherit onFailure;
          unitConfig.RequiresMountsFor = [ "/mnt/pool" ];
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          serviceConfig = lib.mkMerge [
            (harden {
              MemoryMax = "1G";
              ReadWritePaths = [
                destination
                graceDir
              ];
            })
            (serviceOneshotDefaults { })
            ioTier.background
            {
              Type = "oneshot";
              StateDirectory = "google-sync";
              # First seed of a large library can run for hours.
              TimeoutStartSec = "4h";
              Environment = [ "RCLONE_CONFIG_PATH=${config.sops.secrets.google_sync_rclone_config.path}" ];
              ExecStartPre = [
                "${pkgs.coreutils}/bin/mkdir -p ${destination} ${graceDir}"
              ]
              ++ dnsGate.serviceConfig.ExecStartPre;
              ExecStart = lib.getExe syncScript;
            }
          ];
        };

        systemd.timers.google-sync = {
          description = "Google Drive mirror sync interval";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = cfg.interval;
            Persistent = true;
            RandomizedDelaySec = "90s";
          };
        };

        services.backup-coordination = {
          backups.google-sync = {
            directory = stateDir;
            filePattern = "last_success";
            maxAgeHours = 25;
          };
        };
      };
    };
}
