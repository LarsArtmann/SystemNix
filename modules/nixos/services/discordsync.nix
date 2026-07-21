# DiscordSync — SystemNix wrapper around upstream nixos-module.
#
# The upstream module (inputs.discordsync.nixosModules.default) provides every
# option (enable, package, user, group, discordTokenFile, dataDir, backend,
# databasePath, tursoUrl, tursoAuthTokenFile, backfillOnStartup, apiAddr,
# apiKeyFile, healthCheck) plus the systemd service with strong hardening and a
# SIGHUP ExecReload. This file layers ONLY the SystemNix-specific concerns on
# top: sops template wiring, DNS-gate, onFailure alert routing, GCS attachment
# backup option, OTel tracing, and a correct readiness gate (upstream's is
# malformed — see healthCheck note below).
{ inputs, ... }:
{
  flake.nixosModules.discordsync =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      inherit (import ../../../lib/default.nix lib)
        harden
        ports
        onFailure
        ;
      cfg = config.services.discordsync;
      discordsyncPkg = inputs.discordsync.packages.${pkgs.stdenv.hostPlatform.system}.default;
      sopsEnvPath = config.sops.templates."discordsync-env".path;

      waitDnsReady = pkgs.writeShellApplication {
        name = "discordsync-wait-dns";
        runtimeInputs = [ pkgs.curl ];
        text = ''
          echo "discordsync: waiting for DNS resolution..."
          curl -sf --max-time 5 --retry 60 --retry-delay 2 --retry-all-errors \
            -o /dev/null "https://discord.com" \
            || { echo "discordsync: DNS/network not ready after 120s — dnsblockd may not be initialized" >&2; exit 1; }
          echo "discordsync: DNS resolution ready"
        '';
      };
    in
    {
      imports = [ inputs.discordsync.nixosModules.default ];

      options.services.discordsync = {
        # Opt-in GCS attachment backup. Upstream has no equivalent option; the
        # binary reads GCS_BUCKET + GOOGLE_APPLICATION_CREDENTIALS env vars.
        gcsBucket = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "GCS bucket name for cloud attachment backup (requires discordsync_gcs_credentials sops secret)";
        };
      };

      config = lib.mkIf cfg.enable {
        services.discordsync = {
          package = lib.mkDefault discordsyncPkg;
          backend = lib.mkDefault "turso-sync";
          backfillOnStartup = lib.mkDefault true;
          apiAddr = lib.mkDefault "127.0.0.1:${toString ports.discordsync-api}";
          # Upstream's ExecStartPost curls http://localhost:${cfg.apiAddr}/readyz
          # which expands to http://localhost:127.0.0.1:8085/readyz — a malformed
          # URL (three colon-separated authority parts). Disabled here; a correct
          # readiness gate is wired in serviceConfig.ExecStartPost below.
          # TODO: drop this override once upstream fixes the URL template.
          healthCheck = lib.mkDefault false;
          # Both token paths point to the single sops template (contains
          # DISCORD_TOKEN, TURSO_URL, TURSO_AUTH_TOKEN). The duplicate entry in
          # upstream's EnvironmentFile list is harmless (systemd re-parses).
          discordTokenFile = lib.mkDefault sopsEnvPath;
          tursoAuthTokenFile = lib.mkDefault sopsEnvPath;
        };

        systemd.services.discordsync = {
          # SystemNix DNS-gate: dnsblockd must resolve before Discord connect.
          after = [
            "sops-nix.service"
            "dnsblockd.service"
          ];
          wants = [
            "sops-nix.service"
            "dnsblockd.service"
          ];
          inherit onFailure;
          startLimitBurst = lib.mkForce 10; # SystemNix uses 10 (upstream is 5)

          environment = {
            # Preserve subdir layout (upstream uses dataDir root).
            ATTACHMENT_STORAGE_PATH = lib.mkForce "${cfg.dataDir}/attachments";
          } // lib.optionalAttrs (cfg.gcsBucket != null) {
            GCS_BUCKET = cfg.gcsBucket;
            GOOGLE_APPLICATION_CREDENTIALS = config.sops.secrets.discordsync_gcs_credentials.path;
          };

          serviceConfig = lib.mkMerge [
            {
              ExecStartPre = "+${lib.getExe waitDnsReady}";
              # Correct /readyz gate (upstream's is malformed — see healthCheck).
              ExecStartPost = [
                "${pkgs.curl}/bin/curl --fail --silent --show-error --retry 5 --retry-delay 2 --retry-all-errors --max-time 10 http://${cfg.apiAddr}/readyz"
              ];
            }
            (harden {
              # Backfill bursts + turso-sync need more than upstream's 512M.
              MemoryMax = lib.mkForce "2G";
              ReadWritePaths = [ cfg.dataDir ];
            })
          ];
        };

        # Pre-create the attachments subdir with correct ownership.
        # (Upstream creates dataDir only — the subdir is a SystemNix convention.)
        system.activationScripts."discordsync-setup" =
          lib.stringAfter
            (
              [ "users" ]
              ++ lib.optional (config.system.activationScripts ? setupSecrets) "setupSecrets"
            )
            ''
              mkdir -p ${cfg.dataDir}/attachments
              chown -R ${cfg.user}:${cfg.group} ${cfg.dataDir}
              chmod 2770 ${cfg.dataDir} ${cfg.dataDir}/attachments
            '';
      };
    };
}
