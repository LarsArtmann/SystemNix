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
{ inputs, ... }: {
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
        mkStateDir
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
          # Turso returns persistent 403 "SQL read operations are forbidden" on
          # the current plan, so the sync engine falls back to local-only mode
          # after every failed push/pull. A local-only `sqlite` backend was
          # attempted, but it caused the startup thumb-hash backfill to take
          # 40+ minutes (likely FTS5 trigger contention with projection workers
          # on a single connection) versus ~21 minutes with `turso-sync`. Until
          # the upstream SQLite backend is optimized, keep `turso-sync`: the
          # 403 errors are log noise only and the service runs fully local.
          # Revert to `turso-sync` is also the fallback if the Turso plan is
          # upgraded and cloud replication is desired.
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
            # OTel traces → local SigNoz OTLP/HTTP collector. The binary
            # installs a noop tracer when this is unset. otlptracehttp.WithEndpoint
            # expects host:port WITHOUT scheme — the SDK constructs the full URL
            # internally (http://<endpoint>/v1/traces). WithInsecure() = plain HTTP.
            OTEL_EXPORTER_OTLP_ENDPOINT = "localhost:${toString ports.signoz-otlp-http}";
          }
          // lib.optionalAttrs (cfg.gcsBucket != null) {
            GCS_BUCKET = cfg.gcsBucket;
            GOOGLE_APPLICATION_CREDENTIALS = config.sops.secrets.discordsync_gcs_credentials.path;
          };

          serviceConfig = lib.mkMerge [
            {
              ExecStartPre = "+${lib.getExe waitDnsReady}";
              # NO ExecStartPost readiness gate: the API server binds in a
              # goroutine AFTER thumb-hash backfill completes (3139+ attachments
              # at ~7/sec = 5-11 min). ExecStartPost runs immediately after
              # ExecStart, so any /readyz probe during backfill kills the
              # service via systemd timeout → crash loop. Health monitoring is
              # delegated to Gatus (60s interval) which correctly handles the
              # startup delay. See AGENTS.md "DiscordSync API startup race".
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
        systemd.tmpfiles.rules = [
          (mkStateDir cfg.dataDir "2770" cfg.user cfg.group)
          (mkStateDir "${cfg.dataDir}/attachments" "2770" cfg.user cfg.group)
        ];
      };
    };
}
