# Runbook: docs/services/nsfw-classifier.md
# nsfw-classifier — native Nix service for the Go/ONNX NSFW image
# classifier (flake input nsfw-classifier).
#
# DELEGATED to the upstream module (inputs.nsfw-classifier.nixosModules.default,
# repo nix/nixos-module.nix — extracted 2026-10-18 FROM this module for
# exactly this delegation): options, unit definition, hardening, package
# selection (ROCm/CPU), state/cache directories all live upstream. This
# file layers ONLY the SystemNix-specific concerns, per the
# DiscordSync/Monitor365 pattern (docs/agents/integration-registry.md):
#   - port from the central registry, lars/user + live-checkout pinning
#     (protectHome = false, modelsDir under ~/projects)
#   - post-crash calm-gate ordering (freeze #40-#48 recovery-boot storm)
#   - ~/projects mount gating (Samsung subvol shadow-mount class)
#   - onFailure alert routing + ioTier (BFQ)
#   - TimeoutStartSec moved to serviceConfig with the upstream unitConfig
#     placement neutralized (class-9 audit + the 2026-11-05 switch-journal
#     "Unknown key 'TimeoutStartSec' in section [Unit]" warning)
#   - catalog + integration registry entries, gatus-coverage exemption
#   - the nightly `nsfw immich` triage units (ADR-061: deployment-only
#     wiring — deliberately NOT upstreamed)
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
        serviceDefaults
        serviceOneshotDefaults
        ioTier
        ports
        onFailure
        ;

      cfg = config.services.nsfw-classifier;

      # The upstream flake's packages for this system. The `?` guard on the
      # ROCm build below keeps evaluation working against a lock that predates
      # the nsfw-classifier-go-rocm package (added 2026-10-15): an old lock
      # silently keeps the CPU build, a bumped lock picks up GPU inference.
      flakePkgs = inputs.nsfw-classifier.packages.${pkgs.stdenv.hostPlatform.system};

      # Post-crash calm gate deps (options-guarded: single-module VM tests
      # importing only nsfw-classifier stay self-contained; evo-x2 carries
      # the gate enabled — freezes #40–#48 recovery-boot storm wiring,
      # 2026-11-05. The 17-ONNX cold start read 3.9 GB in the first 120 s
      # of the freeze-#48 recovery boot, stacked with five other GB-scale
      # cold readers on the QLC root).
      calmGateDeps = lib.optionals (
        (options ? services.post-crash-calm-gate) && config.services.post-crash-calm-gate.enable
      ) [ "post-crash-calm-gate.service" ];

      # ~/projects mount gate, shared by the server unit and the immich
      # scan (2026-10-28 projects-subvol plan D6): the models checkout
      # lives under ~/projects — fail loud when the Samsung subvol mount is
      # absent (never serve from the stale @ shadow). Conditional on the
      # mount being declared.
      projectsMountGate =
        lib.optionals (builtins.hasAttr "/home/lars/projects" config.fileSystems)
          [ "/home/lars/projects" ];
    in
    {
      imports = [ inputs.nsfw-classifier.nixosModules.default ];

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

        # gatus-coverage exemption (2026-11-08): the health-dashboard
        # federation remote + rediscover sweep reference 8104 by name — the
        # sweep itself probes it (/health /readyz /healthz) so the audit's
        # "never probed" premise is false there. UNCONDITIONAL (not inside
        # mkIf enable): the sweep bakes the port literal on hosts where the
        # classifier is disabled too, which is exactly the reference the
        # audit flags. Scoped to this one port; every other port stays
        # audited.
        {
          services.gatus-coverage-audit.allowPorts = [ ports.nsfw ];
        }

        (lib.mkIf cfg.enable {
          services.nsfw-classifier = {
            # SystemNix port catalog default (extension discovery contract:
            # nsfw.home.lan:<port>; upstream default 8080 is the fallback
            # candidate, not the primary).
            port = lib.mkDefault ports.nsfw;
            # Live-checkout deployment shape (upstream defaults target a
            # dedicated user + /var/lib models — NOT this deployment):
            # models sit under a 0700 home, so the unit runs as the
            # checkout-owning user with home protection off, and the
            # dashboard's group is the home group, not the (uncreated
            # upstream-default) nsfw-classifier group.
            user = lib.mkDefault "lars";
            group = lib.mkDefault "users";
            modelsDir = lib.mkDefault "/home/lars/projects/nsfw-classifier/models";
            protectHome = false;
            # Old-lock tolerance the upstream default lacks: `?` on the
            # ROCm package keeps a pre-2026-10-15 lock evaluating on the
            # CPU build. vendorHash: NO consumer shim. The 2026-10-28 float
            # briefly needed one for the floated rev 1e95693 (spec aP3tjRj8,
            # got tRYzmtvJ), but that rev does not COMPILE upstream
            # (half-wired F0.3 telemetry — see the rev pin comment in
            # flake.nix), so the input is pinned back to 58d398dc whose
            # baked hash is green. Re-add ONLY via nix-hash-fix evidence if
            # a future float re-stales this FOD.
            package = lib.mkDefault (
              if pkgs.stdenv.hostPlatform.isx86_64 && flakePkgs ? nsfw-classifier-go-rocm then
                flakePkgs.nsfw-classifier-go-rocm
              else
                flakePkgs.nsfw-classifier-go
            );
          };

          systemd.services.nsfw-classifier = {
            # Behind the post-crash calm gate (2026-11-05): the ONNX ensemble
            # cold load is a measured boot-storm reader; on a refused boot the
            # extension degrades to no-verdict (graceful), and the next calm
            # window admits it.
            after = calmGateDeps;
            requires = calmGateDeps;
            # ~/projects reader (mount-gate, see projectsMountGate).
            unitConfig.RequiresMountsFor = projectsMountGate;
            # Unit failures page via the notify-failure template (Discord) —
            # registry convention: silent failures are unacceptable.
            inherit onFailure;
            serviceConfig = lib.mkMerge [
              (serviceDefaults { })
              ioTier.background
            ];
            # TimeoutStartSec: upstream-owned since the 2026-11-08 fix
            # (serviceConfig section, 10min — the old unitConfig copy was
            # neutralized here via mkForce null; both sides dropped at the
            # re-lock past nsfw-classifier@<fix>).
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
              ]
              # The silent-CPU guard (2026-10-15 incident): /api/health is
              # the public machine twin (same exemption as /health — no
              # pairing token needed) and reports the EFFECTIVE inference
              # provider. On the ROCm default build any "cpu" here means
              # every model fell back at session build (journal WARN per
              # model) — verdicts keep flowing but 10-50x slower, which is
              # exactly how the incident hid for a week. x86_64-only: on
              # other hosts the CPU build is the correct answer, so the
              # condition would false-alarm.
              ++ lib.optionals pkgs.stdenv.hostPlatform.isx86_64 [
                {
                  name = "nsfw-classifier-provider";
                  group = "AI";
                  path = "/api/health";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*\"provider\":\"rocm\"*)"
                  ];
                  alert = "NSFW classifier fell back to CPU inference — verdicts are 10-50x slower and the extension's fast path will time out under load. Check journalctl -u nsfw-classifier for 'falling back to CPU' per model, /metrics provider_cpu_fallbacks, and that the unit runs the -rocm package — runbook: docs/services/nsfw-classifier.md (GPU runtime section)";
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

          # ── Nightly `nsfw immich` triage (media-atlas v0.1 plan C7) ────────
          # Classify NEW Immich assets and write the verdicts back as
          # nsfw:* tags — the verdict PRODUCER the media-atlas lane join
          # (04:00 `atlas pull --with-lanes`) reads the same night. The CLI
          # is upstream `nsfw immich` verbatim (ADR-061: the classifier
          # repo stays change-free): incremental via the provenance marker
          # (--only-new), resumable checkpoint under the cache dir,
          # fail-open per asset. Calendar 01:00 → poll 02:00 → umap 03:00
          # → lane join 04:00 on evo-x2. Deployment-only wiring — NOT part
          # of the upstream module.
          systemd.services.nsfw-immich-scan = lib.mkIf (cfg.enable && cfg.immichScan.enable) {
            description = "nsfw-classifier — nightly Immich triage (classify new assets, write nsfw:* tags)";
            inherit onFailure;
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            # The models checkout lives under ~/projects — same
            # mount-gate as the server unit (fail loud on the stale
            # shadow-subvol class).
            unitConfig.RequiresMountsFor = projectsMountGate;
            startLimitBurst = 3;
            startLimitIntervalSec = 3600;
            # First full pass over a five-figure library is HOURS of
            # GPU inference (the nightly re-runs are minutes —
            # --only-new); Persistent=true catches up a missed night.
            # [Service]-section key (unitConfig placement is silently
            # ignored — same class as the server unit's 2026-11-05
            # switch-journal warning).
            path = [ pkgs.coreutils ];
            serviceConfig = lib.mkMerge [
              {
                TimeoutStartSec = "6h";
                Type = "oneshot";
                # Same user as the server: modelsDir traverses a 0700
                # home, and the checkpoint rides the shared cache dir.
                User = cfg.user;
                CacheDirectory = "nsfw-classifier";
                Environment = [ "XDG_CACHE_HOME=/var/cache" ];
                StateDirectory = "nsfw-classifier/state";
                StateDirectoryMode = "0700";
                ExecStart = lib.concatStringsSep " " (
                  [
                    "${cfg.package}/bin/nsfw immich"
                    "--url ${cfg.immichScan.url}"
                    "--api-key-file ${cfg.immichScan.apiKeyFile}"
                    "--models-dir ${cfg.modelsDir}"
                    "--only-new"
                    "--report /var/lib/nsfw-classifier/state/immich-scan-$(date +%F).json"
                  ]
                  ++ cfg.immichScan.extraArgs
                );
              }
              # Ensemble inference ≈ the server's footprint (the CLI
              # loads the same 17-model posture); BE/6 for the model
              # load + preview-download IO, inference itself is GPU.
              (harden {
                MemoryMax = "16G";
                ProtectHome = false;
                ProtectSystem = "strict";
              })
              ioTier.background
              (serviceOneshotDefaults { })
            ];
          };

          systemd.timers.nsfw-immich-scan = lib.mkIf (cfg.enable && cfg.immichScan.enable) {
            description = "Nightly nsfw Immich triage";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnCalendar = cfg.immichScan.calendar;
              Persistent = true;
              RandomizedDelaySec = "15m";
            };
          };
        })
      ];

      options.services.nsfw-classifier.immichScan = {
        # ADR-061: the nightly Immich triage is DEPLOYMENT wiring (media-atlas
        # lane pipeline), deliberately not part of the upstream module — the
        # classifier repo stays change-free. Options live here because the
        # scan units below are SystemNix-owned.
        enable = lib.mkEnableOption ''
          the nightly `nsfw immich` triage — classify NEW Immich assets and
          write the verdicts back as nsfw:* tags (the media-atlas lane
          join reads those tags nightly at 04:00; ADR-061: the classifier
          repo stays change-free, this is deployment-only wiring)
        '';

        calendar = lib.mkOption {
          type = lib.types.str;
          default = "*-*-* 01:00";
          description = "OnCalendar for the scan (before the media-atlas 02:00 poll → 04:00 lane join, so fresh verdicts land in the same night's lanes).";
        };

        url = lib.mkOption {
          type = lib.types.str;
          default = "http://127.0.0.1:2283";
          description = "Immich API base URL the scan triages.";
        };

        apiKeyFile = lib.mkOption {
          type = lib.types.str;
          description = ''
            Immich API key file for the scan — must carry asset read
            (previews) AND tag write (the verdicts). NOT the hub's
            read-only key; mint a dedicated key (Immich shows it once at
            creation) and install it 0400 under the state root.
          '';
        };

        extraArgs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Extra flags for `nsfw immich` (e.g. \"--album\" \"NSFW review\" or visibility filters).";
        };
      };
    };
}
