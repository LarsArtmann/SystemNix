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
_: {
  flake.nixosModules.paperless =
    {
      config,
      lib,
      ...
    }:
    let
      inherit (import ../../../lib/default.nix lib)
        ioTier
        onFailure
        ports
        ;

      cfg = config.services.paperless;
      dataDir = cfg.dataDir;
      llmEndpoint = "http://127.0.0.1:${toString ports.fastflowlm}/v1";
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
            # dropped rather than rendered as "none".
            PAPERLESS_FILENAME_FORMAT = "{created_year}/{correspondent}/{title}";
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
            # Socket activation cold-loads the 13.6 GB model in 1-3 min; the
            # default 120s timeout would abort the first AI request after an
            # idle unload. 300s mirrors the papdashboard insight enricher.
            PAPERLESS_AI_LLM_REQUEST_TIMEOUT = 300;
            # Semantic search / RAG chat need an embedding endpoint; served
            # by FastFlowLM once loadEmbed is enabled and the model is pulled
            # (`flm pull embed-gemma:300m` into /data/ai/models/fastflowlm).
            PAPERLESS_AI_LLM_EMBEDDING_BACKEND = "openai-like";
            PAPERLESS_AI_LLM_EMBEDDING_ENDPOINT = llmEndpoint;
            PAPERLESS_AI_LLM_EMBEDDING_MODEL = "embed-gemma:300m";
          };
        };

        services.tika.port = ports.tika;
        services.gotenberg.port = ports.gotenberg;

        systemd.tmpfiles.settings."20-paperless-trash" = {
          "${dataDir}/trash".d = {
            user = cfg.user;
            group = config.users.users.${cfg.user}.group;
          };
        };

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
              ];
            };
            paperless-consumer = mountGate // {
              serviceConfig = lib.mkMerge [
                ioTier.background
                {
                  MemoryMax = "1G";
                  CPUQuota = "200%";
                }
              ];
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
              serviceConfig = lib.mkMerge [
                ioTier.background
                {
                  MemoryMax = "2G";
                  CPUQuota = "200%";
                }
              ];
            };
          };
      };
    };
}
