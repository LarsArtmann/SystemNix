# Mail-relay outcome textfile collector for node_exporter.
#
# The 2026-11-11 Resend outage class: artmann.tech silently lost domain
# verification in the Resend dashboard and EVERY outbound application mail
# bounced (`550 The artmann.tech domain is not verified`) for HOURS while
# the pipeline read success at the postfix client hop — the client 250 is
# local truth only; the relay-hop journal line is the transport verdict
# (docs/status/2026-11-11_09-20 §d.1). This collector surfaces those
# verdicts as metrics so the invisible-outbound-bouncing class pages
# instead of silently bleeding.
#
# Mirrors the usb-flap-metrics design: the collector BODY lives in
# scripts/mail-relay-verdicts-collector.sh so the fixture selftest
# (scripts/test-mail-relay-verdicts-collector.sh + the
# mail-relay-verdicts-selftest flake check) exercises the SAME file the unit
# runs. Journal read needs root (systemd-journal membership via User=root);
# postqueue needs root. mktemp in the sticky textfile dir + CAP_FOWNER
# (mail-relay 2026-09-02..06 foreign-owned-prom class).
#
# SPLIT with services.mail-relay's own mail-relay-metrics unit (different
# concern, different user, different prom file — one owner per file, the
# 2026-11-12 split-brain catch): that unit is relay HEALTH (queue depth +
# credential placeholder, runs AS the postfix user to read the 0400 SASL
# map, writes mail-relay.prom); this one is transport VERDICTS (relay-hop
# journal lines, runs as root for journal access, writes
# mail-relay-verdicts.prom). node_exporter merges every .prom in the
# textfile dir; neither file ever clobbers the other.
#
# Alerting: the SigNoz rule "Outbound Mail Bounced at Relay" pages on
# increase(node_mail_relay_bounced_total[10m]) — the textfile→SigNoz path
# the gpu-gtt rule already proves. Gatus does NOT get a leg: it probes
# endpoints, not metrics; the SigNoz rule is the paging surface
# (emeet-pixyd precedent).
{
  config,
  pkgs,
  lib,
  ...
}:
{
  flake.nixosModules.mail-relay-verdicts =
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

      cfg = config.services.mail-relay-verdicts;

      textfileDir = "/var/lib/prometheus-node-exporter/textfile_collectors";
    in
    {
      options.services.mail-relay-verdicts = {
        enable = lib.mkEnableOption "Mail-relay outcome metrics (postfix relay-hop journal → node_exporter textfile)";

        alertThreshold = lib.mkOption {
          type = lib.types.int;
          default = 1;
          description = "Relay rejections inside the rolling window at which node_mail_relay_bounce_over_threshold flips to 1 (the outage class pages on ANY rejection).";
        };

        windowSeconds = lib.mkOption {
          type = lib.types.int;
          default = 3600;
          description = "Rolling window for the bounce-rate metric, in seconds.";
        };

        interval = lib.mkOption {
          type = lib.types.str;
          default = "2min";
          description = "Collection interval (OnUnitActiveSec).";
        };
      };

      config = lib.mkIf cfg.enable {
        systemd.services.mail-relay-verdicts = {
          description = "Mail-relay outcome metrics collector (textfile)";
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          inherit onFailure;
          path = [
            pkgs.systemd
            pkgs.gnugrep
            pkgs.gawk
            pkgs.coreutils
            pkgs.postfix
          ];
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = "root";
              StateDirectory = "mail-relay-verdicts";
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
            OUT="${textfileDir}/mail-relay-verdicts.prom" \
            TEXTFILE_DIR="${textfileDir}" \
            STATE_DIR="''${STATE_DIRECTORY:-/var/lib/mail-relay-verdicts}" \
            THRESHOLD=${toString cfg.alertThreshold} \
            WINDOW=${toString cfg.windowSeconds} \
            exec ${pkgs.bash}/bin/bash ${../../../scripts/mail-relay-verdicts-collector.sh}
          '';
        };

        systemd.timers.mail-relay-verdicts = {
          description = "Collect mail-relay outcome metrics every ${cfg.interval}";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "3min";
            OnUnitActiveSec = cfg.interval;
            Persistent = true;
          };
        };
      };
    };
}
