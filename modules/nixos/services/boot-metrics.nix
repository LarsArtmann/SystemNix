# Boot-duration metrics — textfile collector for per-boot phase timings.
#
# Why: the 2026-10-12 boot dispatch measured a 14min19s boot (62.7s firmware
# + 12m57s userspace) and its four fixes shipped with NO regression signal —
# the verdict waited on a human running `systemd-analyze` after a reboot
# window (monitoring.md "Boot-duration textfile collector" row). With 15
# crash-class boots in the 12 days before (zero clean reboots since Oct 1),
# every reboot is a free verification boot IF the numbers are captured
# automatically. This collector emits:
#
#   boot_phase_duration_seconds{phase=firmware|loader|kernel|initrd|userspace}
#   boot_total_duration_seconds
#   boot_uptime_seconds            (age context: how old this sample is)
#   boot_reset_reason_watchdog 1|0 (kernel-logged "hardware watchdog timer
#                                   expired" — the freeze-class reset marker;
#                                   full reason text goes to the unit journal)
#   boot_userspace_regression 1|0  (userspace > threshold — pages via Gatus)
#   boot_metrics_scrape_errors 1|0 (fail-closed; never a phantom green)
#   transaction_open 1|0         (boot startup transaction still open —
#                                  systemd-analyze refuses; the netbird
#                                  infinite-boot class, 2026-10-17)
#   transaction_open_seconds_past_graphical (age of the open transaction;
#                                  0 when closed — makes the class MEASURED)
#
# Storm-boot tolerance: `systemd-analyze` refuses to answer ("Bootup is not
# yet finished") until userspace target completes — 13min on the measured
# storm boot. The script retries (2min sleep, bounded) instead of failing,
# so storm boots still get captured. A single run is still a bounded window:
# the 2026-10-15 watchdog-reset storm boot finished userspace at 47m48s —
# AFTER the 24min single-run budget — leaving the prom phase-less (only the
# fail-closed scrape_errors=1) for the whole boot, which the pre-deploy
# phantom-metric gate then trips on every deploy that day. The timer
# therefore re-fires on `reEmitInterval` (OnUnitActiveSec): systemd-analyze
# is boot-relative and stable once the boot finishes, so the re-run
# converges the sample idempotently (boot_uptime_seconds carries sample age).
#
# mktemp in the sticky textfile dir + CAP_FOWNER (mail-relay 2026-09-02..06
# foreign-owned-prom class), buildcache/pool-smart collector pattern.
{
  flake.nixosModules.boot-metrics =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceOneshotDefaults
        onFailure
        ;

      cfg = config.services.boot-metrics;

      textfileDir = "/var/lib/prometheus-node-exporter/textfile_collectors";
    in
    {
      options.services.boot-metrics = {
        enable = lib.mkEnableOption "boot-duration textfile collector (systemd-analyze phases → node_exporter)";

        userspaceRegressionSeconds = lib.mkOption {
          type = lib.types.int;
          default = 180;
          description = ''
            Userspace-phase duration (seconds) above which
            boot_userspace_regression flips to 1. Calibrated against the
            post-2026-10-12-fix calm baseline (~40-60s expected) with headroom
            for IO-cold first boots; the 12m57s storm class sits far above it.
            Fine-grained regression trending belongs to the SigNoz dashboard
            on boot_phase_duration_seconds — this flag is only the PAGER line.
          '';
        };

        emitDelay = lib.mkOption {
          type = lib.types.str;
          default = "2min";
          description = "OnBootSec delay before the first emission attempt (boot must reach the timer target first).";
        };

        maxRetries = lib.mkOption {
          type = lib.types.int;
          default = 12;
          description = "Retry budget while systemd-analyze reports the boot as unfinished (2min sleep per retry — 12 covers ~26min userspace boots).";
        };

        reEmitInterval = lib.mkOption {
          type = lib.types.str;
          default = "30min";
          description = ''
            OnUnitActiveSec re-fire interval (convergence path for boots that
            finish AFTER the single-run retry budget — see header). Re-runs
            are idempotent for the current boot: systemd-analyze output is
            boot-relative and stable post-boot; boot_uptime_seconds carries
            the sample age between reboots.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        systemd.services.boot-metrics-emit = {
          description = "Boot-duration metrics collector (systemd-analyze phases → textfile)";
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          inherit onFailure;
          wants = [ "network.target" ];
          # late-applications (2026-10-26 ordering-cycle class fix): the
          # timer-fired re-sample must still run past the boot transaction,
          # but without arming the After=multi-user backward-edge class —
          # ordering under the late target instead (this box's single
          # sanctioned After=multi-user carrier).
          after = [ "late-applications.target" ];
          path = [
            pkgs.systemd
            pkgs.coreutils
            pkgs.gnugrep
            pkgs.gawk
          ];
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = "root";
              # maxRetries × 120s sleep + parse margin.
              TimeoutStartSec = "45min";
            }
            (harden {
              ReadWritePaths = [ textfileDir ];
              CapabilityBoundingSet = "CAP_FOWNER";
              MemoryMax = "64M";
            })
            (serviceOneshotDefaults { })
          ];
          script = ''
            set -eu

            OUT="${textfileDir}/boot-metrics.prom"
            mkdir -p "${textfileDir}"
            TMP="$(mktemp "${textfileDir}/boot-metrics.prom.XXXXXX")"
            chmod 644 "$TMP"
            trap 'rm -f "$TMP"' EXIT

            METRICS="$(mktemp)"
            scrape_errors=0

            # Age of an OPEN boot transaction: seconds past graphical.target
            # activation (falls back to uptime when graphical has not been
            # reached yet). systemctl show is in-repo-precedented under
            # harden{} (btrfs-verify-snapshots probes unit state the same
            # way); a missing/unparseable property degrades to uptime.
            # DEFINED ABOVE ITS FIRST CALL SITE (the retry loop below): a
            # helper defined after the call is not yet a command when the
            # loop body runs, and the 127 takes `set -e` down with it — the
            # 2026-10-18 failure where the open-transaction gauge this loop
            # exists to emit was never written on exactly the boots it is
            # for (systemd-analyze refusing).
            open_age_secs() {
              local up ge
              up="$(awk '{ printf "%.0f", $1 }' /proc/uptime)"
              ge="$(systemctl show graphical.target -p ActiveEnterTimestampMonotonic 2>/dev/null | grep -oE '[0-9]+' || true)"
              if [ -n "$ge" ] && [ "$ge" -gt 0 ] 2>/dev/null; then
                awk -v n="$up" -v g="$ge" 'BEGIN { d = n - g / 1000000; if (d < 0) d = n; printf "%.0f", d }'
              else
                printf '%s\n' "$up"
              fi
            }

            # ── systemd-analyze with bounded retry for storm boots ──────────
            analysis=""
            attempt=0
            while [ "$attempt" -lt ${toString cfg.maxRetries} ]; do
              attempt=$((attempt + 1))
              analysis="$(${pkgs.systemd}/bin/systemd-analyze --no-pager 2>&1 || true)"
              case "$analysis" in
                *"Bootup is not yet finished"*|*"Bootup is not yet complete"*)
                  echo "boot-metrics: boot unfinished (attempt $attempt/${toString cfg.maxRetries}), retrying in 120s" >&2
                  # MEASURE the open transaction instead of only sleeping on
                  # it: write the gauge mid-wait so an infinite-boot box
                  # surfaces a number within the first retry cycle (the
                  # 2026-10-17 class was invisible to blame + systemd-analyze
                  # for 55+ min). Atomic textfile write per house doctrine.
                  open_age="$(open_age_secs)"
                  {
                    echo "# HELP transaction_open 1 while the boot startup transaction is still open (systemd-analyze refuses), 0 once finished"
                    echo "# TYPE transaction_open gauge"
                    echo "transaction_open 1"
                    echo "# HELP transaction_open_seconds_past_graphical Seconds past graphical.target activation while the transaction stays open (uptime fallback pre-graphical); 0 when closed"
                    echo "# TYPE transaction_open_seconds_past_graphical gauge"
                    echo "transaction_open_seconds_past_graphical $open_age"
                    echo "# HELP boot_uptime_seconds Sample age (see above)"
                    echo "# TYPE boot_uptime_seconds gauge"
                    echo "boot_uptime_seconds $(awk '{ printf "%.0f", $1 }' /proc/uptime)"
                  } > "$TMP"
                  mv "$TMP" "$OUT"
                  echo "boot-metrics: transaction OPEN at ''${open_age}s past graphical — gauge written, retrying" >&2
                  sleep 120
                  ;;
                *) break ;;
              esac
            done

            # to_seconds "1h 29min 25.454s" | "12min 57.314s" | "4.036s" → seconds (3 decimals).
            # Hours case added 2026-10-17: the leftmost-longest substring match
            # below used to drop a leading "1h " on pathological (>1h) boots —
            # under-reporting exactly the class these metrics exist to measure
            # (live catch: userspace 1765.454 emitted for the 1h 29min 25.454s
            # infinite-boot transaction).
            to_seconds() {
              local t="$1" hrs=0 mins=0
              case "$t" in
                *h\ *)
                  hrs="''${t%%h*}"
                  t="''${t#*h }"
                  ;;
              esac
              case "$t" in
                *min*)
                  mins="''${t%%min*}"
                  t="''${t#*min }"
                  ;;
              esac
              awk -v h="$hrs" -v m="$mins" -v s="''${t%s}" 'BEGIN { printf "%.3f", h * 3600 + m * 60 + s }'
            }

            emit_phase() {
              local phase="$1" body="$2"
              local dur
              dur="$(printf '%s\n' "$body" | grep -oE "[0-9]+h [0-9]+min [0-9.]+s \(''${phase}\)|[0-9]+min [0-9.]+s \(''${phase}\)|[0-9.]+s \(''${phase}\)" | head -1 || true)"
              if [ -n "$dur" ]; then
                dur="''${dur% (*}"
                echo "boot_phase_duration_seconds{phase=\"$phase\"} $(to_seconds "''${dur# }")" >> "$METRICS"
              fi
            }

            phase_body="$(printf '%s\n' "$analysis" | sed -n 's/^Startup finished in //p' | sed 's/ = .*//')"
            if [ -n "$phase_body" ]; then
              for phase in firmware loader kernel initrd userspace; do
                emit_phase "$phase" "$phase_body"
              done
              # [[:space:]]*: systemd-analyze ends the summary line with a
              # trailing space; a bare $ anchor never matched (total absent
              # from every prom since launch, 2026-10-15).
              total="$(printf '%s\n' "$analysis" | grep -oE '= [0-9]+h [0-9]+min [0-9.]+s[[:space:]]*$|= [0-9]+min [0-9.]+s[[:space:]]*$|= [0-9.]+s[[:space:]]*$' | head -1 || true)"
              if [ -n "$total" ]; then
                echo "boot_total_duration_seconds $(to_seconds "''${total#= }")" >> "$METRICS"
              fi
            else
              scrape_errors=1
            fi

            userspace_line="$(grep '^boot_phase_duration_seconds{phase="userspace"} ' "$METRICS" 2>/dev/null || true)"
            regression=0
            if [ -n "$userspace_line" ]; then
              userspace_secs="''${userspace_line##* }"
              if awk -v u="$userspace_secs" -v t="${toString cfg.userspaceRegressionSeconds}" 'BEGIN { exit !(u > t) }'; then
                regression=1
              fi
            fi

            # ── reset-reason classification (per-boot, automatic) ───────────
            # The 2026-10-12 dispatch's key firmware probe, made standing:
            # "x86/amd: Previous system reset reason [...]" one grep separates
            # watchdog/cold/warm classes. Free text goes to the journal only
            # (labels must stay bounded-cardinality).
            reset_reason="$(journalctl -k -b 0 --no-pager --output cat 2>/dev/null | grep -m1 -o 'Previous system reset reason.*' || true)"
            if [ -n "$reset_reason" ]; then
              echo "boot-metrics: $reset_reason" >&2
            fi
            reset_watchdog=0
            case "$reset_reason" in
              *"hardware watchdog timer expired"*) reset_watchdog=1 ;;
            esac

            uptime_secs="$(awk '{ printf "%.0f", $1 }' /proc/uptime)"

            # Closed-transaction state for the final sample — or the FINAL
            # open age when the retry budget ran out (the give-up path keeps
            # the class visible: transaction_open 1 + last age + scrape_errors
            # below, instead of a bare phase-less error).
            case "$analysis" in
              *"Bootup is not yet finished"*|*"Bootup is not yet complete"*)
                tx_open=1
                tx_open_age="$(open_age_secs)"
                ;;
              *)
                tx_open=0
                tx_open_age=0
                ;;
            esac

            {
              echo "# HELP boot_phase_duration_seconds Duration of one boot phase (systemd-analyze), current boot only — sample age = boot_uptime_seconds"
              echo "# TYPE boot_phase_duration_seconds gauge"
              grep '^boot_phase_duration_seconds' "$METRICS" 2>/dev/null || true
              echo "# HELP boot_total_duration_seconds Total boot time (systemd-analyze '= …' tail), current boot only"
              echo "# TYPE boot_total_duration_seconds gauge"
              grep '^boot_total_duration_seconds' "$METRICS" 2>/dev/null || true
              echo "# HELP boot_uptime_seconds Seconds since boot when this sample was written (staleness/age context between reboots)"
              echo "# TYPE boot_uptime_seconds gauge"
              echo "boot_uptime_seconds $uptime_secs"
              echo "# HELP boot_reset_reason_watchdog 1 if the kernel logged a hardware-watchdog reset for this boot (freeze-class marker; full reason text in the unit journal), 0 otherwise"
              echo "# TYPE boot_reset_reason_watchdog gauge"
              echo "boot_reset_reason_watchdog $reset_watchdog"
              echo "# HELP boot_userspace_regression 1 if the userspace phase exceeded ${toString cfg.userspaceRegressionSeconds}s, 0 otherwise"
              echo "# TYPE boot_userspace_regression gauge"
              echo "boot_userspace_regression $regression"
              echo "# HELP boot_metrics_scrape_errors 1 if systemd-analyze produced no parseable output after the retry budget, 0 otherwise"
              echo "# TYPE boot_metrics_scrape_errors gauge"
              echo "boot_metrics_scrape_errors $scrape_errors"
              echo "# HELP transaction_open 1 while the boot startup transaction is still open (systemd-analyze refuses), 0 once finished"
              echo "# TYPE transaction_open gauge"
              echo "transaction_open $tx_open"
              echo "# HELP transaction_open_seconds_past_graphical Seconds past graphical.target activation while the transaction stays open (uptime fallback pre-graphical); 0 when closed"
              echo "# TYPE transaction_open_seconds_past_graphical gauge"
              echo "transaction_open_seconds_past_graphical $tx_open_age"
            } > "$TMP"
            mv "$TMP" "$OUT"
            trap - EXIT
            echo "boot-metrics: wrote $OUT ($(wc -l < "$OUT") lines)"
          '';
        };

        systemd.timers.boot-metrics-emit = {
          description = "Emit boot-duration metrics (boot-start attempt + interval re-sample)";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = cfg.emitDelay;
            OnUnitActiveSec = cfg.reEmitInterval;
            # Deliberately NOT Persistent: values are boot-relative and the
            # sample is only meaningful for the CURRENT boot.
            Persistent = false;
            Unit = "boot-metrics-emit.service";
          };
        };
      };
    };
}
