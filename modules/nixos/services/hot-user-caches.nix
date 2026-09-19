# User cache subvolumes on the Samsung TLC hot disk (by-label tlc).
#
# The 2026-09-18/19 IO audit (docs/status/2026-09-19_11-08_io-pressure-audit-
# and-cache-relocation.md) pinned ~8.7 GB of nix fetch cache (gitv3 6.3 G +
# tarballs 2.1 G) on the saturated QLC root NVMe inside the automounted
# @cache-home subvolume. snapshots.nix kept @cache-home only because those
# caches had "no off-NVMe home" — this module is that home: each listed cache
# gets a dedicated subvolume on the TLC disk, mounted AT its existing path.
#
# Style notes:
# - Mounts follow the snapshots.nix cacheSubvolumes family (noauto +
#   x-systemd.automount + idle-timeout), NOT the hermes plain-mount style:
#   hermes needed tmpfiles to see the mounted subvolume (automount+tmpfiles is
#   the shadow-dir class), while caches have no tmpfiles rules and WANT the
#   lazy mount so both this subvol and the @cache-home parent can expire idle.
# - fstab cannot create subvolumes: a forgejo-subvol-bootstrap-style oneshot
#   creates parent dirs + the leaf subvol through the /mnt/hot toplevel mount
#   before the automount unit ever answers a lookup (the test-cv pool-fmt
#   chicken-and-egg class). Idempotent; runs at boot via the automount unit.
# - The mount shadows any pre-existing directory content at the mount point
#   (the ClickHouse shadow-dir class): move old cache content aside BEFORE
#   the first activation — it is regenerable cache, not state.
# - Caches must never join a btrbk leg (snapshot churn); the users/ tree has
#   no legs — keep it that way when adding entries.
_: {
  flake.nixosModules.hot-user-caches =
    {
      pkgs,
      lib,
      config,
      utils,
      ...
    }:
    let
      inherit (config.users) primaryUser;
      cfg = config.services.hot-user-caches;
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceOneshotDefaults
        mkFilesystem
        ;
      cacheGroup = config.users.users.${primaryUser}.group;
    in
    {
      options.services.hot-user-caches = {
        enable = lib.mkEnableOption "user cache subvolumes on the Samsung TLC hot disk (IO-audit relocation)";

        device = lib.mkOption {
          type = lib.types.str;
          default = "/dev/disk/by-label/tlc";
          description = "Device hosting the cache subvolumes (device names swap across boots — always by-label).";
        };

        hotMount = lib.mkOption {
          type = lib.types.str;
          default = "/mnt/hot";
          description = "Toplevel mount of the hot disk, used by the bootstrap to create subvolumes.";
        };

        caches = lib.mkOption {
          type =
            with lib.types;
            attrsOf (submodule {
              options.subvol = lib.mkOption {
                type = str;
                description = "Subvolume path on the hot disk filesystem (leaf component only must not exist yet).";
              };
              options.mountPoint = lib.mkOption {
                type = str;
                description = "Path the subvolume mounts at (existing cache directory).";
              };
            });
          description = "Cache directories to relocate onto the hot disk.";
          default.nix = {
            subvol = "users/${primaryUser}/cache/nix";
            mountPoint = "/home/${primaryUser}/.cache/nix";
          };
        };
      };

      config = lib.mkIf cfg.enable {
        fileSystems = lib.mapAttrs' (
          name: cache:
          lib.nameValuePair cache.mountPoint (mkFilesystem {
            device = cfg.device;
            fsType = "btrfs";
            options = [
              "subvol=${cache.subvol}"
              "compress=zstd"
              "noatime"
              "nodiscard"
              "commit=300"
              "noauto"
              "x-systemd.automount"
              "x-systemd.idle-timeout=10min"
            ];
          })
        ) cfg.caches;

        systemd.services = lib.mapAttrs' (
          name: cache:
          let
            automountUnit = "${utils.escapeSystemdPath cache.mountPoint}.automount";
          in
          lib.nameValuePair "hot-user-caches-${name}-bootstrap" {
            description = "Idempotently create the ${name} cache subvolume on the hot disk";
            # The automount unit pulls this in at boot and waits (before):
            # the autofs trigger must never answer a lookup before the
            # subvol exists.
            wantedBy = [ automountUnit ];
            before = [ automountUnit ];
            after = [ "mnt-hot.mount" ];
            wants = [ "mnt-hot.mount" ];
            unitConfig.RequiresMountsFor = [ cfg.hotMount ];
            path = [
              pkgs.btrfs-progs
              pkgs.coreutils
            ];
            serviceConfig = lib.mkMerge [
              {
                Type = "oneshot";
                User = "root";
                RemainAfterExit = true;
              }
              (serviceOneshotDefaults { })
              (harden {
                # btrfs subvolume create is a privileged ioctl; chown for the
                # cache owner (harden{}'s empty bounding set would EPERM both).
                CapabilityBoundingSet = "CAP_SYS_ADMIN CAP_CHOWN CAP_DAC_OVERRIDE";
                # The MOUNT ROOT — never a subdir inside it (226 class):
                # RequiresMountsFor above guarantees the root exists before
                # the namespace is built.
                ReadWritePaths = [ cfg.hotMount ];
              })
            ];
            script = ''
              set -euo pipefail
              subvol=${cfg.hotMount}/${cache.subvol}
              if ${pkgs.btrfs-progs}/bin/btrfs subvolume show "$subvol" >/dev/null 2>&1; then
                echo "hot-user-caches-${name}-bootstrap: $subvol already exists"
              else
                mkdir -p "$(dirname "$subvol")"
                ${pkgs.btrfs-progs}/bin/btrfs subvolume create "$subvol"
                echo "hot-user-caches-${name}-bootstrap: created $subvol"
              fi
              chown ${primaryUser}:${cacheGroup} "$subvol"
              chmod 0700 "$subvol"
            '';
          }
        ) cfg.caches;        assertions = [
          {
            assertion = config.fileSystems ? ${cfg.hotMount};
            message = "services.hot-user-caches requires the ${cfg.hotMount} Samsung-toplevel mount (hardware-configuration.nix) — the bootstrap creates subvolumes through it.";
          }
        ];
      };
    };
}
