# VM test for the hot-user-caches module + the 2026-09-24 boot-transaction
# tmpfiles regression.
#
# The regression (live 2026-09-24 22:35, first boot after the module's
# deploy): wiring the bootstrap's wantedBy=/before= against the fstab
# .AUTOMOUNT unit closed an ordering cycle inside the boot transaction —
# systemd-tmpfiles-setup.service's start job got DELETED to break the cycle
# ("Job systemd-tmpfiles-setup.service/start deleted to break ordering
# cycle"), so the main tmpfiles pass never ran and /run/binfmt (nix sandbox
# extra-sandbox-paths), /run/systemnix/sev1, /run/lock/* never existed for
# the whole boot. Every sandboxed nix build died "getting attributes of
# path /run/binfmt"; sev1-bridge 226'd 2900x. Only an actual BOOT catches
# transaction cycles — eval cannot see them.
#
# Asserts:
#   1. systemd-tmpfiles-setup.service is ACTIVE after boot, and a probe
#      tmpfiles rule was actually applied (rule application, not just unit
#      state).
#   2. No failed units from the automount chain.
#   3. First cache access: automount triggers → .mount pulls the bootstrap
#      → subvolume created on the hot disk → btrfs mount serves it.
#   4. Writes through the automounted path land on the hot disk.
{
  pkgs,
}:
let
  # Two-statement load form (the miniflux Nix-parsing trap: apply-then-select
  # does not parse as intended).
  hotUserCachesFile = import ../modules/nixos/services/hot-user-caches.nix;
  hotUserCachesModule = (hotUserCachesFile { }).flake.nixosModules.hot-user-caches;
in
{
  name = "hot-user-caches";

  nodes.machine =
    { lib, ... }:
    {
      imports = [
        ./test-helpers.nix
        hotUserCachesModule
      ];

      users.primaryUser = "lars";
      users.users.lars.isNormalUser = true;

      boot.supportedFilesystems = [ "btrfs" ];
      virtualisation.emptyDiskImages = [ 512 ];

      # Mirror the production /mnt/hot Samsung-toplevel mount. MUST be
      # virtualisation.fileSystems, NOT fileSystems (qemu-vm mkVMOverride
      # replaces the whole option — plain entries vanish from the guest
      # fstab; test-cv/test-pool-recovery precedent). The module's eval-time
      # assertion still sees the merged config.fileSystems entry.
      virtualisation.fileSystems."/mnt/hot" = {
        device = "/dev/disk/by-label/tlc";
        fsType = "btrfs";
        options = [ "nofail" ];
      };

      # Test-cv pool-fmt pattern: format the hot disk BEFORE mnt-hot.mount
      # starts (its by-label device unit only exists after mkfs).
      systemd.services.hot-fmt = {
        description = "Format the virtio disk as btrfs label tlc (test-only)";
        wantedBy = [ "local-fs.target" ];
        before = [
          "mnt-hot.mount"
          "local-fs.target"
        ];
        serviceConfig = {
          Type = "oneshot";
          User = "root";
        };
        path = [
          pkgs.btrfs-progs
          pkgs.util-linux
          pkgs.systemd
        ];
        script = ''
          if ! blkid /dev/vdb | grep -q 'LABEL="tlc"'; then
            mkfs.btrfs -f -L tlc /dev/vdb
          fi
          udevadm settle
        '';
      };

      # Probe rule: proves the main tmpfiles CREATE pass actually applied
      # rules (unit state alone could be RemainAfterExit theatre).
      systemd.tmpfiles.rules = [ "d /run/huc-tmpfiles-probe 0755 root root -" ];

      services.hot-user-caches.enable = true;

      system.stateVersion = "25.11";
    };

  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")

    # 1. THE REGRESSION TRIPWIRE — with the pre-2026-09-25 wiring (bootstrap
    # wantedBy/before on the .automount), systemd deleted the tmpfiles start
    # job to break the boot ordering cycle and BOTH of these fail.
    machine.succeed("systemctl is-active --quiet systemd-tmpfiles-setup.service")
    machine.succeed("test -d /run/huc-tmpfiles-probe")

    # 2. No failed units from the automount/bootstrap chain.
    machine.fail("systemctl --failed --no-legend | grep -v '0 loaded units'")

    # 3. First cache access: automount → .mount → bootstrap → subvol → mount.
    # The bootstrap cold-creates the subvolume and pulls mnt-hot.mount, so
    # allow a generous timeout for the first trigger.
    machine.succeed("ls /home/lars/.cache/nix/ >/dev/null")
    machine.wait_for_unit("home-lars-.cache-nix.mount", timeout=120)
    machine.succeed("findmnt -n -o FS_TYPE /home/lars/.cache/nix | grep -q btrfs")
    machine.succeed("systemctl is-active --quiet hot-user-caches-nix-bootstrap.service")

    # 4. Writes land on the hot-disk subvolume (the mount is live, not a
    # shadow of the underlying @ dir).
    machine.succeed("touch /home/lars/.cache/nix/alive && test -f /home/lars/.cache/nix/alive")
    machine.succeed("test -f /mnt/hot/users/lars/cache/nix/alive")
  '';
}
