# Paperless-ngx 3.x document management (OCR, consume, archive, AI) on the
# mirrored pool. Layered on top of the nixpkgs services.paperless module:
#
#  - PostgreSQL (shared with Immich) via database.createLocally — peer-auth
#    unix socket, no password in any store path. Metadata leaves the
#    crash-sensitive SQLite behind while the library is still small.
#  - Tika + Gotenberg (configureTika) — Office documents and e-mail become
#    consumable, not just PDFs/images.
#  - Paperless AI (v3 flagship) against the local NPU LLM (FastFlowLM):
#    title/tag/correspondent suggestions, AI chat, and — once the embedding
#    model is pulled — semantic search over the archive. All traffic stays
#    on localhost.
#  - Trash: deletions park in ${dataDir}/trash for 30 days instead of
#    vanishing instantly.
#  - Barcode separation (PATCHT) + Code-39 ASN tagging for scanner workflows.
#  - Filename format {created_year}/{correspondent}/{title} (private-cloud
#    heritage) with REMOVE_NONE so empty correspondents don't litter paths.
#  - Layer 1 native OIDC SSO via Pocket ID (django-allauth openid_connect):
#    client registered in pocket-id.nix, secret bridged at runtime by the
#    paperless-oidc-setup oneshot, Caddy on plain reverse_proxy.
_: {
  flake.nixosModules.paperless =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (import ../../../lib/default.nix lib)
        harden
        ioTier
        onFailure
        ports
        serviceOneshotDefaults
        ;

      cfg = config.services.paperless;
      inherit (cfg) dataDir;
      llmEndpoint = "http://127.0.0.1:${toString ports.fastflowlm}/v1";
      embeddingEndpoint = "http://127.0.0.1:${toString ports.llama-embeddings}/v1";

      # ── Layer 1 native OIDC via Pocket ID ────────────────────────────────────
      # Optional-dependency refs (dns-blocker `or false` idiom): hosts
      # without the Pocket ID modules degrade to local-login-only instead of
      # failing eval. A silently-disabled bridge is caught by the Gatus
      # login-page condition + the post-deploy SSO-button smoke.
      oidcEnabled = config.services.pocket-id-config.enable or false;
      pocketIdDataDir = config.services.pocket-id.dataDir or "/var/lib/pocket-id";
      oidcEnvFile = "/var/lib/paperless-oidc/pocket-id.env";

      # Outbound email (share links, password-protected archives, account
      # mails) rides the central Postfix null-client relay. Off (VM tests,
      # relay-less hosts) → the PAPERLESS_EMAIL_* block below is omitted and
      # paperless keeps Django's inert localhost default (EMAIL_ENABLED false).
      mailRelayEnabled = config.services.mail-relay.enable or false;
      paperlessUnits = [
        "paperless-consumer.service"
        "paperless-scheduler.service"
        "paperless-task-queue.service"
        "paperless-web.service"
      ];

      # Provider config WITHOUT the secret (store-safe); the
      # paperless-oidc-setup bridge injects the secret at runtime via jq.
      # server_url is the bare issuer: allauth's wk_server_url() appends
      # /.well-known/openid-configuration when the URL doesn't already
      # contain /.well-known/ (allauth openid_connect/provider.py).
      # token_auth_method is pinned per the paperless v3 migration note —
      # allauth 65.x no longer guesses, and an unpinned method surfaces as
      # invalid_client at the token exchange, past every smoke check.
      oidcProvidersJson = pkgs.writeText "paperless-socialaccount-providers.json" (
        builtins.toJSON {
          openid_connect = {
            SCOPE = [
              "openid"
              "profile"
              "email"
            ];
            OAUTH_PKCE_ENABLED = true;
            APPS = [
              {
                provider_id = "pocket-id";
                name = "Pocket ID";
                client_id = "paperless";
                secret = "__INJECTED_AT_RUNTIME__";
                settings = {
                  server_url = "https://auth.${config.networking.domain}";
                  token_auth_method = "client_secret_basic";
                };
              }
            ];
          };
        }
      );

      # The secret-carrying env file MUST NOT go through the nixpkgs module's
      # environmentFile option: the paperless-manage wrapper bash-`source`s
      # that file, and bash strips the inner quotes of a raw JSON value
      # (VAR={"a":"b"} → {a:b}, verified empirically) — the corrupted value
      # then fails json.loads inside Django settings and breaks every manage
      # command incl. the daily exporter. systemd's EnvironmentFile parser
      # takes unquoted values literally, so the file is attached to the
      # units directly instead. "-" prefix = optional: an absent file
      # degrades to no-SSO instead of failing the unit.
      oidcEnvFragment = lib.optionalAttrs oidcEnabled {
        EnvironmentFile = [ "-${oidcEnvFile}" ];
      };
    in
    {
      config = lib.mkIf cfg.enable {
        services.paperless = {
          port = ports.paperless;
          address = "127.0.0.1";

          # All state (db, search index, media, consume dir, trash, exporter
          # output) lives on the dedicated pool subvol so it is independently
          # snapshottable via the btrbk-pool instance and survives an NVMe
          # loss. mkDefault: VM tests override this to a local path.
          dataDir = lib.mkDefault "/mnt/pool/services/paperless";

          # Sets PAPERLESS_URL only (correct CSRF/absolute URLs behind the
          # proxy). configureNginx stays off — Caddy is the house proxy and
          # exposure goes through the standard Layer-2 protectedVHost.
          domain = "paperless.${config.networking.domain}";

          # sops secret; consumed by paperless-scheduler via systemd
          # LoadCredential (read by PID 1, root ownership is sufficient).
          # Re-set on every scheduler start only when the value changed
          # (upstream manage_superuser + superuser-state guard).
          passwordFile = config.sops.secrets.paperless_admin_password.path;

          # Shared PostgreSQL instance (Immich runs on it too). Peer auth via
          # /run/postgresql — no password secret needed. The module adds
          # ensureDatabases/ensureUsers and orders every unit after
          # postgresql.target.
          database.createLocally = true;

          # Office + e-mail parsing. Wires PAPERLESS_TIKA_* endpoints and runs
          # tika (Java, OCR-enabled) + gotenberg (LibreOffice/Chromium
          # conversions) as additional units — see systemd.services below.
          configureTika = true;

          # Daily documentexporter -> dataDir/export; freshness is watched by
          # services.backup-coordination (see configuration.nix). The exporter
          # output is the primary DR artifact (restorable into any fresh
          # paperless via document_importer).
          exporter.enable = true;

          settings = {
            # Rebuilds tesseract with equ+osd+eng+deu (upstream package apply).
            PAPERLESS_OCR_LANGUAGE = "deu+eng";

            # v3 defaults already sane: OCR_MODE=auto (OCR only when the
            # original has no text layer), ARCHIVE_FILE_GENERATION=auto,
            # OCR_DESKEW/ROTATE_PAGES=true, DATE_ORDER=DMY, audit log on,
            # tantivy index managed by the module.

            # Archive layout: year/correspondent/title; empty segments are
            # dropped rather than rendered as "none". v3 native Jinja-style
            # double-curly placeholders (single-curly still works but logs a
            # deprecation warning on every start).
            PAPERLESS_FILENAME_FORMAT = "{{ created_year }}/{{ correspondent }}/{{ title }}";
            PAPERLESS_FILENAME_FORMAT_REMOVE_NONE = true;

            # Deletions park in the trash dir for 30 days (default delay)
            # before the nightly empty-trash task purges them.
            PAPERLESS_TRASH_DIR = "${dataDir}/trash";

            # No phone-home version checks — updates arrive via nixpkgs.
            PAPERLESS_ENABLE_UPDATE_CHECK = false;

            # Two celery workers (default 1): OCR + AI classification of
            # multi-document batches parallelizes; 16-core host, 2G ceiling.
            PAPERLESS_TASK_WORKERS = 2;

            # Consume subdirectories too (folder drops from a scanner's
            # document feeder)…
            PAPERLESS_CONSUMER_RECURSIVE = true;
            # …and split multi-document scans on PATCHT barcodes, plus accept
            # Code-39 ASN barcodes to assign archive serial numbers.
            PAPERLESS_CONSUMER_ENABLE_BARCODES = true;
            PAPERLESS_CONSUMER_ENABLE_ASN_BARCODE = true;

            # --- Paperless AI (v3) on the local NPU LLM -------------------
            # FastFlowLM is OpenAI-compatible and ignores the Authorization
            # header entirely (verified: no auth handling in the binary), so
            # a static dummy key satisfies llama-index's "key required"
            # guard without a sops secret. LLM_ALLOW_INTERNAL_ENDPOINTS
            # defaults to true (localhost endpoints allowed).
            PAPERLESS_AI_ENABLED = true;
            PAPERLESS_AI_LLM_BACKEND = "openai-like";
            PAPERLESS_AI_LLM_ENDPOINT = llmEndpoint;
            PAPERLESS_AI_LLM_MODEL = config.services.fastflowlm.model;
            PAPERLESS_AI_LLM_API_KEY = "fastflowlm-local-no-auth";
            # Socket activation cold-loads the 21.6 GB model in 2-5 min; the
            # default 120s timeout would abort the first AI request after an
            # idle unload. 480s matches the fastflowlm proxy deadline (v1.0.2
            # weights grew 13.6 GB → 21.6 GB — 300s sat exactly at the boundary).
            PAPERLESS_AI_LLM_REQUEST_TIMEOUT = 480;
            # --- Embeddings (RAG semantic search) on llama-server (GPU) -------
            # Served by the llama-rag module's embeddings instance (bge-m3)
            # at :8848. llama-server is OpenAI-compatible and ignores the
            # Authorization header, so a dummy API key satisfies llama-index's
            # "key required" guard. The embedding model alias is set via
            # --alias on the llama-server side (see llama-rag.nix).
            PAPERLESS_AI_LLM_EMBEDDING_BACKEND = "openai-like";
            PAPERLESS_AI_LLM_EMBEDDING_ENDPOINT = embeddingEndpoint;
            PAPERLESS_AI_LLM_EMBEDDING_MODEL = config.services.llama-rag.embeddingsAlias;
            PAPERLESS_AI_LLM_EMBEDDING_API_KEY = "llama-server-no-auth";
          }
          # --- Outbound email via the central mail relay ----------------------
          # Point Django's SMTP backend at the loopback relay (no auth, no
          # TLS — the relay is loopback-only and the relay→upstream leg is
          # where credentials/TLS live). EMAIL_ENABLED flips on precisely
          # because the host is no longer the literal string "localhost"
          # (paperless settings.py: EMAIL_HOST != "localhost" or user != "").
          # DEFAULT_FROM_EMAIL = PAPERLESS_EMAIL_FROM; it MUST be on a domain
          # the upstream provider verified — locally-generated senders are
          # rewritten by the relay, but this explicit value is what every
          # sent mail carries.
          // lib.optionalAttrs mailRelayEnabled {
            PAPERLESS_EMAIL_HOST = "127.0.0.1";
            PAPERLESS_EMAIL_PORT = ports.mail-relay;
            PAPERLESS_EMAIL_HOST_USER = "";
            PAPERLESS_EMAIL_HOST_PASSWORD = "";
            PAPERLESS_EMAIL_USE_TLS = false;
            PAPERLESS_EMAIL_USE_SSL = false;
            PAPERLESS_EMAIL_FROM = config.services.mail-relay.fromAddress;
          }
          # --- Layer 1 SSO: native OIDC via Pocket ID ------------------------
          # The provider JSON (with the client secret) rides in the
          # paperless-oidc-setup env file, never in the store. AUTO_SIGNUP:
          # the first Pocket ID login provisions the paperless user.
          // lib.optionalAttrs oidcEnabled {
            PAPERLESS_APPS = "allauth.socialaccount.providers.openid_connect";
            PAPERLESS_SOCIAL_AUTO_SIGNUP = true;
          };
        };

        services.tika.port = ports.tika;
        services.gotenberg.port = ports.gotenberg;

        systemd.tmpfiles.settings."20-paperless-trash" = {
          "${dataDir}/trash".d = {
            inherit (cfg) user;
            group = config.users.users.${cfg.user}.group;
          };
        };

        # nixpkgs ships the exporter timer WITHOUT Persistent=true — the only
        # backup timer in the fleet that misses boot catch-up. Proven live
        # 2026-08-31: with the machine off at the 01:30 window during the DAS
        # outage, the export stayed 254h stale after recovery while every
        # Persistent backup timer re-fired at the 14:30 boot. Missed windows
        # now fire as soon as the timer unit comes back.
        systemd.timers.paperless-exporter.timerConfig.Persistent = true;

        systemd.services =
          let
            mountGate = {
              unitConfig.RequiresMountsFor = [ dataDir ];
              inherit onFailure;
              startLimitBurst = 5;
              startLimitIntervalSec = 300;
            };
          in
          {
            # Upstream defaultServiceConfig already hardens thoroughly (strict
            # ProtectSystem, empty CapabilityBoundingSet, SystemCallFilter). Only
            # resource ceilings + I/O tier are layered on top.
            paperless-web = mountGate // {
              serviceConfig = lib.mkMerge [
                ioTier.background
                {
                  MemoryMax = "2G";
                  CPUQuota = "200%";
                }
                oidcEnvFragment
              ];
            };
            # Scheduler runs DB migrations + superuser bootstrap in preStart;
            # give the first start (migration + index init) headroom over the
            # global 3min DefaultTimeoutStartSec.
            paperless-scheduler = mountGate // {
              serviceConfig = lib.mkMerge [
                ioTier.background
                {
                  MemoryMax = "512M";
                  CPUQuota = "100%";
                  TimeoutStartSec = "5min";
                }
                oidcEnvFragment
              ];
            };
            # Task queue does OCR + classification + AI indexing — the heavyweight.
            paperless-task-queue = mountGate // {
              serviceConfig = lib.mkMerge [
                ioTier.background
                {
                  MemoryMax = "2G";
                  CPUQuota = "200%";
                }
                oidcEnvFragment
              ];
            };
            paperless-consumer = mountGate // {
              serviceConfig = lib.mkMerge [
                ioTier.background
                {
                  MemoryMax = "1G";
                  CPUQuota = "200%";
                }
                oidcEnvFragment
              ];
            };

            # One-time SQLite → PostgreSQL engine migration (2026-08-18 switch
            # to database.createLocally). The nixpkgs scheduler preStart gates
            # BOTH `manage.py migrate` and `manage_superuser` on state files in
            # dataDir that survive the engine switch: src-version (same package
            # version ⇒ migrate SKIPPED ⇒ the fresh postgres DB never gets its
            # tables) and superuser-state (admin bootstrap SKIPPED ⇒ no login).
            # Live incident 2026-08-18: scheduler crash-looped with
            # `UndefinedTable: relation "auth_user" does not exist` and dragged
            # web/consumer/task-queue down as dependencies. Drop BOTH files
            # while the legacy db.sqlite3 is still present so the bootstrap
            # re-runs once against postgres. Self-neutralizing: removing
            # db.sqlite3 after verification makes the Condition skip forever;
            # re-running while it exists is harmless (migrate is idempotent,
            # manage_superuser no-ops once the admin exists, preStart rewrites
            # the state files).
            paperless-sqlite-to-pg-migration = {
              description = "Paperless SQLite-to-PostgreSQL migration bootstrap";
              unitConfig.ConditionPathExists = [ "${dataDir}/db.sqlite3" ];
              before = [ "paperless-scheduler.service" ];
              wantedBy = [ "paperless-scheduler.service" ];
              serviceConfig.Type = "oneshot";
              script = "rm -f '${dataDir}/superuser-state' '${dataDir}/src-version'";
            };

            # Tika (Java + tesseract subprocess for OCR'd attachments) and
            # Gotenberg (spawns LibreOffice + Chromium on demand) come from
            # their nixpkgs modules with their own sandboxing; layer the house
            # resource ceilings, I/O tier, and rate limits on top. Without
            # these, an Office-heavy consume batch would run at default
            # (unbounded) priority against the QLC NVMe.
            tika = {
              inherit onFailure;
              startLimitBurst = 5;
              startLimitIntervalSec = 300;
              serviceConfig = lib.mkMerge [
                ioTier.background
                {
                  MemoryMax = "2G";
                  CPUQuota = "200%";
                }
              ];
            };
            gotenberg = {
              inherit onFailure;
              startLimitBurst = 5;
              startLimitIntervalSec = 300;
              # Gotenberg 8.36 ships an always-on OTel autoexport metrics
              # uploader whose compiled-in default endpoint is
              # https://localhost:4318 — a TLS error against our plaintext
              # collector every 60s (live 2026-08-18). Gotenberg's autoexport
              # path parses the endpoint as a URL, so unlike code-configured
              # Go otlptracehttp (bare host:port) it REQUIRES the scheme:
              # schemeless "localhost:4318" parses as scheme "localhost" and
              # posts to https:///v1/metrics ("no Host in request URL").
              # http:// explicitly selects the plaintext OTLP/HTTP receiver.
              environment.OTEL_EXPORTER_OTLP_ENDPOINT = "http://localhost:${toString ports.signoz-otlp-http}";
              serviceConfig = lib.mkMerge [
                ioTier.background
                {
                  MemoryMax = "2G";
                  CPUQuota = "200%";
                }
              ];
            };
          }
          # Bridges the Pocket ID client secret into the OIDC env file read by
          # all four paperless units (LoadCredential = PID 1 reads the file as
          # root, crossing pocket-id's 0700-ish dataDir). A missing secret is
          # FATAL for LoadCredential (systemd.exec: with a path given, absence
          # is an error — no optional prefix exists), so ConditionPathExists
          # gates the whole unit: before pocket-id-provision has created the
          # client, the bridge skips cleanly (inactive, NOT failed) and the
          # units' optional (-) env file makes paperless boot
          # local-login-only instead of failing. Indirect unit (wantedBy =
          # paperless-*) — deploy.sh restarts it in the dedicated OIDC-bridge
          # block (the provisioner loop's is-enabled gate skips indirect
          # units, the dnsblockd 2026-08-22 lesson).
          // lib.optionalAttrs oidcEnabled {
            paperless-oidc-setup = {
              description = "Paperless — Pocket ID OIDC secret bridge";
              after = [ "pocket-id-provision.service" ];
              wants = [ "pocket-id-provision.service" ];
              before = paperlessUnits;
              wantedBy = paperlessUnits;
              startLimitBurst = 5;
              startLimitIntervalSec = 300;
              unitConfig.ConditionPathExists = [
                "${pocketIdDataDir}/client-secrets/paperless"
              ];

              serviceConfig = lib.mkMerge [
                {
                  Type = "oneshot";
                  RemainAfterExit = true;
                  StateDirectory = "paperless-oidc";
                  LoadCredential = [
                    "pocket-id-secret:${pocketIdDataDir}/client-secrets/paperless"
                  ];
                }
                (harden { ProtectSystem = "strict"; })
                (serviceOneshotDefaults { })
              ];

              path = [
                pkgs.coreutils
                pkgs.jq
              ];

              script = ''
                secret_file="''${CREDENTIALS_DIRECTORY}/pocket-id-secret"
                umask 077

                # Defense-in-depth: the ConditionPathExists gate should make
                # this unreachable, but never hard-fail the stack on a race —
                # an empty-providers value keeps Django parsing.
                if [ ! -s "$secret_file" ]; then
                  printf 'PAPERLESS_SOCIALACCOUNT_PROVIDERS={}\n' > "${oidcEnvFile}"
                  echo "paperless-oidc-setup: Pocket ID secret missing — paperless starts local-login-only (check pocket-id-provision)"
                  exit 0
                fi

                # jq -c keeps the JSON on ONE line (multi-line values are not
                # valid in systemd EnvironmentFiles); --arg is injection-safe
                # against quotes inside the secret.
                printf 'PAPERLESS_SOCIALACCOUNT_PROVIDERS=%s\n' "$(
                  jq -c --arg secret "$(cat "$secret_file")" \
                    '.openid_connect.APPS[0].secret = $secret' \
                    ${oidcProvidersJson}
                )" > "${oidcEnvFile}"
                echo "paperless-oidc-setup: Pocket ID OIDC env file written"
              '';
            };
          };
      };
    };
}
