# Runbook: docs/services/ai-meter.md
# ai-meter — transparent metering proxy for every AI call on this host.
#
# All OpenAI-compatible traffic (crush providers, paperless-gpt, inboxclean,
# future consumers) flows through ONE loopback endpoint that meters tokens,
# cost, latency and per-client attribution without changing any model name
# or request shape. Routing is path-based:
#
#   http://127.0.0.1:<port>/v1/<upstream>/chat/completions
#
# so a consumer's model vocabulary stays identical (crush still sends
# "glm-5.3-flash" to provider "zai"; only the provider base URL changes).
#
# Surfaces:
#   :8107  proxy (loopback, per-client Bearer keys required)
#   :8108  admin (Prometheus /metrics + /health; scraped by SigNoz)
#
# Secrets doctrine:
#   - UPSTREAM provider keys: sops-declared COPIES owned by the ai-meter
#     user (crush.yaml's zai/gemini — independent of the source
#     blocks' enablement). openrouter upstream dropped 2026-10-17: its
#     openrouter_api_key was never set in openseo.yaml, so the sops
#     manifest validation refused the copy — re-add only after setting
#     that key. kimi removed 2026-10-27 (owner directive: do not use
#     anymore; zero traffic since the deploy).
#   - CLIENT keys: RUNTIME-MINTED by the ai-meter-keys oneshot
#     (openssl rand, /run/ai-meter-keys, 0400 per consumer user) — the
#     bank-sync runtime-mint pattern; NO client key ever exists in the
#     repo or in sops. Keys live for the boot; consumers read them at
#     start (daemons) or per session (crush via $(cat) in the crushrc).
#     TWO COPIES per client: the consumer copy (consumer-user-owned 0400)
#     and an ai-meter-owned mirror at /run/ai-meter-keys/config/<name>
#     (0400) — the daemon authenticates ONLY against the mirror; it
#     cannot read consumer-owned files (the 2026-10-17 VM start-loop
#     this two-copy mint closed).
#
# Origin: the 2026-10-16 Agent Router evaluation (docs/research/
# 2026-10-16_agent-router-deep-dive.html) — owner wants metrics + metering
# for ALL AI calls; Agent Router's packaging cost (no nixpkgs package,
# func-e Envoy downloads) buys governance features this single-user host
# does not need. This proxy is the exact-scope replacement.
_: {
  flake.nixosModules.ai-meter =
    {
      config,
      options,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.services.ai-meter;
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceDefaults
        serviceOneshotDefaults
        onFailure
        ports
        ;

      stateDir = "/var/lib/ai-meter";
      keysDir = "/run/ai-meter-keys";

      # Same derivation as `nix build .#ai-meter` (identical src + pkgs file on
      # both call sites → identical store path — the paperless-gpt doctrine).
      pkg = pkgs.callPackage ../../../pkgs/ai-meter.nix {
        src = lib.sources.cleanSource ../../../pkgs/ai-meter;
      };

      primaryUser = config.users.primaryUser;

      # Cloud upstreams (secrets via sops placeholders) + local OpenAI-compat
      # servers (key "unused" — they ignore Authorization). Local ports come
      # from the registry, not the owning modules' options, so this list stays
      # a pure function of lib/ports.nix.
      upstreams = [
        {
          name = "zai";
          # Coding-plan endpoint, NOT the general /api/paas/v4 one: the
          # account bills via a GLM Coding Plan (Max Yearly) resource
          # package that only applies here. The general endpoint has zero
          # pay-as-you-go balance, so it 429s with code 1113 "Insufficient
          # balance or no resource package" (verified 2026-10-17; coding
          # endpoint returned 200 for glm-5.3 and glm-5.3-flash, general
          # 1113). This also matches crush's built-in zai provider default.
          # The plan covers exactly glm-5.3 + glm-5.3-flash (older ids
          # auto-route; docs.z.ai/devpack/overview); concurrency is
          # unpublished ("Max > Pro > Lite", dynamically adjusted).
          base_url = "https://api.z.ai/api/coding/paas/v4";
          api_key = "${config.sops.placeholder.ai-meter-zai-key}";
        }
        {
          # NATIVE Google transport (crush's gemini provider rides
          # google-genai-sdk): bare host — clients append
          # v1beta/models/<model>:streamGenerateContent themselves — and
          # the key forwards as X-Goog-Api-Key (native endpoints reject
          # Bearer API keys). Probe evidence: docs/todo/ai-stack.md gemini
          # row.
          name = "gemini";
          base_url = "https://generativelanguage.googleapis.com";
          api_key = "${config.sops.placeholder.ai-meter-gemini-key}";
          auth_style = "x-goog-api-key";
        }
        {
          name = "llama-chat";
          base_url = "http://127.0.0.1:${toString ports.llama-chat}/v1";
          api_key = "unused";
        }
        {
          name = "fastflowlm";
          base_url = "http://127.0.0.1:${toString ports.fastflowlm}/v1";
          api_key = "unused";
        }
        {
          name = "llama-embeddings";
          base_url = "http://127.0.0.1:${toString ports.llama-embeddings}/v1";
          api_key = "unused";
        }
      ];

      proxyConfig = builtins.toJSON {
        listen = "127.0.0.1:${toString cfg.port}";
        metrics_listen = "127.0.0.1:${toString cfg.metricsPort}";
        ledger_path = "${stateDir}/usage.jsonl";
        inject_stream_usage = true;
        # Daemon reads the ai-meter-owned mirror copies (see mintScript) —
        # never the consumer-owned 0400 originals.
        clients = lib.mapAttrsToList (name: _client: {
          inherit name;
          key_file = "${keysDir}/config/${name}";
        }) cfg.clients;
        inherit upstreams;
        costs = lib.mapAttrs (_: cost: {
          inherit (cost) input;
          inherit (cost) output;
          cached_input = cost.cachedInput;
        }) cfg.costs;
      };

      clientList = lib.mapAttrsToList (name: client: {
        inherit name;
        inherit (client) user envKey;
      }) cfg.clients;

      # Runtime client-key mint: idempotent per boot, root-owned oneshot.
      # Existing keys are NEVER regenerated (running daemons hold them in
      # memory; a silent rotation would 401 every consumer until restart).
      # Each key is mirrored ai-meter-owned into config/ so the daemon can
      # read it; `install` re-syncs the mirror on every run, so the pair can
      # never diverge.
      mintScript = pkgs.writeShellScript "ai-meter-keys-mint" (
        ''
          set -eu
          umask 077
          mkdir -p ${keysDir}
          chmod 0711 ${keysDir}
          # Daemon-mirror dir: root-owned but group-traversable by ai-meter —
          # the daemon reads mirrors via its group; the mint (root) writes via
          # ownership. Never ai-meter-owned: sandboxed root could not create
          # files inside it.
          mkdir -p ${keysDir}/config
          chown root:ai-meter ${keysDir}/config
          chmod 0750 ${keysDir}/config
        ''
        + lib.concatMapStringsSep "\n" (
          client:
          let
            keyFile = "${keysDir}/${client.name}";
            daemonKeyFile = "${keysDir}/config/${client.name}";
            envFile = "${keysDir}/${client.name}.env";
          in
          ''
            if [ ! -s ${lib.escapeShellArg keyFile} ]; then
              ${lib.getExe pkgs.openssl} rand -hex 24 > ${lib.escapeShellArg keyFile}
              echo "ai-meter-keys: minted client key for ${client.name}"
            fi
            chown ${lib.escapeShellArg client.user}: ${lib.escapeShellArg keyFile}
            chmod 0400 ${lib.escapeShellArg keyFile}
            install -o ai-meter -g ai-meter -m 0400 ${lib.escapeShellArg keyFile} ${lib.escapeShellArg daemonKeyFile}
          ''
          + lib.optionalString (client.envKey != null) ''
            if [ ! -s ${lib.escapeShellArg envFile} ]; then
              printf '%s=%s\n' ${lib.escapeShellArg client.envKey} "$(cat ${lib.escapeShellArg keyFile})" > ${lib.escapeShellArg envFile}
            fi
            chown ${lib.escapeShellArg client.user}: ${lib.escapeShellArg envFile}
            chmod 0400 ${lib.escapeShellArg envFile}
          ''
        ) clientList
      );
    in
    {
      # Platform-truth catalog entry (ADR-008): unconditional — describes what
      # EXISTS platform-wide. Hosts/VMs importing this module MUST co-import
      # nixosModules.catalog (loud eval failure otherwise).
      imports = [
        {
          services.catalog.ai-meter = {
            subdomain = null;
            inherit (cfg) port;
            description = "AI metering proxy for all OpenAI-compatible calls (loopback-only, no vHost)";
            healthPath = "/health";
          };
        }
      ];

      options.services.ai-meter = {
        enable =
          lib.mkEnableOption "ai-meter transparent metering proxy for OpenAI-compatible AI calls"
          // {
            default = false;
          };

        package = lib.mkOption {
          type = lib.types.package;
          default = pkg;
          description = "ai-meter package (in-tree Go source, pkgs/ai-meter).";
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = ports.ai-meter;
          description = "Loopback port for the metering proxy.";
        };

        metricsPort = lib.mkOption {
          type = lib.types.port;
          default = ports.ai-meter-metrics;
          description = "Loopback port for the admin plane (/metrics + /health).";
        };

        clients = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              options = {
                user = lib.mkOption {
                  type = lib.types.str;
                  description = "User owning this client's key file (the consumer process's user).";
                };
                envKey = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = ''
                    When set, an additional KEY=value env file is minted at
                    /run/ai-meter-keys/<name>.env for systemd EnvironmentFile
                    consumption (e.g. "OPENAI_API_KEY"). null mints only the
                    raw key file (crush reads it via $(cat) in the crushrc).
                  '';
                };
              };
            }
          );
          default = {
            crush.user = primaryUser;
          };
          description = "Consuming apps. Each gets a runtime-minted proxy key keyed to its name for attribution.";
        };

        costs = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              options = {
                input = lib.mkOption {
                  type = lib.types.float;
                  default = 0.0;
                  description = "USD per 1M prompt tokens.";
                };
                output = lib.mkOption {
                  type = lib.types.float;
                  default = 0.0;
                  description = "USD per 1M completion tokens.";
                };
                cachedInput = lib.mkOption {
                  type = lib.types.float;
                  default = 0.0;
                  description = "USD per 1M cached prompt tokens (subset of prompt).";
                };
              };
            }
          );
          default = {
            # PAYG reference prices (docs.z.ai/guides/overview/pricing,
            # verified 2026-10-17). NOTE: both models are covered by the
            # GLM Coding Plan (Max Yearly), which bills credits, not
            # tokens — real marginal spend is $0. These entries are
            # deliberate REFERENCE costs (what the traffic would cost
            # pay-as-you-go), chosen by the owner 2026-10-17 for
            # visibility; spend panels therefore overstate real
            # subscription spend by design. glm-5.3-flash mirrors the
            # crushrc model declaration (crush-config model add
            # zai/glm-5.3-flash --price-input 0.15 --price-output 0.5
            # --price-cache-hit 0.03). Extend per model as consumers adopt
            # them; unknown models meter tokens exactly and cost $0.
            "glm-5.3" = {
              input = 1.4;
              output = 4.4;
              cachedInput = 0.26;
            };
            "glm-5.3-flash" = {
              input = 0.15;
              output = 0.5;
              cachedInput = 0.03;
            };
          };
          description = "Per-model cost table (USD per 1M tokens). Best-effort: tokens are always exact, cost only for known models.";
        };

        configFile = lib.mkOption {
          type = lib.types.path;
          readOnly = true;
          description = "Rendered proxy config (sops template; placeholders decrypted at activation).";
        };
      };

      config = lib.mkIf cfg.enable {
        services.ai-meter.configFile = config.sops.templates."ai-meter-config".path;

        users.users.ai-meter = {
          isSystemUser = true;
          group = "ai-meter";
          home = stateDir;
          description = "ai-meter metering proxy";
        };
        users.groups.ai-meter = { };

        # --- Upstream provider keys (sops copies owned by the service user) --
        # Same encrypted keys as the crush/openseo blocks, re-declared so this
        # module never breaks if those blocks become enablement-guarded.
        sops.secrets = builtins.listToAttrs (
          map
            (
              {
                name,
                sopsFile ? ../../../platforms/nixos/secrets/crush.yaml,
                key,
              }:
              {
                name = "ai-meter-${name}-key";
                value = {
                  inherit sopsFile key;
                  owner = "ai-meter";
                  group = "ai-meter";
                  restartUnits = [ "ai-meter.service" ];
                };
              }
            )
            [
              {
                name = "zai";
                key = "zai_api_key";
              }
              {
                name = "gemini";
                key = "gemini_api_key";
              }
            ]
        );

        sops.templates."ai-meter-config" = {
          owner = "ai-meter";
          group = "ai-meter";
          mode = "0400";
          restartUnits = [ "ai-meter.service" ];
          content = proxyConfig;
        };

        # --- Runtime client-key mint -----------------------------------------
        systemd.services.ai-meter-keys = {
          description = "ai-meter - runtime client key mint";
          wantedBy = [ "multi-user.target" ];
          before = [ "ai-meter.service" ];
          inherit onFailure;
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              RemainAfterExit = true;
              # writeShellScript's store path IS the executable (no bin/).
              ExecStart = "${mintScript}";
              RuntimeDirectory = "ai-meter-keys";
              RuntimeDirectoryMode = "0711";
              # Re-runs (deploy convergence) must not wipe consumer keys:
              # the dir lives for the boot, not the unit activation.
              RuntimeDirectoryPreserve = true;
              # The mint chowns keys to consumer users and to ai-meter, and
              # chmods files it no longer owns (install runs chown BEFORE
              # chmod; consumer loop runs chmod after chown) — impossible
              # under harden's empty default bounding set. A chown-to-ROOT
              # target is a kernel no-op that hides this (the first VM run
              # passed mint with a root client; the prod-shape clients would
              # have failed). Exactly a provisioner's three caps:
              #   CAP_CHOWN        - hand keys to consumer users / ai-meter
              #   CAP_DAC_OVERRIDE - re-open 0400 mirrors on converging re-runs
              #   CAP_FOWNER       - chmod files already chowned away
              CapabilityBoundingSet = [
                "CAP_CHOWN"
                "CAP_DAC_OVERRIDE"
                "CAP_FOWNER"
              ];
            }
            (harden { ProtectSystem = "strict"; })
            (serviceOneshotDefaults { })
          ];
        };

        # --- Daemon ------------------------------------------------------------
        systemd.services.ai-meter = {
          description = "ai-meter - metering proxy for OpenAI-compatible AI calls";
          after = [
            "network-online.target"
            "ai-meter-keys.service"
          ];
          wants = [ "network-online.target" ];
          requires = [ "ai-meter-keys.service" ];
          wantedBy = [ "multi-user.target" ];
          inherit onFailure;
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          serviceConfig = lib.mkMerge [
            {
              User = "ai-meter";
              Group = "ai-meter";
              StateDirectory = "ai-meter";
              StateDirectoryMode = "0700";
              ExecStart = "${lib.getExe cfg.package} -config ${cfg.configFile}";
              RestartSec = "3s";
            }
            (harden { MemoryMax = "256M"; })
            (serviceDefaults { })
          ];
        };

        # --- Registry entry: loopback-only, monitored, NO vHost ----------------
        services.integration = lib.optionalAttrs (options ? services.integration) {
          ai-meter = {
            inherit (cfg) enable port;
            vHost.layer = "none";
            monitored = true;
            checks = [
              {
                name = "ai-meter";
                group = "AI";
                url = "http://localhost:${toString cfg.port}/health";
                interval = "60s";
                conditions = [
                  "[STATUS] == 200"
                  "[RESPONSE_TIME] < 500"
                ];
                alert = "ai-meter proxy down - all routed AI calls (crush, paperless-gpt, inboxclean) are failing. Check: journalctl -u ai-meter -n 50";
              }
              {
                # Functional: the admin plane must actually EXPOSE the metering
                # families (presence check; values are per-call).
                name = "ai-meter metrics";
                group = "AI";
                url = "http://localhost:${toString cfg.metricsPort}/metrics";
                interval = "60s";
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] == pat(*ai_meter_requests_total*)"
                ];
                alert = "ai-meter admin plane down - metering metrics are not scrapeable. Check: journalctl -u ai-meter -n 50";
              }
            ];
          };
        };
      };
    };
}
