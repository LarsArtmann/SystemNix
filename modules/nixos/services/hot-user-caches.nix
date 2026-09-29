# User cache subvolumes on the Samsung TLC hot disk (by-label tlc).
#
# The 2026-09-18/19 IO audit (docs/status/2026-09-19_11-08_io-pressure-audit-
# and-cache-relocation.md) pinned ~8.7 GB of nix fetch cache (gitv3 6.3 G +
# tarballs 2.1 G) on the saturated QLC root NVMe inside the automounted
# @cache-home subvolume. snapshots.nix kept @cache-home only because those
# caches had "no off-NVMe home" — this module is that home: each listed cache
# gets a dedicated subvolume on the TLC disk, mounted AT its existing path.
#
# Doctrine (2026-09-29, after FOUR failed boots — see history below):
# - Subvolumes are PROVISIONING state. disko/samsung-tlc.nix declares every
#   cache subvolume (flake geometryGuards assert them at eval time), so a
#   provisioned disk ALWAYS carries them. fstab just mounts. NOTHING runtime
#   may sit between an automount and its mount — same shape as snapshots.nix
#   cacheSubvolumes (@cache-home), which has run cleanly since forever.
# - Missing subvol (drifted/misprovisioned disk) = mount fails FAST and LOUD
#   ("subvol not found" in the journal, autofs returns an error to the
#   waiter). x-systemd.mount-timeout bounds even a pathological mount job.
#   Honest failure beats silent healing — especially healing that, in
#   practice, never ran.
# - Adding a cache entry: add the subvolume to disko/samsung-tlc.nix (it is
#   created at next provision; on the LIVE disk create it once by hand:
#   `btrfs subvolume create /mnt/hot/<subvol>`), then list it here.
#
# Mounts follow the snapshots.nix cacheSubvolumes family (noauto +
# x-systemd.automount + idle-timeout), NOT the hermes plain-mount style:
# hermes needed tmpfiles to see the mounted subvolume (automount+tmpfiles is
# the shadow-dir class), while caches have no tmpfiles rules and WANT the
# lazy mount so both this subvol and the @cache-home parent can expire idle.
# The mount shadows any pre-existing directory content at the mount point
# (the ClickHouse shadow-dir class): move old cache content aside BEFORE the
# first activation — it is regenerable cache, not state.
# Caches must never join a btrbk leg (snapshot churn); the users/ tree has
# no legs — keep it that way when adding entries.
#
# Incident history — the deleted runtime bootstrap (2026-09-20 → 2026-09-29):
# fstab cannot create subvolumes, so v1/v2 wired a just-in-time oneshot
# (`hot-user-caches-<name>-bootstrap`) that idempotently created the leaf
# subvol through /mnt/hot before the automount ever answered a lookup. It
# NEVER completed successfully — 0 for 4 boots — and each failure wedged the
# automount, parking every process touching the path in eternal autofs_wait
# D-state (on this host: EVERY nix invocation — flake check, build,
# print-devenv, direnv):
#   2026-09-20 11:41 — ordering cycle at activation ("Transaction order is
#     cyclic"); chmod EPERM (CapabilityBoundingSet gap) → exit-4 loop.
#   2026-09-24 22:35 — cycle inside the boot transaction; systemd deleted
#     systemd-tmpfiles-setup.service to break it → /run/binfmt etc. never
#     existed; every sandboxed nix build died. (Fix attempt #1: pull the
#     bootstrap from the .mount instead of the .automount.)
#   2026-09-27 17:57 & 20:34 — same cycle class again (fix not yet live),
#     bootstrap hung pre-exec both boots; the cache mount NEVER ran.
#   2026-09-29 09:58 — fix live: no boot-transaction cycle, but btop's
#     first walk into /home/lars/.cache/nix pulled the bootstrap into the
#     automount transaction, where its child hung PRE-EXEC (empty
#     /proc/<pid>/cmdline — forked, never exec'd; sandbox namespace
#     construction × the pending direct-autofs). SIGKILL undeliverable,
#     TimeoutStartSec unable to complete the job → mount job "waiting"
#     forever → 84 D-state processes, load 86, boot transaction stuck
#     3+h before anyone noticed. The subvol existed the whole time; the
#     script had been a no-op-to-be since 2026-09-20.
# Removed 2026-09-29. If a runtime provisioner is EVER reintroduced here,
# it must carry JobTimeoutSec + JobRunningTimeoutSec AND must not be
# ordered against any mount/automount unit.
_: {
  flake.nixosModules.hot-user-caches =
    {
      lib,
      config,
      ...
    }:
    let
      inherit (config.users) primaryUser;
      cfg = config.services.hot-user-caches;
      inherit (import ../../../lib/default.nix lib) mkFilesystem;
    in
    {
      options.services.hot-user-caches = {
        enable = lib.mkEnableOption "user cache subvolumes on the Samsung TLC hot disk (IO-audit relocation)";

        device = lib.mkOption {
          type = lib.types.str;
          default = "/dev/disk/by-label/tlc";
          description = "Device hosting the cache subvolumes (device names swap across boots — always by-label).";
        };

        caches = lib.mkOption {
          type =
            with lib.types;
            attrsOf (submodule {
              options.subvol = lib.mkOption {
                type = str;
                description = "Subvolume path on the hot disk filesystem. MUST also be declared in disko/samsung-tlc.nix — provisioning creates it, this module only mounts it.";
              };
              options.mountPoint = lib.mkOption {
                type = str;
                description = "Path the subvolume mounts at (existing cache directory).";
              };
            });
          description = "Cache directories to relocate onto the hot disk.";
          default = {
            nix = {
              subvol = "users/${primaryUser}/cache/nix";
              mountPoint = "/home/${primaryUser}/.cache/nix";
            };
            # go-build is DELIBERATELY ABSENT (2026-09-20, first live run):
            # ~/.cache/go-build is an HM mkOutOfStoreSymlink →
            # /mnt/buildcache/go-build (home.nix env-less-processes
            # doctrine), and systemd CANONICALIZES mount units through
            # symlinks — the go-build entry materialized as
            # mnt-buildcache-go\x2dbuild.automount, an autofs NESTED INSIDE
            # the /mnt/buildcache autofs, failing at unit load (exit-4 on
            # every activation, live 2026-09-20 11:41). A proper integration
            # needs the HM symlink gated off AND a boot ordering that never
            # loads the automount while the symlink exists (HM activates
            # AFTER early-boot automounts). The BuildFlow env_guard
            # fallback-cache relocation stays PARKED until that design
            # exists; the Samsung subvol created 2026-09-20
            # (users/<user>/cache/go-build) is inert and harmless.
          };
        };
      };

      config = lib.mkIf cfg.enable {
        fileSystems = lib.mapAttrs' (
          _name: cache:
          lib.nameValuePair cache.mountPoint (mkFilesystem {
            inherit (cfg) device;
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
              # Bounds the mount JOB itself (e.g. a btrfs mount hung on an
              # early-boot replay window): after the timeout the job fails
              # and autofs returns an error to waiters instead of parking
              # them in autofs_wait forever (2026-09-29 class).
              "x-systemd.mount-timeout=90s"
            ];
          })
        ) cfg.caches;
      };
    };
}
