# Runbook: docs/services/pbx-backup-pull.md
# pbx-backup-pull — pull-side leg of the pbx.artmann.tech backup doctrine.
#
# Source of truth for the pull SCRIPT is the pbx-artmann repo
# (backups/evo-x2/pbx-backup-pull.sh — the text below is that script
# verbatim; its /etc-install README path is the zero-dependency fallback
# for hosts without this module). This file layers ONLY SystemNix
# concerns: systemd hardening, pool mount gating, the primary user's ssh
# identity, tmpfiles dest provisioning, IO tiering, and
# backup-coordination freshness (Gatus Discord alert when stale).
#
# Design notes (the why):
# - PULL direction by doctrine: the PBX holds zero credentials for this
#   machine. Each run rsyncs into a NEW timestamped dir — nothing is
#   mutated in place, a failed run leaves no partial state.
# - The unit is a SYSTEM unit running as the primary user: the PBX's only
#   authorized root key is lars@evo-x2, so the ssh leg must use that
#   identity — no new credentials, no sops, no second key on the PBX.
# - The dest dir is provisioned ONCE via tmpfiles (root-owned op, then
#   user-owned dir) — deliberately NOT a converger oneshot, so the
#   deploy-restart-audit class never applies.
# - ProtectHome = "read-only" (not the harden{} default true): ssh must
#   read ~/.ssh/{id_*,known_hosts}. BatchMode: an unknown host or missing
#   key FAILS the unit visibly instead of prompting (correct — the host
#   key is long-known to the primary user).
# - Persistent=true: the first pull after enable fires immediately on
#   the next deploy/boot (the timer has never run before).
_: {
  flake.nixosModules.pbx-backup-pull =
    {
      config,
      options,
      pkgs,
      lib,
      ...
    }:
    let
      inherit (import ../../../lib/default.nix lib)
        harden
        ioTier
        serviceOneshotDefaults
        ;
      cfg = config.services.pbx-backup-pull;
      primaryUser = config.users.primaryUser or "lars";
      destDir = "/mnt/pool/backups/pbx";

      # VERBATIM from pbx-artmann/backups/evo-x2/pbx-backup-pull.sh — do
      # not diverge without updating that repo (and its Go test
      # internal/backuppull, which pins the script's --check contract).
      pullScript = pkgs.writeShellApplication {
        name = "pbx-backup-pull";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.findutils
          pkgs.gawk
          pkgs.openssh
          pkgs.rsync
          pkgs.util-linux
        ];
        text = ''
          #!/usr/bin/env bash
          # pbx-backup-pull.sh — run ON evo-x2 (systemd unit or manually).
          # Pulls the newest staged backup snapshots from pbx.artmann.tech into
          # timestamped local dirs. PULL direction by design: the PBX holds no
          # credentials for this machine; the authorized root key on the PBX already
          # is lars@evo-x2. Each run rsyncs into a NEW timestamped dir (no in-place
          # mutation of previous snapshots).
          set -euo pipefail

          HOST="''${PBX_BACKUP_HOST:-root@pbx.artmann.tech}"
          SRC="''${PBX_BACKUP_SRC:-/var/lib/backup-staging/}"
          DEST_ROOT="''${PBX_BACKUP_DEST:-/mnt/pool/backups/pbx}" # RAID1 pool mount on evo-x2 (SystemNix `/mnt/pool`)
          KEEP="''${PBX_BACKUP_KEEP:-56}"                         # newest 56 snapshots ≈ 2 weeks at 6h cadence

          # --check: pre-flight only, pulls nothing. Guards the failure classes this
          # kit has actually hit: dest resolving to the root fs (the /pool incident)
          # and an unreachable or empty remote staging.
          if [ "''${1:-}" = "--check" ]; then
          	probe="$DEST_ROOT"
          	while [ ! -e "$probe" ]; do probe="$(dirname "$probe")"; done
          	mount_point="$(findmnt -n -o TARGET -T "$probe")"
          	if [ "$mount_point" = "/" ]; then
          		echo "pbx-backup-pull: dest '$DEST_ROOT' would land on the root fs (is /mnt/pool mounted?)" >&2
          		exit 1
          	fi
          	if ! latest_remote="$(ssh -o BatchMode=yes "$HOST" "ls -1t '$SRC' | head -1" 2>&1)"; then
          		echo "pbx-backup-pull: ssh to $HOST failed: $latest_remote" >&2
          		exit 1
          	fi
          	if [ -z "$latest_remote" ]; then
          		echo "pbx-backup-pull: remote staging '$SRC' is empty (nothing staged yet)" >&2
          		exit 1
          	fi
          	echo "pbx-backup-pull: check ok: dest on '$mount_point', freshest remote snapshot: $latest_remote"
          	exit 0
          fi
          if [ $# -gt 0 ]; then
          	echo "usage: $0 [--check]" >&2
          	exit 64
          fi

          STAMP="$(date -u +%Y-%m-%dT%H%M%SZ)"
          DEST="$DEST_ROOT/$STAMP"
          mkdir -p "$DEST"

          rsync -aHAX --numeric-ids --timeout=300 "$HOST:$SRC" "$DEST"

          # record what we got, then verify the freshest snapshot is inside
          latest_remote="$(ssh "$HOST" "ls -1t '$SRC' | head -1")"
          if [ -z "$latest_remote" ]; then
          	echo "pbx-backup-pull: remote staging '$SRC' is empty — nothing staged yet" >&2
          	exit 1
          fi
          if [ ! -d "$DEST/$latest_remote" ]; then
          	echo "pbx-backup-pull: freshest remote snapshot '$latest_remote' not received" >&2
          	exit 1
          fi
          touch "$DEST_ROOT/.last-success"

          # retention: keep the newest $KEEP snapshot dirs (RAID1 pool holds them)
          find "$DEST_ROOT" -mindepth 1 -maxdepth 1 -type d -name '20*' -printf '%T@ %p\n' |
          	sort -rn | tail -n +"$((KEEP + 1))" | cut -d' ' -f2- | xargs -r rm -rf --

          echo "pbx-backup-pull: ok -> $DEST (freshest: $latest_remote)"
        '';
      };
    in
    {
      options.services.pbx-backup-pull = {
        enable = lib.mkEnableOption "pull-side PBX backup (rsync snapshots from pbx.artmann.tech onto the pool every 6h)";

        host = lib.mkOption {
          type = lib.types.str;
          default = "root@pbx.artmann.tech";
          description = "ssh pull source (the PBX).";
        };

        src = lib.mkOption {
          type = lib.types.str;
          default = "/var/lib/backup-staging/";
          description = "Remote staging dir on the PBX to pull.";
        };

        keep = lib.mkOption {
          type = lib.types.int;
          default = 56;
          description = "Newest snapshot dirs to keep (~2 weeks at the 6h cadence).";
        };

        onCalendar = lib.mkOption {
          type = lib.types.str;
          default = "*-*-* 00,06,12,18:15:00";
          description = "Timer schedule (15 past the hour to dodge the top-of-hour crowd; the PBX stages at 05:30).";
        };
      };

      config = lib.mkIf cfg.enable (
        lib.mkMerge [
          {
            # Dest provisioning (once, at boot + every deploy via the deploy.sh
            # tmpfiles pass). Root op, user-owned result — see header.
            systemd.tmpfiles.rules = [ "d ${destDir} 0755 ${primaryUser} users - -" ];

            systemd.services.pbx-backup-pull = {
              description = "Pull PBX (pbx.artmann.tech) backup snapshots over rsync/ssh";
              wants = [ "network-online.target" ];
              after = [ "network-online.target" ];
              # Refuse to run unless the RAID1 pool is mounted: mkdir into an
              # unmounted /mnt/pool would silently land on the root fs (the
              # /pool incident class).
              unitConfig.RequiresMountsFor = "/mnt/pool";
              startLimitBurst = 5;
              startLimitIntervalSec = 300;
              serviceConfig = lib.mkMerge [
                (harden {
                  ProtectHome = "read-only";
                  ReadWritePaths = [ "/mnt/pool" ];
                })
                ioTier.background
                (serviceOneshotDefaults { })
                {
                  User = primaryUser;
                  # First pull after a long gap can carry many staged snapshots
                  # + recordings — well past the 3min global default.
                  TimeoutStartSec = "20min";
                  Environment = [
                    "PBX_BACKUP_HOST=${cfg.host}"
                    "PBX_BACKUP_SRC=${cfg.src}"
                    "PBX_BACKUP_DEST=${destDir}"
                    "PBX_BACKUP_KEEP=${toString cfg.keep}"
                  ];
                  ExecStart = lib.getExe pullScript;
                }
              ];
            };

            systemd.timers.pbx-backup-pull = {
              description = "Pull PBX backup snapshots every 6 hours";
              wantedBy = [ "timers.target" ];
              timerConfig = {
                OnCalendar = cfg.onCalendar;
                Persistent = true;
                RandomizedDelaySec = "5m";
              };
            };
          }
          (lib.optionalAttrs (options ? services.integration) {
            services.integration.pbx-backup-pull = {
              subdomain = null;
              port = null;
              vHost.layer = "none";
              checks = [ ];
              backup = {
                directory = destDir;
                filePattern = "*";
                # 6h cadence: 25h = a full missed day (four skipped windows)
                # before Gatus pages — matches the fleet-wide freshness norm.
                maxAgeHours = 25;
              };
            };
          })
        ]
      );

      # Platform-truth catalog entry (ADR-008): unconditional — the pull leg
      # exists platform-wide even where this host has it disabled. The catalog
      # OPTION comes from nixosModules.catalog, which every host (and VM test)
      # importing this module must also import — a missing import fails LOUDLY
      # at eval, which is the point (no silent absence).
      imports = [
        {
          services.catalog.pbx-backup-pull = {
            subdomain = null;
            port = null;
            description = "Pull-side PBX backup (rsync snapshots from pbx.artmann.tech onto the pool)";
          };
        }
      ];
    };
}
