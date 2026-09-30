# EMEET PIXY — SystemNix wrapper around the upstream NixOS module.
#
# The upstream module (inputs.emeet-pixyd.nixosModules.default →
# hardware.emeet-pixy) owns the service shape: the graphical-session USER
# unit (emeet-pixyd.service), the v4l2 webcam auto-activation daemon, its
# sandboxing, and the loopback HTTP surface on ports.emeet-pixyd (web UI +
# control API consumed by the DMS quickshell widget).
#
# This file layers ONLY the SystemNix-specific registry wiring: the
# home.lan vHost, DNS, Gatus endpoint checks, and the dashboard tile via
# the services.integration entry, plus the platform catalog entry.
#
# ALERTING CALIBRATION: the daemon is a graphical-session user unit — it
# legitimately does not run during reboots or SSH-only periods. The
# endpoint checks below are deliberately SILENT (alert = ""); paging is
# owned by the session-aware meta check in gatus-config.nix
# (`system_emeet_pixyd_expected_down`), which fires only when niri is
# running but the daemon is not — the same design as the niri health
# checks.
{
  inputs,
  ...
}:
{
  flake.nixosModules.emeet-pixyd =
    {
      config,
      options,
      lib,
      ...
    }:
    let
      inherit (import ../../../lib/default.nix lib) ports;
      cfg = config.hardware.emeet-pixy;
    in
    {
      imports = [
        inputs.emeet-pixyd.nixosModules.default
        # Platform-truth catalog entry (ADR-008): unconditional — the
        # webcam daemon exists platform-wide even where this host has it
        # disabled. The catalog OPTION comes from nixosModules.catalog,
        # which every host importing this module must also import (loud
        # eval failure if missing — no silent absence).
        {
          services.catalog.emeet-pixyd = {
            subdomain = "emeet-pixyd";
            port = ports.emeet-pixyd;
            description = "EMEET PIXY webcam auto-activation daemon (tracking, privacy, presets)";
            healthPath = "/api/health";
          };
        }
      ];

      config = lib.mkIf cfg.enable {
        services.integration = lib.optionalAttrs (options ? services.integration) {
          emeet-pixyd = {
            subdomain = "emeet-pixyd";
            port = ports.emeet-pixyd;
            # Layer 2: the daemon has NO native auth and exposes webcam
            # CONTROL endpoints (POST /api/track, /api/ptz, presets,
            # privacy) — external clients go through oauth2-proxy, LAN
            # bypasses. Plain layer would leave webcam control open to
            # anything on the LAN.
            vHost.layer = "protected";
            checks = [
              # Liveness: the daemon answers /api/health with 200 "ok"
              # (camera online) or 503 "offline" (daemon up, camera
              # unplugged). [STATUS] < 500 keeps an unplugged webcam from
              # reding the check — only a dead/unreachable daemon fails.
              {
                name = "EMEET PIXY Daemon";
                group = "Infrastructure";
                path = "/api/health";
                interval = "60s";
                conditions = [
                  "[STATUS] < 500"
                  "[RESPONSE_TIME] < 2000"
                  "[BODY] == pat(*\"status\"*)"
                ];
                # Silent: graphical-session user unit — down during
                # reboots/SSH-only is EXPECTED. Paging is owned by the
                # session-aware meta check (system_emeet_pixyd_expected_down).
                alert = "";
              }
              # Functional: the web panel renders HTML (liveness alone
              # would stay green through a broken static/render path).
              {
                name = "EMEET PIXY Panel Renders";
                group = "Infrastructure";
                path = "/panel";
                interval = "5m";
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] == pat(*<html*)"
                ];
                alert = "";
              }
            ];
            homepage = {
              name = "EMEET PIXY";
              group = "Infrastructure";
              description = "Webcam auto-activation daemon (tracking, privacy, presets)";
              icon = "mdi-webcam";
            };
            # Deliberately NOT monitored=true: emeet-pixyd.service is a
            # USER unit — node_exporter's systemd collector (system bus)
            # never sees it, so a monitored row would sit absent/red
            # forever. Unit-state alerting rides the session-aware meta
            # check in gatus-config.nix.
            monitored = false;
          };
        };
      };
    };
}
