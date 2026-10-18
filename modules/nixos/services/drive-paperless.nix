# Runbook: docs/services/google-sync.md (section "Drive → Paperless ingest")
# Google Drive mirror → Paperless-ngx archival pipeline.
#
# Scans the google-sync mirror trees on the HDD pool (or any configured
# source directory), filters to document types (PDFs, office documents,
# text/email/e-book formats), and uploads new/changed files into
# Paperless-ngx via the DRF API with per-account metadata:
#   correspondent = per-source (Google Drive / Google Workspace),
#   tags          = global import tag + per-source remote tag,
#   title         = filename stem, created = Drive modified time (mtime).
#
# Why API upload instead of the consume directory: the API sets metadata
# atomically at upload (PostDocumentView accepts correspondent/tags/title/
# created — verified against the pinned paperless-ngx 3.3.1 source), needs
# no global PAPERLESS_CONSUMER_* flag flips that would change semantics for
# every other consume-dir user, and rides the bank-sync-paperless runtime
# token-mint pattern (drf_create_token, tmpfs-only, zero sops steps).
#
# Idempotence: an append-only TSV journal (<source>tab<path>tab<size>) per
# state dir gates re-uploads; paperless itself dedups byte-identical content
# server-side, so a journal miss is harmless (worst case: one rejected
# duplicate task). A file whose SIZE changed (new Drive revision synced by
# rclone) misses its journal line and uploads as a new document version.
#
# Storm discipline: bounded batch per run (default 200) + hourly timer +
# ioTier.background — the 1.9 TB private account can hold six-digit file
# counts and this box's IO-storm history (PSI freezes) forbids unbounded
# directory walks + uploads in one transaction. Uploads of large files are
# disk-read-bound on the HDD pool.
_: {
  flake.nixosModules.drive-paperless =
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
        serviceOneshotDefaults
        onFailure
        ports
        ioTier
        ;

      cfg = config.services.drive-paperless;

      # The paperless module is optional at eval scope (only hosts/tests
      # that carry it define services.paperless). nixpkgs assigns
      # services.paperless.manage (readOnly) ONLY when the service is
      # enabled — every unit touching it gates on the same condition and
      # the assertion below keeps the misconfig loud (bank-sync pattern).
      paperlessPresent = options ? services.paperless;
      paperlessEnabled = paperlessPresent && config.services.paperless.enable;

      stateDir = "/var/lib/drive-paperless";
      journal = "${stateDir}/journal.tsv";
      runEnv = "/run/drive-paperless/env";

      # google-sync is optional at eval scope the same way (VM tests may
      # import this module alone). When present, the default sources mirror
      # its mirror list 1:1 — one google-sync enable flip brings up mirror
      # AND ingest with no second config edit.
      googleSyncPresent = options ? services.google-sync;
      correspondentFor =
        remote:
        {
          gdrive = "Google Drive (private)";
          gdrive-shared = "Google Drive (shared with me)";
          gwork = "Google Workspace";
        }
        ?${remote} or "Google Drive (${remote})";
      defaultSources =
        if googleSyncPresent then
          map
            (m: {
              path = m.destination;
              correspondent = correspondentFor m.remote;
              tag = m.remote;
            })
            config.services.google-sync.mirrors
        else
          [ ];

      docExtensions = [
        "pdf"
        "doc"
        "docx"
        "odt"
        "ods"
        "xls"
        "xlsx"
        "ppt"
        "pptx"
        "txt"
        "rtf"
        "html"
        "htm"
        "eml"
        "epub"
        "md"
      ];
      imageExtensions = [
        "jpg"
        "jpeg"
        "png"
        "tiff"
        "tif"
        "webp"
        "gif"
      ];
      allExtensions = docExtensions ++ lib.optionals cfg.ingestImages imageExtensions;
      extRegex = lib.concatStringsSep "|" (map lib.escapeRegex allExtensions);

      mintChownScript = pkgs.writeShellScript "drive-paperless-token-chown" ''
        chown ${cfg.user}:${cfg.group} ${runEnv}
        chmod 0400 ${runEnv}
      '';

      # One ensure-metadata block per source, baked at build time (the
      # syncScript pattern): resolves/creates the correspondent + tags via
      # the API and prints "cid<space>tid1 tid2" consumed by the scan block.
      ensureBlock =
        src:
        let
          slug = lib.strings.sanitizeDerivationName src.tag;
        in
        ''
          echo "drive-paperless: ensuring metadata for source ${src.tag}"
          meta_$slug="$(
            cid="$(ensure_id correspondents ${lib.escapeShellArg src.correspondent})" || exit 1
            tids=""
            for tag_name in ${lib.escapeShellArg cfg.globalTag} ${lib.escapeShellArg src.tag}; do
              tid="$(ensure_id tags "$tag_name")" || exit 1
              tids="$tids $tid"
            done
            printf '%s %s\n' "$cid" "$tids"
          )"
        '';

      scanBlock =
        src:
        let
          slug = lib.strings.sanitizeDerivationName src.tag;
        in
        ''
          root="${src.path}"
          if [ ! -d "$root" ]; then
            echo "drive-paperless: source dir $root missing — skipping (first seed not run?)" >&2
            continue_sources=1
            continue
          fi
          read -r cid tids <<<"$(cat "$meta_file_${slug}")"
          find "$root" -xdev -type f -size +0c -size -${toString (cfg.maxFileSizeMB * 1024 * 1024)}c \
            -regextype posix-extended -iregex '.*\.(${extRegex})' -print0 \
          | LC_ALL=C sort -z \
          | while IFS= read -r -d '' f; do
              if [ "$uploaded" -ge "$BATCH" ]; then
                echo "drive-paperless: batch cap ($BATCH) reached — more files pending for ${src.tag}"
                break
              fi
              rel="${"\${f#\"$root\"/}"}"
              case "$rel" in
                *$'\n'*)
                  echo "drive-paperless: skipping newline-in-name file: $rel" >&2
                  continue
                  ;;
              esac
              size="$(stat -c %s -- "$f")"
              line="$(printf '%s\t%s\t%s' ${lib.escapeShellArg src.tag} "$rel" "$size")"
              if grep -qxF "$line" "${journal}" 2>/dev/null; then
                continue
              fi
              title="$(basename -- "$f")"
              title="${"\${title%.*}"}"
              title="$(printf '%.128s' "$title")"
              created="$(date -u -d @"$(stat -c %Y -- "$f")" +%Y-%m-%d 2>/dev/null || true)"
              args_post=(-F "document=@$f" -F "title=$title" -F "correspondent=$cid")
              if [ -n "$created" ]; then
                args_post+=(-F "created=$created")
              fi
              for tid in $tids; do
                args_post+=(-F "tags=$tid")
              done
              echo "drive-paperless: uploading [${
                lib.escapeShellArg src.tag
              }] $rel"
              if curl -fsS -H "Authorization: Token $TOKEN" \
                -X POST "$BASE/api/documents/post_document/" "''${args_post[@]}"; then
                printf '%s\n' "$line" >>"${journal}"
                uploaded=$((uploaded + 1))
              else
                echo "drive-paperless: upload FAILED for $rel (not journaled; retried next run)" >&2
                failed=$((failed + 1))
              fi
            done
        '';

      ingestScript = pkgs.writeShellApplication {
        name = "drive-paperless-ingest";
        runtimeInputs = [
          pkgs.curl
          pkgs.jq
          pkgs.coreutils
          pkgs.findutils
          pkgs.gnugrep
          pkgs.bash
        ];
        text = ''
          set -euo pipefail

          BASE="''${DRIVE_PAPERLESS_URL:?DRIVE_PAPERLESS_URL not set}"
          TOKEN="''${DRIVE_PAPERLESS_TOKEN:?DRIVE_PAPERLESS_TOKEN not set}"
          STATE="''${DRIVE_PAPERLESS_STATE:?DRIVE_PAPERLESS_STATE not set}"
          BATCH=${toString cfg.batchSize}
          uploaded=0
          failed=0
          mkdir -p "$STATE"

          api() {
            curl -fsS -H "Authorization: Token $TOKEN" "$@"
          }

          # ensure_id <correspondents|tags> <name> -> id (created if missing)
          ensure_id() {
            kind="$1"
            name="$2"
            if resp="$(api --get --data-urlencode "name__iexact=$name" "$BASE/api/$kind/")"; then
              id="$(printf '%s' "$resp" | jq -r '.results | if length > 0 then .[0].id else empty end')"
              if [ -n "$id" ]; then
                echo "$id"
                return 0
              fi
            fi
            api -X POST -H "Content-Type: application/json" \
              -d "$(jq -cn --arg n "$name" '{name: $n}')" "$BASE/api/$kind/" \
              | jq -r '.id'
          }

          # Per-source metadata snapshots: each source writes its resolved
          # "cid tids" to a state file so the (subshell-free) scan blocks
          # read them without re-calling the API per file.
          ${
            lib.concatMapStringsSep "\n" (src: ''
              meta_file_${lib.strings.sanitizeDerivationName src.tag}="$STATE/meta_${lib.strings.sanitizeDerivationName src.tag}"
            '') cfg.sources
          }
          continue_sources=0
          ${
            lib.concatMapStringsSep "\n " (src: ensureBlock src) cfg.sources
          }

          ${
            lib.concatMapStringsSep "\n " (src: scanBlock src) cfg.sources
          }

          echo "drive-paperless: run complete — uploaded=$uploaded failed=$failed"
          if [ "$failed" -gt 0 ]; then
            echo "drive-paperless: $failed upload(s) failed — NOT touching last_success; unit fails so onFailure alerts" >&2
            exit 1
          fi
          touch "$STATE/last_success"
        '';
      };
    in
    {
      options.services.drive-paperless = {
        enable = lib.mkEnableOption "Google Drive mirror → Paperless-ngx ingest pipeline";

        sources = lib.mkOption {
          type = lib.types.listOf (
            lib.types.submodule {
              options = {
                path = lib.mkOption {
                  type = lib.types.str;
                  description = "Directory scanned for documents (typically a google-sync mirror destination under /mnt/pool).";
                };
                correspondent = lib.mkOption {
                  type = lib.types.str;
                  description = "Paperless correspondent name for documents from this source (created if missing).";
                };
                tag = lib.mkOption {
                  type = lib.types.str;
                  description = "Per-source Paperless tag (created if missing); also the journal source key. Must be unique across sources.";
                };
              };
            }
          );
          default = defaultSources;
          description = ''
            One entry per scanned tree. Defaults derive 1:1 from
            services.google-sync.mirrors when that module is in scope
            (gdrive/gdrive-shared/gwork with account-named correspondents).
          '';
        };

        globalTag = lib.mkOption {
          type = lib.types.str;
          default = "google-drive";
          description = "Tag applied to EVERY ingested document on top of the per-source tag.";
        };

        ingestImages = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Also ingest raster images (jpg/png/tiff/webp/gif). OFF by default:
            camera photos belong in Immich, and a photo-heavy Drive would
            flood the document archive with misclassified pictures. Enable
            only for scanned-document image collections.
          '';
        };

        batchSize = lib.mkOption {
          type = lib.types.ints.positive;
          default = 200;
          description = "Max files uploaded per run (IO-storm discipline; the hourly timer drains the rest).";
        };

        maxFileSizeMB = lib.mkOption {
          type = lib.types.ints.positive;
          default = 100;
          description = "Files larger than this are skipped (huge PDFs choke OCR); recorded in the run log only.";
        };

        interval = lib.mkOption {
          type = lib.types.str;
          default = "hourly";
          description = "OnCalendar for the ingest timer.";
        };

        user = lib.mkOption {
          type = lib.types.str;
          default = "drive-paperless";
          description = "System user running the ingest (needs read access to the mirror trees).";
        };

        group = lib.mkOption {
          type = lib.types.str;
          default = "drive-paperless";
          description = "System group for the ingest user.";
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = paperlessPresent && config.services.paperless.enable;
            message = "drive-paperless.enable requires services.paperless.enable: uploads go through its DRF API and the token mint runs drf_create_token against its DB";
          }
          {
            assertion = cfg.sources != [ ];
            message = "drive-paperless: sources must not be empty (default derives from services.google-sync.mirrors when in scope)";
          }
          {
            assertion = (lib.unique (map (s: s.tag) cfg.sources)) == (map (s: s.tag) cfg.sources);
            message = "drive-paperless: source tags must be unique (they key the journal)";
          }
          {
            assertion = lib.all (s: lib.strings.hasPrefix "/" s.path) cfg.sources;
            message = "drive-paperless: source paths must be absolute";
          }
          {
            assertion = lib.all (s: lib.strings.hasPrefix "/mnt/" s.path) cfg.sources;
            message = "drive-paperless: source paths must live under /mnt/ (mount-gating doctrine — never scan a root-fs shadow of a detached pool)";
          }
        ];

        users.users.${cfg.user} = {
          isSystemUser = true;
          inherit (cfg) group;
          home = stateDir;
          description = "Drive → Paperless ingest user";
        };
        users.groups.${cfg.group} = { };

        # Idempotent DRF token mint (bank-sync-paperless-token pattern):
        # drf_create_token is get_or_create, the token lives only in tmpfs,
        # and the mint runs as the paperless user (peer-auth PG socket).
        # The ingest unit runs as drive-paperless, so a root ExecStartPost
        # ("+" prefix) hands the env file over.
        systemd.services.drive-paperless-token = lib.mkIf paperlessEnabled {
          description = "Drive → Paperless ingest - API token mint";
          after = [
            "network-online.target"
            "postgresql.service"
          ];
          wants = [
            "network-online.target"
            "postgresql.service"
          ];
          inherit onFailure;
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          unitConfig.RequiresMountsFor = [ config.services.paperless.dataDir ];
          path = [
            pkgs.coreutils
            pkgs.gnugrep
          ];
          script = ''
            MINT_OUT=${runEnv}
            umask 077
            token="$(${config.services.paperless.manage}/bin/paperless-manage drf_create_token admin)"
            hex="$(printf '%s\n' "$token" | grep -oE '[0-9a-f]{40}' | head -n1)"
            if [ -z "$hex" ]; then
              echo "drive-paperless-token: token extraction failed (unexpected drf_create_token output)" >&2
              exit 1
            fi
            printf 'DRIVE_PAPERLESS_TOKEN=%s\n' "$hex" > "$MINT_OUT"
          '';
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              # Django system checks write a probe file into the dataDir
              # (paperless checks.py, 2026-09-16 EROFS lesson in
              # paperless.nix) — paperless-user identity + write access.
              User = config.services.paperless.user;
              ReadWritePaths = [ config.services.paperless.dataDir ];
              RuntimeDirectory = "drive-paperless";
              # 0711: the ingest user must traverse to its 0400 env file.
              RuntimeDirectoryMode = "0711";
              # Default (no) would DELETE the dir when this oneshot
              # deactivates — before the ingest unit ever reads its
              # EnvironmentFile. tmpfs semantics are untouched.
              RuntimeDirectoryPreserve = true;
              TimeoutStartSec = "3min";
              ExecStartPost = "+${mintChownScript}";
            }
            (harden { ProtectSystem = "strict"; })
            (serviceOneshotDefaults { })
          ];
        };

        systemd.services.drive-paperless = lib.mkIf paperlessEnabled {
          description = "Google Drive mirror → Paperless-ngx ingest";
          after =
            [ "drive-paperless-token.service" ]
            ++ lib.optionals (config.systemd ? services && config.systemd.services ? paperless-web) [ "paperless-web.service" ]
            ++ lib.optionals (googleSyncPresent && config.services.google-sync.enable) [ "google-sync.service" ];
          wants =
            [ "drive-paperless-token.service" ]
            ++ lib.optionals (config.systemd ? services && config.systemd.services ? paperless-web) [ "paperless-web.service" ]
            ++ lib.optionals (googleSyncPresent && config.services.google-sync.enable) [ "google-sync.service" ];
          # Token must exist before every run (convergent mint).
          requires = [ "drive-paperless-token.service" ];
          # Never scan root-fs shadows of a detached pool.
          unitConfig.RequiresMountsFor = lib.unique (map (s: s.path) cfg.sources);
          inherit onFailure;
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = cfg.user;
              Group = cfg.group;
              ExecStart = lib.getExe ingestScript;
              Environment = [
                "DRIVE_PAPERLESS_URL=http://127.0.0.1:${toString ports.paperless}"
                "DRIVE_PAPERLESS_STATE=${stateDir}"
              ];
              EnvironmentFile = [ runEnv ];
              # A full batch of max-size files is disk-read-bound on the
              # HDD pool; give the walk + upload room beyond the 5min floor.
              TimeoutStartSec = "30min";
            }
            (harden {
              # find over six-digit file counts + jq + curl buffers.
              MemoryMax = "512M";
              # Only the state dir is written; mirror trees stay read-only
              # (ProtectSystem=full keeps /usr,/boot,/etc RO, /mnt readable).
              ReadWritePaths = [ stateDir ];
            })
            (serviceOneshotDefaults { })
            ioTier.background
          ];
        };

        systemd.timers.drive-paperless = lib.mkIf paperlessEnabled {
          description = "Drive → Paperless ingest timer";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = cfg.interval;
            Persistent = true;
            RandomizedDelaySec = "10m";
          };
        };

        # Freshness sentinel (google-sync pattern): a stale last_success
        # trips the global backup_all_healthy Gatus check within 25h —
        # hourly runs + catch-up make 25h generous.
        services.backup-coordination = lib.optionalAttrs (options ? services.backup-coordination) {
          backups.drive-paperless = {
            directory = stateDir;
            filePattern = "last_success";
            maxAgeHours = 25;
          };
        };
      };
    };
}
