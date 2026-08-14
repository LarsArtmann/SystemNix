# Hermes AI Agent Gateway: Discord bot, cron scheduler, messaging
{ inputs, ... }: {
  flake.nixosModules.hermes =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      inherit (import ../../../lib/default.nix lib)
        harden
        mkStateDir
        serviceDefaults
        onFailure
        serviceTypes
        ports
        ;
      cfg = config.services.hermes;
      hermesPkg =
        let
          # Upstream (v2026.7.20+) uses fetcherVersion=2 in nix/lib.nix, no hash patching needed.
          baseOverlay = inputs.hermes-agent.overlays.default;
          # registration_lifecycle.py is a top-level module in the upstream
          # source but is missing from pyproject.toml's [tool.setuptools]
          # py-modules list, so uv2nix doesn't install it into the sealed
          # venv. hermes_cli/plugins.py imports it at module level, causing
          # ModuleNotFoundError on every startup. We extract the file from
          # the flake source and inject it via PYTHONPATH until upstream
          # adds it to py-modules.
          registrationLifecycle = pkgs.runCommand "hermes-registration-lifecycle" { } ''
            mkdir -p $out/lib/python3.12/site-packages
            cp ${inputs.hermes-agent}/registration_lifecycle.py \
              $out/lib/python3.12/site-packages/
          '';
          pythonPath = "${registrationLifecycle}/lib/python3.12/site-packages";
          patchedOverlay =
            final: prev:
            let
              base = baseOverlay final prev;
            in
            base
            // {
              hermes-agent = (base.hermes-agent.override {
                extraDependencyGroups = [
                  "anthropic"
                  "azure-identity"
                  "bedrock"
                  "daytona"
                  "dingtalk"
                  "edge-tts"
                  "exa"
                  "fal"
                  "feishu"
                  "firecrawl"
                  "hindsight"
                  "honcho"
                  "messaging"
                  "matrix"
                  "modal"
                  "parallel-web"
                  "tts-premium"
                  "voice"
                ];
              }).overrideAttrs (old: {
                nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.makeWrapper ];
                postInstall = (old.postInstall or "") + ''
                  for bin in $out/bin/hermes $out/bin/hermes-agent $out/bin/hermes-acp; do
                    if [ -f "$bin" ]; then
                      wrapProgram "$bin" --suffix PYTHONPATH : "${pythonPath}"
                    fi
                  done
                '';
              });
            };
          pkgs' = pkgs.extend patchedOverlay;
        in
        pkgs'.hermes-agent;
      sopsEnvPath = config.sops.templates."hermes-env".path;
      oldStateDirs = [
        "/home/${cfg.user}/.hermes"
        "/var/lib/hermes"
      ];

      mergeEnvScript = pkgs.writeShellApplication {
        name = "hermes-merge-env";
        runtimeInputs = [ pkgs.gnused ];
        text = ''
          ENV_FILE="${cfg.stateDir}/.env"

          if [ ! -f "$ENV_FILE" ]; then
            touch "$ENV_FILE"
            chmod 600 "$ENV_FILE"
          fi

          # shellcheck disable=SC2043
          for dep_key in MESSAGING_CWD; do
            if grep -q "^''${dep_key}=" "$ENV_FILE" 2>/dev/null; then
              sed -i "/^''${dep_key}=/d" "$ENV_FILE"
              echo "hermes-merge: removed deprecated key $dep_key from .env"
            fi
          done

          for pair in "OLLAMA_API_KEY=ollama" "TERMINAL_ENV=local"; do
            key="''${pair%%=*}"
            value="''${pair#*=}"
            [ -z "$key" ] && continue
            if grep -q "^''${key}=" "$ENV_FILE" 2>/dev/null; then
              sed -i "/^''${key}=/d" "$ENV_FILE"
            fi
            echo "$key=$value" >> "$ENV_FILE"
          done
        '';
      };

      fixPermissionsScript = pkgs.writeShellApplication {
        name = "hermes-fix-permissions";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.findutils
        ];
        text = ''
          if [ "$(stat -c '%U:%G' ${cfg.stateDir} 2>/dev/null)" = "${cfg.user}:${cfg.group}" ] \
             && [ "$(stat -c '%a' ${cfg.stateDir} 2>/dev/null)" = "2770" ]; then
            exit 0
          fi

          echo "hermes-perms: fixing ownership and permissions in ${cfg.stateDir}"
          chown -R ${cfg.user}:${cfg.group} ${cfg.stateDir}
          find ${cfg.stateDir} -type d -exec chmod 2770 {} + 2>/dev/null || true
          find ${cfg.stateDir} -type f -exec chmod 0660 {} + 2>/dev/null || true
        '';
      };

      # Grant hermes (via 'users' group) read+execute access to the primary
      # user's home so it can navigate to shared project directories. Uses ACLs
      # instead of broad chmod to avoid making the entire home directory
      # writable. Only read+execute (r-x) is granted, not write. Runs as root
      # via the ExecStartPre `+` prefix (cannot be expressed via tmpfiles).
      aclSetupScript = pkgs.writeShellApplication {
        name = "hermes-acl-setup";
        runtimeInputs = [
          pkgs.acl
          pkgs.coreutils
          pkgs.getent
        ];
        text = ''
          primaryHome=$(getent passwd ${config.users.primaryUser} 2>/dev/null | cut -d: -f6)
          if [ -n "$primaryHome" ] && [ -d "$primaryHome" ]; then
            setfacl -m "g:${cfg.group}:r-x" "$primaryHome" 2>/dev/null || chmod g+rx "$primaryHome"
          fi
        '';
      };

      migrateScript = pkgs.writeShellApplication {
        name = "hermes-migrate-state";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.sqlite
          pkgs.rsync
        ];
        text = ''
          NEW="${cfg.stateDir}"

          if command -v chattr &>/dev/null; then
            chattr +C "$NEW" 2>/dev/null || true
          fi

          DB="$NEW/state.db"
          if [ -f "$DB" ]; then
            INTEGRITY=$(sqlite3 "$DB" "PRAGMA integrity_check;" 2>&1 || echo "error")
            if [ "$INTEGRITY" != "ok" ]; then
              BACKUP="$DB.malformed-$(date +%Y%m%d-%H%M%S)"
              echo "hermes-migrate: SQLite database malformed, backing up to $BACKUP"
              mv "$DB" "$BACKUP"
              rm -f "$DB-wal" "$DB-shm"
            else
              sqlite3 "$DB" "PRAGMA journal_mode=WAL; PRAGMA synchronous=NORMAL;" 2>/dev/null || true
            fi
          fi

          if [ -f "$NEW/state.db" ] && [ "$(stat -c%s "$NEW/state.db" 2>/dev/null)" -gt 1048576 ]; then
            echo "hermes-migrate: $NEW has existing state ($(stat -c%s "$NEW/state.db") bytes), skipping migration"
            exit 0
          fi

          for OLD in ${lib.concatStringsSep " " (map (p: "\"${p}\"") oldStateDirs)}; do
            if [ -d "$OLD" ] && [ "$(ls -A "$OLD" 2>/dev/null)" ]; then
              echo "hermes-migrate: migrating state from $OLD to $NEW"
              mkdir -p "$NEW"
              rsync -a --chown=${cfg.user}:${cfg.group} "$OLD/" "$NEW/"
              echo "hermes-migrate: migration complete (from $OLD)"
              exit 0
            fi
          done

          echo "hermes-migrate: no old state found, skipping migration"
        '';
      };
    in
    {
      options.services.hermes = {
        enable = lib.mkEnableOption "Hermes AI Agent Gateway";

        inherit
          (serviceTypes.systemdServiceIdentity {
            defaultUser = "hermes";
            defaultStateDir = "/home/hermes";
          })
          user
          group
          stateDir
          ;

        restartSec = serviceTypes.restartDelay "5";

        timeoutStopSec = serviceTypes.stopTimeout "120";
      };

      config = lib.mkIf cfg.enable {
        users.groups.${cfg.group} = { };

        users.users.${cfg.user} = {
          isSystemUser = true;
          inherit (cfg) group;
          extraGroups = [
            "users"
            "render"
          ];
          home = cfg.stateDir;
          createHome = true;
          description = "Hermes AI Agent Gateway service user";
        };

        environment.systemPackages = [ hermesPkg ];

        # Directory creation and ownership handled declaratively via tmpfiles.
        # The `setfacl` (ACL grant on primary user's home) and recursive file
        # permission fix-up run via ExecStartPre (aclSetupScript +
        # fixPermissionsScript) — they cannot be expressed as tmpfiles rules.
        systemd.tmpfiles.rules =
          map (path: mkStateDir path "2770" cfg.user cfg.group) [
            cfg.stateDir
            "${cfg.stateDir}/sessions"
            "${cfg.stateDir}/skills"
            "${cfg.stateDir}/memories"
            "${cfg.stateDir}/cron"
            "${cfg.stateDir}/cache"
            "${cfg.stateDir}/logs"
            "${cfg.stateDir}/logs/curator"
            "${cfg.stateDir}/workspace"
          ]
          ++ [
            "f ${cfg.stateDir}/.managed 0644 ${cfg.user} ${cfg.group} -"
          ];

        systemd.services.hermes = {
          description = "Hermes Agent Gateway - Messaging Platform Integration";
          wantedBy = [ "multi-user.target" ];
          after = [
            "network-online.target"
            "sops-nix.service"
            "dnsblockd.service"
          ];
          wants = [
            "network-online.target"
            "sops-nix.service"
            "dnsblockd.service"
          ];
          inherit onFailure;
          startLimitIntervalSec = 600;
          startLimitBurst = 5;

          path = [
            hermesPkg
            pkgs.bash
            pkgs.binutils
            pkgs.coreutils
            pkgs.git
          ];

          serviceConfig = lib.mkMerge [
            {
              Type = "simple";
              User = cfg.user;
              Group = cfg.group;
              ExecStartPre = [
                "+${lib.getExe aclSetupScript}"
                "+${lib.getExe fixPermissionsScript}"
                "+${lib.getExe migrateScript}"
                "${lib.getExe mergeEnvScript}"
              ];
              ExecStart = "${lib.getExe' hermesPkg "hermes"} gateway run --replace";
              WorkingDirectory = cfg.stateDir;
              Environment = [
                "HOME=${cfg.stateDir}"
                "HERMES_HOME=${cfg.stateDir}"
                "HERMES_MANAGED=true"
                "GATEWAY_ALLOW_ALL_USERS=true"
                "LD_LIBRARY_PATH=${pkgs.libopus}/lib"
                # OTLP tracing — Python SDK expects full URL with scheme.
                # Noop until upstream Hermes adds opentelemetry-sdk instrumentation.
                "OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:${toString ports.signoz-otlp-http}"
              ];
              EnvironmentFile = [ sopsEnvPath ];
              RestartForceExitStatus = 75;
              KillMode = "mixed";
              KillSignal = "SIGTERM";
              TimeoutStopSec = cfg.timeoutStopSec;
              # State migration (535 MB) + ACL setup + permission fix can exceed
              # systemd's default 90s during system switches. 3 min covers
              # worst observed case (~96s on cold I/O).
              TimeoutStartSec = "3min";
              ExecReload = "/bin/kill -USR1 $MAINPID";
              StandardOutput = "journal";
              StandardError = "journal";
              UMask = "0026";
            }
            (serviceDefaults { RestartSec = cfg.restartSec; })
            (harden {
              MemoryMax = "24G"; # PyTorch + ROCm + HIP libraries require significant GPU memory mapping
              CPUQuota = "400%"; # PyTorch data preprocessing + inference can spike multi-core
              ProtectHome = false;
              ReadWritePaths = [ cfg.stateDir ];
            })
          ];
        };
      };
    };
}
