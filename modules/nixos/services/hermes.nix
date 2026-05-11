{inputs, ...}: {
  flake.nixosModules.hermes = {
    config,
    pkgs,
    lib,
    ...
  }: let
    inherit (import ../../../lib/default.nix lib) harden serviceDefaults serviceTypes;
    cfg = config.services.hermes;
    hermesPkg = let
      # Upstream hermes-agent has a stale npmDepsHash in nix/tui.nix.
      # On hermes upgrade: remove fixedHash, let upstream hash attempt, if it fails:
      #   1. Delete the hash below
      #   2. Run: nix build .#nixosConfigurations.evo-x2 --no-out-link 2>&1 | grep got
      #   3. Paste the correct hash here
      fixedHash = "sha256-Chz+NW9NXqboXHOa6PKwf5bhAkkcFtKNhvKWwg2XSPc=";
      baseOverlay = inputs.hermes-agent.overlays.default;
      patchedOverlay = final: prev: let
        base = baseOverlay final prev;
        tuiFixed = base.hermes-agent.passthru.hermesTui.overrideAttrs (old: {
          npmDeps = final.fetchNpmDeps {
            inherit (old) src;
            hash = fixedHash;
          };
        });
        interceptCallPackage = path: args:
          if builtins.match ".*tui\\.nix" (toString path) != null
          then tuiFixed
          else final.callPackage path args;
      in
        base
        // {
          hermes-agent = base.hermes-agent.override {
            callPackage = interceptCallPackage;
          };
        };
      pkgs' = pkgs.extend patchedOverlay;
    in
      pkgs'.hermes-agent;
    sopsEnvPath = config.sops.templates."hermes-env".path;
    oldStateDirs = ["/home/lars/.hermes" "/var/lib/hermes"];

    mergeEnvScript = pkgs.writeShellScript "hermes-merge-env" ''
      set -euo pipefail
      ENV_FILE="${cfg.stateDir}/.env"

      if [ ! -f "$ENV_FILE" ]; then
        touch "$ENV_FILE"
        chmod 600 "$ENV_FILE"
      fi

      # Clean up deprecated keys
      for dep_key in MESSAGING_CWD; do
        if grep -q "^''${dep_key}=" "$ENV_FILE" 2>/dev/null; then
          ${pkgs.gnused}/bin/sed -i "/^''${dep_key}=/d" "$ENV_FILE"
          echo "hermes-merge: removed deprecated key $dep_key from .env"
        fi
      done

      # Write non-secret env vars only (secrets come from sops via EnvironmentFile)
      for pair in "OLLAMA_API_KEY=ollama" "TERMINAL_ENV=local"; do
        key="''${pair%%=*}"
        value="''${pair#*=}"
        [ -z "$key" ] && continue
        if grep -q "^''${key}=" "$ENV_FILE" 2>/dev/null; then
          ${pkgs.gnused}/bin/sed -i "/^''${key}=/d" "$ENV_FILE"
        fi
        echo "$key=$value" >> "$ENV_FILE"
      done
    '';

    fixPermissionsScript = pkgs.writeShellScript "hermes-fix-permissions" ''
      set -euo pipefail
      echo "hermes-perms: fixing ownership and permissions in ${cfg.stateDir}"
      chown -R ${cfg.user}:${cfg.group} ${cfg.stateDir}
      # Ensure all directories are traversable and writable by owner
      find ${cfg.stateDir} -type d -exec chmod 2770 {} + 2>/dev/null || true
      find ${cfg.stateDir} -type f -exec chmod 0660 {} + 2>/dev/null || true
    '';

    migrateScript = pkgs.writeShellScript "hermes-migrate-state" ''
      set -euo pipefail
      NEW="${cfg.stateDir}"

      # Disable BTRFS Copy-on-Write on state directory to prevent SQLite corruption
      if command -v chattr &>/dev/null; then
        chattr +C "$NEW" 2>/dev/null || true
      fi

      # Auto-recover malformed SQLite databases
      DB="$NEW/state.db"
      if [ -f "$DB" ]; then
        INTEGRITY=$(${pkgs.sqlite}/bin/sqlite3 "$DB" "PRAGMA integrity_check;" 2>&1 || echo "error")
        if [ "$INTEGRITY" != "ok" ]; then
          BACKUP="$DB.malformed-$(date +%Y%m%d-%H%M%S)"
          echo "hermes-migrate: SQLite database malformed, backing up to $BACKUP"
          mv "$DB" "$BACKUP"
          # Remove WAL/SHM sidecars too
          rm -f "$DB-wal" "$DB-shm"
        else
          # Enforce WAL mode for resilience
          ${pkgs.sqlite}/bin/sqlite3 "$DB" "PRAGMA journal_mode=WAL; PRAGMA synchronous=NORMAL;" 2>/dev/null || true
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
          ${pkgs.rsync}/bin/rsync -a --chown=${cfg.user}:${cfg.group} "$OLD/" "$NEW/"
          echo "hermes-migrate: migration complete (from $OLD)"
          exit 0
        fi
      done

      echo "hermes-migrate: no old state found, skipping migration"
    '';
  in {
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
      users.groups.${cfg.group} = {};

      users.users.${cfg.user} = {
        isSystemUser = true;
        inherit (cfg) group;
        extraGroups = ["users" "render"];
        home = cfg.stateDir;
        createHome = true;
        description = "Hermes AI Agent Gateway service user";
      };

      environment.systemPackages = [hermesPkg];

      systemd.tmpfiles.rules = [
        "d ${cfg.stateDir}           2770 ${cfg.user} ${cfg.group} -"
        "d ${cfg.stateDir}/sessions  2770 ${cfg.user} ${cfg.group} -"
        "d ${cfg.stateDir}/skills    2770 ${cfg.user} ${cfg.group} -"
        "d ${cfg.stateDir}/memories  2770 ${cfg.user} ${cfg.group} -"
        "d ${cfg.stateDir}/cron      2770 ${cfg.user} ${cfg.group} -"
        "d ${cfg.stateDir}/cache     2770 ${cfg.user} ${cfg.group} -"
        "d ${cfg.stateDir}/logs/curator 2770 ${cfg.user} ${cfg.group} -"
        "d ${cfg.stateDir}/workspace 2770 ${cfg.user} ${cfg.group} -"
      ];

      system.activationScripts."hermes-setup" = lib.stringAfter (["users"] ++ lib.optional (config.system.activationScripts ? setupSecrets) "setupSecrets") ''
        mkdir -p ${cfg.stateDir}/{sessions,skills,memories,cron,cache,logs/curator,workspace}
        chown -R ${cfg.user}:${cfg.group} ${cfg.stateDir}
        chmod 2770 ${cfg.stateDir} ${cfg.stateDir}/{sessions,skills,memories,cron,cache,logs,logs/curator,workspace}

        # Grant hermes (via 'users' group) read+execute access to the primary user's home
        # so it can navigate to shared project directories.
        # NOTE: This uses ACLs instead of broad chmod to avoid making the entire
        # home directory writable. Only read+execute (r-x) is granted, not write.
        primaryHome=$(getent passwd lars 2>/dev/null | cut -d: -f6)
        if [ -n "$primaryHome" ] && [ -d "$primaryHome" ]; then
          setfacl -m "g:${cfg.group}:r-x" "$primaryHome" 2>/dev/null || chmod g+rx "$primaryHome"
        fi

        find ${cfg.stateDir} -maxdepth 1 \( -name "*.db" -o -name "*.db-wal" -o -name "*.db-shm" -o -name "SOUL.md" \) \
          -exec chmod g+rw {} + 2>/dev/null || true
        for _subdir in sessions skills memories cron cache logs; do
          find "${cfg.stateDir}/$_subdir" -type f -exec chmod g+rw {} + 2>/dev/null || true
        done

        touch ${cfg.stateDir}/.managed
        chown ${cfg.user}:${cfg.group} ${cfg.stateDir}/.managed
        chmod 0644 ${cfg.stateDir}/.managed
      '';

      systemd.services.hermes = {
        description = "Hermes Agent Gateway - Messaging Platform Integration";
        wantedBy = ["multi-user.target"];
        after = ["network-online.target"];
        wants = ["network-online.target"];
        onFailure = ["notify-failure@%n.service"];
        startLimitIntervalSec = 600;
        startLimitBurst = 5;

        path = [
          hermesPkg
          pkgs.bash
          pkgs.binutils
          pkgs.coreutils
          pkgs.git
        ];

        serviceConfig =
          {
            Type = "simple";
            User = cfg.user;
            Group = cfg.group;
            ExecStartPre = ["+${fixPermissionsScript}" "+${migrateScript}" mergeEnvScript];
            ExecStart = "${hermesPkg}/bin/hermes gateway run --replace";
            WorkingDirectory = cfg.stateDir;
            Environment = [
              "HOME=${cfg.stateDir}"
              "HERMES_HOME=${cfg.stateDir}"
              "HERMES_MANAGED=true"
              "GATEWAY_ALLOW_ALL_USERS=true"
              "LD_LIBRARY_PATH=${pkgs.libopus}/lib"
            ];
            EnvironmentFile = [sopsEnvPath];
            RestartForceExitStatus = 75;
            KillMode = "mixed";
            KillSignal = "SIGTERM";
            TimeoutStopSec = cfg.timeoutStopSec;
            ExecReload = "/bin/kill -USR1 $MAINPID";
            StandardOutput = "journal";
            StandardError = "journal";
            UMask = "0026";
          }
          // serviceDefaults {RestartSec = cfg.restartSec;}
          // harden {
            MemoryMax = "24G"; # PyTorch + ROCm + HIP libraries require significant GPU memory mapping
            ProtectHome = false;
            ReadWritePaths = [cfg.stateDir];
          };
      };
    };
  };
}
