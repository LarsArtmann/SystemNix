# VM test for the rescue snapshot tier (platforms/nixos/system/btrfs-rescue.nix).
#
# Proves, against a REAL btrfs filesystem in the VM:
#   1. Boot-run creates /mnt/btrfs-root/.rescue/@.rescue-* (read-only) and
#      the append-only self-test stamps protection=1.
#   2. INDEPENDENT reproduction of the kernel semantics the whole design
#      rests on: `btrfs subvolume delete` inside a chattr +a directory FAILS.
#      If a future kernel ever stops enforcing append-only on the subvol-
#      delete ioctl, this test goes red here (not in production).
#   3. Rotation: 3 fake (older-sorting) rescue subvols + a manual run →
#      total == keep (2), fakes pruned, newest real kept.
#   4. The rescue snapshot actually captures @ content (rollback works).
{ pkgs }:
let
  baseNode = {
    imports = [ ../platforms/nixos/system/btrfs-rescue.nix ];
    boot.supportedFilesystems = [ "btrfs" ];
    system.stateVersion = "25.11";
    environment.systemPackages = [
      pkgs.btrfs-progs
      pkgs.e2fsprogs # lsattr
    ];
    virtualisation.emptyDiskImages = [ 512 ];
    services.btrfs-rescue = {
      enable = true;
      keep = 2;
    };
    # VM tests must use virtualisation.fileSystems: qemu-vm.nix replaces the
    # whole `fileSystems` option at priority 900 (a plain fileSystems entry
    # silently vanishes from the guest fstab — test-pool-recovery precedent).
    virtualisation.fileSystems."/mnt/btrfs-root" = {
      device = "/dev/disk/by-label/rescuefs";
      fsType = "btrfs";
      options = [ "nofail" ];
    };
    systemd.services.rescue-fmt = {
      description = "Format the virtio disk as btrfs label rescuefs + create @ (test-only)";
      # Must complete BEFORE the by-label mount starts — same pattern as
      # test-pool-recovery's pool-fmt. NOTE the escaped dash in the mount
      # unit name (systemd-escape -p /mnt/btrfs-root → mnt-btrfs\x2droot).
      wantedBy = [ "local-fs.target" ];
      before = [
        "mnt-btrfs\\x2droot.mount"
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
        if ! blkid /dev/vdb | grep -q 'LABEL="rescuefs"'; then
          mkfs.btrfs -f -L rescuefs /dev/vdb
        fi
        mkdir -p /tmp/rescue-fmt
        mount /dev/vdb /tmp/rescue-fmt
        if [ ! -d /tmp/rescue-fmt/@ ]; then
          btrfs subvolume create /tmp/rescue-fmt/@
        fi
        echo rescue-tier-test > /tmp/rescue-fmt/@/canary.txt
        umount /tmp/rescue-fmt
        udevadm settle
      '';
    };
  };
in
{
  name = "btrbk-rescue";

  nodes.machine = baseNode;

  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")

    # 1. Boot-run: one rescue snapshot exists, append-only self-test stamped 1
    machine.succeed("ls /mnt/btrfs-root/.rescue/ | grep -c '^@\\.rescue-' | grep -qx 1")
    machine.succeed("test \"$(cat /var/lib/btrfs-rescue/protection)\" = 1")

    # 4. The snapshot captured @ content
    machine.succeed(
      "cat /mnt/btrfs-root/.rescue/$(ls /mnt/btrfs-root/.rescue/ | grep '^@\\.rescue-' | head -1)/canary.txt | grep -qx rescue-tier-test"
    )

    # 2. THE kernel-semantics proof: subvolume delete inside the +a dir fails,
    #    and the snapshot survives it.
    snap = machine.succeed(
      "ls /mnt/btrfs-root/.rescue/ | grep '^@\\.rescue-' | head -1"
    ).strip()
    machine.fail(f"btrfs subvolume delete /mnt/btrfs-root/.rescue/{snap}")
    machine.succeed(f"btrfs subvolume show /mnt/btrfs-root/.rescue/{snap}")

    # 3. Rotation: 3 fake OLDER-sorting rescue subvols, manual run → keep == 2
    for i in range(1, 4):
        machine.succeed(
            f"btrfs subvolume snapshot -r /mnt/btrfs-root/@ /mnt/btrfs-root/.rescue/@.rescue-000{i}"
        )
    machine.succeed("systemctl start btrfs-rescue-snapshot.service")
    machine.succeed("test \"$(ls /mnt/btrfs-root/.rescue/ | grep -c '^@\\.')\" -eq 2")
    # the fakes were the oldest → all pruned
    machine.succeed("test \"$(ls /mnt/btrfs-root/.rescue/ | grep -c 'fake\\|000')\" -eq 0")
    # self-test still passing after rotation
    machine.succeed("test \"$(cat /var/lib/btrfs-rescue/protection)\" = 1")

    # No probe leftovers: the append-only probe must be cleaned every run
    machine.succeed("test \"$(ls -A /mnt/btrfs-root/.rescue/ | grep -c probe)\" -eq 0")
  '';
}
