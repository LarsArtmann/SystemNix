# Google Drive → HDD pool mirror (rclone).
#
# Continuous one-way sync of Google Drive accounts to /mnt/pool/backups,
# semantically equivalent to Google Drive Desktop "Mirror" mode — local is an
# exact copy of the cloud, remote deletions propagate locally after a grace
# window. Unlike Drive Desktop, cloud-side deletions are NOT applied
# instantly: they land in per-mirror grace directories
# (google-drive-deleted/<remote>/) for retentionDays before expiring, so
# ransomware or a fat-fingered cloud delete never silently destroys the only
# local copy.
#
# Multi-account by design (user setup 2026-08-18): a ~1.9 TB private account
# (My Drive + shared-with-me) and a small Google Workspace work account
# (team drive). Each `mirrors` entry pairs one rclone remote (declared in the
# sops rclone.conf) with one destination; shared-with-me is a separate remote
# with `shared_with_me = true` (a forest of shared roots, not a tree — an
# unshare is just another deletion into grace), and a team drive is the work
# remote with `team_drive = <id>` set in its config section.
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

      # Grace tree MUST live outside the synced destinations — rclone sync
      # deletes local paths that are absent on the remote, and a nested
      # backup-dir would be deleted by its own sync run (rclone also refuses
      # it). Per-mirror subdirectories keep deletion collisions apart.
      graceDir = "/mnt/pool/backups/google-drive-deleted";
      stateDir = "/var/lib/google-sync";

      gracePath = mirror: "${graceDir}/${mirror.remote}";

      dnsGate = mkDnsGate {
        inherit pkgs;
        serviceName = "google-sync";
        hostname = "www.googleapis.com";
      };

      # Fail fast with an actionable message when the sops secret still holds
      # OAuth placeholders (the module ships disabled for exactly this reason)
      # or a configured remote is missing from the INI — otherwise rclone
      # buries the cause in auth errors and the unit just crash-loops
      # inscrutably.
      configCheck = pkgs.writeShellApplication {
        name = "google-sync-config-check";
        runtimeInputs = [
          pkgs.rclone
          pkgs.gnugrep
        ];
        text = ''
          set -euo pipefail
          cfg="''${RCLONE_CONFIG_PATH:?RCLONE_CONFIG_PATH not set}"
          if grep -q REPLACE_WITH "$cfg"; then
            echo "google-sync: $cfg still contains OAuth placeholders." >&2
            echo "Complete the go-live checklist (TODO_LIST.md P0): create the OAuth" >&2
            echo "client (publishing status 'In production'), rclone authorize EVERY" >&2
            echo "account, fill the sops token, then redeploy." >&2
            exit 1
          fi
          # Parse + completeness check: catches truncated/garbage INI and
          # missing remotes before rclone sync drowns the journal.
          # listremotes is offline (config parse only).
          remotes="$(rclone listremotes --config "$cfg")"
        ''
        + lib.concatMapStringsSep "\n" (mirror: ''
          echo "$remotes" | grep -qx "${mirror.remote}:" || {
            echo "google-sync: remote '${mirror.remote}:' missing from $cfg" >&2
            exit 1
          }
        '') cfg.mirrors;
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

          # Per-mirror flag rationale:
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
        ''
        + lib.concatMapStringsSep "\n\n" (mirror: ''
          echo "google-sync: syncing ${mirror.remote}: → ${mirror.destination}"
          rclone sync "${mirror.remote}:" "${mirror.destination}" \
            --config "''${RCLONE_CONFIG_PATH}" \
            --fast-list \
            --checksum \
            --drive-skip-checksum-gphotos \
            --drive-export-formats "${cfg.exportFormats}" \
            --backup-dir "${gracePath mirror}" \
            --suffix ".del_''${stamp}" \
            --transfers 8 \
            --checkers 32 \
            --retries 3 \
            --low-level-retries 10 \
            --stats-one-line \
            --log-level INFO
        '') cfg.mirrors
        + ''

          # Expire grace entries past the retention window, then drop empty
          # subdirectories. -mindepth 2 keeps the per-mirror grace dirs
          # themselves alive. rm (not trash) is deliberate: this is
          # rebuildable grace data on the pool, trashing it would write it
          # back to the NVMe.
          find "${graceDir}" -mindepth 2 -type f -mtime +${toString cfg.retentionDays} -delete
          find "${graceDir}" -depth -mindepth 2 -type d -empty -delete

          # Freshness sentinel for backup-coordination (Gatus alerts via the
          # global backup_all_healthy check when this goes stale).
          touch "${stateDir}/last_success"
          echo "google-sync: all mirrors converged at $stamp"
        '';
      };

      allPaths = lib.concatMap (mirror: [
        mirror.destination
        (gracePath mirror)
      ]) cfg.mirrors;
    in
    {
      options.services.google-sync = {
        enable = lib.mkEnableOption "Google Drive → HDD pool mirror via rclone";

        interval = lib.mkOption {
          type = lib.types.str;
          default = "*:0/5";
          description = "OnCalendar for the sync timer (default: every 5 minutes).";
        };

        mirrors = lib.mkOption {
          type = lib.types.listOf (
            lib.types.submodule {
              options = {
                remote = lib.mkOption {
                  type = lib.types.str;
                  description = "rclone remote name (section in the sops rclone.conf) without the trailing colon.";
                };
                destination = lib.mkOption {
                  type = lib.types.str;
                  description = "Local directory this remote mirrors into (must be under /mnt/pool).";
                };
              };
            }
          );
          default = [
            {
              remote = "gdrive";
              destination = "/mnt/pool/backups/google-drive";
            }
            {
              remote = "gdrive-shared";
              destination = "/mnt/pool/backups/google-drive-shared";
            }
            {
              remote = "gwork";
              destination = "/mnt/pool/backups/google-drive-work";
            }
          ];
          description = ''
            One mirror per rclone remote. Defaults model the known account
            layout: gdrive = private My Drive, gdrive-shared = private
            shared-with-me (remote needs shared_with_me = true in its config
            section), gwork = Google Workspace work account (set team_drive =
            <id> in its config section if the data lives on a shared drive).
          '';
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
        # Secret google_sync_rclone_config (full rclone.conf INI with ALL
        # mirror remotes) is declared centrally in sops.nix — mkSecrets
        # "google-sync.yaml", gated on svcEnabled "google-sync". Consumed via
        # RCLONE_CONFIG_PATH below. Read-only at runtime: rclone refreshes
        # access tokens in memory. The refresh token survives ONLY with each
        # OAuth client in "In production" publishing status — testing-mode
        # clients expire refresh tokens after 7 days.

        # The mirror dirs MUST exist before google-sync.service starts: systemd
        # sets up mount namespacing (ReadWritePaths) BEFORE any ExecStartPre,
        # and a ReadWritePaths entry pointing at a missing path aborts the unit
        # with status=226/NAMESPACE (live incident 2026-08-18 00:33, the
        # accidentally deployed force-enable build crash-looped 4x on this).
        # Same shape as atticd-storage-dir: mount-gated (detached DAS fails
        # loudly instead of contaminating the root fs) and deliberately NO
        # tmpfiles rule (tmpfiles can pre-date the pool mount). deploy.sh
        # restarts it after switches — oneshot+RemainAfterExit ignores
        # restartTriggers.
        systemd.services.google-sync-dirs = {
          description = "Create Google Drive mirror directories on the HDD pool";
          wantedBy = [ "multi-user.target" ];
          unitConfig.RequiresMountsFor = [ "/mnt/pool" ];
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = "root";
              RemainAfterExit = true;
            }
            (harden {
              MemoryMax = "128M";
              ReadWritePaths = [ "/mnt/pool/backups" ];
            })
            (serviceOneshotDefaults { })
          ];
          script = lib.concatMapStringsSep "\n" (mirror: ''
            mkdir -p ${mirror.destination} ${gracePath mirror}
            chmod 0755 ${mirror.destination} ${gracePath mirror}
          '') cfg.mirrors;
        };

        systemd.services.google-sync = {
          description = "Google Drive → HDD pool mirror (rclone sync)";
          after = [ "google-sync-dirs.service" ] ++ dnsGate.after;
          wants = [ "google-sync-dirs.service" ] ++ dnsGate.wants;
          inherit onFailure;
          unitConfig.RequiresMountsFor = [ "/mnt/pool" ];
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          serviceConfig = lib.mkMerge [
            (harden {
              # 2G: --fast-list holds large trees in memory (~1KB/object — a
              # 1.9 TB library can be 500k+ files) on top of the per-transfer
              # chunk buffers.
              MemoryMax = "2G";
              ReadWritePaths = allPaths;
            })
            (serviceOneshotDefaults { })
            ioTier.background
            {
              Type = "oneshot";
              StateDirectory = "google-sync";
              # First seed of a ~1.9 TB private Drive can run for many hours
              # to days; subsequent runs converge in minutes. Timer ticks
              # don't stack while a run is active.
              TimeoutStartSec = "48h";
              Environment = [ "RCLONE_CONFIG_PATH=${config.sops.secrets.google_sync_rclone_config.path}" ];
              ExecStartPre = [ (lib.getExe configCheck) ] ++ dnsGate.serviceConfig.ExecStartPre;
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
