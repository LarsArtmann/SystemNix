# Runbook: docs/services/audible-sync.md
# audible-sync — Audible library → HDD pool archive (audible-cli).
#
# Weekly full-library sync of every book in the Audible account ("all books
# ever bought or listened to" = the account library listing): exports the
# library listing as JSON for audit/diff, downloads every item as AAXC +
# license voucher + cover + chapter metadata + PDF, then decrypts each book
# to a DRM-free M4B into books/ (vendored audible-cli decrypt plugin +
# ffmpeg, chapters rebuilt from the API metadata). The raw AAXC + voucher
# stay in downloads/ — they are the recoverable source of truth; books/ is
# the convenience copy.
#
# Why audible-cli and NOT OpenAudible (installed, GUI): OpenAudible has no
# headless mode (its own docs: GUI app; the Docker image is a browser GUI).
# audible-cli is fully scriptable and its CI-proven auth shape is just two
# stable device credentials (adp_token + device_private_key) — no
# refresh-token rotation, so the sops-rendered auth file can stay
# read-only forever.
#
# Ships DISABLED until the owner completes the interactive Amazon login and
# pastes the two device credentials into the sops scaffold
# (platforms/nixos/secrets/audible-sync.yaml) — the unit tripwire fails
# loudly with the go-live checklist while PLACEHOLDER values remain.
_: {
  flake.nixosModules.audible-sync =
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
        ioTier
        onFailure
        mkDnsGate
        ;

      cfg = config.services.audible-sync;

      poolDir = "/mnt/pool/services/audible";
      stateDir = "/var/lib/audible-sync";

      apiHost = "api.audible.${cfg.countryCode}";

      dnsGate = mkDnsGate {
        inherit pkgs;
        serviceName = "audible-sync";
        hostname = apiHost;
      };

      # The `decrypt` plugin command is NOT shipped in the audible-cli wheel
      # (plugin_cmds/ lives outside src/ upstream) — vendored from the
      # pinned upstream rev, verified API-compatible with nixpkgs
      # audible-cli 0.3.3 (pass_session + AudibleCliException both exist
      # there; plugins.py loads cmd_*.py from AUDIBLE_PLUGIN_DIR).
      decryptPlugin = pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/mkb79/audible-cli/274539eba80a63ddccb79a9ec4f59b2fe911e232/plugin_cmds/cmd_decrypt.py";
        hash = "sha256-uvni0qj29UGw0PNG4DiB/oD8bYmwN5P0GixpYWfW6XQ=";
      };

      pluginDir = pkgs.runCommand "audible-sync-plugins" { } ''
        mkdir -p $out
        cp ${decryptPlugin} $out/cmd_decrypt.py
      '';

      configToml = pkgs.writeText "audible-sync-config.toml" ''
        [APP]
        primary_profile = "default"

        [profile.default]
        auth_file = "auth.json"
        country_code = "${cfg.countryCode}"
      '';

      # Fail fast with an actionable message when the sops scaffold still
      # holds PLACEHOLDER device credentials (the module ships disabled for
      # exactly this reason) or the auth JSON is not parseable in the
      # CI-proven minimal shape — otherwise audible-cli buries the cause in
      # auth errors. Also assembles AUDIBLE_CONFIG_DIR: config.toml (plain
      # Nix text) + auth.json (sops-rendered) symlinked into one dir,
      # because audible-cli always requires both in the same dir and has no
      # env-var-only auth.
      configCheck = pkgs.writeShellApplication {
        name = "audible-sync-config-check";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gnugrep
          pkgs.jq
        ];
        text = ''
          set -euo pipefail

          authFile="''${AUDIBLE_SYNC_AUTH_FILE:?AUDIBLE_SYNC_AUTH_FILE not set}"
          configDir="${stateDir}/config"

          if grep -q PLACEHOLDER "$authFile"; then
            cat >&2 <<'EOT'
          audible-sync: Audible device credentials are still PLACEHOLDER.
          Go-live checklist (docs/services/audible-sync.md):
            1. Run `nix shell nixpkgs#audible-cli -c audible-quickstart`
               (interactive Amazon login, ONCE — on any machine).
            2. Extract the two stable device credentials:
               `jq -r '.adp_token, .device_private_key' < ~/.audible/auth.json`
            3. Paste them into the auth JSON via the sops EDITOR (never a
               command line):
               SOPS_AGE_KEY=$(sudo cat /etc/ssh/ssh_host_ed25519_key | ssh-to-age -private-key) \
                 sops platforms/nixos/secrets/audible-sync.yaml
               shape: {"adp_token": "...", "device_private_key": "..."}
            4. Redeploy (`nix run .#deploy`).
          EOT
            exit 1
          fi

          jq -e '.adp_token and .device_private_key' < "$authFile" > /dev/null || {
            echo "audible-sync: $authFile is not the expected auth JSON shape" >&2
            echo "audible-sync: expected {\"adp_token\": \"...\", \"device_private_key\": \"...\"}" >&2
            exit 1
          }

          mkdir -p "$configDir"
          ln -sfn ${configToml} "$configDir/config.toml"
          ln -sfn "$authFile" "$configDir/auth.json"
        '';
      };

      syncScript = pkgs.writeShellApplication {
        name = "audible-sync-run";
        runtimeInputs = [
          pkgs.audible-cli
          pkgs.ffmpeg
          pkgs.coreutils
          pkgs.findutils
          pkgs.jq
        ];
        text = ''
          set -euo pipefail

          libDir="${poolDir}/library"
          dlDir="${poolDir}/downloads"
          bookDir="${poolDir}/books"
          mkdir -p "$libDir" "$dlDir" "$bookDir"

          # 1. Full library listing as JSON: the audit trail of "every book
          #    in the account", diffable across runs (dated snapshots, pruned
          #    to the N newest).
          echo "audible-sync: exporting full library listing"
          audible library export -f json -o "$libDir/library.json"
          cp "$libDir/library.json" "$libDir/library-$(date +%Y-%m-%d).json"
          ls -1t "$libDir"/library-*.json | tail -n +${toString (cfg.librarySnapshots + 1)} | xargs -r rm -f
          libItems=$(jq 'length' < "$libDir/library.json")
          echo "audible-sync: library lists $libItems items"

          # 2. Download everything. Default is skip-if-exists (--overwrite
          #    would re-download), so weekly runs are incremental after the
          #    first seed. --ignore-errors keeps one bad book from blocking
          #    the rest of the library; the command STILL exits non-zero if
          #    any job failed (raise_for_errors), which set -e turns into a
          #    failed unit → last_success NOT touched → backup-coordination
          #    alerts → OnFailure Discord names the ASIN from the journal.
          echo "audible-sync: downloading full library (AAXC + voucher + cover + chapters + pdf)"
          audible download --all --aaxc --chapter --cover --cover-size ${toString cfg.coverSize} --pdf \
            --ignore-errors -y --no-progress -j ${toString cfg.jobs} \
            --filename-mode ${cfg.filenameMode} -o "$dlDir"

          dlCount=$(find "$dlDir" -name '*.aaxc' | wc -l)
          echo "audible-sync: $dlCount AAXC files present (library: $libItems items; podcasts count as multiple episode files)"

          # 3. Decrypt to DRM-free M4B. Per-file loop: the plugin has NO
          #    error handling (its own docstring) — one corrupt file would
          #    abort a plain --all pass at the same point every week and
          #    silently starve every book after it. Chapters are rebuilt
          #    from the API metadata (-r), tolerating mismatches (-t).
          #    The raw AAXC + voucher stay in downloads/ either way.
          echo "audible-sync: decrypting to DRM-free M4B (books/)"
          failures=0
          while IFS= read -r -d '' f; do
            audible decrypt "$f" -d "$bookDir" -r -t || {
              echo "audible-sync: DECRYPT FAILED: $f (raw AAXC + voucher kept in $dlDir)"
              failures=$((failures + 1))
            }
          done < <(find "$dlDir" -name '*.aaxc' -print0)
          bookCount=$(find "$bookDir" -name '*.m4b' | wc -l)
          echo "audible-sync: $bookCount M4B in books/, $failures decrypt failures"

          if [ "$failures" -gt 0 ]; then
            echo "audible-sync: $failures book(s) failed to decrypt — failing the unit so the shortfall is visible"
            echo "audible-sync: recovery: delete the corrupt .aaxc + .voucher in $dlDir so next week re-downloads it (docs/services/audible-sync.md)"
            exit 1
          fi

          # 4. Freshness sentinel for backup-coordination (Gatus alerts via
          #    the global backup_all_healthy check when this goes stale).
          #    Only touched when the download pass AND every decrypt passed.
          touch "${stateDir}/last_success"
          echo "audible-sync: run complete — last_success updated"
        '';
      };
    in
    {
      options.services.audible-sync = {
        enable = lib.mkEnableOption "Audible library → HDD pool archive via audible-cli";

        schedule = lib.mkOption {
          type = lib.types.str;
          default = "Sun *-*-* 05:00";
          description = "OnCalendar for the sync timer (default: weekly, Sunday 05:00).";
        };

        countryCode = lib.mkOption {
          type = lib.types.str;
          default = "de";
          description = ''
            Audible marketplace country code (config.toml + api.audible.
            <tld> DNS-gate host). Only direct-TLD markets work verbatim
            (de, fr, it, es, com); co.uk/com.au markets need adjusting.
          '';
        };

        jobs = lib.mkOption {
          type = lib.types.int;
          default = 3;
          description = "audible download --jobs (parallel downloads).";
        };

        coverSize = lib.mkOption {
          type = lib.types.int;
          default = 1215;
          description = "Cover image size (largest Audible API offers).";
        };

        filenameMode = lib.mkOption {
          type = lib.types.enum [
            "ascii"
            "asin_ascii"
            "unicode"
            "asin_unicode"
            "asin_only"
          ];
          default = "asin_ascii";
          description = "Filename scheme; asin_ascii = stable, collision-free, ASIN-prefixed.";
        };

        librarySnapshots = lib.mkOption {
          type = lib.types.int;
          default = 13;
          description = "How many dated library-<date>.json snapshots to keep (a quarter of weekly runs).";
        };

        timeout = lib.mkOption {
          type = lib.types.str;
          default = "48h";
          description = "TimeoutStartSec; the first full-library seed can run for many hours.";
        };

        maxAgeHours = lib.mkOption {
          type = lib.types.int;
          default = 240;
          description = "backup-coordination staleness window (weekly cadence → 10 days).";
        };
      };

      config = lib.mkIf cfg.enable {
        users.users.audible-sync = {
          isSystemUser = true;
          group = "audible-sync";
          description = "Audible library sync service user";
        };
        users.groups.audible-sync = { };

        # Secret audible_sync_auth_json (the CI-proven minimal auth JSON:
        # adp_token + device_private_key — stable device credentials, no
        # refresh-token rotation, so the rendered file is read-only) is
        # declared centrally in sops.nix — mkSecrets "audible-sync.yaml",
        # gated on svcEnabled "audible-sync". Consumed via
        # AUDIBLE_SYNC_AUTH_FILE below.

        # The pool dirs MUST exist before audible-sync.service starts:
        # systemd sets up mount namespacing (ReadWritePaths) BEFORE any
        # ExecStartPre, and a ReadWritePaths entry pointing at a missing
        # path aborts the unit with status=226/NAMESPACE (google-sync
        # incident 2026-08-18). Mount-gated so a detached pool fails loudly
        # instead of contaminating the root fs; deliberately NO tmpfiles
        # rule (tmpfiles can pre-date the pool mount). deploy.sh restarts
        # the oneshot after switches — oneshot+RemainAfterExit ignores
        # restartTriggers.
        systemd.services.audible-sync-dirs = {
          description = "Create Audible archive directories on the HDD pool";
          wantedBy = [ "multi-user.target" ];
          unitConfig.RequiresMountsFor = [ "/mnt/pool" ];
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = "root";
              RemainAfterExit = true;
            }
            (harden {
              MemoryMax = "128M";
              ReadWritePaths = [ poolDir ];
            })
            (serviceOneshotDefaults { })
          ];
          script = ''
            for d in library downloads books; do
              mkdir -p ${poolDir}/$d
              chown audible-sync:audible-sync ${poolDir}/$d
              chmod 0755 ${poolDir}/$d
            done
          '';
        };

        systemd.services.audible-sync = {
          description = "Audible library → HDD pool archive (audible-cli weekly full-library sync)";
          after = [ "audible-sync-dirs.service" ] ++ dnsGate.after;
          wants = [ "audible-sync-dirs.service" ] ++ dnsGate.wants;
          inherit onFailure;
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          serviceConfig = lib.mkMerge [
            (harden {
              MemoryMax = "1G";
              ReadWritePaths = [ poolDir ];
            })
            (serviceOneshotDefaults { })
            ioTier.background
            {
              Type = "oneshot";
              User = "audible-sync";
              Group = "audible-sync";
              StateDirectory = "audible-sync";
              # First full-library seed can run for many hours to days;
              # subsequent runs converge in minutes. Timer ticks don't
              # stack while a run is active.
              TimeoutStartSec = cfg.timeout;
              Environment = [
                "AUDIBLE_CONFIG_DIR=${stateDir}/config"
                "AUDIBLE_PLUGIN_DIR=${pluginDir}"
                "AUDIBLE_SYNC_AUTH_FILE=${config.sops.secrets.audible_sync_auth_json.path}"
              ];
              ExecStartPre = [ (lib.getExe configCheck) ] ++ dnsGate.serviceConfig.ExecStartPre;
              ExecStart = lib.getExe syncScript;
            }
          ];
        };

        systemd.timers.audible-sync = {
          description = "Weekly Audible library sync";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = cfg.schedule;
            Persistent = true;
            RandomizedDelaySec = "10min";
          };
        };

        services.backup-coordination.backups.audible-sync = {
          directory = stateDir;
          filePattern = "last_success";
          maxAgeHours = cfg.maxAgeHours;
        };

        # Service-integration registry entry: the homepage tile only (no
        # vHost — the sync is a weekly CLI timer landing on the HDD pool;
        # freshness alerting stays on the backup-coordination row above).
        services.integration = lib.optionalAttrs (options ? services.integration) {
          audible-sync = {
            inherit (cfg) enable;
            vHost.layer = "none";
            homepage = {
              name = "Audible Sync";
              group = "Sync & Backup";
              description = "Audible library → HDD pool archive (weekly)";
              # No Audible glyph exists in the dashboard-icons pack (checked
              # upstream 2026-11-01); openaudible.png is the nearest
              # semantic one and the user already runs OpenAudible.
              icon = "openaudible.png";
            };
          };
        };
      };
    };
}
