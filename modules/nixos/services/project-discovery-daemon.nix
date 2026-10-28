# project-discovery-daemon — standalone discovery daemon over a unix socket.
#
# Owns /run/project-discovery/daemon.sock for ALL consumers (overview, PMA,
# editor tooling). Replaces PMA's co-located embedded daemon (2026-09-07
# flip): previously PMA hosted the socket, so every PMA deploy/restart
# dragged overview's discovery down with it, and PMA's 8G cgroup had to
# absorb the ~7GB discovery spike alongside its own work.
#
# The daemon pays the discovery spike ONCE; consumers stay thin (overview
# runs unprivileged at ~250MB steady state).
#
# Monitoring: WatchdogSec covers liveness (the daemon sends WATCHDOG=1 via
# sd_notify at half-interval — a verified sender, not a Type=notify-only
# assumption). Overview's boot gate + its discovery watchdog cover the
# functional path. No direct Gatus check: gatus cannot dial unix sockets,
# and proxying discovery data through Caddy would expose it.
_: {
  flake.nixosModules.project-discovery-daemon =
    {
      config,
      lib,
      pkgs,
      inputs,
      ...
    }:
    let
      cfg = config.services.project-discovery-daemon;
      inherit (lib)
        mkEnableOption
        mkIf
        mkOption
        types
        ;
      inherit (import ../../../lib/default.nix lib)
        harden
        ioTier
        serviceDefaults
        onFailure
        ;
    in
    {
      options.services.project-discovery-daemon = {
        enable = mkEnableOption "standalone project-discovery daemon (unix socket)";

        package = mkOption {
          type = types.package;
          # vendorHash shim DROPPED (2026-10-12): the SERVICE surface was
          # the missed second surface of the 2026-10-11 wave8 pdd drop —
          # it kept specifying the 1f9b57c-era Mrn25ftf… while the lock
          # (ea6e8ce9) bakes 6ZDAkBB… upstream (flake.nix:60), so the FOD
          # failed with specified-Mrn25ftf/got-6ZDAkBB and blocked the
          # toplevel (first-hand /tmp/toplevel-fix-20261012.log). The same
          # BOTH-surfaces trap as PMA (wave5). Re-add ONLY via nix-hash-fix
          # evidence, never by hand.
          # TEMPORARY vendorHash shim RE-ADDED (2026-10-15 fleet wave,
          # first-hand got-hash from the 02:46 nh enumeration at locked
          # rev df32945; class comment: lib/lars-packages.nix
          # flakePkgShim — same value as the lars-packages surface).
          # RE-STALE 2026-10-19 wave: keep-going toplevel enumeration
          # (/tmp/toplevel-build-20261019.log) mismatched this shim's own
          # nNKXDH5N… at locked rev d4443ff; got jLpz/NzH….
          # RE-STALE AGAIN 2026-10-26 lock float: spec jLpz/NzH, got
          # XbZifGSt (float-proof-20261026-174429.log — module surface;
          # PATH surface rode the same value).
          default =
            inputs.project-discovery-daemon.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs
              {
                vendorHash = "sha256-XbZifGStHDNLF9lMBnTTHi+wkWqNDc69Oy8UAxfpatw=";
              };
          defaultText = lib.literalExpression ''
            inputs.project-discovery-daemon.packages.''${system}.default
          '';
          description = "project-discovery-daemon package.";
        };

        user = mkOption {
          type = types.str;
          default = config.users.primaryUser;
          defaultText = "config.users.primaryUser";
          description = ''
            User the daemon runs as. Discovery runs git INSIDE the search-path
            repos and reads ~/.mrconfig, so it must be a user that can read the
            primary home — a dedicated service user cannot see a 0700 /home.
          '';
        };

        socketPath = mkOption {
          type = types.str;
          default = "/run/project-discovery/daemon.sock";
          description = "Unix socket path the daemon listens on.";
        };

        socketMode = mkOption {
          type = types.str;
          default = "0660";
          example = "0666";
          description = ''
            Socket permission bits, octal string. Widen only as far as the
            consumer set requires: 0660 plus a shared service group, or 0666
            for any local user (the parity value used until consumer users are
            group-managed).
          '';
        };

        searchPaths = mkOption {
          type = types.listOf types.str;
          default = [ ];
          example = [ "/home/lars/projects" ];
          description = ''
            Directories the daemon discovers projects in. Unset falls back to
            the SDK default (the user's whole home directory) — always set
            this explicitly.
          '';
        };

        cacheTTL = mkOption {
          type = types.str;
          default = "5m";
          example = "24h";
          description = ''
            Server hot-cache TTL (Go duration string). The file watcher and
            background refresh invalidate entries per-change; the TTL is only
            the upper bound.
          '';
        };

        extraEnvironment = mkOption {
          type = types.attrsOf types.str;
          default = { };
          description = ''
            Extra environment variables for the daemon (e.g.
            PROJECT_DISCOVERY_REFRESH_INTERVAL, PROJECT_DISCOVERY_WORKERS,
            PROJECT_DISCOVERY_FLIGHT_RECORDER).
          '';
        };
      };

      config = mkIf cfg.enable {
        systemd.services.project-discovery-daemon = {
          description = "Project discovery daemon (unix-socket discovery service)";
          wantedBy = [ "multi-user.target" ];

          startLimitBurst = 5;
          startLimitIntervalSec = 300;

          # ~/projects walker (2026-10-28 projects-subvol plan D6): discovery
          # roots live under ~/projects — fail loud when the Samsung subvol
          # mount is absent (never index the stale @ shadow). Conditional on
          # the mount being declared (VM/test hosts unaffected).
          unitConfig.RequiresMountsFor =
            lib.optionals (builtins.hasAttr "/home/lars/projects" config.fileSystems) [ "/home/lars/projects" ];

          inherit onFailure;

          environment = {
            PROJECT_DISCOVERY_DAEMON_ADDR = cfg.socketPath;
            PROJECT_DISCOVERY_SEARCH_PATHS = lib.concatStringsSep ":" cfg.searchPaths;
            PROJECT_DISCOVERY_SOCKET_MODE = cfg.socketMode;
            PROJECT_DISCOVERY_CACHE_TTL = cfg.cacheTTL;
          }
          // cfg.extraEnvironment;

          serviceConfig = {
            Type = "notify";
            User = cfg.user;
            Group = "users";
            ExecStart = lib.getExe cfg.package;
            # The daemon pings WATCHDOG=1 at half-interval (sd_notify sender).
            WatchdogSec = "30s";
            # Owned by cfg.user; the socket inside carries cfg.socketMode.
            RuntimeDirectory = "project-discovery";
            RuntimeDirectoryMode = "0755";
            # Start contract: "started" means the SOCKET exists, not just the
            # process. During the 2026-10-07 ghost-socket incident the daemon
            # ran 26h "active" while unreachable (socket unlinked by another
            # unit's RuntimeDirectory stop) — overview crash-looped on its
            # daemon-gate the whole time. Bounded wait covers a notify-before-
            # bind race; if the socket never appears the unit FAILS and
            # Restart=always (serviceDefaults) heals it, instead of silently
            # leaving every consumer gated forever.
            ExecStartPost = "${pkgs.coreutils}/bin/timeout 30 ${pkgs.bash}/bin/bash -c 'until test -S ${cfg.socketPath}; do sleep 1; done'";
          }
          // (harden {
            # Full discovery of ~260 repos spikes ~7GB (measured while PMA
            # hosted the daemon; 8G covered peak with headroom).
            MemoryMax = "8G";
            # Discovery is CPU-bursty: git, go.mod parsing, file walks.
            CPUQuota = "400%";
            # Discovery READS the repos and mrconfig under /home — never writes.
            ProtectHome = "read-only";
          })
          # BE/6 background tier (2026-09-19 IO audit): this daemon is the
          # top sustained root-NVMe reader (40 GB reads + 17 GB zram writes
          # attributed via cgroup io.stat over one boot, 10.2 GiB/30 min
          # spike in the audit window) — discovery latency is invisible to
          # consumers (5m TTL cache), but its bursts starve the desktop and
          # stack with builds on the saturated QLC root. BFQ is active on
          # all disks, so the tier is effective; scheduler-level, immune to
          # the nvme0/nvme1 name swaps.
          // ioTier.background
          // serviceDefaults { };
        };
      };
    };
}
