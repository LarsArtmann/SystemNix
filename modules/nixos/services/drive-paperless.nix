# Runbook: docs/services/google-sync.md (section "Drive → Paperless ingest")
# Google Drive mirror → Paperless-ngx archival pipeline.
#
# Scans the google-sync mirror trees on the HDD pool (or any configured
# source directory), routes DOCUMENT types (PDFs, office documents,
# text/email/e-book formats) into Paperless-ngx via the DRF API with
# per-account metadata:
#   correspondent = per-source (Google Drive / Google Workspace),
#   tags          = global import tag + per-source remote tag,
#   title         = filename stem, created = Drive modified time (mtime).
# With ingestImages = true, raster images (jpg/png/heic/webp/…) route to
# IMMICH instead (POST /api/assets — contract verified against the deployed
# immich 3.3.3 source: multipart assetData + required ISO
# fileCreatedAt/fileModifiedAt, x-api-key auth; byte-identical duplicates
# return 200 status=duplicate and are harmless).
#
# Why API upload instead of the consume directory: the API sets metadata
# atomically at upload (PostDocumentView accepts correspondent/tags/title/
# created — verified against the pinned paperless-ngx 3.3.1 source), needs
# no global PAPERLESS_CONSUMER_* flag flips that would change semantics for
# every other consume-dir user, and rides the bank-sync-paperless runtime
# token-mint pattern (drf_create_token, tmpfs-only, zero sops steps).
#
# Idempotence: an append-only TSV journal (source TAB path TAB size) gates
# re-uploads; paperless itself dedups byte-identical content server-side,
# so a journal miss is harmless (worst case: one rejected duplicate task).
# A file whose SIZE changed (new Drive revision synced by rclone) misses
# its journal line and uploads as a new document version.
#
# Storm discipline: bounded batch per run (default 200) + hourly timer +
# ioTier.background — the ~1.9 TB private account can hold six-digit file
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
      runEnv = "/run/drive-paperless/env";

      # google-sync is optional at eval scope the same way (VM tests may
      # import this module alone). When present, the default sources mirror
      # its mirror list 1:1 — one google-sync enable flip brings up mirror
      # AND ingest with no second config edit.
      googleSyncPresent = options ? services.google-sync;
      # Image-routing target (ingestImages): same eval-optional treatment —
      # isolated checks co-import the nixpkgs immich module.
      immichPresent = options ? services.immich;
      correspondentFor =
        remote:
        {
          gdrive = "Google Drive (private)";
          gdrive-shared = "Google Drive (shared with me)";
          gwork = "Google Workspace";
        }.${remote} or "Google Drive (${remote})";
      defaultSources =
        if googleSyncPresent then
          map (m: {
            path = m.destination;
            correspondent = correspondentFor m.remote;
            tag = m.remote;
          }) config.services.google-sync.mirrors
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
        "heic"
        "heif"
        "avif"
        "bmp"
      ];
      allExtensions = docExtensions ++ lib.optionals cfg.ingestImages imageExtensions;
      extRegex = lib.concatStringsSep "|" allExtensions;
      imageExtPattern = lib.concatStringsSep "|" imageExtensions;

      # Shell-safe identifier for per-source variable names: '-' is legal in
      # the tag alphabet but NOT in bash identifiers — gdrive-shared must
      # become meta_gdrive_shared or every reference is a bad-substitution
      # error at runtime (caught 2026-10-19: the identity no-op version broke
      # the default-derived gdrive-shared source; fixtures only used
      # hyphen-free tags until the images leg added one). Uniqueness is
      # asserted on SLUGS so tags differing only in -/_ cannot collide.
      slug = lib.replaceStrings [ "-" ] [ "_" ];

      mintChownScript = pkgs.writeShellScript "drive-paperless-token-chown" ''
        chown ${cfg.user}:${cfg.group} ${runEnv}
        chmod 0400 ${runEnv}
      '';

      # Resolve-or-create correspondent + tags ONCE per source, before any
      # scanning (fail loud here if paperless is unreachable).
      ensureBlock = src: ''
        echo "drive-paperless: ensuring metadata for source ${src.tag}"
        meta_${slug src.tag}="$(
          cid="$(ensure_id correspondents ${lib.escapeShellArg src.correspondent})"
          tids=""
          for tag_name in ${lib.escapeShellArg cfg.globalTag} ${lib.escapeShellArg src.tag}; do
            tid="$(ensure_id tags "$tag_name")"
            tids="$tids $tid"
          done
          printf '%s %s\n' "$cid" "$tids"
        )"
      '';

      scanBlock = src: ''
        root="${src.path}"
        if [ -d "$root" ]; then
          read -r cid tids <<<"''${meta_${slug src.tag}}"
          # Loop reads from process substitution, NOT a pipeline —
          # `find | while` forks the loop into a subshell and silently
          # drops the uploaded/failed/cap_hit counters the summary and
          # the fail-loud exit below depend on.
          while IFS= read -r -d ''' f; do
            if [ "$uploaded" -ge "$BATCH" ]; then
              echo "drive-paperless: batch cap ($BATCH) reached — more files pending for ${src.tag}" >&2
              cap_hit=1
              break
            fi
            rel="''${f#"$root"/}"
              case "$rel" in
                *$'\n'*)
                  echo "drive-paperless: skipping newline-in-name file: $rel" >&2
                  continue
                  ;;
              esac
              size="$(stat -c %s -- "$f")"
              line="$(printf '%s\t%s\t%s' ${lib.escapeShellArg src.tag} "$rel" "$size")"
              if grep -qxF "$line" "$journal" 2>/dev/null; then
                continue
              fi
              lower="''${rel,,}"
              if [ "$IMAGES_ENABLED" = "1" ] && [[ "$lower" =~ \.(${imageExtPattern})$ ]]; then
                # Drive image → Immich (contract verified against the
                # deployed immich 3.3.3 source: byte-identical duplicates
                # answer 200 status=duplicate — a journal miss is harmless).
                iso="$(date -u -d @"$(stat -c %Y -- "$f")" +%Y-%m-%dT%H:%M:%SZ)"
                echo "drive-paperless: uploading [${src.tag}] $rel → immich"
                if immich -X POST "$IMMICH_URL/api/assets" \
                  -F "assetData=@$f" \
                  -F "filename=$(basename -- "$f")" \
                  -F "fileCreatedAt=$iso" \
                  -F "fileModifiedAt=$iso"; then
                  printf '%s\n' "$line" >>"$journal"
                  uploaded=$((uploaded + 1))
                  images=$((images + 1))
                else
                  echo "drive-paperless: immich upload FAILED for $rel (not journaled; retried next run)" >&2
                  printf '%s\n' "$line" >>"$failed_log"
                  failed=$((failed + 1))
                fi
              else
                title="$(basename -- "$f")"
                title="''${title%.*}"
                title="$(printf '%.128s' "$title")"
                created="$(date -u -d @"$(stat -c %Y -- "$f")" +%Y-%m-%d 2>/dev/null || true)"
                args_post=(-F "document=@$f" -F "title=$title" -F "correspondent=$cid")
                if [ -n "$created" ]; then
                  args_post+=(-F "created=$created")
                fi
                for tid in $tids; do
                  args_post+=(-F "tags=$tid")
                done
                echo "drive-paperless: uploading [${src.tag}] $rel"
                if curl -fsS -H "Authorization: Token $TOKEN" \
                  -X POST "$BASE/api/documents/post_document/" "''${args_post[@]}"; then
                  printf '%s\n' "$line" >>"$journal"
                  uploaded=$((uploaded + 1))
                  docs=$((docs + 1))
                else
                  echo "drive-paperless: upload FAILED for $rel (not journaled; retried next run)" >&2
                  printf '%s\n' "$line" >>"$failed_log"
                  failed=$((failed + 1))
                fi
              fi
            done < <(find "$root" -xdev -type f -size +0c -size -${
              toString (cfg.maxFileSizeMB * 1024 * 1024)
            }c \
            -regextype posix-extended -iregex '.*\.(${extRegex})' -print0 | LC_ALL=C sort -z)
        else
          echo "drive-paperless: source dir $root missing — skipped (first seed not run yet?)" >&2
          missing_source=$((missing_source + 1))
        fi
      '';

      ingestScript = pkgs.writeShellApplication {
        name = "drive-paperless-ingest";
        runtimeInputs = [
          pkgs.curl
          pkgs.jq
          pkgs.coreutils
          pkgs.findutils
          pkgs.gnugrep
        ];
        text = ''
          set -euo pipefail
          # Without this, failures inside $( ) command substitutions do NOT
          # propagate (bash default) — a dead API would yield empty
          # correspondent/tag ids and uploads with blank metadata. Proven
          # by the fixture's broken-stub leg (2026-10-19).
          shopt -s inherit_errexit

          BASE="''${DRIVE_PAPERLESS_URL:?DRIVE_PAPERLESS_URL not set}"
          TOKEN="''${DRIVE_PAPERLESS_TOKEN:?DRIVE_PAPERLESS_TOKEN not set}"
          STATE="''${DRIVE_PAPERLESS_STATE:?DRIVE_PAPERLESS_STATE not set}"
          BATCH=${toString cfg.batchSize}
          # bash 0/1 flag — lib.boolToString renders "true"/"false", useless
          # for [ x = "1" ] comparisons.
          IMAGES_ENABLED=${if cfg.ingestImages then "1" else "0"}
          journal="$STATE/journal.tsv"
          failed_log="$STATE/failed.log"
          uploaded=0
          docs=0
          images=0
          failed=0
          cap_hit=0
          missing_source=0
          mkdir -p "$STATE"
          : >"$failed_log"

          api() {
            curl -fsS -H "Authorization: Token $TOKEN" "$@"
          }

          immich() {
            curl -fsS -H "x-api-key: $IMMICH_API_KEY" "$@"
          }

          if [ "$IMAGES_ENABLED" = "1" ]; then
            IMMICH_URL="''${IMMICH_URL:?IMMICH_URL not set (ingestImages requires Immich)}"
            IMMICH_API_KEY="''${IMMICH_API_KEY:?IMMICH_API_KEY not set (ingestImages requires the drive_paperless_immich_api_key sops secret)}"
            case "$IMMICH_API_KEY" in
              PLACEHOLDER*)
                echo "drive-paperless: IMMICH_API_KEY is still a PLACEHOLDER — create an Immich API key (Account Settings → API Keys, scope asset.read + asset.upload) and sops --set it into platforms/nixos/secrets/drive-paperless-immich.yaml (runbook: docs/services/google-sync.md)" >&2
                exit 1
                ;;
            esac
            # Preflight: docs + images are ONE pipeline — an unreachable or
            # key-rejecting Immich fails the whole run loudly (onFailure)
            # instead of silently skipping half the payload.
            if ! curl -fsS --max-time 10 "$IMMICH_URL/api/server/ping" >/dev/null 2>&1; then
              echo "drive-paperless: Immich unreachable at $IMMICH_URL — failing the run (docs + images are one pipeline; availability is also Gatus-owned, but a dead Immich must not pass silently)" >&2
              exit 1
            fi
            key_code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 -H "x-api-key: $IMMICH_API_KEY" "$IMMICH_URL/api/users/me" || echo 000)"
            if [ "$key_code" != "200" ]; then
              echo "drive-paperless: Immich rejected the API key (HTTP $key_code) — wrong secret or missing asset.read/asset.upload scope; see drive-paperless-immich.yaml" >&2
              exit 1
            fi
          fi

          # ensure_id <correspondents|tags> <name> -> id (created if missing).
          # Both endpoints support ?name__iexact= (verified in the pinned
          # paperless-ngx 3.3.1 filters.py CHAR_KWARGS); creation POSTs
          # {name}.
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

          ${lib.concatMapStringsSep "\n" ensureBlock cfg.sources}

          ${lib.concatMapStringsSep "\n" scanBlock cfg.sources}

          echo "drive-paperless: run complete — uploaded=$uploaded (docs=$docs images=$images) failed=$failed cap_hit=$cap_hit missing_source=$missing_source"
          if [ "$failed" -gt 0 ]; then
            echo "drive-paperless: $failed upload(s) failed (see $failed_log) — NOT touching last_success; unit fails so onFailure alerts" >&2
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
            Route raster images (jpg/png/heic/webp/gif/tiff/avif/bmp) to
            Immich via its /api/assets endpoint instead of skipping them;
            documents keep going to Paperless and images NEVER land in
            Paperless through this pipeline. OFF by default: requires the
            drive_paperless_immich_api_key sops secret
            (platforms/nixos/secrets/drive-paperless-immich.yaml) to carry a
            real key — Immich → Account Settings → API Keys, scope
            asset.read + asset.upload. The run fails loudly while the
            secret still holds its PLACEHOLDER.
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
            assertion = (lib.unique (map (s: slug s.tag) cfg.sources)) == (map (s: slug s.tag) cfg.sources);
            message = "drive-paperless: source tags must be unique after '-'→'_' sanitization (they key per-source shell variables)";
          }
          {
            assertion = lib.all (s: lib.strings.match "[a-zA-Z0-9_-]+" s.tag != null) cfg.sources;
            message = "drive-paperless: source tags must match [a-zA-Z0-9_-]+ (they become shell variable names post slug-sanitization)";
          }
          {
            assertion = lib.all (s: lib.strings.hasPrefix "/mnt/" s.path) cfg.sources;
            message = "drive-paperless: source paths must live under /mnt/ (mount-gating doctrine — never scan a root-fs shadow of a detached pool)";
          }
        ]
        ++ lib.optionals cfg.ingestImages [
          {
            assertion = immichPresent && config.services.immich.enable;
            message = "drive-paperless.ingestImages requires services.immich.enable: images upload via its /api/assets endpoint authenticated by the drive_paperless_immich_api_key sops secret";
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
          description = "Google Drive mirror → Paperless/Immich ingest";
          after = [
            "drive-paperless-token.service"
          ]
          ++ lib.optionals paperlessEnabled [ "paperless-web.service" ]
          ++ lib.optionals (cfg.ingestImages && immichPresent && config.services.immich.enable) [
            "immich-server.service"
          ]
          ++ lib.optionals (googleSyncPresent && config.services.google-sync.enable) [
            "google-sync.service"
          ];
          wants = [
            "drive-paperless-token.service"
          ]
          ++ lib.optionals paperlessEnabled [ "paperless-web.service" ]
          ++ lib.optionals (cfg.ingestImages && immichPresent && config.services.immich.enable) [
            "immich-server.service"
          ]
          ++ lib.optionals (googleSyncPresent && config.services.google-sync.enable) [
            "google-sync.service"
          ];
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
              ]
              ++ lib.optionals cfg.ingestImages [
                "IMMICH_URL=http://127.0.0.1:${toString ports.immich}"
              ];
              # sops path read by PID 1 (EnvironmentFile semantics) — the
              # secret is declared gated in sops.nix; isolated evals
              # co-import tests/mock-sops.nix and declare it (google-sync
              # pattern).
              EnvironmentFile = [
                runEnv
              ]
              ++ lib.optionals cfg.ingestImages [
                config.sops.secrets.drive_paperless_immich_api_key.path
              ];
              # systemd creates + owns /var/lib/drive-paperless (pre-namespace,
              # before ReadWritePaths processing — the 226 class). Without
              # this, the first live run dies at mkdir against root-owned
              # /var/lib (fixture missed it because the fixture injects STATE
              # into a scratch dir; found in the 2026-10-19 self-review §d.1).
              StateDirectory = "drive-paperless";
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
        # hourly runs + catch-up make 25h generous. UNGUARDED like
        # google-sync's row: eval scopes (VM tests, fixture checks) that
        # enable this module MUST co-import backup-coordination.nix — an
        # options?-guard does not survive the mkIf push-down (documented
        # integration.nix trap, 2026-09-15).
        services.backup-coordination.backups.drive-paperless = {
          directory = stateDir;
          filePattern = "last_success";
          maxAgeHours = 25;
        };
      };
    };
}
