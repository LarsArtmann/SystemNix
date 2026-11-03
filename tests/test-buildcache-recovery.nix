# VM test for the build-cache recovery unit (modules/nixos/services/buildcache.nix).
#
# Regression class (2026-11-03, gitea-runner): deploy.sh starts
# buildcache-usb-recovery after every switch, and the script used to tear the
# mount down unconditionally. Because a consumer's RequiresMountsFor implies
# Requires= on mnt-buildcache.mount, that teardown STOPPED every bound daemon
# (the Actions runner died at 21:11:01, the post-deploy smoke FAILed, and
# nothing restarted it until its own 5-min ensure timer fired 72s later).
#
# Two behaviours are pinned here:
#   1. HEALTHY FAST PATH: a mount that answers real I/O is never torn down, so
#      its consumers are never stopped by a deploy-time recovery run.
#   2. CONSUMER CONVERGENCE: a bound daemon that is failed/inactive (whether it
#      was stopped by a real recovery remount or externally) is started again
#      inside the same recovery run.
{ pkgs }:
let
  buildcacheModule = (import ../modules/nixos/services/buildcache.nix).flake.nixosModules.buildcache;
in
{
  name = "buildcache-recovery";

  nodes.machine =
    { ... }:
    {
      imports = [
        ./test-helpers.nix
        buildcacheModule
        # co-import: the module declares a services.integration entry behind an
        # `options ? services.integration` guard that is evaluated eagerly in
        # the test harness (pool-recovery precedent, 2026-09-15).
        (import ../modules/nixos/services/integration.nix { }).flake.nixosModules.integration
      ];

      users.primaryUser = "lars";
      users.users.lars.isNormalUser = true;

      boot.supportedFilesystems = [ "ext4" ];
      virtualisation.emptyDiskImages = [ 512 ];

      # Whole-disk ext4 (no partition table): the by-id serial parser returns
      # null for /dev/vdb, which is exactly the "udev recovery rule skipped"
      # path production uses for non-by-id devices.
      services.buildcache = {
        enable = true;
        device = "/dev/vdb";
        wholeDiskDevice = "/dev/vdb";
        recoveryRestartUnits = [ "buildcache-consumer-test.service" ];
      };

      # qemu-vm mkVMOverride REPLACES the whole `fileSystems` option with
      # virtualisation.fileSystems (pool-recovery/test-cv precedent), so the
      # module's own entry is restated here with the production option set.
      # device-timeout is 30s, NOT the production 2s: the guest's udev only
      # processes virtio disks after switch-root (udev socket up ~11.7s, the
      # boot transaction queues dev-vdb.device at ~11.5s), so a 2s bound
      # fails the FIRST mount attempt with "Timed out waiting for device".
      virtualisation.fileSystems."/mnt/buildcache" = {
        device = "/dev/vdb";
        fsType = "ext4";
        options = [
          "noatime"
          "nofail"
          "x-systemd.automount"
          "x-systemd.device-timeout=30s"
          "x-systemd.device-bound"
        ];
      };

      # Format before anything can pull the automount (sysinit-target stage,
      # so local-fs and multi-user units see a filesystem).
      environment.systemPackages = [ pkgs.e2fsprogs ];
      boot.postBootCommands = "${pkgs.e2fsprogs}/bin/mkfs.ext4 -F -L buildcache /dev/vdb";

      # Consumer fixture: daemon-shaped (Restart != no) and bound to a path
      # UNDER the mount point, the same shape the runner has via
      # RequiresMountsFor=/mnt/buildcache/ci-runner-cache.
      systemd.services.buildcache-consumer-test = {
        description = "buildcache recovery convergence fixture";
        wantedBy = [ "multi-user.target" ];
        unitConfig.RequiresMountsFor = "/mnt/buildcache/ci-runner-cache";
        serviceConfig = {
          Type = "simple";
          ExecStart = "${pkgs.coreutils}/bin/sleep infinity";
          Restart = "on-failure";
        };
      };
    };

  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("buildcache-consumer-test.service")

    # ---------- 1. healthy mount: never torn down, never stops consumers ----------
    machine.succeed("systemctl start buildcache-usb-recovery.service")
    machine.succeed("journalctl -u buildcache-usb-recovery.service | grep -q 'buildcache healthy'")
    machine.succeed("systemctl is-active --quiet buildcache-consumer-test.service")
    machine.succeed("findmnt -n -o FSTYPE /mnt/buildcache | grep -qx ext4")

    # ---------- 2. externally stopped consumer is converged ----------
    machine.succeed("systemctl stop buildcache-consumer-test.service")
    machine.succeed("systemctl start buildcache-usb-recovery.service")
    machine.succeed("systemctl is-active --quiet buildcache-consumer-test.service")
    machine.succeed(
      "journalctl -u buildcache-usb-recovery.service | grep -q 'starting enabled-but-inactive buildcache consumer: buildcache-consumer-test.service'"
    )

    # ---------- 3. real remount path stops the consumer, recovery brings it back ----------
    # Stop the mount the way a USB flap does: mount gone, automount unarmed.
    # RequiresMountsFor propagates the mount stop into the consumer (this is
    # the production failure mechanism).
    machine.succeed("systemctl stop mnt-buildcache.mount")
    machine.succeed("systemctl stop mnt-buildcache.automount")
    machine.succeed("! systemctl is-active --quiet buildcache-consumer-test.service")

    machine.succeed("systemctl start buildcache-usb-recovery.service")
    machine.succeed("journalctl -u buildcache-usb-recovery.service | grep -q 'buildcache recovered'")
    machine.succeed("systemctl is-active --quiet buildcache-consumer-test.service")
    machine.succeed("findmnt -n -o FSTYPE /mnt/buildcache | grep -qx ext4")
    fstype = machine.succeed("findmnt -n -o SOURCE,FSTYPE /mnt/buildcache").strip()
    assert "ext4" in fstype, f"buildcache remounted wrong fs: {fstype}"
  '';
}
