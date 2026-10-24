# USB flap-counter metrics — textfile collector for the DAS/USB link churn.
#
# The 2026-08-16 enclosure storm logged 11 re-enumerations in 3.5 h and the
# 2026-08-22 JMS567 wedge took the whole DAS offline for 9 days — but the
# flap RATE was only ever countable by hand from the kernel journal, so the
# "did the enclosure swap / udev fix actually help" question (status report
# 2026-08-16_19-12 §f.12) stayed unanswerable. This collector counts kernel
# USB disconnect events from the persistent journal into Prometheus metrics
# and adds a rolling-hour rate flag Gatus can page on:
#
#   usb_flap_disconnects_total          cumulative across boots (state file)
#   usb_flap_disconnects_delta          since the previous run
#   usb_flap_disconnects_last_hour      rolling 1h window (event timestamps)
#   usb_flap_rate_over_threshold 1|0   last_hour >= alertThreshold
#   usb_flap_last_disconnect_epoch      0 = never within the journal window
#
# Fail-closed: on any journalctl error the file still lands with
# usb_flap_scrape_errors 1 so the pre-deploy phantom-metric gate and Gatus
# see a broken collector, never a silently frozen one.
#
# mktemp in the sticky textfile dir + CAP_FOWNER (mail-relay 2026-09-02..06
# foreign-owned-prom class); journal read needs no extra caps (adm group via
# systemd-journal group membership is granted by running as root).
#
# The collector BODY lives in scripts/usb-flap-collector.sh so the fixture
# selftest (scripts/test-usb-flap-collector.sh + the
# usb-flap-metrics-selftest flake check) exercises the SAME file the unit
# runs — never a grep of its own copy.
{
  flake.nixosModules.usb-flap-metrics =
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

      cfg = config.services.usb-flap-metrics;

      textfileDir = "/var/lib/prometheus-node-exporter/textfile_collectors";
    in
    {
      options.services.usb-flap-metrics = {
        enable = lib.mkEnableOption "USB flap-counter metrics (kernel journal → node_exporter textfile)";

        alertThreshold = lib.mkOption {
          type = lib.types.int;
          default = 5;
          description = "Disconnects within the rolling hour at which usb_flap_rate_over_threshold flips to 1 (the 2026-08-16 storm ran ~2/h steady with 9 in 36 min).";
        };

        windowSeconds = lib.mkOption {
          type = lib.types.int;
          default = 3600;
          description = "Rolling window for the rate metric, in seconds.";
        };

        interval = lib.mkOption {
          type = lib.types.str;
          default = "5min";
          description = "Collection interval (OnUnitActiveSec).";
        };
      };

      config = lib.mkIf cfg.enable {
        systemd.services.usb-flap-metrics = {
          description = "USB flap-counter metrics collector (textfile)";
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          inherit onFailure;
          path = [
            pkgs.systemd
            pkgs.gawk
            pkgs.gnugrep
            pkgs.coreutils
          ];
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = "root";
              StateDirectory = "usb-flap-metrics";
            }
            (harden {
              ReadWritePaths = [ textfileDir ];
              # CAP_FOWNER for the sticky-dir rename over a foreign-owned
              # prom (mail-relay class). No device access needed.
              CapabilityBoundingSet = "CAP_FOWNER";
              MemoryMax = "128M";
            })
            (serviceOneshotDefaults { })
          ];
          script = ''
            OUT="${textfileDir}/usb-flap.prom" \
            TEXTFILE_DIR="${textfileDir}" \
            STATE_DIR="''${STATE_DIRECTORY:-/var/lib/usb-flap-metrics}" \
            THRESHOLD=${toString cfg.alertThreshold} \
            WINDOW=${toString cfg.windowSeconds} \
            exec ${pkgs.bash}/bin/bash ${../../../scripts/usb-flap-collector.sh}
          '';
        };

        systemd.timers.usb-flap-metrics = {
          description = "Collect USB flap-counter metrics every ${cfg.interval}";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "2min";
            OnUnitActiveSec = cfg.interval;
            Persistent = true;
          };
        };
      };
    };
}
