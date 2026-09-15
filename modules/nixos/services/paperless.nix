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
#  - Declarative dashboards (services.paperless-dashboard): saved views +
#    visibility provisioned through the REST API by the
#    paperless-dashboard-provision oneshot (create-only; UI edits stick).
_: {
  flake.nixosModules.paperless =
    {
      config,
      options,
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

      # ── Declarative dashboards (saved views) ────────────────────────────────
      # Paperless v3 moved dashboard visibility OUT of SavedView into
      # per-user UiSettings (migration 0014_savedview_visibility_to_ui_settings);
      # env vars cannot reach it. The paperless-dashboard-provision oneshot
      # drives the REST API instead — details on the unit below.
      dcfg = config.services.paperless-dashboard;

      # The declared views, as consumed by the provisioner script (jq).
      # A store path here means a spec change rewrites the unit file, which
      # switch-to-configuration restarts (oneshot+RemainAfterExit restarts
      # DO fire on unit-file diffs; only restartTriggers are inert).
      viewsJson = pkgs.writeText "paperless-dashboard-views.json" (builtins.toJSON dcfg.savedViews);

      # Executed via `paperless-manage shell < file`: resolves the single
      # allauth SocialAccount-linked user (the Pocket ID SSO user). Any
      # failure (import error, missing table) prints nothing and the
      # provisioner degrades to admin with a WARN — never a crash.
      ownerResolverPy = pkgs.writeText "paperless-dashboard-owner-resolve.py" ''
        from allauth.socialaccount.models import SocialAccount
        from django.contrib.auth import get_user_model

        User = get_user_model()
        linked = list(
            User.objects.filter(socialaccount__isnull=False, is_active=True)
            .values_list("username", flat=True)
            .distinct()
            .order_by("username")
        )
        if len(linked) == 1:
            print("USER:" + linked[0])
        elif not linked:
            print("NONE")
        else:
            print("AMBIGUOUS:" + ",".join(linked))
      '';

      # Null-safe option embeds: interpolating a null option into the script
      # string would throw at eval time, so resolve emptiness in Nix first.
      ownerOpt = if dcfg.owner == null then "" else dcfg.owner;
      appTitleFlag = dcfg.appTitle != null;
      # File delivery keeps quoting hazards out of the script entirely.
      appTitleFile = pkgs.writeText "paperless-dashboard-app-title" (
        if dcfg.appTitle == null then "" else dcfg.appTitle
      );
    in
    {
      options.services.paperless-dashboard = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Provision Paperless saved views (dashboard widgets + sidebar
            entries) declaratively via the paperless-dashboard-provision
            oneshot. Create-only: views that already exist under the same
            name are never modified or deleted, so manual UI edits and
            widget reordering survive every deploy.
          '';
        };

        owner = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            Paperless user owning the provisioned views. null auto-resolves
            at runtime: the single allauth SocialAccount-linked user (the
            Pocket ID SSO user) when exactly one exists, otherwise the
            admin superuser. The resolved owner is printed in the
            provisioner journal.
          '';
        };

        appTitle = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            Application title applied via PATCH /api/config/ (browser
            title, login page, dashboard header). Requires the admin
            superuser token (the config endpoint carries
            DjangoModelPermissions; the SSO owner may be a regular user).
            null leaves the title untouched. May not contain single quotes.
          '';
        };

        savedViews = lib.mkOption {
          type = lib.types.listOf (
            lib.types.submodule {
              options = {
                name = lib.mkOption {
                  type = lib.types.str;
                  description = "Saved view name; unique among the declared views (the create-only key).";
                };
                icon = lib.mkOption {
                  # SavedView.Icon.choices from the paperless 3.1.3 source
                  # (documents/models.py) — eval-time rejection instead of
                  # a runtime 400.
                  type = lib.types.enum [
                    "archive"
                    "bank"
                    "basket"
                    "bell"
                    "bookmark"
                    "boxes"
                    "briefcase"
                    "building"
                    "calculator"
                    "calendar"
                    "camera"
                    "card-checklist"
                    "cash"
                    "chat-left-text"
                    "check-circle"
                    "clipboard"
                    "clock-history"
                    "credit-card"
                    "download"
                    "envelope"
                    "exclamation-triangle"
                    "file-earmark"
                    "file-earmark-check"
                    "file-earmark-lock"
                    "file-earmark-medical"
                    "file-earmark-person"
                    "file-earmark-spreadsheet"
                    "file-text"
                    "files"
                    "folder"
                    "funnel"
                    "gear"
                    "globe2"
                    "hash"
                    "heart"
                    "house"
                    "inbox"
                    "journals"
                    "list-task"
                    "newspaper"
                    "paperclip"
                    "people"
                    "person"
                    "printer"
                    "receipt"
                    "safe"
                    "search"
                    "send"
                    "shop"
                    "stack"
                    "stars"
                    "tag"
                    "tags"
                    "telephone"
                    "truck"
                    "upc-scan"
                    "wallet2"
                  ];
                  default = "funnel";
                  description = "Icon (paperless SavedView.Icon choices).";
                };
                showOnDashboard = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                  description = "Add the view's widget to the owner's dashboard (API v9 legacy visibility = additive UiSettings merge).";
                };
                showInSidebar = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                  description = "List the view in the owner's sidebar.";
                };
                sortField = lib.mkOption {
                  type = lib.types.str;
                  default = "added";
                  description = "Sort field (free-form frontend key: added, created, title, correspondent, asn, ...).";
                };
                sortReverse = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                  description = "Sort descending (newest first).";
                };
                filterRules = lib.mkOption {
                  type = lib.types.listOf (
                    lib.types.submodule {
                      options = {
                        ruleType = lib.mkOption {
                          type = lib.types.ints.between 0 49;
                          description = ''
                            SavedViewFilterRule.RULE_TYPES id. Common:
                            5 = in inbox, 6 = has tag, 17 = does not have
                            tag, 19 = title or content contains,
                            43/44 = added from/to, 45/46 = created from/to.
                          '';
                        };
                        tagName = lib.mkOption {
                          type = lib.types.nullOr lib.types.str;
                          default = null;
                          description = "Resolve this tag NAME to its id at runtime (rule value = tag id as string). Unresolvable tags drop the rule with a warning.";
                        };
                        value = lib.mkOption {
                          type = lib.types.nullOr lib.types.str;
                          default = null;
                          description = "Literal rule value (text for contains rules, empty for inbox). Ignored when tagName is set.";
                        };
                      };
                    }
                  );
                  default = [ ];
                  description = "Filters defining the view. A view whose rules ALL fail to resolve is skipped (a rule-less view would show every document).";
                };
              };
            }
          );
          # Both target InboxClean papersync tags (documents/bank statements
          # archived by the Gmail pipeline); the "encrypted" tag marks
          # password-protected PDFs parked undecrypted (see AGENTS.md).
          default = [
            {
              name = "Gmail Archive";
              icon = "envelope";
              filterRules = [
                {
                  ruleType = 6;
                  tagName = "gmail";
                }
              ];
            }
            {
              name = "Encrypted (needs attention)";
              icon = "exclamation-triangle";
              filterRules = [
                {
                  ruleType = 6;
                  tagName = "encrypted";
                }
              ];
            }
          ];
          description = "Saved views to provision on the owner's dashboard.";
        };
      };

      config = lib.mkMerge [
        {
          assertions = [
            {
              assertion = (!dcfg.enable || cfg.enable);
              message = "services.paperless-dashboard.enable requires services.paperless.enable = true";
            }
            {
              assertion =
                (builtins.length dcfg.savedViews)
                == (builtins.length (lib.unique (map (v: v.name) dcfg.savedViews)));
              message = "services.paperless-dashboard.savedViews: duplicate view names are not allowed (create-only convergence keys on the name)";
            }
          ];
        }

        (lib.mkIf cfg.enable {
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

              # Reject duplicate content at the door (delete the incoming file,
              # fail the task with document_already_exists). Paperless's DEFAULT
              # only WARNS and stores the duplicate — proven live 2026-09-03:
              # the same bank statement mailed to two mailboxes arrived via
              # InboxClean's per-account ledgers within seconds and Paperless
              # archived every byte-identical copy ("Consuming duplicate … 1
              # existing document(s) share the same content", then succeeded
              # anyway). InboxClean's fire-and-forget upload still records its
              # ledger entry, so a rejected duplicate never re-uploads.
              PAPERLESS_CONSUMER_DELETE_DUPLICATES = true;

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
                  # Password login is DISABLED only while the Pocket ID secret
                  # is present (user decision 2026-09-02: "I do not like
                  # password logins"): the flags ride in the SAME env file, so
                  # a degraded bridge (secret missing → condition-skip → file
                  # absent → optional "-" prefix) AUTOMATICALLY restores the
                  # password form as break-glass. SSO fully on or fully off —
                  # never a locked-out middle state where neither path answers.
                  # Caveat: DISABLE_REGULAR_LOGIN also blocks username/password
                  # API-token acquisition (mobile app password login); existing
                  # API tokens keep working.
                  printf 'PAPERLESS_DISABLE_REGULAR_LOGIN=true\n' >> "${oidcEnvFile}"
                  printf 'PAPERLESS_REDIRECT_LOGIN_TO_SSO=true\n' >> "${oidcEnvFile}"
                  echo "paperless-oidc-setup: Pocket ID OIDC env file written (password login disabled, redirect-to-SSO on)"
                '';
              };
            }

            # ── Declarative dashboards: saved-view provisioner ──────────────────
            # Drives the REST API with a runtime-minted DRF token. Visibility
            # rides the API v9 LEGACY fields (Accept: application/json;
            # version=9): SavedViewSerializer.create() merges them ADDITIVELY
            # into UiSettings.saved_views.dashboard_views_visible_ids — the
            # only non-destructive path. The v10 ui_settings POST is a
            # WHOLESALE settings replacement (dark mode, language, everything)
            # and is never used for writes here, only read for verification.
            # Create-only convergence: same-name views are skipped forever, so
            # the user's manual reordering/edits always win. Indirect unit
            # (wantedBy = paperless-web) — converged per-deploy by the
            # dedicated deploy.sh block (the provisioner loop's is-enabled
            # gate skips indirect units, the dnsblockd 2026-08-22 lesson).
            # Deliberately no restartTriggers: they are inert on
            # oneshot+RemainAfterExit (dead config per deploy-restart-audit);
            # a spec change rewrites the unit file via viewsJson, and stc
            # restarts units whose FILE changed.
            // lib.optionalAttrs dcfg.enable {
              paperless-dashboard-provision = {
                description = "Paperless - declarative dashboard saved-views provisioner";
                after = [ "paperless-web.service" ];
                wants = [ "paperless-web.service" ];
                wantedBy = [ "paperless-web.service" ];
                inherit onFailure;
                startLimitBurst = 5;
                startLimitIntervalSec = 300;

                serviceConfig = lib.mkMerge [
                  {
                    Type = "oneshot";
                    RemainAfterExit = true;
                    # paperless OS user: paperless-manage + drf_create_token
                    # need the peer-auth PostgreSQL socket identity.
                    User = cfg.user;
                    StateDirectory = "paperless-dashboard";
                    StateDirectoryMode = "0700";
                    TimeoutStartSec = "3min";
                  }
                  (harden { ProtectSystem = "strict"; })
                  (serviceOneshotDefaults { })
                ];

                path = [
                  pkgs.coreutils
                  pkgs.curl
                  pkgs.gnugrep
                  pkgs.jq
                ];

                # paperless-web is Type=simple: "active" before Django binds
                # its port — poll the login page before touching the API.
                preStart = ''
                  curl -sf --retry 30 --retry-delay 2 --retry-all-errors \
                    -o /dev/null http://127.0.0.1:${toString cfg.port}/accounts/login/
                '';

                script = ''
                  API_BASE="http://127.0.0.1:${toString cfg.port}"
                  MANAGE="${cfg.manage}/bin/paperless-manage"

                  api() {
                    # api METHOD PATH [JSON_BODY] -> response JSON on stdout.
                    # On HTTP failure the body is dumped to stderr (journal)
                    # before returning non-zero.
                    local out status body
                    if [ $# -ge 3 ]; then
                      out=$(curl -s -w '\n%{http_code}' -X "$1" \
                        --header @"$TOKEN_FILE" \
                        -H 'Accept: application/json; version=9' \
                        -H 'Content-Type: application/json' \
                        -d "$3" "$API_BASE$2") || return 1
                    else
                      out=$(curl -s -w '\n%{http_code}' \
                        --header @"$TOKEN_FILE" \
                        -H 'Accept: application/json; version=9' \
                        "$API_BASE$2") || return 1
                    fi
                    status="''${out##*$'\n'}"
                    body="''${out%$'\n'*}"
                    if [ "$status" -ge 200 ] 2>/dev/null && [ "$status" -lt 300 ] 2>/dev/null; then
                      printf '%s' "$body"
                    else
                      echo "paperless-dashboard-provision: $1 $2 -> HTTP $status: $(printf '%s' "$body" | head -c 400)" >&2
                      return 1
                    fi
                  }

                  # 1. Owner resolution: config pin > single SocialAccount
                  #    link (the Pocket ID SSO user) > admin fallback.
                  if [ -n "${ownerOpt}" ]; then
                    OWNER="${ownerOpt}"
                    echo "paperless-dashboard-provision: owner pinned by config: $OWNER"
                  else
                    RESOLVED=$("$MANAGE" shell < ${ownerResolverPy} 2>/dev/null || true)
                    case "$RESOLVED" in
                      USER:*)
                        OWNER="''${RESOLVED#USER:}"
                        echo "paperless-dashboard-provision: owner auto-resolved to SSO user: $OWNER"
                        ;;
                      AMBIGUOUS:*)
                        OWNER=admin
                        echo "paperless-dashboard-provision: multiple SocialAccount users (''${RESOLVED#AMBIGUOUS:}) - falling back to admin" >&2
                        ;;
                      *)
                        OWNER=admin
                        echo "paperless-dashboard-provision: no SocialAccount-linked user (or resolver failed) - falling back to admin"
                        ;;
                    esac
                  fi

                  # 2. Idempotent DRF token mint. stdout is
                  #    "Generated token <40-hex> for user <name>" (DRF 3.17.1
                  #    authtoken/management/commands/drf_create_token.py); the
                  #    key is extracted, validated, then the file is rewritten
                  #    as a curl --header @file so the token never appears in
                  #    argv, an env var, or the journal.
                  TOKEN_FILE=$(mktemp "''${STATE_DIRECTORY}/token.XXXXXX")
                  ADMIN_TOKEN_FILE=""
                  trap 'rm -f "$TOKEN_FILE" "$ADMIN_TOKEN_FILE" 2>/dev/null || true' EXIT
                  if ! "$MANAGE" drf_create_token "$OWNER" > "$TOKEN_FILE"; then
                    echo "paperless-dashboard-provision: token mint failed for '$OWNER' (user missing?)" >&2
                    exit 1
                  fi
                  TOKEN=$(grep -oE '[0-9a-f]{40}' "$TOKEN_FILE" | head -n1)
                  if ! printf '%s' "$TOKEN" | grep -qE '^[0-9a-f]{40}$'; then
                    echo "paperless-dashboard-provision: token extraction failed (unexpected drf_create_token output)" >&2
                    exit 1
                  fi
                  printf 'Authorization: Token %s\n' "$TOKEN" > "$TOKEN_FILE"

                  # 3. Existing view names (owner-scoped: SavedView is an
                  #    owned object) + the tag name->id map. Tag names are NOT
                  #    unique at the DB level (tree tags); exact-match first
                  #    hit wins, deterministically.
                  EXISTING=$(api GET "/api/saved_views/?page_size=100000" | jq -r '.results[].name')
                  TAGS_JSON=$(api GET "/api/tags/?page_size=100000")

                  tag_id() {
                    printf '%s' "$TAGS_JSON" | jq -r --arg n "$1" \
                      'first(.results[] | select(.name == $n) | .id | tostring) // "MISSING"'
                  }

                  # 4. Create-only loop. A subshell would eat the counters, so
                  #    the name list feeds a here-string instead of a pipe.
                  CREATED=0
                  SKIPPED_EXISTING=0
                  SKIPPED_NO_RULES=0
                  DROPPED_RULES=0
                  CREATED_DASH_IDS=""

                  while IFS= read -r NAME; do
                    if printf '%s\n' "$EXISTING" | grep -qxF "$NAME"; then
                      echo "paperless-dashboard-provision: saved view '$NAME' already exists - skipping (create-only)"
                      SKIPPED_EXISTING=$((SKIPPED_EXISTING + 1))
                      continue
                    fi

                    VIEW=$(jq -c --arg n "$NAME" '.[] | select(.name == $n)' ${viewsJson})

                    RULES=[]
                    DECLARED_RULES=$(printf '%s' "$VIEW" | jq '.filterRules | length')
                    IDX=0
                    while [ "$IDX" -lt "$DECLARED_RULES" ]; do
                      RULE_TYPE=$(printf '%s' "$VIEW" | jq -r ".filterRules[$IDX].ruleType")
                      TAG_NAME=$(printf '%s' "$VIEW" | jq -r ".filterRules[$IDX].tagName // \"\"") || TAG_NAME=""
                      if [ -n "$TAG_NAME" ]; then
                        TID=$(tag_id "$TAG_NAME")
                        if [ "$TID" = "MISSING" ]; then
                          echo "paperless-dashboard-provision: dropping rule $RULE_TYPE for '$NAME' - tag '$TAG_NAME' not found" >&2
                          DROPPED_RULES=$((DROPPED_RULES + 1))
                        else
                          RULES=$(printf '%s' "$RULES" | jq -c --argjson t "$RULE_TYPE" --arg v "$TID" '. + [{rule_type: $t, value: $v}]')
                        fi
                      else
                        LITERAL=$(printf '%s' "$VIEW" | jq -r ".filterRules[$IDX].value // \"\"")
                        RULES=$(printf '%s' "$RULES" | jq -c --argjson t "$RULE_TYPE" --arg v "$LITERAL" '. + [{rule_type: $t, value: $v}]')
                      fi
                      IDX=$((IDX + 1))
                    done

                    RESOLVED_RULE_COUNT=$(printf '%s' "$RULES" | jq 'length')
                    if [ "$DECLARED_RULES" -gt 0 ] && [ "$RESOLVED_RULE_COUNT" -eq 0 ]; then
                      echo "paperless-dashboard-provision: skipping view '$NAME' - none of its filter rules resolved (a rule-less view would show ALL documents)" >&2
                      SKIPPED_NO_RULES=$((SKIPPED_NO_RULES + 1))
                      continue
                    fi

                    BODY=$(printf '%s' "$VIEW" | jq -c --argjson rules "$RULES" \
                      '{name, icon, sort_field: .sortField, sort_reverse: .sortReverse, show_on_dashboard: .showOnDashboard, show_in_sidebar: .showInSidebar, filter_rules: $rules}')

                    NEW_ID=$(api POST /api/saved_views/ "$BODY" | jq -r '.id')
                    echo "paperless-dashboard-provision: created saved view '$NAME' (id=$NEW_ID, owner=$OWNER, rules=$RESOLVED_RULE_COUNT)"
                    CREATED=$((CREATED + 1))
                    if printf '%s' "$VIEW" | grep -q '"showOnDashboard":true'; then
                      CREATED_DASH_IDS="$CREATED_DASH_IDS $NEW_ID"
                    fi
                  done <<< "$(jq -r '.[].name' ${viewsJson})"

                  # 5. End-to-end assertion (phantom-green killer): every view
                  #    created in THIS run with showOnDashboard=true must
                  #    appear in the owner's dashboard_views_visible_ids (the
                  #    v9 additive merge). Views from PREVIOUS runs that the
                  #    user manually unchecked are deliberately NOT asserted
                  #    (create-only: user edits win).
                  for ID in $CREATED_DASH_IDS; do
                    if ! api GET /api/ui_settings/ | jq -e --argjson id "$ID" \
                        '.settings.saved_views.dashboard_views_visible_ids | index($id) != null' > /dev/null; then
                      echo "paperless-dashboard-provision: view id=$ID missing from dashboard_views_visible_ids after creation - visibility merge failed" >&2
                      exit 1
                    fi
                  done

                  # 6. Optional app title (cosmetic; WARN-never-fatal). The
                  #    config endpoint requires model permissions, so this
                  #    always uses the admin SUPERUSER token even when the
                  #    views belong to the SSO user.
                  if [ "${toString appTitleFlag}" = "true" ]; then
                    ADMIN_TOKEN_FILE=$(mktemp "''${STATE_DIRECTORY}/admin-token.XXXXXX")
                    if "$MANAGE" drf_create_token admin > "$ADMIN_TOKEN_FILE"; then
                      ATOKEN=$(grep -oE '[0-9a-f]{40}' "$ADMIN_TOKEN_FILE" | head -n1)
                      printf 'Authorization: Token %s\n' "$ATOKEN" > "$ADMIN_TOKEN_FILE"
                      CONFIG_RESP=$(curl -s -w '\n%{http_code}' --header @"$ADMIN_TOKEN_FILE" \
                        -H 'Accept: application/json' "$API_BASE/api/config/?page_size=1")
                      CONFIG_STATUS="''${CONFIG_RESP##*$'\n'}"
                      CONFIG_BODY="''${CONFIG_RESP%$'\n'*}"
                      CONFIG_ID=""
                      if [ "$CONFIG_STATUS" -ge 200 ] 2>/dev/null && [ "$CONFIG_STATUS" -lt 300 ] 2>/dev/null; then
                        CONFIG_ID=$(printf '%s' "$CONFIG_BODY" | jq -r '.results[0].id // empty') || CONFIG_ID=""
                      fi
                      if [ -n "$CONFIG_ID" ]; then
                        PATCH_STATUS=$(curl -s -o /dev/null -w '%{http_code}' --header @"$ADMIN_TOKEN_FILE" -X PATCH \
                          -H 'Content-Type: application/json' \
                          -d "$(jq -nc --arg t "$(cat ${appTitleFile})" '{app_title: $t}')" \
                          "$API_BASE/api/config/$CONFIG_ID/")
                        if printf '%s' "$PATCH_STATUS" | grep -qE '^2'; then
                          echo "paperless-dashboard-provision: app_title applied"
                        else
                          echo "paperless-dashboard-provision: WARN - PATCH /api/config/ -> HTTP $PATCH_STATUS, app_title not applied" >&2
                        fi
                      else
                        echo "paperless-dashboard-provision: WARN - could not resolve /api/config/ id (GET -> HTTP $CONFIG_STATUS), app_title not applied" >&2
                      fi
                    else
                      echo "paperless-dashboard-provision: WARN - admin token mint failed, app_title not applied" >&2
                    fi
                  fi

                  echo "paperless-dashboard-provision: done - owner=$OWNER created=$CREATED skipped_existing=$SKIPPED_EXISTING skipped_no_rules=$SKIPPED_NO_RULES dropped_rules=$DROPPED_RULES dashboard_assertions=$(printf '%s' "$CREATED_DASH_IDS" | wc -w)"
                '';
              };
            };

          # Service-integration registry entries: the document-exporter backup
          # freshness + the Pocket ID OIDC client (django-allauth;
          # callback path fixed by allauth URL routing, PKCE both sides)
          # ride the main entry; the four paperless units + Tika +
          # Gotenberg self-register for unit-state monitoring. The SSO-only
          # vHost (plain layer, /admin hard-block) stays hand-written in
          # caddy.nix; the login-page + sidecar Gatus checks stay in
          # gatus-config.nix's core list (multi-unit + body-pattern
          # semantics owned by the SSO bring-up).
          services.integration = lib.optionalAttrs (options ? services.integration) {
            paperless = {
              enable = cfg.enable;
              subdomain = "paperless";
              port = cfg.port;
              vHost.layer = "plain";
              backup = {
                # Daily documentexporter output (01:30 + randomized delay).
                directory = "/mnt/pool/services/paperless/export";
                maxAgeHours = 25;
              };
              oidc = {
                name = "Paperless";
                clientId = "paperless";
                launchURL = "https://paperless.${config.networking.domain}";
                callbackURLs = [
                  "https://paperless.${config.networking.domain}/accounts/oidc/pocket-id/login/callback/"
                ];
                pkceEnabled = true;
              };
            };
            paperless-consumer = {
              enable = cfg.enable;
              vHost.layer = "none";
              monitored = true;
            };
            paperless-scheduler = {
              enable = cfg.enable;
              vHost.layer = "none";
              monitored = true;
            };
            paperless-task-queue = {
              enable = cfg.enable;
              vHost.layer = "none";
              monitored = true;
            };
            paperless-web = {
              enable = cfg.enable;
              vHost.layer = "none";
              monitored = true;
            };
            tika = {
              enable = cfg.enable;
              vHost.layer = "none";
              monitored = true;
            };
            gotenberg = {
              enable = cfg.enable;
              vHost.layer = "none";
              monitored = true;
            };
          };
        })
      ];
    };
}
