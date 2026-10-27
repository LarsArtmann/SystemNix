# Runbook: docs/services/signoz.md
# SigNoz migrator-gap guard — the "1010 squash-gap" detector.
#
# WHY (docs/agents/monitoring.md "SigNoz schema drift"): the collector's
# ClickHouse schema migrator once shipped a state where traces migration 1010
# was NEVER applied (no row at all) while 1011-1014 ran after it — `migrate
# sync up` treats everything below the high-water mark as done, so the gap
# is never healed, exporter writes rot silently, and the only symptom was a
# swallowed ClickHouse error every few minutes. This guard keeps that class
# impossible to miss:
#
#   1. BUILD-TIME: the KNOWN migration list per DB is extracted from the
#      PINNED signoz-otel-collector source (inputs.signoz-collector-src) by
#      two awk passes over cmd/signozschemamigrator/schema_migrator:
#        pass 1 extracts each Go operation type's sync/async flag table
#        (IsMutation/IsIdempotent/IsLightweight/ForceMigrate — the exact
#        IsAsyncOperation semantics from manager.go; unknown/complex bodies
#        classify conservatively as async so a mis-read can never false-alarm);
#        pass 2 maps every MigrationID to db + group + class, where
#        group "incremental" = the per-startup sync series (the 1010 class
#        lives here) and "squashed" = install-time/legacy-bridge series
#        (legitimately absent on hosts migrated through the legacy table, so
#        gap detection covers ONLY the incremental group).
#   2. RUNTIME (this collector, 5 min): reads <db>.schema_migrations_v2
#      FINAL for all six DBs (manager.go `Databases`) and emits
#        signoz_migrator_missing_applied{database,migration}  known
#        incremental-sync migration with no finished row (THE 1010 signal)
#        signoz_migrator_unknown_applied{database,migration}  applied row
#        unknown to the pinned source (state drift / downgrade / tampering —
#        the item's "applied ⊆ known" assertion)
#        signoz_migrator_failed_applied{database,migration}   row stuck in
#        status=failed (failed startup migration)
#      plus signoz_migrator_*_total aggregates and
#      signoz_migrator_guard_scrape_errors. Fail-closed: any ClickHouse
#      failure writes scrape_errors 1 and NO totals, so the Gatus anchored
#      pat() conditions fail visibly instead of phantom-green.
#   3. Gatus "SigNoz Migrator Guard" pages on any nonzero total (module
#      gatus-config.nix).
#
# Live validation at landing (2026-10-27, rev b8fed01): the extractor's
# sync/async classification was diffed clean against a hand-verified
# classifier over the same source, and the guard evaluates GREEN against the
# live migration state (the only applied-set holes are async-classified
# migrations, which only `migrate async up` would apply — by design absent).
{
  flake.nixosModules.signoz-migrator-guard =
    {
      config,
      lib,
      pkgs,
      inputs,
      ...
    }:
    let
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceOneshotDefaults
        onFailure
        mkStateDir
        ;

      cfg = config.services.signoz-migrator-guard;

      textfileDir = "/var/lib/prometheus-node-exporter/textfile_collectors";

      # The six DBs the migrator manages (manager.go `Databases`).
      databases = [
        "signoz_traces"
        "signoz_logs"
        "signoz_metrics"
        "signoz_metadata"
        "signoz_analytics"
        "signoz_meter"
      ];

      # ── pass 1: operation-type flag table from the pinned source ──
      extractFlagsAwk = pkgs.writeText "migrator-extract-flags.awk" ''
        # Output: type \t method \t value (1=true, 0=false, -1=complex).
        # Reads only bool method definitions; comment lines are stripped and
        # the last `return <expr>` decides. -1 (unknown/field-dependent)
        # classifies conservatively as async downstream.
        match($0, /func \([A-Za-z0-9_]+ ([A-Za-z0-9_]+)\) ([A-Za-z0-9_]+)\(\) bool \{/, m) {
          type = m[1]; meth = m[2]
          depth = 1
          body = substr($0, RSTART + RLENGTH)
          while (depth > 0) {
            tmp = body; oc = gsub(/{/, "", tmp)
            tmp = body; cc = gsub(/}/, "", tmp)
            if (depth + oc - cc <= 0) {
              k = length(body)
              while (k > 0 && substr(body, k, 1) != "}")
                k--
              body = substr(body, 1, k - 1)
              break
            }
            depth += oc - cc
            if ((getline line) <= 0)
              break
            body = body "\n" line
          }
          gsub(/\/\/[^\n]*/, "", body)
          n = split(body, bl, "\n")
          expr = ""
          for (i = 1; i <= n; i++) {
            if (bl[i] ~ /^[[:space:]]*return[[:space:]]/) {
              e = bl[i]
              sub(/^[[:space:]]*return[[:space:]]+/, "", e)
              sub(/[[:space:]]+$/, "", e)
              expr = e
            }
          }
          val = (expr == "true") ? 1 : (expr == "false") ? 0 : -1
          printf "%s\t%s\t%d\n", type, meth, val
        }
      '';

      # ── pass 2: migration rows (db, id, group, class) ──
      extractMigrationsAwk = pkgs.writeText "migrator-extract-migrations.awk" ''
        # stdin: flags.tsv FIRST (consumed via FNR==NR), then the migration
        # definition files. Unknown op types conservatively classify async.
        function is_async(op,    force, mut, idem, light) {
          force = FLAGS[op SUBSEP "ForceMigrate"]
          mut = FLAGS[op SUBSEP "IsMutation"]
          idem = FLAGS[op SUBSEP "IsIdempotent"]
          light = FLAGS[op SUBSEP "IsLightweight"]
          if (force == 1)
            return 0
          if (mut == 0 && idem == 1 && light == 1)
            return 0
          return 1
        }

        function flush_row() {
          if (cur_id == "")
            return
          class = (cur_ops_async > 0) ? "async" : "sync"
          printf "%s\t%d\t%s\t%s\n", cur_db, cur_id, cur_group, class
          cur_id = ""
          cur_ops_async = 0
        }

        FNR == NR {
          split($0, f, /\t/)
          FLAGS[f[1] SUBSEP f[2]] = f[3] + 0
          if (f[2] == "IsMutation")
            OPS[f[1]] = 1
          next
        }

        FILENAME != cur_file {
          flush_row()
          cur_file = FILENAME
          base = FILENAME
          sub(/.*\//, "", base)
          cur_db = ""
          cur_group = ""
          if (base ~ /^(traces|logs|metrics|metadata|analytics|meter)_migrations\.go$/) {
            cur_group = "incremental"
            db = base
            sub(/_migrations\.go$/, "", db)
            cur_db = "signoz_" db
          } else if (base ~ /^squashed_(traces|logs|metrics)_migrations\.go$/) {
            cur_group = "squashed"
            db = base
            sub(/^squashed_/, "", db)
            sub(/_migrations\.go$/, "", db)
            cur_db = "signoz_" db
          } else if (base ~ /^v2_squashed_(logs|metrics|traces)_migrations?\.go$/) {
            cur_group = "squashed"
            db = base
            sub(/^v2_squashed_/, "", db)
            sub(/_migrations?\.go$/, "", db)
            cur_db = "signoz_" db
          }
          if (cur_db == "" && base !~ /_test\.go$/ && base !~ /tables\.go$/)
            printf "migrator-extract: unmapped migration file skipped: %s\n", base > "/dev/stderr"
        }

        cur_db == "" { next }

        match($0, /MigrationID:[[:space:]]*([0-9]+),/, m) {
          flush_row()
          cur_id = m[1] + 0
          in_down = 0
          next
        }

        cur_id == "" { next }

        /DownItems:/ { in_down = 1 }

        in_down == 0 {
          s = $0
          while (match(s, /[A-Z][A-Za-z0-9_]*\{/, t)) {
            op = substr(t[0], 1, length(t[0]) - 1)
            if (op != "Operation" && (op in OPS) && is_async(op))
              cur_ops_async++
            s = substr(s, RSTART + RLENGTH - 1)
          }
        }

        END { flush_row() }
      '';

      # Known migration list, rebuilt automatically whenever the flake lock
      # moves the collector source.
      knownMigrations = pkgs.runCommand "signoz-migrator-known-migrations" { } ''
        SRC="${inputs.signoz-collector-src}/cmd/signozschemamigrator/schema_migrator"
        mkdir -p $out
        go_files=$(find "$SRC" -maxdepth 1 -name '*.go' ! -name '*_test.go')
        mig_files=$(printf '%s\n' "$go_files" | grep -E '/((traces|logs|metrics|metadata|analytics|meter)_migrations|squashed_(traces|logs|metrics)_migrations|v2_squashed_(logs|metrics|traces)_migrations?)\.go$' || true)
        # Fail the build on an empty known list (source-layout drift) — a
        # silently-empty list would emit false unknown_applied for every
        # real migration on the first run.
        test -n "$mig_files"
        printf '%s\n' "$go_files" | xargs ${pkgs.gawk}/bin/awk -f ${extractFlagsAwk} > flags.tsv
        printf '%s\n' "$mig_files" | xargs ${pkgs.gawk}/bin/awk -f ${extractMigrationsAwk} flags.tsv | sort -u > $out/known.tsv
        test -s $out/known.tsv
      '';

      guardCollector = pkgs.writeShellApplication {
        name = "signoz-migrator-guard-metrics";
        runtimeInputs = [
          pkgs.clickhouse
          pkgs.gawk
          pkgs.coreutils
        ];
        text = ''
          OUT="${textfileDir}/signoz-migrator-guard.prom"
          mkdir -p "${textfileDir}"
          TMP="$(mktemp "${textfileDir}/signoz-migrator-guard.prom.XXXXXX")"
          chmod 644 "$TMP"
          trap 'rm -f "$TMP" "$TMP.applied"' EXIT

          ch_query() {
            timeout 45 clickhouse-client --format TSVRaw --query "$1"
          }

          # ClickHouse "active" only means the listener exists; retry boot
          # races instead of paging (same pattern as signoz-coverage).
          ready=false
          for _attempt in 1 2 3; do
            if ch_query "SELECT 1" >/dev/null 2>&1; then
              ready=true
              break
            fi
            sleep 20
          done

          ERRORS=0
          APPLIED_FILE="$TMP.applied"
          : > "$APPLIED_FILE"
          if [ "$ready" != true ]; then
            echo "signoz-migrator-guard: clickhouse not ready after 3 attempts" >&2
            ERRORS=1
          else
            for db in ${lib.concatStringsSep " " databases}; do
              ROWS=$(ch_query "SELECT '$db', migration_id, status FROM $db.schema_migrations_v2 FINAL") || ERRORS=1
              if [ "$ERRORS" = 1 ]; then
                echo "signoz-migrator-guard: query failed for $db.schema_migrations_v2" >&2
                break
              fi
              printf '%s\n' "$ROWS" >> "$APPLIED_FILE"
            done
          fi

          {
            echo "# HELP signoz_migrator_guard_scrape_errors 1 if the migration-state queries failed, healthy value is zero"
            echo "# TYPE signoz_migrator_guard_scrape_errors gauge"
            if [ "$ERRORS" = 1 ]; then
              # Fail-closed: no totals, so the Gatus pat() presence legs fail
              # visibly. (No early exit — the redirect must reach the mv.)
              echo "signoz_migrator_guard_scrape_errors 1"
            else
              echo "signoz_migrator_guard_scrape_errors 0"
              echo "# HELP signoz_migrator_known_sync_total incremental-series sync migrations known to the pinned collector source"
              echo "# TYPE signoz_migrator_known_sync_total gauge"
              awk -F '\t' '$3 == "incremental" && $4 == "sync" { c[$1]++ } END { for (d in c) printf "signoz_migrator_known_sync_total{database=\"%s\"} %d\n", d, c[d] }' "${knownMigrations}/known.tsv" | sort
              echo "# HELP signoz_migrator_missing_applied 1 for every known incremental-sync migration without a finished row (the 1010 squash-gap class)"
              echo "# TYPE signoz_migrator_missing_applied gauge"
              echo "# HELP signoz_migrator_unknown_applied 1 for every applied migration row unknown to the pinned collector source"
              echo "# TYPE signoz_migrator_unknown_applied gauge"
              echo "# HELP signoz_migrator_failed_applied 1 for every migration row stuck in status=failed"
              echo "# TYPE signoz_migrator_failed_applied gauge"
              awk -F '\t' '
                FNR == NR {
                  if ($3 == "incremental" && $4 == "sync")
                    needsync[$1 SUBSEP $2] = 1
                  known[$1 SUBSEP $2] = 1
                  next
                }
                NF >= 3 {
                  if (!($1 SUBSEP $2 in known))
                    printf "signoz_migrator_unknown_applied{database=\"%s\",migration=\"%s\"} 1\n", $1, $2
                  if ($3 == "failed")
                    printf "signoz_migrator_failed_applied{database=\"%s\",migration=\"%s\"} 1\n", $1, $2
                }
                END {
                  for (k in needsync)
                    if (status[k] != "finished")
                      printf "signoz_migrator_missing_applied{database=\"%s\",migration=\"%s\"} 1\n", substr(k, 1, index(k, SUBSEP) - 1), substr(k, index(k, SUBSEP) + 1)
                }
              ' "${knownMigrations}/known.tsv" "$APPLIED_FILE" | sort
              echo "# HELP signoz_migrator_missing_applied_total known incremental-sync migrations without a finished row, healthy value is zero"
              echo "# TYPE signoz_migrator_missing_applied_total gauge"
              echo "signoz_migrator_missing_applied_total $(awk -F '\t' '
                FNR == NR {
                  if ($3 == "incremental" && $4 == "sync")
                    needsync[$1 SUBSEP $2] = 1
                  next
                }
                NF >= 3 { status[$1 SUBSEP $2] = $3 }
                END {
                  n = 0
                  for (k in needsync)
                    if (status[k] != "finished")
                      n++
                  print n
                }
              ' "${knownMigrations}/known.tsv" "$APPLIED_FILE")"
              echo "# HELP signoz_migrator_unknown_applied_total applied migration rows unknown to the pinned source, healthy value is zero"
              echo "# TYPE signoz_migrator_unknown_applied_total gauge"
              echo "signoz_migrator_unknown_applied_total $(awk -F '\t' '
                FNR == NR { known[$1 SUBSEP $2] = 1; next }
                NF >= 3 && !($1 SUBSEP $2 in known) { n++ }
                END { print n + 0 }
              ' "${knownMigrations}/known.tsv" "$APPLIED_FILE")"
              echo "# HELP signoz_migrator_failed_applied_total migration rows stuck in status=failed, healthy value is zero"
              echo "# TYPE signoz_migrator_failed_applied_total gauge"
              echo "signoz_migrator_failed_applied_total $(awk -F '\t' '
                NF >= 3 && $3 == "failed" { n++ }
                END { print n + 0 }
              ' "$APPLIED_FILE")"
            fi
          } > "$TMP"

          mv "$TMP" "$OUT"
        '';
      };
    in
    {
      options.services.signoz-migrator-guard = {
        enable = lib.mkEnableOption "SigNoz migrator-gap guard (known-migration extraction + applied-state audit collector)";
      };

      config = lib.mkIf cfg.enable {
        systemd = {
          tmpfiles.rules = [
            (mkStateDir textfileDir "1777" "nobody" "nogroup")
          ];

          services.signoz-migrator-guard-metrics = {
            description = "SigNoz migrator-gap guard collector (applied migration state vs pinned known list)";
            inherit onFailure;
            after = [ "clickhouse.service" ];
            serviceConfig = lib.mkMerge [
              (harden {
                MemoryMax = "256M";
                # Sticky-dir rename over a foreign-owned prom (mail-relay class).
                CapabilityBoundingSet = "CAP_FOWNER";
              })
              (serviceOneshotDefaults { })
              {
                Type = "oneshot";
                ExecStart = lib.getExe guardCollector;
                ReadWritePaths = [ textfileDir ];
                TimeoutStartSec = "3min";
              }
            ];
          };

          timers.signoz-migrator-guard-metrics = {
            description = "Audit SigNoz migration state every 5 minutes";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnBootSec = "2min";
              OnUnitActiveSec = "5min";
            };
          };
        };
      };
    };
}
