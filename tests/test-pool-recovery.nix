# VM test for the pool DAS replug self-heal (modules/nixos/services/pool-recovery.nix).
#
# Three scenarios, three nodes (no QEMU hotplug gymnastics needed):
#
#   healthy — 2 virtio disks as btrfs raid1 label=pool mounted at /mnt/pool.
#     1. Recovery no-ops cleanly on a healthy mount (real-IO short-circuit).
#     2. ZOMBIE SIMULATION without hotplug: stop the mount, mount a FOREIGN
#        ext4 disk (vdd) at /mnt/pool, run the unit — its devt-vs-members
#        check must reap the stale mount and remount the pool from fstab.
#        This is the exact code path a real replug exercises (the persisted
#        mount holds a devt no current member has).
#     3. Counters + prom metrics written (mounted=1, recoveries_total=1).
#     4. udev rule generated with SYSTEMD_WANTS on both member serials.
#
#   partial — 1 of 2 declared members present (vdb exists but is NOT the
#     pool fs): the unit must FAIL LOUDLY and must NOT mount anything.
#     Degraded mounting is a user decision, never automated.
#
#   absent — 0 members present: the unit must exit CLEANLY (the DAS-link
#     Gatus check owns whole-link-down alerting; boots without the DAS must
#     not pollute systemctl --failed). Metrics still write fail-closed.
{ pkgs }:
let
  poolRecoveryModule = (import ../modules/nixos/services/pool-recovery.nix).flake.nixosModules.pool-recovery;

  baseNode =
    { lib, ... }:
    {
      imports = [ poolRecoveryModule ];
      system.stateVersion = "25.11";
      environment.systemPackages = [ pkgs.e2fsprogs pkgs.btrfs-progs ];
    };
in
{
  nodes.healthy = {
    imports = [ baseNode ];
    virtualisation.emptyDiskImages = [
      512
      512
      512
    ];
    services.pool-recovery = {
      enable = true;
      members = [
        "/dev/vdb"
        "/dev/vdc"
      ];
      settleTimeoutSeconds = 10;
    };
    # Simulate the production pool: btrfs raid1, by-label fstab entry.
    fileSystems."/mnt/pool" = {
      device = "/dev/disk/by-label/pool";
      fsType = "btrfs";
      options = [ "nofail" ];
    };
    systemd.services.pool-fmt = {
      description = "Format the two virtio disks as btrfs raid1 label pool (test-only)";
      wantedBy = [ "mnt-pool.mount" ];
      before = [ "mnt-pool.mount" ];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
      path = [ pkgs.btrfs-progs pkgs.util-linux ];
      script = ''
        if ! blkid /dev/vdb | grep -q 'LABEL="pool"'; then
          mkfs.btrfs -f -d raid1 -m raid1 -L pool /dev/vdb /dev/vdc
        fi
      '';
    };
  };

  nodes.partial = {
    imports = [ baseNode ];
    virtualisation.emptyDiskImages = [ 512 ];
    services.pool-recovery = {
      enable = true;
      members = [
        "/dev/vdb"
        "/dev/vdc"
      ];
      settleTimeoutSeconds = 8;
    };
    fileSystems."/mnt/pool" = {
      device = "/dev/disk/by-label/pool";
      fsType = "btrfs";
      options = [ "nofail" ];
    };
  };

  nodes.absent = {
    imports = [ baseNode ];
    services.pool-recovery = {
      enable = true;
      members = [
        "/dev/vdb"
        "/dev/vdc"
      ];
      settleTimeoutSeconds = 8;
    };
  };

  testScript = ''
    start_all()

    # ---------- healthy ----------
    healthy.wait_for_unit("mnt-pool.mount")
    healthy.wait_for_unit("multi-user.target")

    # udev rule generated: SYSTEMD_WANTS on both member serials
    healthy.succeed("grep -rq 'SYSTEMD_WANTS.*pool-usb-recovery' /etc/udev/rules.d/")
    healthy.succeed("grep -rq 'ID_SERIAL==\"TOSHIBA_MG08ACA16TE_72U0A005FWTG\"' /etc/udev/rules.d/")
    healthy.succeed("grep -rq 'ID_SERIAL==\"TOSHIBA_MG08ACA16TE_72U0A0ZUFWTG\"' /etc/udev/rules.d/")

    # 1. healthy mount: recovery is a clean no-op
    healthy.succeed("systemctl start pool-usb-recovery.service")
    healthy.succeed("journalctl -u pool-usb-recovery.service | grep -q 'mount healthy'")

    # 3+2. ZOMBIE SIMULATION: foreign disk at the mountpoint → reap + remount
    healthy.succeed("systemctl stop mnt-pool.mount")
    healthy.succeed("mkfs.ext4 -F /dev/vdd")
    healthy.succeed("mount /dev/vdd /mnt/pool")
    healthy.succeed("systemctl start pool-usb-recovery.service")
    healthy.succeed("journalctl -u pool-usb-recovery.service | grep -q 'reaping stale pool mount'")
    # back on the pool fs (btrfs = /dev/vdb), not the foreign ext4 disk
    fstype = healthy.succeed("findmnt -n -o FSTYPE /mnt/pool").strip()
    assert fstype == "btrfs", f"pool remounted wrong fs: {fstype}"
    healthy.succeed("test -s /var/lib/pool-recovery/recoveries")
    healthy.succeed("test \"$(cat /var/lib/pool-recovery/recoveries)\" = 1")

    # 3. metrics: real-IO mounted=1, both members, recovery counter
    healthy.succeed("systemctl start pool-recovery-metrics.service")
    healthy.succeed(
      "grep -q 'pool_usb_recovery_mounted 1' /var/lib/prometheus-node-exporter/textfile_collectors/pool-recovery.prom"
    )
    healthy.succeed(
      "grep -q 'pool_usb_recovery_members_present 2' /var/lib/prometheus-node-exporter/textfile_collectors/pool-recovery.prom"
    )
    healthy.succeed(
      "grep -q 'pool_usb_recovery_recoveries_total 1' /var/lib/prometheus-node-exporter/textfile_collectors/pool-recovery.prom"
    )

    # ---------- partial: 1 of 2 members present → FAIL LOUDLY, mount nothing ----------
    partial.wait_for_unit("multi-user.target")
    partial.fail("systemctl start pool-usb-recovery.service")
    partial.succeed("systemctl is-failed --quiet pool-usb-recovery.service")
    partial.fail("findmnt -n /mnt/pool")

    # metrics fail-closed: file written even in the broken state
    partial.succeed("systemctl start pool-recovery-metrics.service")
    partial.succeed(
      "grep -q 'pool_usb_recovery_mounted 0' /var/lib/prometheus-node-exporter/textfile_collectors/pool-recovery.prom"
    )
    partial.succeed(
      "grep -q 'pool_usb_recovery_members_present 1' /var/lib/prometheus-node-exporter/textfile_collectors/pool-recovery.prom"
    )

    # ---------- absent: 0 members → clean exit, no failed unit ----------
    absent.wait_for_unit("multi-user.target")
    absent.succeed("systemctl start pool-usb-recovery.service")  # must NOT fail
    absent.fail("systemctl is-failed --quiet pool-usb-recovery.service")
    result = absent.succeed("systemctl show -p Result --value pool-usb-recovery.service").strip()
    assert result == "success", f"absent-node recovery should exit success, got {result}"
    absent.succeed("journalctl -u pool-usb-recovery.service | grep -q 'no pool members'")

    # metrics still fail-closed with the drive gone
    absent.succeed("systemctl start pool-recovery-metrics.service")
    absent.succeed(
      "grep -q 'pool_usb_recovery_mounted 0' /var/lib/prometheus-node-exporter/textfile_collectors/pool-recovery.prom"
    )
    absent.succeed(
      "grep -q 'pool_usb_recovery_members_present 0' /var/lib/prometheus-node-exporter/textfile_collectors/pool-recovery.prom"
    )
  '';
}
