# Runbook: docs/services/gatus-alert-relay.md
# Local gate on gatus' Discord webhook path (T-007: boot/restart alert-storm
# + flap suppression, 2026-10-24).
#
# Why a relay: gatus 5.37 has NO native flap suppression and its maintenance
# windows are time-fixed — neither can key on "services are still settling
# after boot" or "the SEV1 bridge is paging". Sqlite storage already prevents
# re-sends of pre-restart failures (persisted triggered-alert state); the
# remaining noise is NEW triggers in boot windows (~25 endpoints x 2 on the
# Oct 20 double reboot) and flapping checks (Monitor365 x89, InboxClean x73
# trigger+resolve pairs in 24h). The relay sits BETWEEN gatus and Discord and
# shapes exactly that noise:
#
#   boot-grace    relay younger than bootGraceSeconds  -> queue trigger,
#                 replay when grace ends if still failing (covers deploy
#                 restarts too — the relay's own start IS the window)
#   sev1-mute     SEV1 bridge page-tier active + endpoint on the
#                 storm-attributable list -> queue, replay when SEV1 clears
#   flap-collapse > flapMaxTriggers forwarded per flapWindow -> drop (the
#                 ONLY lossy rule — it is the point) until flapQuiet idle
#   rearm-guard   trigger within rearmGuardSeconds of a resolve -> queue,
#                 replay at deadline if still failing
#
# Contract: a mute may DELAY an alert, never lose it (all rules except
# flap-collapse replay). Resolves ALWAYS forward. Unparseable payloads
# forward (fail-open): a gatus template drift degrades to today's behavior,
# never to silence. Suppression decisions journal as
# `relay decision=suppress reason=… endpoint="…"` lines.
_: {
  flake.nixosModules.gatus-alert-relay =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.services.gatus-alert-relay;
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceDefaults
        onFailureP0
        serviceTypes
        ioTier
        ports
        ;
      # Same callPackage + src as flake/parts/packages.nix → identical
      # store path from both sides (ai-meter doctrine).
      pkg = pkgs.callPackage ../../../pkgs/gatus-alert-relay.nix {
        src = lib.sources.cleanSource ../../../pkgs/gatus-alert-relay;
      };
    in
    {
      options.services.gatus-alert-relay = {
        enable = lib.mkEnableOption "gatus Discord alert gate (boot grace, SEV1 mute, flap collapse)";

        port = serviceTypes.servicePort ports.gatusAlertRelay "HTTP port for the relay /hook + /healthz (loopback only)";

        bootGraceSeconds = lib.mkOption {
          type = lib.types.ints.positive;
          default = 900;
          description = "Suppress triggers while the relay process is younger than this (boot windows + deploy restarts; queued + replayed).";
        };

        flapWindowSeconds = lib.mkOption {
          type = lib.types.ints.positive;
          default = 21600;
          description = "Sliding window for flap-collapse counting (forwarded triggers only).";
        };

        flapMaxTriggers = lib.mkOption {
          type = lib.types.ints.positive;
          default = 4;
          description = "Forwarded triggers per flapWindow before flap collapse suppresses further ones (lossy, by design).";
        };

        flapQuietSeconds = lib.mkOption {
          type = lib.types.ints.positive;
          default = 1800;
          description = "Event-free period that resets an endpoint's flap counter.";
        };

        rearmGuardSeconds = lib.mkOption {
          type = lib.types.ints.positive;
          default = 600;
          description = "Hold re-triggers that follow a resolve within this window; replay at deadline if still failing.";
        };

        sev1FreshnessSeconds = lib.mkOption {
          type = lib.types.ints.positive;
          default = 600;
          description = "Max age of the SEV1 alert file's epoch line before it stops counting as active.";
        };

        sev1MuteEndpoints = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            # Storm-attributable family: metrics-scrape checks that false-RED
            # under IO/memory storms, plus the two documented flappers
            # (2026-10-21 review §3c.1/§3c.2). DisplayName form = "Group/Name".
            "Monitoring/System-Health Metrics"
            "Monitoring/Swap Metrics"
            "Monitoring/Memory Metrics"
            "Monitoring/Memory Pressure"
            "Monitoring/Node Exporter"
            "Monitoring/ZRAM Fill"
            "Monitoring/GPU VRAM Metrics"
            "Monitoring/USB Flap Rate"
            "Monitoring/Textfile Collector Health"
            "Monitoring/Storage Collector Health"
            "Monitoring/Gatus"
            "Monitoring/Monitor365 Server"
            "Productivity/InboxClean"
          ];
          description = "Group/Name display names muted while the SEV1 bridge page tier is active (queued + replayed on clear).";
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = config.services.gatus-config.enable or false;
            message = "gatus-alert-relay: enabled without gatus-config — a relay whose gatus does not point at it is a dead letterbox (alerts bypass the gate).";
          }
        ];

        systemd.services.gatus-alert-relay = {
          description = "Gate on gatus' Discord webhook (boot grace, SEV1 mute, flap collapse)";
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          # Ordering vs gatus: if the relay is not up when gatus fires its
          # first webhook POST, that alert is lost (gatus does not retry
          # provider sends). Start before gatus; both are wanted by
          # multi-user.target, ordering makes the race practically impossible
          # (the relay binds in milliseconds).
          before = [ "gatus.service" ];
          wantedBy = [ "multi-user.target" ];
          onFailure = onFailureP0;
          serviceConfig = lib.mkMerge [
            (harden { MemoryMax = "80M"; })
            (serviceDefaults { Restart = "always"; })
            # The relay is IO-trivial (in-memory state, one HTTPS POST per
            # alert) — standard service tier.
            ioTier.service
            {
              EnvironmentFile = config.sops.templates."gatus-env".path;
              ExecStart = "${lib.getExe pkg} -listen 127.0.0.1:${toString cfg.port} -boot-grace ${toString cfg.bootGraceSeconds}s -flap-window ${toString cfg.flapWindowSeconds}s -flap-max ${toString cfg.flapMaxTriggers} -flap-quiet ${toString cfg.flapQuietSeconds}s -rearm-guard ${toString cfg.rearmGuardSeconds}s -sev1-freshness ${toString cfg.sev1FreshnessSeconds}s -sev1-mute ${lib.concatStringsSep "," cfg.sev1MuteEndpoints}";
            }
          ];
        };
      };
    };
}
