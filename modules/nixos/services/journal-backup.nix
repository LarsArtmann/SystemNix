# Runbook: docs/services/journal.md
# journal-backup — nightly GoBD backup of the accounting kernel's books.
#
# journal is CLI-first by design; its web dashboard is served by the
# sibling journal-serve.nix module (loopback 8484 + protected vHost,
# owner g-2 answer 2026-10-26 — runbook). This backup timer is the
# deployment-owned piece
# assigned to the NixOS side by the journal repo's own month-end runbook:
# "A systemd timer for the nightly run belongs to the deployment (NixOS
# module)". The run is `journal backup --out backups/journal-$(date +%F).db
# --verify` — VACUUM INTO (consistent against a live WAL writer) plus the
# doctor battery proven on the copy, so a backup that would not restore
# FAILS the unit (onFailure toast) instead of rotting silently. Append-only
# by construction (the command refuses overwrite); GoBD retention keeps
# every night — no prune ever.
#
# The books home (~/books: journal.yaml, journal.db, charts, entries/) is
# USER data, deliberately outside /var/lib (runbook: the CLI owns its
# working directory; nothing under /var/lib, no backup-coordination row).
# Consequences for this unit:
#   - runs as the primary user with a single ReadWritePaths hole for the
#     books dir (ProtectHome=read-only everywhere else)
#   - WorkingDirectory = books dir: config's `database: journal.db` is
#     CWD-relative (config.AbsoluteDatabase → filepath.Abs)
#   - a missing books dir is a clean condition-skip, never a failure —
#     the unit is inert on hosts without books (fresh installs, VMs)
#   - same-day re-runs no-op on the existing dated file (idempotency
#     discipline: re-runs are provable no-ops, like every journal command)
#
# Nightly 03:30 + 10m jitter — an idle-IO background citizen between cv
# (03:17) and crm (03:40); a few hundred KB VACUUM today, sized for the
# books growing with real months. Persistent: downtime catches up.
{ inputs, ... }: {
  flake.nixosModules.journal-backup =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.journal-backup;
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceOneshotDefaults
        onFailure
        ;
      primaryUser = config.users.primaryUser;
    in
    {
      options.services.journal-backup = {
        enable = lib.mkEnableOption "nightly GoBD backup of the journal accounting kernel's books (VACUUM INTO snapshot, doctor-verified, append-only)";

        booksDir = lib.mkOption {
          type = lib.types.str;
          default = "/home/${primaryUser}/books";
          description = ''
            The journal books home (journal.yaml + journal.db + charts).
            Owned by the primary user and managed with the journal CLI;
            this unit only ever reads the books and writes backups/ inside.
          '';
        };

        calendar = lib.mkOption {
          type = lib.types.str;
          default = "*-*-* 03:30:00";
          description = "Backup calendar (local time). Default: nightly 03:30, between the cv (03:17) and crm (03:40) jobs.";
        };

        package = lib.mkOption {
          type = lib.types.package;
          # Same store path as the PATH binary (lib/lars-packages.nix
          # journal = flakePkgShim inputs.journal) — single source of truth.
          # vendorHash shim 2026-10-29 float: journal@50b4941 spec R6w7rVD9…,
          # got OzU6YCvB… (first-hand,
          # ~/.cache/lockfloat/float-proof-20261029-180630.log); mirrors the
          # flakePkgShim in lars-packages.nix — edit ALL THREE sites.
          default = inputs.journal.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs {
            vendorHash = "sha256-OzU6YCvBTkDl9Jfj5fCOAczSzYMPbv397a7BuDF2rdA=";
          };
          defaultText = lib.literalExpression "inputs.journal.packages.\${pkgs.stdenv.hostPlatform.system}.default";
          description = "journal package to run the backup with.";
        };
      };

      config = lib.mkIf cfg.enable {
        systemd.services.journal-backup = {
          description = "Nightly GoBD backup of the journal books (VACUUM INTO + doctor verify)";
          inherit onFailure;

          # Clean skip on hosts without books — never a failed unit.
          unitConfig.ConditionPathExists = [ "${cfg.booksDir}/journal.yaml" ];

          serviceConfig = lib.mkMerge [
            (harden {
              MemoryMax = "1G";
              # Books live under /home: read-only home, one RW hole for
              # the books dir (VACUUM INTO writes backups/ + WAL siblings
              # while the kernel opens the source DB).
              ProtectHome = "read-only";
              ReadWritePaths = [ cfg.booksDir ];
            })
            (serviceOneshotDefaults { })
            {
              Type = "oneshot";
              User = primaryUser;
              Group = "users";
              WorkingDirectory = cfg.booksDir;
              Environment = [ "HOME=/home/${primaryUser}" ];
              Nice = 10;
              IOSchedulingClass = "idle";
              TimeoutStartSec = "10min";
            }
          ];

          script = ''
            set -eu
            OUT="backups/journal-$(date +%F).db"
            if [ -f "$OUT" ]; then
              echo "journal-backup: $OUT already exists — append-only, idempotent no-op"
              exit 0
            fi
            # --verify runs the doctor battery on the snapshot and fails
            # loudly if the copy would not restore (GoBD cadence, runbook).
            exec ${lib.getExe' cfg.package "journal"} --config journal.yaml backup --out "$OUT" --verify
          '';
        };

        systemd.timers.journal-backup = {
          description = "Nightly journal books backup (GoBD cadence)";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = cfg.calendar;
            RandomizedDelaySec = "10min";
            Persistent = true;
          };
        };
      };
    };
}
