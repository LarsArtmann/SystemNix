# Runbook: docs/services/nsfw-classifier.md
# nsfw-classifier — native Nix service for the Go/ONNX NSFW image
# classifier (flake input nsfw-classifier).
#
# Purpose: the browser extension (auto-loaded into helium via
# --load-extension in platforms/common/packages/base.nix) pairs with its
# backend with ZERO user engagement: with default settings it probes
# nsfw.home.lan:<port> (then localhost:8080), requires a pairing token from
# /readyz, and sends X-Pair-Token on every classify. This module supplies
# that backend — a fast-mode single-model nsfw-server bound to all
# interfaces with --pair-token auto. See nsfw-extension/url-utils.js
# (DEFAULT_SERVER_URLS, pairingTokenFromReadyz) for the client half of the
# contract.
#
# Models are NOT in the store (multi-GB, gitignored): the unit reads the
# live checkout at /home/lars/projects/nsfw-classifier/models read-only —
# the same live-checkout contract as the extension load path. That is also
# why the unit runs as User "lars" (the checkout sits under a 0700 home).
{ inputs, ... }:
{
  flake.nixosModules.nsfw-classifier =
    {
      config,
      lib,
      options,
      pkgs,
      ...
    }:
    let
      libHelpers = import ../../../lib/default.nix lib;
      inherit (libHelpers)
        harden
        serviceDefaults
        ioTier
        ports
        ;

      cfg = config.services.nsfw-classifier;

      pkg = inputs.nsfw-classifier.packages.${pkgs.stdenv.hostPlatform.system}.nsfw-classifier-go;
      modelsDir = "/home/lars/projects/nsfw-classifier/models";

      # Fast mode (single model, minimum latency) — exactly what the
      # extension's quick-scan path wants. falconsai is the registry's
      # DefaultModels[0] (the same model `--fast` would pick implicitly);
      # passing it explicitly keeps the unit deterministic if the registry
      # default ever reorders.
      execStart = lib.concatStringsSep " " [
        "${pkg}/bin/nsfw-server"
        "--host 0.0.0.0"
        "--port ${toString cfg.port}"
        "--fast"
        "--models ${cfg.model}"
        "--models-dir ${modelsDir}"
        "--pair-token auto"
      ];
    in
    {
      options.services.nsfw-classifier = {
        enable = lib.mkEnableOption ''
          nsfw-classifier — Go/ONNX NSFW image server on nsfw.home.lan
          (browser-extension backend, fast mode, pairing-token gated)
        '';

        port = lib.mkOption {
          type = lib.types.port;
          default = ports.nsfw;
          description = "HTTP port; the extension's discovery candidate list hardcodes nsfw.home.lan:<port>.";
        };

        model = lib.mkOption {
          type = lib.types.str;
          default = "falconsai";
          description = "Single model key for --fast mode (must be exported under models/<key>/model.onnx).";
        };
      };

      config = lib.mkMerge [
        # Platform-truth catalog entry (ADR-008): unconditional — nsfw exists
        # platform-wide even where the service is disabled. The inline
        # optionalAttrs module keeps the guard-shape surgical on hosts
        # without catalog.nix.
        (lib.optionalAttrs (options ? services.catalog) {
          services.catalog.nsfw = {
            subdomain = "nsfw";
            port = ports.nsfw;
            description = "nsfw-classifier — NSFW image server (browser-extension backend)";
            healthPath = "/readyz";
          };
        })

        (lib.mkIf cfg.enable {
          systemd.services.nsfw-classifier = {
            description = "nsfw-classifier — NSFW image server (browser-extension backend, fast mode)";
            wantedBy = [ "multi-user.target" ];
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            startLimitBurst = 5;
            startLimitIntervalSec = 300;

            # Binds the port BEFORE loading models (fast-fail on port-in-use),
            # so Type=simple is sufficient; /readyz gates readiness during
            # model load + warmup.
            serviceConfig = lib.mkMerge [
              {
                Type = "simple";
                ExecStart = execStart;
                # The models checkout lives under a 0700 home — only lars can
                # traverse it (DynamicUser cannot; see header comment).
                User = "lars";
                # Pairing token, verdict cache, and feedback JSONL persist via
                # os.UserCacheDir → XDG_CACHE_HOME → /var/cache/nsfw-classifier
                # (systemd creates it; owner lars). Stable across restarts so
                # the extension stays paired. LIST form — signoz-coverage
                # walks serviceConfig.Environment as a list.
                CacheDirectory = "nsfw-classifier";
                Environment = [ "XDG_CACHE_HOME=/var/cache" ];
              }
              (serviceDefaults { })
              (harden {
                MemoryMax = "2G";
                # ProtectHome must stay OFF: the multi-GB gitignored models
                # checkout is the unit's only non-store input and sits under
                # /home/lars. Everything else stays locked down (ProtectSystem
                # "strict" + private tmp + no new privs from harden defaults).
                ProtectHome = false;
                ProtectSystem = "strict";
              })
              ioTier.background
            ];
          };

          # Service-integration registry entry: the nsfw vHost (Layer 1
          # plain — the classify API's auth layer IS the pairing token; a
          # forward-auth gate would break the extension's direct :port
          # clients), unit-state monitoring, and the Gatus readiness check.
          services.integration = lib.optionalAttrs (options ? services.integration) {
            nsfw-classifier = {
              inherit (cfg) enable;
              subdomain = "nsfw";
              inherit (cfg) port;
              vHost.layer = "plain";
              monitored = true;
              checks = [
                {
                  name = "nsfw-classifier";
                  group = "AI";
                  path = "/readyz";
                }
              ];
              homepage = {
                name = "NSFW Filter";
                group = "AI";
                description = "Image NSFW classifier — browser-extension backend";
              };
            };
          };
        })
      ];
    };
}
