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

      # The upstream flake's packages for this system. The `?` guard on the
      # ROCm build below keeps evaluation working against a lock that predates
      # the nsfw-classifier-go-rocm package (added 2026-10-15): an old lock
      # silently keeps the CPU build, a bumped lock picks up GPU inference.
      flakePkgs = inputs.nsfw-classifier.packages.${pkgs.stdenv.hostPlatform.system};

      pkg = cfg.package;

      # FULL posture: --all loads EVERY NSFW-detection model exported in
      # modelsDir (17 of 18 registry entries — jiechau is product-moderation
      # and excluded upstream). Registry ORDER is preserved
      # (cli.AvailableModelsOnDisk iterates registry.NSFWDetectionModels()),
      # so keys[0] stays falconsai: the extension's fast=true quick-scan
      # still gets a single-model verdict from it; non-fast/stream requests
      # run the whole ensemble vote. Explicit model lists remain available
      # by setting models to a non-null list (a lean deterministic posture).
      # The aux evidence stack (nudenet/skinseg/face) is disk-gated and
      # independent of this flag.
      execStart = lib.concatStringsSep " " (
        [
          "${pkg}/bin/nsfw-server"
          "--host 0.0.0.0"
          "--port ${toString cfg.port}"
        ]
        ++ lib.optionals (cfg.models != null) [
          "--models ${lib.concatStringsSep "," cfg.models}"
        ]
        ++ lib.optionals (cfg.models == null) [ "--all" ]
        ++ [
          "--models-dir ${cfg.modelsDir}"
          "--pair-token auto"
        ]
        ++
          lib.optionals (cfg.stateRoot != null)
            # ADR-0016 (upstream docs/adr/0016): durable stores belong in the
            # STATE root — /var/cache's contract is "deletable to reclaim
            # space", which is the wrong home for irreplaceable feedback
            # (golden human labels), the DNS-feed evidence journal, and
            # unrepeatable capture history. verdicts.db stays in cache
            # (recomputable by design), as do feedback.jsonl (rebuilt from the
            # journal when missing) and the pair token (auto re-pair). null =
            # upstream cache-dir defaults (pre-migration rollback = set null).
            [
              "--feedback-db ${cfg.stateRoot}/feedback.db"
              "--domain-db ${cfg.stateRoot}/domains.db"
              "--history-db ${cfg.stateRoot}/history.db"
              "--history-dir ${cfg.stateRoot}/history"
            ]
      );
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
          type = lib.types.nullOr (lib.types.listOf lib.types.str);
          default = null;
          description = ''
            Model keys to load. null (default) passes --all: EVERY
            NSFW-detection model exported under models/<key>/model.onnx
            loads, in registry order (first entry serves fast=true
            quick-scan requests — falconsai today). A non-null list pins a
            lean deterministic posture instead. jiechau (product
            moderation) is never auto-loaded.
          '';
        };

        # NOT lib.mkPackageOption: that helper resolves its default as an
        # attrpath inside `pkgs`, but this package comes from the
        # nsfw-classifier flake input, not nixpkgs.
        #
        # x86_64 prefers the ROCm-wrapped build: this host class is AMD
        # (Strix Halo), and the CPU-wrapped package's ONNX Runtime (the
        # Microsoft release) cannot enable MIGraphX — every model silently
        # falls back to CPU inference. That ran unnoticed while the box was
        # idle until 2026-10-15, when sibling-session load pushed CPU
        # fast-mode inference to 5-15s and the browser extension's 10s
        # upload timeout failed every classify (journal: "auto-detected
        # provider unavailable, falling back to CPU" per model, every
        # restart since at least Oct 7). The `?` guard keeps an old lock
        # (pre-rocm-package) evaluating on the CPU build. Verify after
        # deploy: /metrics "provider":"rocm" and provider_cpu_fallbacks 0.
        # vendorHash: NO consumer shim. The 2026-10-28 float briefly needed
        # one for the floated rev 1e95693 (spec aP3tjRj8, got tRYzmtvJ), but
        # that rev does not COMPILE upstream (half-wired F0.3 telemetry —
        # see the rev pin comment in flake.nix), so the input is pinned back
        # to 58d398dc whose baked hash is green. Re-add ONLY via nix-hash-fix
        # evidence if a future float re-stales this FOD.
        package = lib.mkOption {
          type = lib.types.package;
          default =
            if pkgs.stdenv.hostPlatform.isx86_64 && flakePkgs ? nsfw-classifier-go-rocm then
              flakePkgs.nsfw-classifier-go-rocm
            else
              flakePkgs.nsfw-classifier-go;
          defaultText = lib.literalExpression "inputs.nsfw-classifier.packages.\${pkgs.stdenv.hostPlatform.system}.nsfw-classifier-go-rocm";
          description = "Package providing the nsfw-server binary (defaults to the flake input's ROCm build on x86_64, CPU build otherwise).";
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

        stateRoot = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = "/var/lib/nsfw-classifier/state";
          description = ''
            State root for the DURABLE domain stores (feedback, domains,
            history) per upstream ADR-0016: placement follows value class,
            and these are the artifacts whose loss is NOT cheap recovery.
            Rendered as StateDirectory + explicit --feedback-db/--domain-db/
            --history-db/--history-dir flags. null restores the upstream
            cache-dir defaults (migration rollback). verdicts.db, the
            feedback.jsonl mirror, and the pair token ALWAYS stay in the
            cache dir (recomputable/regenerable by design).
          '';
        };

        watchdogSec = lib.mkOption {
          type = lib.types.nullOr lib.types.int;
          default = null;
          description = ''
            WatchdogSec budget: restart the unit when the binary stops
            re-arming the watchdog (hung boot, wedged cgo inference — the
            2026-10-18 postmortem class). The binary speaks sd_notify
            (READY=1 at serve start, STOPPING=1 at drain, WATCHDOG=1 at
            WATCHDOG_USEC/2 while serving; upstream
            internal/server/sdnotify.go, 2026-10-25). null (default) keeps
            the unit Type=simple with no watchdog; any value flips the unit
            to Type=notify (systemd only delivers NOTIFY_SOCKET to notify
            units). Budget generously: cold start loads every model and
            MIGraphX compiles per session (measured minutes, boot budgets
            in the runbook) — 300 is the recommended floor.
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
          # The unified CLI on PATH: `nsfw` (classify/benchmark/evaluate/...)
          # resolves to the SAME package the unit runs, so interactive
          # subcommands share its ROCm/CPU ONNX Runtime wrapping. bin also
          # carries the nsfw-server/nsfw-classify/... compat shims.
          environment.systemPackages = [ cfg.package ];

          systemd.services.nsfw-classifier = {
            description = "nsfw-classifier — NSFW image server (browser-extension backend, full ensemble)";
            wantedBy = [ "multi-user.target" ];
            # NO network-online.target: loopback-only binder behind Caddy, all
            # 17 ONNX models local on disk (network-online sweep 2026-10-17).
            startLimitBurst = 5;
            startLimitIntervalSec = 300;
            # Cold start loads 17 ONNX models on CPU — the global 3-min
            # DefaultTimeoutStartSec is the queued watch-class trap; give
            # the full posture an explicit budget (TimeoutStartSec is a
            # [Unit]-section key in modern systemd).
            unitConfig.TimeoutStartSec = "10min";
            # ~/projects reader-writer (2026-10-28 projects-subvol plan D6):
            # the models checkout lives under ~/projects — fail loud when the
            # Samsung subvol mount is absent (never serve from the stale @
            # shadow). Conditional on the mount being declared.
            unitConfig.RequiresMountsFor =
              lib.optionals (builtins.hasAttr "/home/lars/projects" config.fileSystems)
                [ "/home/lars/projects" ];
            # Unit failures page via the notify-failure template (Discord) —
            # registry convention: silent failures are unacceptable.
            inherit onFailure;

            # Binds the port BEFORE loading models (fast-fail on port-in-use),
            # so Type=simple is sufficient; /readyz gates readiness during
            # model load + warmup.
            serviceConfig = lib.mkMerge [
              {
                # sd_notify is only delivered to notify units, so the
                # watchdog option flips the type; without it (default) the
                # shape is unchanged: simple + /readyz readiness.
                Type = if cfg.watchdogSec != null then "notify" else "simple";
                WatchdogSec = lib.mkIf (cfg.watchdogSec != null) cfg.watchdogSec;
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
                # Durable stores live in the STATE root (ADR-0016): feedback
                # is irreplaceable golden data, domains/history are
                # unrepeatable observations — the cache dir's deletability
                # contract must never apply to them. 0700: history blobs are
                # sensitive browsing-derived images.
                StateDirectory = lib.mkIf (cfg.stateRoot != null) "nsfw-classifier/state";
                StateDirectoryMode = lib.mkIf (cfg.stateRoot != null) "0700";
              }
              (serviceDefaults { })
              (harden {
                # Full ensemble: 17 NSFW models (~6.3G fp32 weights) + ONNX
                # arenas under parallel inference, plus the aux evidence
                # stack. Was 2G (single model), then 4G (trio).
                MemoryMax = "16G";
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
                icon = "frigate.png";
              };
            };
          };
        })
      ];
    };
}
