# InboxClean health-timeout canary (freeze-#27/#28 IO-saturation signal).
#
# The inboxclean-web health handler timed out at its 8s budget throughout
# the 2026-10-12 freeze (`GET /health status=503` + `failed to encode
# health response error="http: Handler timeout"`, docs/status/tasks/
# 2026-10-13_01-40_freeze-27-unit-io-attribution.md) — a signature visible
# ONLY by journal archaeology after the crash until this collector landed.
# The pattern is an IO-saturation canary: the web app's worker loop (DB
# scans, IMAP resyncs) saturating the disk long before anything else
# goes red.
#
# Upstream fix (InboxClean cached-health snapshot, 2026-10-13) removes the
# per-probe registry re-run, so post-deploy the burst should stay 0 — the
# rule doubles as the regression guard for that fix. If it fires after the
# cached-health deploy, either the cache regressed or the box is IO-swept
# badly enough that even a 15s-cadence background refresh cannot finish.
#
# Mechanism: 2-min oneshot counts `Handler timeout` lines in the last
# 10 minutes of the inboxclean-web journal into the node_exporter textfile
# dir; the SigNoz rule (InboxClean Health Handler Timeout Burst) alerts at
# >=3 in the window. Runbook: docs/services/inboxclean.md.
{ inputs, ... }: {
  flake.nixosModules.inboxclean-canary =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (import ../../../lib/default.nix lib)
        harden
        onFailure
        serviceOneshotDefaults
        ;

      textfileDir = "/var/lib/prometheus-node-exporter/textfile_collectors";

      windowMinutes = 10;
      burstThreshold = 3;

      inboxcleanCanaryMetrics = pkgs.writeShellApplication {
        name = "inboxclean-canary-metrics";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.systemd
          pkgs.gnugrep
        ];
        text = ''
          OUT="${textfileDir}/inboxclean-canary.prom"
          mkdir -p "${textfileDir}"
          # Unique tmp per run (mktemp): the textfile dir is sticky 1777 and
          # nobody can rename over a foreign-owned leftover without CAP_FOWNER
          # (the 2026-09-02..06 mail-relay outage class).
          TMP="$(mktemp "${textfileDir}/inboxclean-canary.prom.XXXXXX")"
          chmod 644 "$TMP"
          trap 'rm -f "$TMP"' EXIT

          errors=0
          # Handler-timeout lines in the last window: the 8s health-503
          # signature (`failed to encode health response error="http: Handler
          # timeout"`). grep -c exits 1 on zero matches — the || fallback keeps
          # count=0 a success, not an error.
          count="$(timeout 30 journalctl -u inboxclean-web.service \
            --since "-${toString windowMinutes} min" --no-pager 2>/dev/null \
            | timeout 30 grep -c 'Handler timeout')" || count=0
          case "$count" in
            ""|*[!0-9]*) count=0; errors=1 ;;
          esac

          burst=0
          if [ "$count" -ge ${toString burstThreshold} ]; then
            burst=1
          fi

          {
            echo "# HELP inboxclean_web_health_handler_timeouts Handler-timeout (8s health 503) lines in the inboxclean-web journal over the last ${toString windowMinutes} minutes"
            echo "# TYPE inboxclean_web_health_handler_timeouts gauge"
            echo "inboxclean_web_health_handler_timeouts{window=\"${toString windowMinutes}m\"} $count"
            echo "# HELP inboxclean_web_health_handler_timeout_burst 1 when the count crossed the burst threshold (IO-saturation canary)"
            echo "# TYPE inboxclean_web_health_handler_timeout_burst gauge"
            echo "inboxclean_web_health_handler_timeout_burst $burst"
            echo "# HELP inboxclean_web_canary_scrape_errors 1 when the journal read failed (values then reflect best-effort reads)"
            echo "# TYPE inboxclean_web_canary_scrape_errors gauge"
            echo "inboxclean_web_canary_scrape_errors $errors"
          } > "$TMP"
          mv "$TMP" "$OUT"

          echo "inboxclean-canary-metrics: count=$count burst=$burst errors=$errors"
        '';
      };
    in
    {
      config = lib.mkIf config.services.inboxclean.enable {
        # Journal-count textfile collector — see the module header for the
        # why. Emits fail-closed (the prom is written on EVERY run).
        systemd.services.inboxclean-canary-metrics = {
          description = "InboxClean health Handler-timeout canary textfile collector";
          inherit onFailure;
          after = [ "inboxclean-web.service" ];
          serviceConfig = lib.mkMerge [
            (harden { MemoryMax = "64M"; })
            (serviceOneshotDefaults { })
            {
              Type = "oneshot";
              ExecStart = lib.getExe inboxcleanCanaryMetrics;
              ReadWritePaths = [ textfileDir ];
              # journalctl + grep are timeout-bounded inside; this is the ceiling.
              TimeoutStartSec = "2min";
            }
          ];
        };

        systemd.timers.inboxclean-canary-metrics = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "90s";
            OnUnitActiveSec = "2min";
          };
        };

        systemd.tmpfiles.rules = [
          # Duplicate of the mail-relay rule when both services are enabled —
          # tmpfiles merges identical "d" rules harmlessly.
          "d ${textfileDir} 1777 nobody nogroup -"
        ];
      };
    };
}
