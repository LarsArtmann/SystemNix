# Runbook: docs/services/architecture-catalog.md (platform inventory leg)
# catalog-inventory-sync — hourly regeneration of the eventcatalog-hub's
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
# Scheduling: HOURLY at :47 + 15min jitter (owner call 2026-10-17) — a
# registry change converges into the committed inventory within ~1h. The
# cadence costs evals, not commits: generate-inventory.sh NO-OPS on
# content-identical exports while the committed generatedAt is <24h old,
# so the hub sees commits only on real changes (+ at most one stamp
# refresh/day). Niced/idle-IO under everything — the freeze history is a
# chronicle of ungated eval batteries; this one stays a background citizen
# (24 eval bursts/day, all yielding). Persistent: downtime catches up on
# the next boot. No port, no daemon, no deploy.sh converger — the timer
# converges on its own after every boot/deploy.
_: {
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
        enable = lib.mkEnableOption "hourly inventory.json regeneration for the federated EventCatalog (evals the SystemNix registry across the real hosts, rewrites the hub checkout)";

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
          default = "*-*-* *:47:00";
          description = ''
            Regeneration calendar (local time). Default: hourly at :47 — a
            registry change converges into the committed inventory.json
            within ~1h (the write path no-ops on unchanged content, so the
            cadence costs evals, not commits).
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
              # The unit runs TWO scripts that both call bare commands: the
              # hub's generate-inventory.sh (`bash`, `date`, `mktemp`, `grep`,
              # `jq`) and our scripts/catalog-inventory.sh (`jq`, `nix eval`).
              # The default system-unit PATH carries only coreutils/findutils/
              # grep/sed/systemd — no bash, no jq, no nix — so this service
              # died at generate-inventory.sh:159 with "bash: command not
              # found" (status 127, failing every hour since it was written;
              # the failure was invisible because the unit is oneshot and its
              # OnFailure only notifies). Declare the toolset explicitly
              # instead of trusting the ambient PATH.
              path = [
                pkgs.bash
                pkgs.jq
                pkgs.nix
                pkgs.coreutils
                pkgs.gnugrep
              ];
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
          description = "Hourly inventory.json regeneration for catalog.home.lan";
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
