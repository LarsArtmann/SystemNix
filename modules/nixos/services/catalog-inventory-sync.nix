# Runbook: docs/services/architecture-catalog.md (platform inventory leg)
# catalog-inventory-sync — daily regeneration of the eventcatalog-hub's
# committed inventory.json from THIS repo's registry.
#
# The platform inventory (owner directive 2026-10-17: everything in
# catalog.home.lan with known deployment locations, zero included) is
# COMMITTED DATA in the hub repo, regenerated LOCALLY because CI can never
# eval SystemNix (private flake inputs). Until this timer, regeneration was
# a manual "whenever hosts/services change" step — nothing noticed a
# forgotten run except the hub CI's staleness WARN. This closes the loop:
# the timer re-exports the union of services.catalog + services.integration
# across the real hosts and rewrites inventory.json in the hub checkout;
# the hub's auto-commit daemon commits the result, and the owner push
# (agents never push) carries it into CI.
#
# Runs as the primary user against the working checkouts: reads SystemNix,
# writes ONLY the hub repo's inventory.json (ReadWritePaths).
# CATALOG_INVENTORY_REQUIRE_ALL_HOSTS=1 makes a failed host eval FATAL —
# without it the exporter WARNs and shrinks the union, and an automated
# shrink would silently drop that host's deployments from the committed
# inventory (a broken regeneration must never look like a real one; the
# last-good committed file stays until the next healthy run).
#
# Scheduling: 04:47 + 15min jitter, local time — after the midnight system
# nightly churn, before the hub CI's 05:23 CEST build, and niced/idle-IO
# under everything (the freeze history is a chronicle of ungated eval
# batteries — this one stays a background citizen). Persistent: downtime
# catches up on the next boot. No port, no daemon, no deploy.sh converger —
# the timer converges on its own after every boot/deploy.
_:
{
  flake.nixosModules.catalog-inventory-sync =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.catalog-inventory-sync;
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceOneshotDefaults
        onFailure
        ;
      primaryUser = config.users.primaryUser;
    in
    {
      options.services.catalog-inventory-sync = {
        enable = lib.mkEnableOption "daily inventory.json regeneration for the federated EventCatalog (evals the SystemNix registry across the real hosts, rewrites the hub checkout)";

        hubDir = lib.mkOption {
          type = lib.types.str;
          default = "/home/${primaryUser}/projects/eventcatalog-hub";
          description = ''
            eventcatalog-hub checkout whose inventory.json gets rewritten.
            Committing the result is the hub repo's auto-commit daemon's
            job — this unit never runs git.
          '';
        };

        systemnixDir = lib.mkOption {
          type = lib.types.str;
          default = "/home/${primaryUser}/projects/SystemNix";
          description = "SystemNix checkout evaluated for the registry union.";
        };

        calendar = lib.mkOption {
          type = lib.types.str;
          default = "*-*-* 04:47:00";
          description = ''
            Regeneration calendar (local time). The default lands after the
            midnight system nightlies and before the hub CI's 05:23 CEST
            nightly build.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        systemd.services.catalog-inventory-sync = {
          description = "Regenerate eventcatalog-hub inventory.json from the SystemNix registry";
          inherit onFailure;

          serviceConfig = lib.mkMerge [
            (harden {
              MemoryMax = "4G";
              # Reads both checkouts; writes only the hub repo's
              # inventory.json. The nix eval cache redirects into
              # StateDirectory so $HOME stays read-only.
              ProtectHome = "read-only";
              ReadWritePaths = [ cfg.hubDir ];
            })
            (serviceOneshotDefaults { })
            {
              Type = "oneshot";
              User = primaryUser;
              Group = "users";
              StateDirectory = "catalog-inventory-sync";
              ExecStart = "${pkgs.bash}/bin/bash ${cfg.hubDir}/scripts/generate-inventory.sh";
              Environment = [
                "HOME=/home/${primaryUser}"
                "SYSTEMNIX_DIR=${cfg.systemnixDir}"
                "CATALOG_INVENTORY_REQUIRE_ALL_HOSTS=1"
                "XDG_CACHE_HOME=/var/lib/catalog-inventory-sync/cache"
              ];
              # Freeze-history doctrine: background eval batteries are this
              # box's documented killer class — stay niced and idle-IO so
              # this never competes with real work.
              Nice = 19;
              IOSchedulingClass = "idle";
              CPUWeight = 10;
              IOWeight = 10;
              TimeoutStartSec = "20min";
            }
          ];
        };

        systemd.timers.catalog-inventory-sync = {
          description = "Daily inventory.json regeneration for catalog.home.lan";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = cfg.calendar;
            RandomizedDelaySec = "15min";
            Persistent = true;
          };
        };
      };
    };
}
