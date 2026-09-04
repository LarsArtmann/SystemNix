# Attic — self-hosted Nix binary cache server
#
# Provides a private binary cache at https://cache.${domain}/ for CI builds.
# Forgejo Actions CI pushes build outputs here; LAN machines pull from it as
# a substituter, avoiding redundant recompilation.
#
# Disk safety:
#   - Storage lives on the mirrored HDD pool (/mnt/pool/services/atticd,
#     snapshotted nightly by btrbk-pool) since 2026-08-18 — off the QLC NVMe
#   - GC runs every 4h, deletes paths older than retention (default 7 days)
#   - A systemd timer checks storage size every 30min and triggers immediate
#     GC if over the size threshold (default 20 GB)
#   - Tradeoff: cache pulls now stream from the HDD pool over the shared USB
#     DAS link — acceptable for a short-retention CI cache, wrong for hot storage
#
# Cache management:
#   attic login local https://cache.${domain}/ <token>
#   attic cache create monitor365
#   attic cache configure monitor365 --retention-period 7d
#   attic push monitor365 <paths>
#
# The JWT signing secret is in sops: platforms/nixos/secrets/attic.yaml
# It is an RS256 RSA PEM PKCS1 key (NOT a random string). Generate with:
#   openssl genrsa -traditional 4096 | base64 -w0
# The nixpkgs atticd module reads ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64.
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
        serviceOneshotDefaults
        onFailure
        ioTier
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
          default = "/mnt/pool/services/atticd/storage";
          description = ''
            Where Attic stores NAR files. Defaults to the mirrored HDD pool
            (subvol snapshotted nightly by btrbk-pool) to protect the QLC NVMe
            from write-endurance wear and disk fill.
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
            # Bind to localhost only — Caddy (port 80/443) is the sole external
            # entry point. Defense-in-depth: even if the firewall rule for port
            # 8200 is accidentally added, the raw HTTP server stays unreachable.
            listen = "127.0.0.1:${toString atticPort}";

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

        # Hardening: the nixpkgs atticd module ships comprehensive hardening
        # (ProtectSystem=strict, ProtectProc=invisible, MemoryDenyWriteExecute,
        # SystemCallFilter, etc.) at default priority. SystemNix's harden{}
        # uses mkDefault' for most values, so nixpkgs' values win on overlap.
        # We set ONLY MemoryMax here (nixpkgs doesn't set it). ReadWritePaths
        # is computed by nixpkgs from the storage path automatically.
        # NOTE: atticd is DynamicUser — sops secrets are root-owned (see sops.nix).
        # The pool mounts nofail — systemd-tmpfiles-setup may run before
        # /mnt/pool is mounted, which would create the storage dir on the
        # ROOT filesystem (hidden under the mount, contaminating the NVMe).
        # There is deliberately NO tmpfiles rule for the storage path for the
        # same reason. This oneshot runs only while the pool is actually
        # mounted (RequiresMountsFor fails loudly on a detached DAS instead of
        # writing to the root fs) and creates the real directory. deploy.sh
        # restarts it after switches — oneshot+RemainAfterExit units ignore
        # restartTriggers in switch-to-configuration.
        systemd.services.atticd-storage-dir = {
          description = "Create Attic storage directory on the HDD pool";
          wantedBy = [ "multi-user.target" ];
          unitConfig = {
            RequiresMountsFor = [ cfg.storagePath ];
          };
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = "root";
              RemainAfterExit = true;
            }
            (harden {
              MemoryMax = "128M";
              ReadWritePaths = [ "/mnt/pool/services/atticd" ];
            })
            (serviceOneshotDefaults { })
          ];
          script = ''
            mkdir -p ${toString cfg.storagePath}
            chmod 0755 ${toString cfg.storagePath}
          '';
        };

        systemd.services.atticd = {
          after = [
            "network.target"
            "atticd-storage-dir.service"
          ];
          wants = [ "atticd-storage-dir.service" ];
          # Detached DAS fails atticd loudly instead of writing NAR storage
          # onto the root filesystem under the /mnt/pool mountpoint (same
          # semantics as the immich/paperless pool gating).
          unitConfig.RequiresMountsFor = [ cfg.storagePath ];
          # AGENTS.md rule 5: every service sets start-limit bounds + onFailure.
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          inherit onFailure;
          # Force restart when settings or package change (nixpkgs module does
          # not set restartTriggers). Same pattern as dnsblockd / homepage.
          restartTriggers = [
            (builtins.toJSON config.services.atticd.settings)
            config.services.atticd.package
          ];
          serviceConfig = lib.mkMerge [
            (harden {
              MemoryMax = "2G";
            })
            (serviceDefaults { })
            ioTier.background
          ];
        };

        # No tmpfiles rule for the storage path — tmpfiles can run before the
        # pool mounts and would create the dir on the root filesystem (see
        # atticd-storage-dir above for the mount-gated creator). Owner is root
        # because atticd is a DynamicUser — the nixpkgs module grants the
        # dynamic user write access via ReadWritePaths + StateDirectory
        # semantics. A non-root owner here would fail (user doesn't resolve).

        # Prometheus metrics collector — measures storage and emits textfile
        # metrics every 5 min. Separated from the size-guard so that metrics
        # emission and GC triggering have independent failure modes, frequencies,
        # and permissions. Same pattern as system-health, btrfs-health, and all
        # other Prometheus textfile collectors in SystemNix.
        systemd.services.atticd-metrics = {
          description = "Attic storage Prometheus metrics collector";
          startLimitBurst = 3;
          startLimitIntervalSec = 300;
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = "root";
            }
            (harden {
              MemoryMax = "128M";
              ReadWritePaths = [
                "/var/lib/prometheus-node-exporter/textfile_collectors"
              ];
            })
            (serviceOneshotDefaults { })
          ];
          script = ''
            storage_path="${cfg.storagePath}"
            textfile_dir="/var/lib/prometheus-node-exporter/textfile_collectors"
            max_gb=${toString cfg.maxStorageGigabytes}

            if [ ! -d "$storage_path" ]; then
              current_bytes=0
            else
              current_bytes=$(du -sb "$storage_path" 2>/dev/null | cut -f1)
              if [ -z "$current_bytes" ]; then
                current_bytes=0
              fi
            fi

            current_gb=$(( current_bytes / 1024 / 1024 / 1024 ))
            max_bytes=$(( max_gb * 1024 * 1024 * 1024 ))
            if [ "$current_bytes" -gt 0 ] && [ "$current_bytes" -gt "$max_bytes" ]; then
              over_threshold=1
            else
              over_threshold=0
            fi

            mkdir -p "$textfile_dir"
            prom_file="$textfile_dir/attic.prom"
            tmp_file="''${prom_file}.tmp"
            cat > "$tmp_file" <<METRICS
            # HELP attic_storage_bytes Total bytes used by Attic NAR storage
            # TYPE attic_storage_bytes gauge
            attic_storage_bytes ''${current_bytes}
            # HELP attic_storage_gb Total gigabytes used by Attic NAR storage
            # TYPE attic_storage_gb gauge
            attic_storage_gb ''${current_gb}
            # HELP attic_storage_max_gb Configured maximum storage in gigabytes
            # TYPE attic_storage_max_gb gauge
            attic_storage_max_gb ''${max_gb}
            # HELP attic_storage_over_threshold 1 if storage exceeds max (GC triggered), 0 otherwise
            # TYPE attic_storage_over_threshold gauge
            attic_storage_over_threshold ''${over_threshold}
            METRICS
            mv "$tmp_file" "$prom_file"
          '';
        };

        systemd.timers.atticd-metrics = {
          description = "Emit Attic storage Prometheus metrics every 5 minutes";
          timerConfig = {
            OnBootSec = "2min";
            OnUnitActiveSec = "5min";
            Persistent = true;
          };
          wantedBy = [ "timers.target" ];
        };

        # Disk-safety guard: if storage exceeds maxStorageGigabytes, trigger
        # an immediate atticd GC cycle. Attic's built-in GC is time-based only
        # (no max-size option), so this is the hard disk bound.
        #
        # GC-on-restart is VERIFIED: atticd's monolithic mode spawns the GC
        # task at startup, and the loop calls run_garbage_collection_once FIRST
        # (before sleeping for the interval). So restarting atticd guarantees
        # an immediate GC sweep of expired paths. Source: server/src/gc.rs:34-64
        # + server/src/main.rs:74-87. An alternative one-shot mode exists
        # (--mode garbage-collector-once) but requires the same DynamicUser
        # context + config file path, making the restart approach simpler.
        systemd.services.atticd-size-guard = {
          description = "Attic storage size guard — emergency GC trigger";
          after = [ "atticd.service" ];
          wants = [ "atticd.service" ];
          startLimitBurst = 3;
          startLimitIntervalSec = 300;
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = "root";
            }
            (harden {
              MemoryMax = "256M";
            })
            (serviceOneshotDefaults { })
          ];
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

            if [ "$current_bytes" -gt 0 ] && [ "$current_bytes" -gt "$max_bytes" ]; then
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

        # Bootstrap: automatically create cache + configure retention on deploy.
        # Eliminates the need for manual `sudo atticd-atticadm make-token` + manual
        # `attic cache create`. Runs atticadm directly (root can read the sops env
        # file and the server config from the nix store), then uses the attic
        # client for cache management via the HTTP API.
        systemd.services.atticd-bootstrap = {
          description = "Bootstrap Attic cache (create cache + configure retention)";
          after = [ "atticd.service" ];
          wants = [ "atticd.service" ];
          wantedBy = [ "multi-user.target" ];
          startLimitBurst = 3;
          startLimitIntervalSec = 300;
          inherit onFailure;
          # Skip cleanly (result=condition) while the DAS is detached: atticd is
          # down BY DESIGN then and the bootstrap can only die with "connection
          # refused" — failing every activation/switch with exit 4 (2026-08-22 +
          # 2026-08-24 DAS outages). The storage dir is created by the
          # mount-gated atticd-storage-dir ONLY while the pool is mounted, so
          # its absence == pool absent == atticd intentionally down. Monitoring
          # is unaffected: atticd.service OnFailure + the Gatus "Attic Binary
          # Cache" endpoint still alert on the outage. Real failures stay loud:
          # with the pool mounted but atticd wedged, the readiness probe below
          # exits 1 with a clear message.
          unitConfig.ConditionPathIsDirectory = [ cfg.storagePath ];
          path = [
            config.services.atticd.package
            pkgs.attic-client
            pkgs.python3
            pkgs.gnused
          ];
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = "root";
              RemainAfterExit = true;
            }
            (harden {
              MemoryMax = "256M";
              ProtectHome = false; # attic login writes to ~/.config/attic/
              ReadWritePaths = [ "/var/lib/atticd" ]; # cache-info.txt output
            })
            (serviceOneshotDefaults { })
          ];
          script = ''
                      set -euo pipefail

                      atticd_ready() {
                        python3 -c "
            import urllib.request, sys
            try:
                urllib.request.urlopen('http://127.0.0.1:${toString atticPort}/', timeout=2)
            except Exception:
                sys.exit(1)
            " 2>/dev/null
                      }

                      # Wait for atticd to be ready (migrations run on first start)
                      for i in $(seq 1 30); do
                        if atticd_ready; then
                          echo "atticd is ready"
                          break
                        fi
                        echo "Waiting for atticd... ($i)"
                        sleep 1
                      done

                      # Fail LOUD and CLEAR when atticd never became ready (pool
                      # detached mid-run or atticd crashed). Without this the
                      # failure surfaces later as an opaque "error sending
                      # request" from an attic client HTTP call.
                      if ! atticd_ready; then
                        echo "ERROR: atticd did not become ready on 127.0.0.1:${toString atticPort} within 30s — check 'journalctl -u atticd.service' (pool detached?)"
                        exit 1
                      fi

                      # Source the RS256 secret (sops-rendered env file, root-readable).
                      # atticadm make-token only needs the RS256 key to sign a JWT —
                      # no database access required.
                      set -a
                      . /run/secrets/rendered/attic-env
                      set +a

                      # Extract the server config path from atticd's ExecStart.
                      # atticadm needs -f <config> to initialize (even for make-token).
                      CONFIG_FILE=$(sed -n 's/^ExecStart=.* -f \([^ ]*\) .*/\1/p' /etc/systemd/system/atticd.service)
                      if [ -z "$CONFIG_FILE" ]; then
                        echo "ERROR: Could not find atticd config file path"
                        exit 1
                      fi

                      # Create a short-lived admin token.
                      TOKEN=$(atticadm -f "$CONFIG_FILE" make-token \
                        --sub bootstrap \
                        --validity 1h \
                        --pull '*' --push '*' \
                        --create-cache '*' --configure-cache '*' \
                        --configure-cache-retention '*' --destroy-cache '*')

                      # Login to the local server
                      attic login local http://127.0.0.1:${toString atticPort}/ "$TOKEN"

                      # Create cache (idempotent — attic cache create fails if it exists)
                      attic cache create monitor365 --public 2>/dev/null \
                        && echo "Created cache 'monitor365'" \
                        || echo "Cache 'monitor365' already exists"

                      # Configure retention (quote to handle spaces in "7 days")
                      attic cache configure monitor365 --retention-period "${cfg.retentionPeriod}"

                      # Print cache info (includes public key for configuration.nix)
                      echo "=== Cache Info ==="
                      attic cache info monitor365
          '';
        };

        # Attic client for cache management (run atticadm, attic push, etc.)
        environment.systemPackages = [ pkgs.attic-client ];

        # Port 8200 is intentionally NOT in networking.firewall.allowedTCPPorts.
        # atticd binds to 127.0.0.1 only — Caddy (ports 80/443) is the sole
        # external entry point via cache.${domain}. No direct access needed.

        # Register the cache as a substituter when a public key is configured
        nix.settings = lib.mkIf (cfg.cachePublicKey != "") {
          substituters = [ cfg.cacheSubstituter ];
          trusted-public-keys = [ cfg.cachePublicKey ];
        };
      };
    };
}
