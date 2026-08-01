# Attic — self-hosted Nix binary cache server
#
# Provides a private binary cache at https://cache.${domain}/ for CI builds.
# Forgejo Actions CI pushes build outputs here; LAN machines pull from it as
# a substituter, avoiding redundant recompilation.
#
# Disk safety:
#   - Storage lives on /data (BTRFS data partition, separate from root)
#   - GC runs every 4h, deletes paths older than retention (default 7 days)
#   - A systemd timer checks storage size every 30min and triggers immediate
#     GC if over the size threshold (default 20 GB)
#   - QLC NVMe write endurance is the primary concern — short retention +
#     size guard prevents unbounded accumulation
#
# Cache management:
#   attic login local https://cache.${domain}/ <token>
#   attic cache create monitor365
#   attic cache configure monitor365 --retention-period 7d
#   attic push monitor365 <paths>
#
# The JWT signing secret is in sops: platforms/nixos/secrets/attic.yaml
# Generate with: openssl rand -base64 32
_: {
  flake.nixosModules.attic =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      cfg = config.services.attic-config;
      inherit (config.networking) domain;
      inherit (import ../../../lib/default.nix lib)
        ports
        harden
        serviceDefaults
        onFailure
        ;
      atticPort = ports.attic;
      stateDir = "/var/lib/atticd";
    in
    {
      options.services.attic-config = {
        enable = lib.mkEnableOption "Attic self-hosted Nix binary cache";

        cacheSubstituter = lib.mkOption {
          type = lib.types.str;
          default = "https://cache.${domain}/monitor365";
          description = "Substituter URL for Nix clients to consume the cache";
        };

        cachePublicKey = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = ''
            Public key for the Attic cache (e.g. "monitor365:...=").
            Obtained after running: attic cache info monitor365
            Leave empty until the cache is created.
          '';
        };

        retentionPeriod = lib.mkOption {
          type = lib.types.str;
          default = "7 days";
          description = "Default retention period for cached paths";
        };

        storagePath = lib.mkOption {
          type = lib.types.path;
          default = "/data/atticd/storage";
          description = ''
            Where Attic stores NAR files. Defaults to /data (BTRFS data
            partition, separate from root) to protect the NVMe root filesystem
            from write endurance wear and disk fill.
          '';
        };

        maxStorageGigabytes = lib.mkOption {
          type = lib.types.ints.positive;
          default = 20;
          description = ''
            Emergency GC trigger: if storage exceeds this many GB, a forced
            GC cycle runs immediately regardless of retention period. This is
            the hard disk-safety bound — Attic's built-in GC is time-based
            only (no max-size option).
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        services.atticd = {
          enable = true;

          # Environment file rendered by sops template (see sops.nix)
          environmentFile = config.sops.templates."attic-env".path;

          settings = {
            listen = "[::]:${toString atticPort}";

            # SQLite metadata — small, lives on root (KB-scale)
            database.url = "sqlite://${stateDir}/server.db?mode=rwc";

            # NAR storage — on /data partition (separate from root)
            storage = {
              type = "local";
              path = cfg.storagePath;
            };

            chunking = {
              nar-size-threshold = 65536;
              min-size = 16384;
              avg-size = 65536;
              max-size = 262144;
            };

            # Frequent GC (every 4h) + short retention (7d default)
            garbage-collection = {
              interval = "4 hours";
              default-retention-period = cfg.retentionPeriod;
            };
          };
        };

        # Hardening: atticd needs write access to state dir AND storage path
        systemd.services.atticd = {
          after = [ "network.target" ];
          serviceConfig = lib.mkMerge [
            (harden {
              MemoryMax = "2G";
              ProtectSystem = "full";
              ReadWritePaths = [
                stateDir
                cfg.storagePath
              ];
            })
            (serviceDefaults { })
          ];
        };

        # Ensure directories exist with correct ownership.
        # Storage lives on /data (BTRFS data partition) to protect root disk.
        systemd.tmpfiles.rules = [
          "d ${stateDir} 0750 atticd atticd - -"
          "d ${cfg.storagePath} 0750 atticd atticd - -"
        ];

        # Disk-safety guard: if storage exceeds maxStorageGigabytes, trigger
        # an immediate atticd GC cycle. Attic's built-in GC is time-based only
        # (no max-size option), so this is the hard disk bound.
        #
        # Checks every 30min — if over threshold, restarts atticd which runs
        # GC on startup with the configured retention period.
        systemd.services.atticd-size-guard = {
          description = "Attic storage size guard — emergency GC trigger";
          after = [ "atticd.service" ];
          wants = [ "atticd.service" ];
          serviceConfig = {
            Type = "oneshot";
            User = "root";
            MemoryMax = "256M";
          };
          script = ''
            storage_path="${cfg.storagePath}"
            max_bytes=$(( ${toString cfg.maxStorageGigabytes} * 1024 * 1024 * 1024 ))

            if [ ! -d "$storage_path" ]; then
              echo "Storage path $storage_path does not exist yet, skipping"
              exit 0
            fi

            current_bytes=$(du -sb "$storage_path" 2>/dev/null | cut -f1)
            if [ -z "$current_bytes" ]; then
              echo "Failed to measure $storage_path"
              exit 0
            fi

            current_gb=$(( current_bytes / 1024 / 1024 / 1024 ))
            echo "Attic storage: ''${current_gb} GB (limit: ${toString cfg.maxStorageGigabytes} GB)"

            if [ "$current_bytes" -gt "$max_bytes" ]; then
              echo "OVER LIMIT — restarting atticd to trigger emergency GC"
              ${lib.getExe' pkgs.systemd "systemctl"} restart atticd.service
            fi
          '';
        };

        systemd.timers.atticd-size-guard = {
          description = "Check Attic storage size every 30 minutes";
          timerConfig = {
            OnBootSec = "5min";
            OnUnitActiveSec = "30min";
            Persistent = true;
          };
          wantedBy = [ "timers.target" ];
        };

        # Attic client for cache management (run atticadm, attic push, etc.)
        environment.systemPackages = [ pkgs.attic-client ];

        # Register the cache as a substituter when a public key is configured
        nix.settings = lib.mkIf (cfg.cachePublicKey != "") {
          substituters = [ cfg.cacheSubstituter ];
          trusted-public-keys = [ cfg.cachePublicKey ];
        };
      };
    };
}
