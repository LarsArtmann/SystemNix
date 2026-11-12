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
#
# DELEGATED 2026-11-08 (own-project upstreaming wave): the deployment
# contract (options, unit, socket-start contract, portable hardening) lives
# upstream — inputs.project-discovery-daemon.nixosModules.default. SystemNix
# layers ONLY site specifics: the vendorHash shim (lock-graph staleness
# class, see package below), the primary-user default, the projects-subvol
# mount gate, onFailure alerting, ioTier, and the fleet harden bounds.
{ inputs, ... }: {
  flake.nixosModules.project-discovery-daemon =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.project-discovery-daemon;
      inherit (import ../../../lib/default.nix lib)
        harden
        ioTier
        serviceDefaults
        onFailure
        ;
    in
    {
      imports = [ inputs.project-discovery-daemon.nixosModules.default ];

      config = lib.mkIf cfg.enable {
        services.project-discovery-daemon = {
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
          # vendorHash shim DROPPED (2026-11-03 night, BOTH surfaces with
          # lib/lars-packages.nix): upstream a6dd6a3 bakes the
          # through-its-own-lock vendorHash OW+eywme… (go-daemon flake pin
          # synced to v0.4.0 0a5d806f, own FOD green first-hand; pdd does
          # not follow our pins, so its own lock governs the FOD content).
          # Re-add ONLY via nix-hash-fix evidence, never by hand.
          # RE-ADDED (2026-11-06 lock float, module surface): at pdd@cfaaecd
          # upstream's own-lock hash OW+eywme… went stale through our graph
          # (spec OW+eyw, got hxcotRZ, float-proof-20261106-004759.log);
          # lars-packages surface re-shimmed in the same wave — edit BOTH.
          package = lib.mkDefault (
            inputs.project-discovery-daemon.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs {
              vendorHash = "sha256-Rd4vxqsiyY1JuHthGNhbHxnsRHe9sQTF9oZzLIWFCXE=";
            }
          );
          # Discovery runs git inside the search-path repos and reads
          # ~/.mrconfig: it must be the primary user (dedicated service
          # users cannot see a 0700 home).
          user = lib.mkDefault config.users.primaryUser;
        };

        systemd.services.project-discovery-daemon = {
          # ~/projects walker (2026-10-28 projects-subvol plan D6): discovery
          # roots live under ~/projects — fail loud when the Samsung subvol
          # mount is absent (never index the stale @ shadow). Conditional on
          # the mount being declared (VM/test hosts unaffected).
          unitConfig.RequiresMountsFor =
            lib.optionals (builtins.hasAttr "/home/lars/projects" config.fileSystems)
              [ "/home/lars/projects" ];

          inherit onFailure;

          serviceConfig = lib.mkMerge [
            # Full discovery of ~260 repos spikes ~7GB (measured while PMA
            # hosted the daemon; 8G covered peak with headroom). CPU-bursty:
            # git, go.mod parsing, file walks. Same values the upstream
            # module mkDefaults — restated at mkForce so the fleet bounds
            # stay SystemNix-owned (the registry's upstream-plain-beats-
            # mkDefault trap; proven via rendered-unit parity).
            (harden {
              MemoryMax = lib.mkForce "8G";
              # Explicit 7G high (was the derived 80% = 6.4G, which sat BELOW
              # the measured ~7GB discovery spike): the 2026-10-10 §17 triage
              # re-read found memory.peak pinned exactly at the 6.4G clip —
              # every full discovery paid reclaim churn at the ceiling while
              # the 8G hard bound had 1.6G it never touched. 7G passes the
              # measured spike; 8G stays the OOM bound.
              MemoryHigh = lib.mkForce "7G";
              CPUQuota = lib.mkForce "400%";
              ProtectHome = lib.mkForce "read-only";
            })
            # BE/6 background tier (2026-09-19 IO audit): this daemon is the
            # top sustained root-NVMe reader (40 GB reads + 17 GB zram writes
            # attributed via cgroup io.stat over one boot, 10.2 GiB/30 min
            # spike in the audit window) — discovery latency is invisible to
            # consumers (5m TTL cache), but its bursts starve the desktop and
            # stack with builds on the saturated QLC root. BFQ is active on
            # all disks, so the tier is effective; scheduler-level, immune to
            # the nvme0/nvme1 name swaps.
            ioTier.background
            (serviceDefaults { })
          ];
        };
      };
    };
}
