# Runbook: docs/services/journal.md
# journal-import — FULL auto-sync: bank-sync's synced bank facts flow into
# the journal kernel on a timer (export → import → reconcile), no hands.
#
# The two kernels are event-sourced by design and deliberately decoupled:
# journal is provider-blind and consumes the schema-stamped transactions.v1
# mesh contract (bank-sync export), and booking stays batch-by-nature —
# reconcile tier 1/2 auto-books clear matches, tier 3 parks proposals, and
# confirm/reject/waive remain human decisions on the Exceptions queue. This
# module automates the PIPELINE, not the judgment: every 15 min (bank-sync's
# own sync pulse) a bank-sync-user export refreshes staging files, and on
# success (OnSuccess chain) a primary-user import feeds every MAPPED balance
# into the kernel and runs reconcile. Idempotency is the kernel's contract
# (fact dedup + "re-running a step never double-books"), so timer re-fires
# are provable no-ops — the same discipline the month-end runbook relies on.
#
# Authority & anti-split-brain:
#   - journal.yaml source_mappings remains the SINGLE source of truth for
#     which balances are in bookkeeping scope. The import side derives the
#     mapped-ID list from `journal status` (the kernel's own rendering of
#     journal.yaml) and skips staging files for unmapped balances (Helpless
#     AI, personal, Astride — facts from those reject loudly upstream, so
#     filtering here is noise control, not scope change). If the coverage
#     table parses EMPTY, the unit FAILS LOUD (status format drift) and
#     deletes nothing — silent-skip is the one failure mode this design
#     refuses.
#   - the export side needs no balance list: it exports every Wise balance
#     the daemon knows (bounded, tiny files, atomically renamed) and lets
#     the import side filter. No Nix-side duplicate of journal.yaml.
#   - staging lives INSIDE bank-sync's dataDir (DAC-private to the bank-sync
#     user by the money-data posture): the export unit runs as the bank-sync
#     user (reads its own DB, writes its own dir), the import unit as the
#     primary user (read-only on staging via 0644 files, RW only on books).
#     Exports go to tmp + rename so the import never reads a half-written
#     file.
#
# Sibling patterns: journal-backup.nix (books-home contract, condition-skip,
# oneshot discipline) and journal-serve.nix (protected surface). The vendor-
# hash shim is deliberately NOT copied here — the journal package is consumed
# from journal-serve's option (and the bank-sync binary from bank-sync's), so
# the "edit ALL THREE" shim surfaces stay three.
{ inputs, ... }: {
  flake.nixosModules.journal-import =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.journal-import;
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceOneshotDefaults
        onFailure
        ;
      primaryUser = config.users.primaryUser;
    in
    {
      options.services.journal-import = {
        enable = lib.mkEnableOption "periodic bank-sync → journal auto-sync (mesh-contract export, kernel import, reconcile)";

        booksDir = lib.mkOption {
          type = lib.types.str;
          default = "/home/${primaryUser}/books";
          description = ''
            The journal books home (journal.yaml + journal.db + charts),
            shared with journal-backup and journal-serve. This unit's import
            + reconcile mutate it (bounded by the kernel's own reconcile
            gates); staging under the bank-sync dataDir is read-only input.
          '';
        };

        stagingDir = lib.mkOption {
          type = lib.types.str;
          default = "${config.services.bank-sync.dataDir}/journal-exports";
          description = ''
            Where per-balance transactions.v1 files land between export and
            import. Lives inside the bank-sync dataDir so the DAC-private
            money-data posture is preserved (bank-sync user writes, primary
            user reads). Files are overwritten per cycle, so staging is
            bounded by the daemon's balance count.
          '';
        };

        calendar = lib.mkOption {
          type = lib.types.str;
          default = "*:0/15";
          description = ''
            Sync cadence. Default: every 15 minutes at :00/:15/:30/:45 —
            matched to bank-sync's own 15-minute sync pulse, so each run
            carries at most one cycle of latency. (True push-based real-time
            is an upstream v2: bank-sync emitting kernel-consumable events.)
          '';
        };

        package = lib.mkOption {
          type = lib.types.package;
          # Single source of truth for the vendorHash shim: consumed from
          # journal-serve's option (same store path as its unit and the PATH
          # binary). Do NOT add a fourth overrideAttrs copy here — the
          # "edit ALL THREE" comment in journal-serve.nix / journal-backup.nix
          # / lib/lars-packages.nix exists because copies drifted.
          default = config.services.journal-serve.package;
          defaultText = lib.literalExpression "config.services.journal-serve.package";
          description = "journal package to run the import + reconcile with.";
        };
      };

      config = lib.mkIf cfg.enable {
        # Pool-bound oneshots: the remount self-heal restarts always-on
        # daemons; a timer-driven oneshot converges itself on its next tick,
        # so it rides restartUnitsExempt (pool-recovery asserts every unit
        # with RequiresMountsFor under the pool is in ONE of the two lists).
        services.pool-recovery.restartUnitsExempt = [
          "journal-sync-export"
          "journal-import"
        ];

        systemd.services.journal-sync-export = {
          description = "journal mesh export: refresh per-balance transactions.v1 staging files from the bank-sync DB";
          inherit onFailure;
          after = [
            "network.target"
            "bank-sync.service"
          ];

          # Pool detached (or DB absent) → clean condition-skip, never a
          # failed unit: the shadow path under /mnt/pool carries no data.db.
          unitConfig.ConditionPathExists = [ "${config.services.bank-sync.dataDir}/data.db" ];
          # Mount-gating audit: ReadWritePaths under /mnt/ gates loudly on a
          # detached pool instead of writing the root-fs shadow.
          unitConfig.RequiresMountsFor = [ cfg.stagingDir ];
          # Chain: import runs only when export actually ran + succeeded
          # (condition-skips and failures both suppress it).
          unitConfig.OnSuccess = [ "journal-import.service" ];

          serviceConfig = lib.mkMerge [
            (harden {
              MemoryMax = "1G";
              # Only the staging dir is writable; the DB is read via
              # mode=ro through its DAC-private directory (bank-sync user).
              ReadWritePaths = [ cfg.stagingDir ];
            })
            (serviceOneshotDefaults { })
            {
              Type = "oneshot";
              User = "bank-sync";
              Group = "bank-sync";
              # No WorkingDirectory: staging may not exist on the very first
              # run and systemd resolves it before the script's mkdir -p —
              # the script uses absolute paths only.
              Environment = [ "HOME=/var/lib/bank-sync" ];
              Nice = 10;
              IOSchedulingClass = "idle";
              TimeoutStartSec = "10min";
            }
          ];

          script =
            let
              sqlite3 = lib.getExe' pkgs.sqlite "sqlite3";
              bankSync = lib.getExe config.services.bank-sync.package;
            in
            ''
              set -eu
              DB="${config.services.bank-sync.dataDir}/data.db"
              STAGING="${cfg.stagingDir}"
              mkdir -p "$STAGING"
              count=0
              for b in $(${sqlite3} "file:$DB?mode=ro" "SELECT id FROM balances WHERE provider='wise';"); do
                # tmp + rename: the import side never sees a half-written file
                ${bankSync} export --schema v1 --format json --provider wise \
                  --balance "$b" --database-path "$DB" \
                  --output "$STAGING/.tmp-tx-$b.json" >/dev/null
                mv "$STAGING/.tmp-tx-$b.json" "$STAGING/tx-$b.json"
                count=$((count + 1))
              done
              echo "journal-sync-export: refreshed $count staging file(s) for the journal mesh"
            '';
        };

        systemd.services.journal-import = {
          description = "journal mesh import: feed mapped bank facts into the kernel and reconcile";
          inherit onFailure;

          unitConfig.ConditionPathExists = [
            "${cfg.booksDir}/journal.yaml"
            cfg.stagingDir
          ];
          unitConfig.RequiresMountsFor = [ cfg.stagingDir ];

          serviceConfig = lib.mkMerge [
            (harden {
              MemoryMax = "1G";
              # Books under /home: read-only home, one RW hole for the books
              # dir (import + reconcile write the kernel DB + WAL siblings).
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
              TimeoutStartSec = "15min";
            }
          ];

          script = ''
            set -eu
            shopt -s nullglob
            STAGING="${cfg.stagingDir}"
            JOURNAL=${lib.getExe' cfg.package "journal"}
            cd ${cfg.booksDir}

            # Mapped balance IDs from the KERNEL's own coverage table —
            # journal.yaml stays the single authority; this script never
            # re-derives scope. A verdict-agnostic parse (any `balance <id>`
            # row), so a balance does not fall out of scope when its verdict
            # upgrades from blind to covered.
            # journal status prints EVERYTHING to stderr (verified 2026-11-10:
            # stdout 0 bytes, stderr 720) — capture 2>&1 or the parse sees an
            # empty stream and the fail-loud guard fires every tick.
            MAPPED=$("$JOURNAL" --config journal.yaml status 2>&1 | sed -n 's/^[[:space:]]*balance \([0-9][0-9]*\) .*/\1/p' | sort -u | tr '\n' ' ')
            if [ -z "$MAPPED" ]; then
              echo "journal-import: coverage table parsed EMPTY — status format drift? refusing to filter staged facts (fail loud, nothing deleted)"
              exit 1
            fi

            imported=0
            kept=0
            skipped=""
            for f in "$STAGING"/tx-*.json; do
              b=''${f##*/}
              b=''${b#tx-}
              b=''${b%.json}
              case " $MAPPED " in
                *" $b "*) ;;
                *)
                  skipped="$skipped $b"
                  continue
                  ;;
              esac
              # Idempotent by kernel contract: a re-import of the same facts
              # dedups. Keep the file on failure so the next tick retries.
              if "$JOURNAL" --config journal.yaml import bank-sync --file "$f" >/dev/null; then
                rm -f "$f"
                imported=$((imported + 1))
              else
                kept=$((kept + 1))
                echo "journal-import: kept tx-$b.json for retry (import failed)"
              fi
            done

            # Tier 1/2 auto-book clear matches; tier 3 parks proposals and
            # exceptions for the human Exceptions queue — automation runs
            # the pipeline, never the judgment.
            "$JOURNAL" --config journal.yaml reconcile >/dev/null
            echo "journal-import: imported $imported file(s), kept $kept failed, unmapped skipped:[$skipped ]"
            "$JOURNAL" --config journal.yaml status 2>&1 | sed -n '1,11p'
          '';
        };

        systemd.timers.journal-import = {
          description = "Periodic bank-sync → journal mesh auto-sync (export, then import + reconcile)";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = cfg.calendar;
            RandomizedDelaySec = "2min";
            Persistent = true;
            # The timer fires the EXPORT; its OnSuccess chains the import.
            Unit = "journal-sync-export.service";
          };
        };
      };
    };
}
