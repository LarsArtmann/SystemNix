# Runbook: docs/services/file-and-image-renamer.md
# AI-powered file and screenshot renaming watcher daemon + health dashboard.
#
# CONSUMES the canonical module from the upstream flake
# (inputs.file-and-image-renamer.nixosModules.file-and-image-renamer):
# unit definitions, the env vocabulary (CQRS_DB_PATH, LOG_DIR, key files,
# OTEL), systemd hardening and the default-user policy live THERE, gated
# by that repo's checks.nixos-module (a real nixosSystem eval). This
# wrapper keeps ONLY machine integration: port-registry healthAddr, the
# primaryUser + home-based dataDir prod shape, the SigNoz OTel endpoint,
# and the services.integration entry (Caddy vHost + Gatus + homepage).
#
# Migration record (2026-10-19): the duplicated options/units that used to
# live here were DELETED in the same change the import was added — keeping
# both would be the split brain this migration kills. The deleted copy had
# drifted: it still set HISTORY_FILE_PATH / HASHDB_PATH / DEAD_LETTER_PATH
# (legacy stores removed upstream 2026-09-18) and never set CQRS_DB_PATH,
# working only because the binary's home-dir default happened to match
# dataDir. The upstream module now sets CQRS_DB_PATH and LOG_DIR
# explicitly to the same paths prod always used.
{
  flake.nixosModules.file-and-image-renamer =
    {
      config,
      options,
      lib,
      inputs,
      ...
    }:
    let
      inherit (config.users) primaryUser;
      sd = import ../../../lib/default.nix lib;
      inherit (sd) ports;

      cfg = config.services.file-and-image-renamer;
      userHome = config.users.users.${cfg.user}.home;
    in
    {
      imports = [ inputs.file-and-image-renamer.nixosModules.file-and-image-renamer ];

      config = lib.mkIf cfg.enable {
        services.file-and-image-renamer = {
          # Prod shape: run as the primary user so ~/Downloads and ~/Pictures
          # are watchable (also: an overridden user is never auto-created by
          # the upstream module — primaryUser exists by definition). State
          # stays under the home .file-renamer dir the binary has always
          # used; CQRS_DB_PATH/LOG_DIR now pin it explicitly instead of
          # relying on the old coincidence.
          user = lib.mkDefault primaryUser;
          dataDir = lib.mkDefault "${userHome}/.file-renamer";
          healthAddr = lib.mkDefault "127.0.0.1:${toString ports.file-and-image-renamer-health}";
          # Upstream's watcherHealthAddr default (127.0.0.1:8087) collides
          # with browser-history's registered port — the 2026-10-29 gen-965
          # restart race EADDRINUSE-killed browser-history. Dedicated port.
          watcherHealthAddr = lib.mkDefault "127.0.0.1:${toString ports.file-and-image-renamer-watcher}";
          # OTel traces -> local SigNoz OTLP/HTTP collector (host:port, no
          # scheme - the OTel SDK builds the URL; noop tracer when null).
          otelEndpoint = lib.mkDefault "localhost:${toString ports.signoz-otlp-http}";
        };

        # Service-integration registry entry: fans out to the Caddy vHost
        # (Layer 2 protected), the Gatus health check, and the homepage tile
        # - replaces rows in caddy.nix / gatus-config.nix / homepage.nix.
        services.integration = lib.optionalAttrs (options ? services.integration) {
          file-and-image-renamer = {
            inherit (cfg) enable;
            subdomain = "renamer";
            port = ports.file-and-image-renamer-health;
            vHost.layer = "protected";
            checks = [
              {
                name = "File Renamer Health";
                group = "Productivity";
                url = "http://localhost:${toString ports.file-and-image-renamer-health}/status";
                interval = "60s";
                conditions = [
                  "[STATUS] == 200"
                  "[RESPONSE_TIME] < 500"
                ];
                alert = "File and Image Renamer health dashboard down - screenshot renaming may be stuck";
              }
            ];
            homepage = {
              name = "File Renamer";
              group = "Productivity";
              description = "AI-Powered File & Image Renaming";
              # filebot.png: bundled icon pack has no 'mdi-*' mdi-style icons;
              # filebot is the canonical self-hosted file-rename tool icon.
              icon = "filebot.png";
            };
          };
        };
      };
    };
}
