# Runbook: docs/services/paperless.md (AI section)
# paperless-gpt — AI metadata enrichment + custom-field extraction bridge
# for Paperless-ngx (github:icereed/paperless-gpt, MIT, packaged from the
# tag-pinned paperless-gpt-src flake input in pkgs/paperless-gpt.nix).
#
# Why this exists: paperless-ngx's NATIVE AI (v3.x) suggests title/tags/
# correspondent/type — but custom fields are NOT an AI suggestion target in
# any upstream version, and upstream has zero rerank support. paperless-gpt
# adds: tag-gated background processing (AUTO_TAG), custom-field extraction
# (Append/Update/Replace write modes), and an optional LLM-OCR rescue path
# for tesseract-failing scans (vision leg disabled until the A16 eval).
#
# Security posture:
#   - LOOPBACK ONLY (LISTEN_INTERFACE=127.0.0.1) — the embedded web UI has
#     NO built-in auth; a vHost.layer must NEVER be set on the registry
#     entry. AI-session access goes through paperless itself.
#   - The paperless API token is RUNTIME-MINTED (bank-sync pattern): the
#     paperless-gpt-token oneshot runs drf_create_token as the paperless
#     OS user (peer-auth PG) and drops a 0400 env file into tmpfs. Zero
#     secrets in sops, zero tokens in the store.
#   - The LLM is FastFlowLM on loopback with a dummy OPENAI_API_KEY
#     (langchaingo requires a key; flm ignores Authorization entirely).
#
# Runtime layout (binary writes RELATIVE TO ITS WORKING DIRECTORY):
#   /var/lib/paperless-gpt/prompts/   prompt templates (copied from
#                                     default_prompts/ on first run)
#   /var/lib/paperless-gpt/config/    settings.json (web-UI-saved defaults)
#   /var/lib/paperless-gpt/db/        gorm sqlite (modification history)
#   /var/lib/paperless-gpt/default_prompts/  seeded from the package
{ inputs, ... }: {
  flake.nixosModules.paperless-gpt =
    {
      config,
      options,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.services.paperless-gpt;
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceDefaults
        serviceOneshotDefaults
        onFailure
        ioTier
        ports
        ;

      paperlessCfg = config.services.paperless;
      paperlessPort = paperlessCfg.port;
      fastflowlmEnabled = (config.services.fastflowlm.enable or false);

      stateDir = "/var/lib/paperless-gpt";
      runtimeEnvFile = "/run/paperless-gpt/env";

      # Same derivation as `nix build .#paperless-gpt` (identical src input
      # + pkgs file on both call sites → identical store path).
      pkg = pkgs.callPackage ../../../pkgs/paperless-gpt.nix {
        src = inputs.paperless-gpt-src;
      };

      # Runtime token mint (bank-sync-paperless-token pattern): idempotent
      # drf_create_token as the paperless user, tmpfs-only storage, then a
      # `+`-privileged chown so the daemon user can read its 0400 env file.
      tokenChownScript = pkgs.writeShellScript "paperless-gpt-token-chown" ''
        chown ${cfg.user}:${cfg.group} ${runtimeEnvFile}
        chmod 0400 ${runtimeEnvFile}
      '';

      daemonEnvironment = {
        PAPERLESS_BASE_URL = "http://127.0.0.1:${toString paperlessPort}";
        LISTEN_INTERFACE = "127.0.0.1:${toString cfg.port}";
        GIN_MODE = "release";
        LOG_LEVEL = cfg.logLevel;
        # LLM: FastFlowLM (OpenAI-compatible, ignores Authorization).
        LLM_PROVIDER = "openai";
        LLM_MODEL = config.services.fastflowlm.model;
        OPENAI_BASE_URL = "http://127.0.0.1:${toString config.services.fastflowlm.port}/v1";
        OPENAI_API_KEY = "fastflowlm-local-no-auth";
        # Suggestion language pinned to the archive's majority language,
        # matching PAPERLESS_AI_LLM_OUTPUT_LANGUAGE in paperless.nix (A11).
        LLM_LANGUAGE = "German";
        # Tag-gating: documents enter processing ONLY via the auto tag —
        # nothing happens to untagged documents. AUTO_TAG_COMPLETE marks
        # processed docs; FAIL_TAG breaks the retry loop after max retries.
        inherit (cfg) manualTag autoTag autoTagComplete failTag;
        AUTO_TAG_MAX_RETRIES = toString cfg.autoTagMaxRetries;
        # Bounded-write posture (Stage-A spirit from the AI-max plan):
        # suggest only EXISTING tags (no unbounded tag creation) and never
        # clobber manual metadata.
        CREATE_NEW_TAGS = lib.boolToString cfg.createNewTags;
        PRESERVE_EXISTING_METADATA = lib.boolToString cfg.preserveExistingMetadata;
      }
      // (lib.optionalAttrs (cfg.ocrProvider == "llm") {
        OCR_PROVIDER = "llm";
        VISION_LLM_PROVIDER = "ollama";
        VISION_LLM_MODEL = cfg.visionModel;
        OLLAMA_HOST = "http://127.0.0.1:${toString config.services.ollama.port or 11434}";
        OCR_LIMIT_PAGES = toString cfg.ocrLimitPages;
        OCR_MAX_RETRIES = "3";
      });
    in
    {
      # Platform-truth catalog entry (ADR-008): unconditional — describes
      # what EXISTS platform-wide. Hosts/VMs importing this module MUST
      # co-import nixosModules.catalog (loud eval failure otherwise).
      imports = [
        {
          services.catalog.paperless-gpt = {
            # Loopback-only service: NO DNS presence (subdomain null).
            subdomain = null;
            inherit (cfg) port;
            description = "paperless-gpt AI enrichment bridge (loopback-only, no vHost)";
            healthPath = "/api/filter-tag";
          };
        }
      ];

      options.services.paperless-gpt = {
        enable = lib.mkEnableOption "paperless-gpt AI enrichment bridge for Paperless-ngx" // {
          default = false;
        };

        package = lib.mkOption {
          type = lib.types.package;
          default = pkg;
          description = "paperless-gpt package (built from the tag-pinned paperless-gpt-src input).";
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = ports.paperless-gpt;
          description = "Loopback port for the paperless-gpt web UI + API.";
        };

        user = lib.mkOption {
          type = lib.types.str;
          default = "paperless-gpt";
          description = "User to run the daemon as.";
        };

        group = lib.mkOption {
          type = lib.types.str;
          default = "paperless-gpt";
          description = "Group for the daemon user.";
        };

        logLevel = lib.mkOption {
          type = lib.types.enum [
            "debug"
            "info"
            "warn"
            "error"
          ];
          default = "info";
          description = "Logrus level for the daemon.";
        };

        manualTag = lib.mkOption {
          type = lib.types.str;
          default = "paperless-gpt";
          description = "Tag gating manual (web-UI) processing.";
        };

        autoTag = lib.mkOption {
          type = lib.types.str;
          default = "paperless-gpt-auto";
          description = "Tag gating automatic background processing. Only tagged documents are ever touched.";
        };

        autoTagComplete = lib.mkOption {
          type = lib.types.str;
          default = "paperless-gpt-auto-complete";
          description = "Tag applied when auto-processing completes (empty disables).";
        };

        failTag = lib.mkOption {
          type = lib.types.str;
          default = "paperless-gpt-failed";
          description = "Tag applied when a document exceeds the retry cap.";
        };

        autoTagMaxRetries = lib.mkOption {
          type = lib.types.ints.unsigned;
          default = 3;
          description = "Retry cap per document before the fail tag lands (0 = retry forever; not recommended).";
        };

        createNewTags = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Allow the LLM to CREATE tags that do not exist yet. Off by
            default: bounded suggestions only (existing vocabulary), the
            same anti-pollution posture as the native AI Stage-A workflow.
          '';
        };

        preserveExistingMetadata = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Never overwrite manually-set metadata on processed documents.";
        };

        # --- Vision OCR (A16 surface — DARK by default until the B56 eval) ---
        # CONSTRAINT (verified against paperless-gpt v0.28.0 main.go): the
        # openai vision provider SHARES OPENAI_BASE_URL with the main LLM,
        # so llama-vlm (:8127/:8128) is NOT reachable as the vision backend
        # while the main LLM points at FastFlowLM — a second OpenAI base
        # URL does not exist upstream. The working shape is the OLLAMA
        # provider path against the local ollama daemon (qwen2.5vl:3b is
        # already pulled). Do NOT wire VISION_LLM_PROVIDER=openai here.
        ocrProvider = lib.mkOption {
          type = lib.types.enum [
            "off"
            "llm"
          ];
          default = "off";
          description = ''
            OCR provider for tesseract-failing scans. "off" (default)
            disables the OCR leg entirely; "llm" routes page images
            through the vision model below, tag-gated upstream by
            AUTO_OCR_TAG (paperless-gpt-ocr-auto).
          '';
        };

        visionModel = lib.mkOption {
          type = lib.types.str;
          default = "qwen2.5vl:3b";
          description = "Ollama vision model for the LLM OCR rescue path (ignored while ocrProvider = \"off\"; must exist in the local ollama daemon).";
        };

        ocrLimitPages = lib.mkOption {
          type = lib.types.ints.positive;
          default = 5;
          description = "Pages per document the image-mode OCR path processes (upstream default 5; 0 would mean all — kept positive for bounded cost).";
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = paperlessCfg.enable;
            message = "services.paperless-gpt requires services.paperless.enable: the token mint (paperless-gpt-token) runs drf_create_token against the paperless DB";
          }
          {
            assertion = fastflowlmEnabled;
            message = "services.paperless-gpt requires services.fastflowlm.enable: suggestions are served by the local FastFlowLM NPU model";
          }
        ];

        users.users.${cfg.user} = {
          isSystemUser = true;
          group = cfg.group;
          home = stateDir;
          description = "paperless-gpt service user";
        };
        users.groups.${cfg.group} = { };

        # --- API token mint (runtime, tmpfs-only, zero sops) --------------
        systemd.services.paperless-gpt-token = {
          description = "paperless-gpt - Paperless API token mint";
          # AFTER the scheduler: its preStart runs the DB migrations + the
          # drf token table needs auth_user to EXIST. On a fresh database a
          # bare after=postgresql raced the migrations and died
          # "relation auth_user does not exist" (the engine-switch bootstrap
          # trap, VM-proven 2026-10-02).
          after = [
            "postgresql.service"
            "paperless-scheduler.service"
          ];
          wants = [
            "postgresql.service"
            "paperless-scheduler.service"
          ];
          inherit onFailure;
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          # drf_create_token runs Django checks that write a probe file into
          # the paperless dataDir (paperless checks.py, 2026-09-16 EROFS
          # lesson) — paperless-user identity + write access, mount-gated.
          unitConfig.RequiresMountsFor = [ paperlessCfg.dataDir ];
          path = [
            pkgs.coreutils
            pkgs.gnugrep
          ];
          script = ''
            MINT_OUT=/run/paperless-gpt/env
            umask 077
            token="$(${paperlessCfg.manage}/bin/paperless-manage drf_create_token admin)"
            hex="$(printf '%s\n' "$token" | grep -oE '[0-9a-f]{40}' | head -n1)"
            if [ -z "$hex" ]; then
              echo "paperless-gpt-token: token extraction failed (unexpected drf_create_token output)" >&2
              exit 1
            fi
            printf 'PAPERLESS_API_TOKEN=%s\n' "$hex" > "$MINT_OUT"
          '';
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              # Stay active(exited) after the mint: the daemon's Requires=
              # pulls become no-ops (the llama-rag-model-fetch pattern),
              # deploy.sh re-runs it explicitly to converge a revoked token.
              RemainAfterExit = true;
              User = paperlessCfg.user;
              ReadWritePaths = [ paperlessCfg.dataDir ];
              RuntimeDirectory = "paperless-gpt";
              # 0711: the daemon user must traverse to its 0400 env file.
              RuntimeDirectoryMode = "0711";
              # Default (no) would DELETE the dir when this oneshot
              # deactivates — before the daemon ever reads its
              # EnvironmentFile (bank-sync pattern).
              RuntimeDirectoryPreserve = true;
              TimeoutStartSec = "3min";
              ExecStartPost = "+${tokenChownScript}";
            }
            (harden { ProtectSystem = "strict"; })
            (serviceOneshotDefaults { })
          ];
        };

        # --- Daemon ---------------------------------------------------------
        systemd.services.paperless-gpt = {
          description = "paperless-gpt - AI enrichment bridge for Paperless-ngx";
          after = [
            "network-online.target"
            "paperless-web.service"
            "paperless-gpt-token.service"
          ];
          wants = [
            "network-online.target"
            "paperless-web.service"
          ];
          requires = [ "paperless-gpt-token.service" ];
          wantedBy = [ "multi-user.target" ];
          inherit onFailure;
          startLimitBurst = 5;
          startLimitIntervalSec = 300;

          environment = daemonEnvironment;

          preStart = ''
            set -eu
            # The binary copies prompt templates from default_prompts/ next
            # to its CWD on first run and writes prompts/, config/, db/
            # around it — seed the defaults copy-if-absent (-n), keep
            # operator-edited prompts on redeploy.
            mkdir -p prompts config db
            cp -rn ${pkg}/share/paperless-gpt/default_prompts ./ 2>/dev/null || true
            # paperless-web is Type=simple: "active" before Django binds —
            # poll the login page before the daemon starts polling the API.
            ${pkgs.curl}/bin/curl -sf --retry 30 --retry-delay 2 --retry-all-errors \
              -o /dev/null http://127.0.0.1:${toString paperlessPort}/accounts/login/
          '';

          serviceConfig = lib.mkMerge [
            {
              User = cfg.user;
              Group = cfg.group;
              StateDirectory = "paperless-gpt";
              StateDirectoryMode = "0700";
              WorkingDirectory = stateDir;
              ExecStart = lib.getExe pkg;
              EnvironmentFile = [ runtimeEnvFile ];
            }
            (harden {
              MemoryMax = "512M";
            })
            (serviceDefaults { })
            ioTier.background
          ];
        };

        # --- Registry entry: loopback-only, monitored, NO vHost ------------
        services.integration = lib.optionalAttrs (options ? services.integration) {
          paperless-gpt = {
            inherit (cfg) enable port;
            # NO vHost — the web UI has NO built-in auth. Loopback only.
            vHost.layer = "none";
            monitored = true;
            checks = [
              {
                # /api/filter-tag answers 200 with the manual tag name and
                # needs neither auth nor paperless — a pure liveness probe
                # of the daemon + router.
                name = "paperless-gpt";
                group = "Documents";
                url = "http://localhost:${toString cfg.port}/api/filter-tag";
                interval = "60s";
                conditions = [
                  "[STATUS] == 200"
                  "[RESPONSE_TIME] < 1000"
                ];
                alert = "paperless-gpt daemon down - AI enrichment (auto tag) and custom-field extraction are not running. Check: journalctl -u paperless-gpt -n 50";
              }
            ];
          };
        };
      };
    };
}
