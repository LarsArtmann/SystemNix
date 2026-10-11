# Runbook: docs/services/nsfw-classifier.md
# nsfw-classifier — native Nix service for the Go/ONNX NSFW image
# classifier (flake input nsfw-classifier).
#
# Purpose: the browser extension (auto-loaded into helium via
# --load-extension in platforms/common/packages/base.nix) pairs with its
# backend with ZERO user engagement: with default settings it probes
# nsfw.home.lan:<port> (then localhost:8080), requires a pairing token from
# /readyz, and sends X-Pair-Token on every classify. This module supplies
# that backend — an ensemble nsfw-server (default trio) bound to all
# interfaces with --pair-token auto. Per-request fast=true still gets a
# single-model verdict (the FIRST listed model). See
# nsfw-extension/url-utils.js
# (DEFAULT_SERVER_URLS, pairingTokenFromReadyz) for the client half of the
# contract.
#
# Models are NOT in the store (multi-GB, gitignored): the unit reads the
# live checkout at services.nsfw-classifier.modelsDir read-only — the same
# live-checkout contract as the extension load path. That is also why the
# unit runs as services.nsfw-classifier.user (the default checkout sits
# under a 0700 home).
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
        onFailure
        serviceDefaults
        ioTier
        ports
        ;

      cfg = config.services.nsfw-classifier;

      pkg = cfg.package;

      # Ensemble posture (NO --fast flag): the flag would load ONLY the
      # first model (fastKey takes keys[0]), so the trio is the point. The
      # extension's quick-scan path sends fast=true and still gets a
      # single-model verdict from the FIRST listed model; non-fast/stream
      # requests get the full vote. falconsai stays first (registry
      # DefaultModels[0] — the same model --fast would pick), so the fast
      # path is unchanged; the explicit list keeps the unit deterministic
      # if the registry default ever reorders.
      execStart = lib.concatStringsSep " " [
        "${pkg}/bin/nsfw-server"
        "--host 0.0.0.0"
        "--port ${toString cfg.port}"
        "--models ${lib.concatStringsSep "," cfg.models}"
        "--models-dir ${cfg.modelsDir}"
        "--pair-token auto"
      ];
    in
    {
      options.services.nsfw-classifier = {
        enable = lib.mkEnableOption ''
          nsfw-classifier — Go/ONNX NSFW image server on nsfw.home.lan
          (browser-extension backend, ensemble mode, pairing-token gated)
        '';

        port = lib.mkOption {
          type = lib.types.port;
          default = ports.nsfw;
          description = "HTTP port; the extension's discovery candidate list hardcodes nsfw.home.lan:<port>.";
        };

        models = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "falconsai"
            "marqo"
            "adamcodd"
          ];
          description = ''
            Model keys loaded in ensemble mode (comma-joined into --models;
            each must be exported under models/<key>/model.onnx). The FIRST
            entry serves every fast=true quick-scan request, so it must
            stay falconsai.
          '';
        };

        # NOT lib.mkPackageOption: that helper resolves its default as an
        # attrpath inside `pkgs`, but this package comes from the
        # nsfw-classifier flake input, not nixpkgs.
        package = lib.mkOption {
          type = lib.types.package;
          default = inputs.nsfw-classifier.packages.${pkgs.stdenv.hostPlatform.system}.nsfw-classifier-go;
          defaultText = lib.literalExpression "inputs.nsfw-classifier.packages.\${pkgs.stdenv.hostPlatform.system}.nsfw-classifier-go";
          description = "Package providing the nsfw-server binary (defaults to the nsfw-classifier flake input's build).";
        };

        user = lib.mkOption {
          type = lib.types.str;
          default = "lars";
          description = ''
            User the unit runs as. Must be able to traverse modelsDir (the
            default checkout lives under a 0700 home, which rules out
            DynamicUser).
          '';
        };

        modelsDir = lib.mkOption {
          type = lib.types.str;
          default = "/home/lars/projects/nsfw-classifier/models";
          description = ''
            Directory holding the exported ONNX models. Multi-GB and
            gitignored, so it is deliberately kept OUT of the Nix store and
            read from the live checkout instead.
          '';
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
            description = "nsfw-classifier — NSFW image server (browser-extension backend, default-model ensemble)";
            wantedBy = [ "multi-user.target" ];
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            startLimitBurst = 5;
            startLimitIntervalSec = 300;
            # Unit failures page via the notify-failure template (Discord) —
            # registry convention: silent failures are unacceptable.
            inherit onFailure;

            # Binds the port BEFORE loading models (fast-fail on port-in-use),
            # so Type=simple is sufficient; /readyz gates readiness during
            # model load + warmup.
            serviceConfig = lib.mkMerge [
              {
                Type = "simple";
                ExecStart = execStart;
                # The models checkout lives under a 0700 home — only the
                # configured user can traverse it (DynamicUser cannot; see
                # header comment). Defaults to lars.
                User = cfg.user;
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
                # Ensemble trio (two 86M-class ViTs + marqo 5.7M) loaded in
                # parallel — ~1.5G resident peak; was 2G in the single-model
                # fast posture.
                MemoryMax = "4G";
                # ProtectHome must stay OFF: the multi-GB gitignored models
                # checkout is the unit's only non-store input and sits under
                # /home/lars. Everything else stays locked down (ProtectSystem
                # "strict" + private tmp + no new privs from harden defaults).
                ProtectHome = false;
                ProtectSystem = "strict";
                # LAN network service: it needs IPv4/IPv6 listeners, the
                # kernel netlink family Go's net package uses for interface
                # enumeration, and AF_UNIX for nss/systemd-resolved. Same
                # baseline as dnsblockd, plus AF_UNIX. service-defaults omits
                # this on purpose (family needs are service-specific).
                RestrictAddressFamilies = [
                  "AF_INET"
                  "AF_INET6"
                  "AF_NETLINK"
                  "AF_UNIX"
                ];
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
                  # /readyz is READINESS: 503 while models load/warm (first
                  # check after a cold start is expected red), and it runs no
                  # inference — measured 0.3-10 ms live, so 500 ms is a tight
                  # bound with ample headroom (integration-registry step 9).
                  conditions = [
                    "[STATUS] == 200"
                    "[RESPONSE_TIME] < 500"
                  ];
                  alert = "NSFW classifier down — nsfw.home.lan unreachable (unit failed or model load wedged). Check: systemctl status nsfw-classifier, journalctl -u nsfw-classifier — runbook: docs/services/nsfw-classifier.md";
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
