# Runbook: docs/services/signoz.md (Ops) + docs/services/gatus.md
# SigNoz rule-evaluator deadman — an EXTERNAL heartbeat for the alert engine.
#
# WHY THIS EXISTS (2026-10-12 13:03:21→13:16:50): the SigNoz rule evaluator
# went SILENT for ~13.5 min while the signoz.service unit stayed "active" —
# no stop line, no fail line, no error lines, mechanism unknown (clickhouse-
# storm correlated). In that state EVERY SigNoz alert rule is blind, and the
# evaluator cannot alert on its own death (self-watch is impossible when the
# evaluator IS the dead thing): the unit-state-gauge rules read 1, and any
# metric-based rule silently stops being evaluated. The 2026-10-12 window
# had BOTH watchers dead at once (gatus OIDC-gate crash-looped on the same
# resolver outage) — that dual-blind residual is owned by the gatus
# fail-open decision row (docs/todo/monitoring.md).
#
# The only externally observable evidence of evaluator liveness is its
# journal output: the engine logs an "evaluating promql query" line per rule
# per evaluation, and the fastest rules run at 1m frequency — silence beyond
# a few minutes is death. This collector measures that silence and the
# gatus check (in gatus-config.nix, "SigNoz Evaluator Deadman") pages on it:
# gatus is an independent process with an independent Discord path, so the
# alert fires exactly when the evaluator cannot.
#
# Own .prom file, NOT system_health.prom: that textfile has a standing
# whole-file rejection history (label-escape class, 4 incidents) and this
# deadman must not share a failure domain with the metrics it watches.
#
# Fail-closed: journal query failure writes scrape_errors 1 AND alive 0 —
# an unmeasurable evaluator reads as dead, never as healthy. Detection
# latency: silence threshold 600s (eval lines flow at >=1/min; the incident
# was silent 13.5 min, so this fires mid-incident) + collector cadence 2min
# + gatus interval 2m => ~10-12 min worst case.
#
# Residual (accepted, house-wide class): if THIS timer dies outright, the
# .prom freezes at its last values and the presence pats stay green — the
# same accepted residual as signoz-coverage.prom; file-level parse rejection
# IS covered (absence fails the gatus presence pats + the Textfile Collector
# Health check).
{
  flake.nixosModules.signoz-evaluator-deadman =
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
        onFailure
        mkStateDir
        ;

      cfg = config.services.signoz-evaluator-deadman;

      textfileDir = "/var/lib/prometheus-node-exporter/textfile_collectors";

      # Eval lines flow at >=1/min (several 1m-frequency rules); 600s of
      # silence = the engine stopped evaluating (the 2026-10-12 incident was
      # 810s silent). Long enough to ride out a signoz restart, short enough
      # to fire mid-incident.
      silenceThresholdSeconds = 600;

      deadmanCollector = pkgs.writeShellApplication {
        name = "signoz-evaluator-deadman";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.systemd
        ];
        text = ''
          OUT="${textfileDir}/signoz-evaluator-deadman.prom"
          # Unique tmp per run (mktemp) + CAP_FOWNER on the unit: in this
          # sticky 1777 dir a fixed/pid tmp can collide with FOREIGN-owned
          # leftovers and rename-over-foreign needs CAP_FOWNER (the
          # 2026-09-02..06 mail-relay outage class).
          mkdir -p "${textfileDir}"
          TMP="$(mktemp "${textfileDir}/signoz-evaluator-deadman.prom.XXXXXX")"
          chmod 644 "$TMP"
          trap 'rm -f "$TMP"' EXIT

          # Journal-stall doctrine: --since bounds the walk AND timeout N is
          # the hard ceiling (the 2026-08-31 unbounded-grep class). journalctl
          # exit codes: 0 = entries shown, 1 = no matches, >=2 = real error.
          # No -b flag: persistent journal (hot tier), so the previous boot's
          # eval lines bridge the post-reboot window until signoz evaluates
          # again — only genuine silence past the threshold pages.
          JEXIT=0
          LAST_LINE="$(timeout 30 journalctl -u signoz.service --since '-15min' --grep 'evaluating promql query' --output short-unix 2>/dev/null | tail -n 1)" || JEXIT=$?

          ERRORS=0
          AGE=0
          # journalctl prints a human "-- No entries --" marker on STDOUT
          # for human-readable outputs even when nothing matched — it must
          # never reach the epoch parser (probed 2026-10-20).
          case "$LAST_LINE" in
            "" | "-- No entries --"*) LAST_LINE="" ;;
          esac
          if [ -z "$LAST_LINE" ]; then
            # Empty read: either no eval lines in the window (evaluator
            # silent — JEXIT 1, alive 0, NOT a scrape error) or the journal
            # query itself failed (JEXIT >= 2 — fail-visible both ways).
            if [ "$JEXIT" -ge 2 ]; then
              ERRORS=1
            fi
            AGE=99999
          else
            # short-unix: "<epoch>.<micros> host ident[pid]: message"
            LAST_EPOCH="$(printf '%s\n' "$LAST_LINE" | cut -d' ' -f1)"
            LAST_SEC="''${LAST_EPOCH%%.*}"
            NOW="$(date +%s)"
            AGE=$((NOW - LAST_SEC))
          fi

          ALIVE=0
          if [ "$ERRORS" -eq 0 ] && [ "$AGE" -lt ${toString silenceThresholdSeconds} ]; then
            ALIVE=1
          fi

          cat > "$TMP" <<EOF
          # HELP system_signoz_evaluator_alive 1 if the SigNoz rule evaluator logged a promql evaluation within ${toString silenceThresholdSeconds}s (evaluator ALIVE), 0 if silent longer or unmeasurable — a dead evaluator cannot fire its own alerts, so this external deadman feeds the gatus check that pages instead
          # TYPE system_signoz_evaluator_alive gauge
          system_signoz_evaluator_alive $ALIVE
          # HELP system_signoz_evaluator_log_age_seconds Seconds since the newest 'evaluating promql query' journal line in signoz.service (99999 when none found in the window or the query failed)
          # TYPE system_signoz_evaluator_log_age_seconds gauge
          system_signoz_evaluator_log_age_seconds $AGE
          # HELP system_signoz_evaluator_scrape_errors 1 if the journal query itself failed (alive is fail-visible 0 in that case, never a phantom green)
          # TYPE system_signoz_evaluator_scrape_errors gauge
          system_signoz_evaluator_scrape_errors $ERRORS
          EOF

          mv -f "$TMP" "$OUT"
          trap - EXIT
        '';
      };
    in
    {
      options.services.signoz-evaluator-deadman = {
        enable = lib.mkEnableOption "SigNoz rule-evaluator deadman (journal-recency heartbeat + gatus-owned paging leg)";
      };

      config = lib.mkIf cfg.enable {
        systemd = {
          tmpfiles.rules = [
            (mkStateDir textfileDir "1777" "nobody" "nogroup")
          ];

          services.signoz-evaluator-deadman = {
            description = "SigNoz evaluator deadman collector (journal-recency of promql evaluations)";
            inherit onFailure;
            after = [ "signoz.service" ];
            serviceConfig = lib.mkMerge [
              (harden {
                MemoryMax = "256M";
                # Sticky-dir rename over a foreign-owned prom (mail-relay class).
                CapabilityBoundingSet = "CAP_FOWNER";
              })
              (serviceOneshotDefaults { })
              {
                Type = "oneshot";
                ExecStart = lib.getExe deadmanCollector;
                ReadWritePaths = [ textfileDir ];
                TimeoutStartSec = "2min";
              }
            ];
          };

          timers.signoz-evaluator-deadman = {
            description = "Collect SigNoz evaluator deadman heartbeat every 2 minutes";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnBootSec = "2min";
              OnUnitActiveSec = "2min";
            };
          };
        };
      };
    };
}
