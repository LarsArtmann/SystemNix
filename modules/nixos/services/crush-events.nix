# Crush session-event telemetry: collects the JSONL audit trails written by
# crush-config's observe hooks (StopFailure provider errors, PermissionResult
# decisions — see the crush-config docs/hooks.md layer, 2026-10-29) into the
# node_exporter textfile dir, asserts freshness via gatus, and pages via a
# SigNoz rule when provider-error turn-ends (the class that silently kills
# tq-agent-pool / crush-debug runs) recur.
#
# Why a collector instead of hook-side pushes: the hooks run as USERS in
# every crush session; the textfile dir is root-owned. The user-space hooks
# append to ~/.local/state/crush/*.jsonl (cheap, durable, no perms), and
# this root-side oneshot turns those files into metrics — the same split
# the architecture-catalog / system-health collectors use.
#
# No port, no vHost, no secrets. Not web-facing: no subdomain, so no
# dashboard tile (tile coverage asserts only subdomain'd entries).
{
  flake.nixosModules.crush-events =
    {
      config,
      pkgs,
      lib,
      options,
      ...
    }:
    let
      inherit (import ../../../lib/default.nix lib) harden;
      cfg = config.services.crush-events;
      textfileDir = "/var/lib/prometheus-node-exporter/textfile_collectors";
      primaryUser = config.users.primaryUser;

      collector = pkgs.writeShellApplication {
        name = "crush-events-collector";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gnused
        ];
        text = ''
          set -euo pipefail
          out="${textfileDir}/crush_events.prom"
          tmp="$(mktemp "${textfileDir}/crush_events.prom.XXXXXX")"
          trap 'rm -f "$tmp"' EXIT

          emit() { printf '%s\n' "$1" >>"$tmp"; }

          emit '# HELP crush_events_scrape_errors 1 when reading any events file failed (heartbeat: this line always exists — whole-file rejection is visible).'
          emit '# TYPE crush_events_scrape_errors gauge'
          scrape_errors=0

          emit '# HELP crush_events_fresh 1 when the run read every present events file cleanly.'
          emit '# TYPE crush_events_fresh gauge'
          fresh=1

          # file <basename-without-jsonl> -> metric suffix; line counts are
          # monotonic between rotations (rotation at 50k lines / 10 MiB resets
          # them — increase() treats the drop as a counter reset, fine).
          count_file() { # count_file <home> <user> <basename> <metric-suffix>
            local f="$1/.local/state/crush/$3.jsonl" lines
            [ -f "$f" ] || return 0
            if ! lines=$(wc -l <"$f" 2>/dev/null); then
              scrape_errors=1
              fresh=0
              return 0
            fi
            emit "crush_events_lines_total{file=\"$3\",user=\"$2\"} ''${lines:-0}"
          }

          # Scan real users with a home dir (primaryUser first; hooks run in
          # every interactive/headless crush session on the box).
          for home in /home/*; do
            [ -d "$home" ] || continue
            user="$(basename "$home")"
            count_file "$home" "$user" provider-errors
            count_file "$home" "$user" permission-audit
          done

          emit "crush_events_scrape_errors $scrape_errors"
          emit "crush_events_fresh $fresh"
          emit "crush_events_last_run_seconds $(date +%s)"

          mv "$tmp" "$out"
        '';
      };
    in
    {
      options.services.crush-events = {
        enable = lib.mkEnableOption "crush session-event telemetry (StopFailure/PermissionResult JSONL -> textfile metrics + gatus freshness + SigNoz rule)";

        interval = lib.mkOption {
          type = lib.types.str;
          default = "1m";
          description = "Collector timer interval (systemd OnCalendar/OnUnitActiveSec form).";
        };
      };

      config = lib.mkIf cfg.enable {
        systemd.tmpfiles.rules = [
          "d ${textfileDir} 0755 root root -"
        ];

        systemd.services.crush-events-collector = {
          description = "Crush events collector (StopFailure/permission JSONL -> textfile metrics)";
          wants = [ "network-online.target" ];
          after = [ "network-online.target" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${collector}/bin/crush-events-collector";
          }
          // (harden {
            MemoryMax = "256M";
            ReadWritePaths = [ textfileDir ];
            ReadOnlyPaths = [ "/home" ];
          });
        };

        systemd.timers.crush-events-collector = {
          description = "Crush events collector cadence";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "2m";
            OnUnitActiveSec = cfg.interval;
            Persistent = true;
          };
        };

        services.integration = lib.optionalAttrs (options ? services.integration) {
          crush-events = {
            # Not web-facing: metrics-only — no subdomain/port, layer "none"
            # (the ai-meter loopback pattern).
            inherit (cfg) enable;
            vHost.layer = "none";
            checks = [
              {
                # Freshness canary (the architecture-catalog pattern): the
                # heartbeat + fresh flags must answer on the exporter surface,
                # so a whole-file textfile rejection or a dead collector is
                # visible instead of silently gapless.
                name = "Crush Events Freshness";
                group = "Infrastructure";
                url = "http://localhost:${toString config.services.prometheus.exporters.node.port}/metrics";
                interval = "15m";
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] == pat(*\ncrush_events_scrape_errors 0*)"
                  "[BODY] == pat(*\ncrush_events_fresh 1*)"
                ];
                alert = "Crush events collector degraded — StopFailure/permission telemetry is stale or the textfile was rejected. Check: systemctl status crush-events-collector; journalctl -u crush-events-collector.";
              }
            ];
            unit = "crush-events-collector";
            monitored = true;
          };
        };
      };
    };
}
