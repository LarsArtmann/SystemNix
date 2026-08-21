# PapDashboard — event-sourced alert hub with NPU insight enricher
#
# Architecture (smart alerting, 2026-08):
#
#   Gatus ──(raw fast-path)──────────────────────────► Discord
#      │
#      └─(custom alerting provider, POST /api/ingest)► PapDashboard
#                                                        │ alert lifecycle (UI/SSE)
#                                                        ▼
#                                          insight enricher (this service)
#                                          correlates storm → collects evidence
#                                          (journalctl + HTTP metrics) → asks
#                                          FastFlowLM (NPU) for root cause →
#                                          publishes sourceApp="insight"
#                                                        │
#                                                        ▼
#                                          outbound Discord (FILTERED to
#                                          PAP_NOTIFY_SOURCE_APPS=insight)
#
# The raw Gatus→Discord path stays untouched (no single point of failure):
# if PapDashboard dies, raw alerts still flow. PapDashboard's outbound is
# filtered to insights only and targets its OWN webhook (sops
# papdashboard_insights_webhook_url), so raw alerts and LLM insights land
# in two separate Discord channels.
#
# The UI has no built-in auth (only the ingest API is key-gated) — external
# access goes through protectedVHost (Layer 2 SSO); LAN access is open.
#
# FastFlowLM cold-loads 2-5 min on first insight request (socket activation
# on :52625 wakes the model; v1.0.2 weights are 21.6 GB) — hence the generous
# default LLM timeout (upstream 300s default is marginal at the boundary).
{
  inputs,
  ...
}:
{
  flake.nixosModules.papdashboard =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.papdashboard;
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceDefaults
        onFailure
        serviceTypes
        mkSecretCheck
        ioTier
        ports
        ;

      papdashboardPkg = inputs.papdashboard.packages.${pkgs.stdenv.hostPlatform.system}.server;

      checkEnv = mkSecretCheck pkgs {
        name = "papdashboard-env";
        secretPath = config.sops.templates."papdashboard-env".path;
        message = "papdashboard: environment file is missing or empty (${
          config.sops.templates."papdashboard-env".path
        }) — API-key-gated ingest and outbound Discord will misbehave";
      };
    in
    {
      options.services.papdashboard = {
        enable = lib.mkEnableOption "PapDashboard alert hub with NPU insight enricher";

        package = lib.mkOption {
          type = lib.types.package;
          default = papdashboardPkg;
          description = "PapDashboard server package.";
        };

        port = serviceTypes.servicePort ports.papdashboard "HTTP port for PapDashboard";

        environment = lib.mkOption {
          type = lib.types.enum [
            "production"
            "development"
          ];
          default = "production";
          description = "PAP_ENV for the server (development enables extra debug routes).";
        };

        llmBaseUrl = lib.mkOption {
          type = lib.types.str;
          default = "http://127.0.0.1:${toString ports.fastflowlm}/v1";
          description = "OpenAI-compatible LLM API root for insight generation (FastFlowLM NPU).";
        };

        llmModel = lib.mkOption {
          type = lib.types.str;
          default = "qwen3.6-moe:35b-a3b";
          description = "Model name for insight generation.";
        };

        journalUnits = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "gatus.service"
            "caddy.service"
            "dnsblockd.service"
          ];
          description = "systemd units whose recent journal entries are collected as LLM evidence.";
        };

        evidenceURLs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "node-metrics=http://localhost:${toString ports.signoz-node-exporter}/metrics"
          ];
          description = ''Extra evidence endpoints as "label=url" entries (comma-joined into PAP_INSIGHT_EVIDENCE_URLS).'';
        };

        notifySourceApps = lib.mkOption {
          type = lib.types.str;
          default = "insight";
          description = "Comma-separated sourceApp allowlist for OUTBOUND notifications (insights only by default).";
        };
      };

      config = lib.mkIf cfg.enable {
        systemd.services.papdashboard = {
          description = "PapDashboard — alert hub with NPU insight enricher";
          wantedBy = [ "multi-user.target" ];
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          inherit onFailure;

          startLimitBurst = 5;
          startLimitIntervalSec = 300;

          environment = {
            PAP_ENV = cfg.environment;
            # OTel traces → local SigNoz OTLP/HTTP collector (Go otlptracehttp,
            # bare host:port). Noop until the binary links the otel package.
            OTEL_EXPORTER_OTLP_ENDPOINT = lib.mkDefault "localhost:${toString ports.signoz-otlp-http}";
            PAP_NOTIFY_SOURCE_APPS = cfg.notifySourceApps;
            PAP_INSIGHT_ENABLED = "true";
            PAP_INSIGHT_LLM_BASE_URL = cfg.llmBaseUrl;
            PAP_INSIGHT_LLM_MODEL = cfg.llmModel;
            # Evidence collection (insight enricher)
            PAP_INSIGHT_JOURNALCTL_PATH = "/run/current-system/sw/bin/journalctl";
            PAP_INSIGHT_JOURNAL_UNITS = lib.concatStringsSep "," cfg.journalUnits;
            PAP_INSIGHT_EVIDENCE_URLS = lib.concatStringsSep "," cfg.evidenceURLs;
          };

          serviceConfig = lib.mkMerge [
            {
              ExecStart = lib.getExe' cfg.package "server";
              ExecStartPre = [ "${checkEnv}/bin/check-papdashboard-env" ];
              EnvironmentFile = [ config.sops.templates."papdashboard-env".path ];
              # DynamicUser: no persistent uid; StateDirectory owns /var/lib/papdashboard.
              # systemd-journal supplementary group grants read access to the
              # journal files the insight enricher collects as evidence.
              DynamicUser = true;
              StateDirectory = "papdashboard";
              SupplementaryGroups = [ "systemd-journal" ];
              Environment = [
                "PAP_PORT=${toString cfg.port}"
                "PAP_DB_PATH=/var/lib/papdashboard/papdashboard.db"
                "GOMEMLIMIT=384MiB"
              ];
            }
            (harden { MemoryMax = "512M"; })
            (serviceDefaults { })
            ioTier.background
          ];
        };
      };
    };
}
