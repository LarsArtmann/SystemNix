# Eval-time audit (WARNING-grade): systemd.services entries that nothing
# ever starts — the "stray attrname" class.
#
# A `systemd.services.<name>` attr that does not match an upstream-defined
# unit does NOT error — it silently creates a dormant unit FILE. An override
# intended for a template or an instance then guards NOTHING:
#   - 2026-08-31..2026-09-29: the scrub deferral guard targeted
#     `btrfs-scrub--`/`btrfs-scrub-data` (unit files systemd never starts)
#     instead of the `btrfs-scrub@` TEMPLATE the weekly timers instantiate —
#     every scrub ran raw through IO storms for a MONTH while every eval
#     stayed green (dead code, phantom protection).
#
# Detection: a unit is flagged when ALL of the following hold:
#   - enable = true (it renders a unit file)
#   - no wantedBy ([Install] never pulls it)
#   - no same-named timer / socket / path unit drives it
#   - NO other unit references it in after/wants/requires/partOf/bindsTo/
#     upholds/onFailure (dependency graph has no incoming edge)
#   - no OTHER unit installs into it via wantedBy/requiredBy (grouping
#     targets, nixpkgs-style oneshot prerequisites — install-time .wants/
#     .requires symlinks the dependency lists never show)
#   - the name carries no "@" (templates + systemd-instantiated instances
#     are shape-allowed: runtime instantiation is invisible to the attrset)
#   - not in allowUnits (the fleet baseline: upstream units wired through
#     presets/aliases/dbus-activation, and SystemNix units started ONLY by
#     deploy.sh / udev SYSTEMD_WANTS / runbooks — each with a comment)
#
# WARNING, not assertion: the heuristic cannot see systemd.packages-provided
# wiring (aliases, dbus activation, preset enables). New hits are drift
# signals for a human, not proven dead config.
#
# Implementation notes (probe-proven 2026-10-01):
#   - dep text is gathered per NAMESPACE and concatenated — NEVER
#     `services // timers // ...`: the // merge DROPS the service entry for
#     every timer+service name twin (the norm), losing its service-side deps
#     and creating phantom orphans.
#   - dep getters tolerate non-list values (`u.k or []` throws on a string
#     value; some upstream units carry `""`).
{
  flake.nixosModules.stray-unit-audit =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.services.stray-unit-audit;

      getList =
        u: k: if u ? "${k}" then (let v = u."${k}"; in if lib.isList v then v else [ ]) else [ ];

      depKeys = [
        "after"
        "onFailure"
        "wants"
        "requires"
        "partOf"
        "bindsTo"
        "upholds"
      ];

      # Per-namespace dep text. A trailing separator keeps adjacent units'
      # names from gluing together.
      depText =
        units:
        lib.concatStrings (
          lib.mapAttrsToList (
            _n: u: lib.concatStringsSep " " (lib.concatMap (getList u) depKeys) + " "
          ) units
        );

      wantedByText =
        units:
        lib.concatStrings (
          lib.mapAttrsToList (
            _n: u: lib.concatStringsSep " " (getList u "wantedBy") + " " + lib.concatStringsSep " " (getList u "requiredBy") + " "
          ) units
        );

      namespaces = [
        config.systemd.services
        config.systemd.timers
        config.systemd.sockets
        config.systemd.paths
        config.systemd.targets
      ];

      refText = lib.concatStrings (map depText namespaces);
      installText = lib.concatStrings (map wantedByText namespaces);

      stray =
        n:
        let s = config.systemd.services."${n}"; in
        s.enable
        && getList s "wantedBy" == [ ]
        && getList s "requiredBy" == [ ]
        && !(config.systemd.timers ? "${n}")
        && !(config.systemd.sockets ? "${n}")
        && !(config.systemd.paths ? "${n}")
        && !lib.hasInfix n refText
        && !lib.hasInfix n installText
        && !lib.hasInfix "@" n
        && !builtins.elem n cfg.allowUnits;

      strays = builtins.filter stray (builtins.attrNames config.systemd.services);
    in
    {
      options.services.stray-unit-audit = {
        allowUnits = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            # ── Upstream (nixpkgs/systemd) units wired through presets,
            #    aliases, sysinit wants, or dbus activation — all invisible
            #    to the attrset graph. Eval-probed on evo-x2 + rpi3-dns
            #    2026-10-01; rpi3-dns is CLEAN with exactly these.
            "ModemManager"
            "dbus-broker"
            "display-manager"
            "keepalived"
            "kmod-static-nodes"
            "polkit"
            "rtkit-daemon"
            "systemd-binfmt"
            "systemd-bless-boot"
            "systemd-boot-random-seed"
            "systemd-hostnamed"
            "systemd-importd"
            "systemd-journal-flush"
            "systemd-localed"
            "systemd-random-seed"
            "systemd-remount-fs"
            "systemd-timedated"
            "systemd-udevd"
            "systemd-update-utmp"
            "xfs_scrub_all"
            # ── SystemNix units started ONLY outside the unit graph:
            #    deploy.sh post-switch blocks, udev SYSTEMD_WANTS, or
            #    runbook-manual runs (deploy-restart-audit's is-enabled/
            #    is-active blocks own their convergence).
            "activitywatch-data-to-pool" # deploy.sh start --no-block
            "buildcache-usb-recovery" # udev SYSTEMD_WANTS (JMS567 flap) + deploy.sh
            "data-to-pool-migration" # deploy.sh start --no-block (self-neutralizing)
            "discordsync-attachments-migrate" # deploy.sh dedicated --no-block block (static unit)
            "forgejo-census" # runbook-manual (sudo systemctl start, census docs)
            "pool-usb-recovery" # udev SYSTEMD_WANTS (Toshiba ID_SERIALs) + deploy.sh
            # ── Inert-by-config: hot-db-bootstrap fills its wantedBy with the
            #    per-entry mount units; with entries = {} (pre-wave) nothing
            #    pulls it BY DESIGN (also in deploy-restart-audit.allowUnits).
            "hot-db-bootstrap"
          ];
          description = ''
            Units the stray-unit audit accepts as deliberately unstarted by the
            unit graph: wired upstream (presets, aliases, dbus activation) or
            started ONLY by deploy.sh / udev SYSTEMD_WANTS / runbooks. Every
            NEW entry MUST carry a justification comment where it is added. A
            unit listed here that no longer exists is harmless (no lint
            either way).
          '';
        };
      };

      config.warnings = lib.optional (strays != [ ]) ''
        stray-unit-audit: systemd.services entries nothing ever starts:
          ${lib.concatStringsSep ", " strays}

        A systemd.services attr that no timer/socket/path drives, no unit
        depends on, and no [Install] pulls renders a DORMANT unit file — an
        override targeted at it guards nothing (the 2026-08-31..09-29
        btrfs-scrub-- dead-guard class). Check the name: template overrides
        belong on the `foo@` TEMPLATE attr (or the instance systemd actually
        instantiates), externally-started units belong in
        services.stray-unit-audit.allowUnits WITH a justification comment.
      '';
    };
}
