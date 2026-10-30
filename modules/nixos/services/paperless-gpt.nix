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
      fastflowlmEnabled = config.services.fastflowlm.enable or false;
      llamaChatEnabled = config.services.llama-chat.enable or false;
      # ai-meter metering proxy (2026-10-16): when enabled, LLM traffic
      # routes through the loopback proxy (attribution + token metering;
      # only the base URL changes, the upstream follows llmUpstream). The
      # proxy key arrives via the runtime-minted env file; it OVERRIDES
      # the dummy OPENAI_API_KEY below (EnvironmentFile beats Environment).
      aiMeterEnabled = config.services.ai-meter.enable or false;

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
        # LLM: OpenAI-compatible local server, directly or through ai-meter
        # when the metering proxy is enabled. Upstream default is llama-chat
        # (see the llmUpstream option for the FastFlowLM evidence).
        LLM_PROVIDER = "openai";
        LLM_MODEL =
          if cfg.llmUpstream == "llama-chat" then
            (config.services.llama-chat.alias or "qwen3.6-35b-a3b-aggressive")
          else
            config.services.fastflowlm.model;
        OPENAI_BASE_URL =
          if aiMeterEnabled then
            "http://127.0.0.1:${toString ports.ai-meter}/v1/${cfg.llmUpstream}"
          else if cfg.llmUpstream == "llama-chat" then
            "http://127.0.0.1:${toString (config.services.llama-chat.port or ports.llama-chat)}/v1"
          else
            "http://127.0.0.1:${toString config.services.fastflowlm.port}/v1";
        OPENAI_API_KEY = "local-no-auth";
        # Prompt budget. Upstream defaults TOKEN_LIMIT=0 (unbounded), which
        # let a single document plus the 235-name correspondent list produce
        # prompts far past the model's window. 6000 leaves room for the
        # templates and the vocabulary lists inside a 32k context, and keeps
        # per-call cost bounded (six calls per document).
        TOKEN_LIMIT = toString cfg.tokenLimit;
        CORRESPONDENT_PROMPT_LIMIT = toString cfg.correspondentPromptLimit;
        # Suggestion language pinned to the archive's majority language,
        # matching PAPERLESS_AI_LLM_OUTPUT_LANGUAGE in paperless.nix (A11).
        # Covers 4 of 5 *.Language template slots and every tag/type prompt.
        LLM_LANGUAGE = "German";
        # Tag-gating: documents enter processing ONLY via the auto tag.
        # Nothing happens to untagged documents. AUTO_TAG_COMPLETE marks
        # processed docs; FAIL_TAG breaks the retry loop after max retries.
        # The names MUST be the upstream SCREAMING_SNAKE_CASE identifiers
        # (main.go reads os.Getenv("AUTO_TAG") and friends). A plain
        # `inherit (cfg) autoTag ...` renders `Environment="autoTag=..."`,
        # which the daemon never reads: every tag name silently fell back to
        # the upstream default. Those defaults equal our values, which is why
        # the bug stayed invisible, but any option change was a no-op
        # (audit 2026-10-29: /api/config reported AUTO_TAG=None while the
        # unit carried only `autoTag=paperless-gpt-auto`).
        MANUAL_TAG = cfg.manualTag;
        AUTO_TAG = cfg.autoTag;
        AUTO_TAG_COMPLETE = cfg.autoTagComplete;
        FAIL_TAG = cfg.failTag;
        AUTO_TAG_MAX_RETRIES = toString cfg.autoTagMaxRetries;
        # Generation switches, pinned explicitly: upstream defaults all of
        # them to true, so this changes no behaviour and makes the intent
        # inspectable in /api/config (the audit found them unset, which reads
        # as "no metadata extraction"). Document types come from the
        # EXISTING paperless vocabulary only, never invented.
        AUTO_GENERATE_TITLE = "true";
        AUTO_GENERATE_TAGS = "true";
        AUTO_GENERATE_CORRESPONDENTS = "true";
        AUTO_GENERATE_DOCUMENT_TYPE = "true";
        AUTO_GENERATE_CREATED_DATE = "true";
        # Bounded-write posture (Stage-A spirit from the AI-max plan):
        # suggest only EXISTING tags (no unbounded tag creation) and never
        # clobber manual metadata.
        CREATE_NEW_TAGS = lib.boolToString cfg.createNewTags;
        PRESERVE_EXISTING_METADATA = lib.boolToString cfg.preserveExistingMetadata;
      }
      // (lib.optionalAttrs (cfg.ocrProvider == "llm") {
        # Vision-OCR route DEAD since the ollama removal (2026-10-12):
        # upstream shares OPENAI_BASE_URL between main+vision LLMs, so the
        # ollama provider was the only separately-pointable vision route.
        # The OLLAMA_HOST throw below fails the eval LOUDLY if anyone sets
        # ocrProvider = "llm" before a replacement lands (llama-vlm bridge
        # or an upstream base-URL split) — never silently target a dead port.
        OCR_PROVIDER = "llm";
        VISION_LLM_PROVIDER = "ollama";
        VISION_LLM_MODEL = cfg.visionModel;
        OLLAMA_HOST = "http://127.0.0.1:${toString (throw "paperless-gpt vision-OCR (ocrProvider = llm) is dead since the ollama removal 2026-10-12 — re-point the vision route at a live LLM (llama-vlm bridge or upstream OPENAI_BASE_URL split) before enabling")}";
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

        # --- LLM route (2026-10-29 audit) -------------------------------------
        # llama-chat is the DEFAULT because FastFlowLM is not usable as the
        # metadata workhorse: it is a socket-activated NPU server whose
        # context is small enough that a ~1.5k-token prompt does not error
        # out, it HANGS (600 s timeout) and then dies with the documented
        # v1.0.2 heap bug (`double free or corruption (!prev)`, SIGABRT,
        # live-proven 2026-10-29). Extraction sends six prompts per document
        # including the whole tag/correspondent/type vocabulary, so it needs
        # a large-context, always-on server. llama-chat carries 32k and is
        # the same model paperless-triage already verdicts with (owner
        # single-endpoint direction, 2026-10-27).
        llmUpstream = lib.mkOption {
          type = lib.types.enum [
            "llama-chat"
            "fastflowlm"
          ];
          default = "llama-chat";
          description = ''
            Which local OpenAI-compatible upstream serves the extraction
            prompts. `llama-chat` (default) is always-on with a 32k window;
            `fastflowlm` is the NPU server, smaller/faster per token but
            socket-activated and crash-prone above ~1k prompt tokens.
          '';
        };

        tokenLimit = lib.mkOption {
          type = lib.types.ints.positive;
          default = 6000;
          description = ''
            Upstream TOKEN_LIMIT: total prompt budget per call (0 upstream
            means unbounded). Content is truncated to whatever is left after
            the template and vocabulary lists.
          '';
        };

        correspondentPromptLimit = lib.mkOption {
          type = lib.types.ints.positive;
          default = 80;
          description = ''
            Upstream CORRESPONDENT_PROMPT_LIMIT: how many correspondent names
            are shown to the model (0 = the whole list). The archive has 235
            correspondents, whose names alone would consume most of a prompt.
          '';
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
        # URL does not exist upstream. The working shape WAS the OLLAMA
        # provider path — DEAD since the ollama removal (2026-10-12, owner
        # directive: bad abstraction on top of llama.cpp). Do NOT wire
        # VISION_LLM_PROVIDER=openai here; re-decide the vision route
        # (llama-vlm bridge or upstream base-URL split) before using "llm".
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
          description = "Vision model for the LLM OCR rescue path (DEAD route since the ollama removal 2026-10-12 — enabling ocrProvider = llm fails eval until the vision route is re-decided; see the OLLAMA_HOST throw above).";
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
            assertion = if cfg.llmUpstream == "llama-chat" then llamaChatEnabled else fastflowlmEnabled;
            message =
              if cfg.llmUpstream == "llama-chat" then
                "services.paperless-gpt with llmUpstream = \"llama-chat\" requires services.llama-chat.enable: extraction prompts are served by the always-on 32k-context chat server"
              else
                "services.paperless-gpt with llmUpstream = \"fastflowlm\" requires services.fastflowlm.enable: prompts are served by the NPU model (small context, socket-activated)";
          }
        ];

        users.users.${cfg.user} = {
          isSystemUser = true;
          inherit (cfg) group;
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
            # The previous mint's ExecStartPost chowns this file to the gpt
            # user at 0400 (daemon reads it) — the next mint's O_TRUNC then
            # EPERMs as the paperless user (2026-10-03 16:18 activation
            # failure). Unlink first: the RuntimeDirectory is paperless-
            # owned, so rm works even when the file itself is not
            # (geometrikks alembic.ini class, same day).
            rm -f "$MINT_OUT"
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
          ]
          ++ lib.optionals aiMeterEnabled [ "ai-meter.service" ]
          ++ lib.optionals (cfg.llmUpstream == "llama-chat") [ "llama-chat.service" ];
          wants = [
            "network-online.target"
            "paperless-web.service"
          ]
          ++ lib.optionals aiMeterEnabled [ "ai-meter.service" ]
          ++ lib.optionals (cfg.llmUpstream == "llama-chat") [ "llama-chat.service" ];
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
              EnvironmentFile = [
                runtimeEnvFile
              ]
              ++ lib.optionals aiMeterEnabled [ "/run/ai-meter-keys/paperless-gpt.env" ];
            }
            (harden {
              MemoryMax = "512M";
            })
            (serviceDefaults { })
            ioTier.background
          ];
        };

        # --- Declarative entity ensure (2026-10-27, triage-plan T6) --------
        # The gpt lifecycle tags + the accounting pilot's custom fields are
        # runtime state a DB restore silently wipes (live probe 2026-10-27:
        # paperless-gpt-auto, faktura, Invoice number, Issue date ALL absent
        # after the 2026-10-19 SUPERB restore — runbook DRIFT box). Declared
        # here, ensured create-only by the paperless-dashboard provisioner on
        # every deploy. Select-type pilot fields stay undeclared (manual /
        # workflow-assigned — runbook accounting section).
        services.paperless-dashboard = lib.optionalAttrs (options ? services.paperless-dashboard) {
          ensureTags = [
            cfg.autoTag
            cfg.autoTagComplete
            cfg.failTag
            "faktura"
          ];
          ensureCustomFields = [
            {
              name = "Invoice number";
              data_type = "string";
            }
            {
              name = "Issue date";
              data_type = "date";
            }
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
