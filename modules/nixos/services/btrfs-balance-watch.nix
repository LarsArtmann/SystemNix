# btrfs-balance-watch — balance-failure alerting (storage-crisis plan S24).
#
# The 2026-10-26 07:22:32 balance ended with kernel `balance: ended with
# status: -28` (ENOSPC during relocation) and that line sat SILENT for 84
# minutes while the box was believed healthy — balance failure is exactly
# the moment the storage textfile metrics matter, and nothing watched it.
# This module scans the kernel journal on a 5-min cadence for any
# `balance: ended with status: -N` line (negative status = canceled or
# errored), keeps a persistent failure ledger, and publishes:
#
#   btrfs_balance_failures_total          — failures ever seen (monotone)
#   btrfs_balance_last_failure_unix_secs  — 0 until the first failure
#   btrfs_balance_failure_recent_24h      — 1 while a failure is <24h old
#   btrfs_balance_watch_fresh             — 1 on every successful scan
#                                           (heartbeat; staleness = the
#                                           watcher itself died)
#
# Gatus check (integration entry below) pages on recent_24h=1 or on a
# missing heartbeat. Tested by SIMULATION: `echo … > /dev/kmsg` from a
# sudo harness produces a real kernel-journal line; the balance itself is
# never re-run to test the detector (plan µ24.1).
#
# Scope note: the kernel emits this line for ANY btrfs on the box that
# runs a balance (root, /data, pool) — the detector watches them all;
# the ledger file records the raw line for post-hoc attribution.
_: {
  flake.nixosModules.btrfs-balance-watch =
    {
      config,
      lib,
      options,
      pkgs,
      ...
    }:
    let
      inherit (import ../../../lib/default.nix lib)
        harden
        onFailure
        serviceOneshotDefaults
        ioTier
        ;
      textfileDir = "/var/lib/prometheus-node-exporter/textfile_collectors";
      stateDir = "/var/lib/btrfs-balance-watch";
      scanInterval = "5m";

      watchScript = pkgs.writeShellApplication {
        name = "btrfs-balance-watch-scan";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gnugrep
          pkgs.systemd
        ];
        text = ''
          set -euo pipefail
          NOW="$(date +%s)"

          # Scan a window slightly wider than the timer cadence so a slow
          # cycle cannot skip a line; the ledger dedupes by exact line text.
          HITS="$(journalctl -k --since "-11m" --no-pager 2>/dev/null \
            | grep -F 'balance: ended with status: -' || true)"

          LEDGER="${stateDir}/ledger"
          COUNT_FILE="${stateDir}/count"
          LAST_FILE="${stateDir}/last_failure"
          touch "$LEDGER"
          COUNT="$(cat "$COUNT_FILE" 2>/dev/null || echo 0)"
          LAST="$(cat "$LAST_FILE" 2>/dev/null || echo 0)"

          if [ -n "$HITS" ]; then
            while IFS= read -r line; do
              # Dedupe: a line already recorded is not a new failure.
              if ! grep -qxF "$line" "$LEDGER"; then
                echo "$line" >> "$LEDGER"
                COUNT=$((COUNT + 1))
                LAST="$NOW"
              fi
            done <<< "$HITS"
            printf '%s\n' "$COUNT" > "$COUNT_FILE"
            printf '%s\n' "$LAST" > "$LAST_FILE"
            echo "btrfs-balance-watch: NEW failure recorded — $HITS" >&2
          fi

          RECENT=0
          if [ "$LAST" -gt 0 ] && [ $((NOW - LAST)) -lt 86400 ]; then
            RECENT=1
          fi

          # mktemp + rename per the sticky-1777 textfile doctrine; the unit
          # carries CAP_FOWNER for the final rename over a foreign leftover.
          TMP="$(mktemp "${textfileDir}/btrfs-balance-watch.prom.XXXXXX")"
          trap 'rm -f "$TMP"' EXIT
          {
            echo "# HELP btrfs_balance_failures_total Balance runs ended with negative status, ever (persistent ledger)"
            echo "# TYPE btrfs_balance_failures_total counter"
            echo "btrfs_balance_failures_total $COUNT"
            echo "# HELP btrfs_balance_last_failure_unix_secs Unix seconds of the newest recorded failure (0 = none)"
            echo "# TYPE btrfs_balance_last_failure_unix_secs gauge"
            echo "btrfs_balance_last_failure_unix_secs $LAST"
            echo "# HELP btrfs_balance_failure_recent_24h 1 while the newest failure is younger than 24h"
            echo "# TYPE btrfs_balance_failure_recent_24h gauge"
            echo "btrfs_balance_failure_recent_24h $RECENT"
            echo "# HELP btrfs_balance_watch_fresh Heartbeat: 1 on every completed scan"
            echo "# TYPE btrfs_balance_watch_fresh gauge"
            echo "btrfs_balance_watch_fresh 1"
          } > "$TMP"
          chmod 0644 "$TMP"
          mv -f "$TMP" "${textfileDir}/btrfs-balance-watch.prom"
          trap - EXIT
        '';
      };
    in
    {
      config = {
        systemd.services.btrfs-balance-watch = {
          description = "Scan kernel journal for btrfs balance failures; publish alert gauges";
          inherit onFailure;
          # Reading the kernel journal requires the systemd-journal group
          # (journal files are root:systemd-journal 0640).
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = "btrfs-balance-watch";
              SupplementaryGroups = [ "systemd-journal" ];
              ExecStart = lib.getExe watchScript;
              StateDirectory = "btrfs-balance-watch";
              TimeoutStartSec = "2min";
            }
            (harden {
              MemoryMax = "128M";
              # No capabilities: journal reads come via the
              # systemd-journal supplementary group and gauge writes via
              # ReadWritePaths. The original CAP_FOWNER bounding-set entry
              # was never granted ambient (non-root User=) and the script
              # does no chown/chmod — dead weight the capability-grant
              # audit correctly rejected; removed rather than granted
              # (2026-10-27).
              ReadWritePaths = [ textfileDir ];
            })
            (serviceOneshotDefaults { })
          ];
        };

        systemd.timers.btrfs-balance-watch = {
          description = "btrfs balance failure scan (${scanInterval} cadence)";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "3m";
            OnUnitActiveSec = scanInterval;
          };
        };

        users.users.btrfs-balance-watch = {
          isSystemUser = true;
          group = "btrfs-balance-watch";
        };
        users.groups.btrfs-balance-watch = { };

        # Registry fan-out: gatus check paging on a fresh failure or a dead
        # watcher. Presence-anchored positives + negative on the alert value
        # (house polarity): green requires the heartbeat line to exist AND
        # read 1 AND no recent failure.
        services.integration = lib.optionalAttrs (options ? services.integration) {
          btrfs-balance-watch = {
            enable = true;
            vHost.layer = "none";
            checks = [
              {
                name = "Btrfs Balance Failure Watch";
                group = "Monitoring";
                url = "http://localhost:${toString config.services.prometheus.exporters.node.port}/metrics";
                interval = "5m";
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] == pat(*\nbtrfs_balance_watch_fresh 1\n*)"
                  "[BODY] != pat(*\nbtrfs_balance_failure_recent_24h 1\n*)"
                ];
                alert = "A btrfs balance run ended with a negative (canceled/errored) status within the last 24h, or the balance-watch heartbeat is stale — check journalctl -k | grep balance and /var/lib/btrfs-balance-watch/ledger";
              }
            ];
          };
        };
      };
    };
}
