# VM test for services.hot-db (Samsung hot-DB tier module).
#
# Verifies the runtime behavior eval CANNOT check:
#   1. The bootstrap oneshot creates the `hot/<name>` subvolume on a REAL
#      btrfs disk before the generated mount comes up (fstab cannot create
#      subvolumes — ordering proof).
#   2. The generated entry mounts AT the dataDir with nodatacow effective
#      (mount option present in /proc/mounts + chattr +C visible via lsattr
#      on the subvolume root).
#   3. The consumer (wired via `unit`) writes successfully — proves
#      RequiresMountsFor ordering (mount before service).
#   4. Anti-shadow: after a manual unmount (simulating a detached
#      Samsung), the consumer condition-skips (ConditionResult=no) instead
#      of writing into a root-fs shadow dir.
#   5. Bootstrap is idempotent (second run creates nothing new, exits 0).
#
# VM-trap notes:
#   - qemu-vm.nix replaces the WHOLE `fileSystems` option via mkVMOverride
#     whenever `virtualisation.fileSystems != {}` — so both the toplevel
#     /mnt/hot mount AND a copy of the module-generated entry mount are
#     declared under virtualisation.fileSystems (test-cv pool-fmt pattern).
#   - The disk must be formatted BEFORE the by-label mount units start
#     (pool-fmt: wantedBy + before local-fs.target and the mount units).
{
  pkgs,
  ...
}:
let
  hotDbModule = (import ../modules/nixos/services/hot-db.nix).flake.nixosModules.hot-db;

  entryPath = "/var/lib/hotdb-test";
  entryMount =
    {
      device = "/dev/disk/by-label/tlc";
      fsType = "btrfs";
      options = [
        "subvol=hot/testdb"
        "noatime"
        "nodiscard"
        "space_cache=v2"
        "nofail"
        "nodatacow"
      ];
    };
in
{
  name = "hot-db";

  nodes.machine =
    { lib, ... }:
    {
      imports = [ hotDbModule ];

      boot.supportedFilesystems = [ "btrfs" ];
      virtualisation.emptyDiskImages = [ 512 ];
      virtualisation.fileSystems = {
        "/mnt/hot" = {
          device = "/dev/disk/by-label/tlc";
          fsType = "btrfs";
          options = [
            "subvolid=5"
            "noatime"
            "nodiscard"
            "space_cache=v2"
            "nofail"
          ];
        };
        "/var/lib/hotdb-test" = entryMount;
      };

      services.hot-db = {
        enable = true;
        entries.testdb = {
          inherit path;
          cow = false;
          unit = "hotdb-consumer.service";
        };
      };

      # Probe consumer: writes into the mounted dataDir. Succeeding at all
      # proves the mount came up first (RequiresMountsFor).
      systemd.services.hotdb-consumer = {
        description = "Hot-DB probe consumer";
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          echo probe > ${entryPath}/probe.txt
        '';
      };

      # Format the virtio disk as btrfs label `tlc` (production label)
      # before any by-label mount unit can start.
      systemd.services.tlc-fmt = {
        description = "Format the virtio disk as btrfs label tlc (test-only)";
        wantedBy = [ "local-fs.target" ];
        before = [
          "mnt-hot.mount"
          "-var-lib-hotdb-test.mount"
          "local-fs.target"
        ];
        serviceConfig = {
          Type = "oneshot";
          User = "root";
        };
        path = [
          pkgs.btrfs-progs
          pkgs.util-linux
        ];
        script = ''
          if ! blkid /dev/vdb | grep -q 'LABEL="tlc"'; then
            mkfs.btrfs -f -L tlc /dev/vdb
          fi
        '';
      };
    };

  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")

    # 1+2: subvolume exists and is mounted AT the dataDir, nodatacow live.
    machine.succeed("btrfs subvolume show /var/lib/hotdb-test")
    machine.succeed("grep -q nodatacow /proc/mounts")
    machine.succeed("btrfs subvolume list /mnt/hot | grep -q 'hot/testdb'")

    # chattr +C landed on the fresh subvolume root (fresh-subvol
    # inheritance does NOT carry the flag — the bootstrap sets it).
    machine.succeed("lsattr -d /mnt/hot/hot/testdb | grep -q -- --C")

    # 3: consumer wrote through the mount.
    machine.wait_for_unit("hotdb-consumer.service")
    machine.succeed("test -f /var/lib/hotdb-test/probe.txt")

    # 5: bootstrap idempotent — second run adds nothing, exits 0.
    machine.succeed("systemctl restart hot-db-bootstrap")
    machine.succeed(
        "systemctl is-failed hot-db-bootstrap && exit 1 || true"
    )
    count = machine.succeed("btrfs subvolume list /mnt/hot | grep -c 'hot/testdb'").strip()
    assert count == "1", f"expected exactly one hot/testdb subvol, got {count}"

    # 4: anti-shadow — unmount (detached-Samsung shape). The mount is
    # nofail so nothing else fails; the consumer must condition-SKIP
    # rather than write into the plain dir left behind.
    machine.succeed("umount /var/lib/hotdb-test")
    machine.succeed("systemctl stop hotdb-consumer.service")
    machine.succeed("systemctl start hotdb-consumer.service")
    cond = machine.succeed("systemctl show -p ConditionResult -o cat hotdb-consumer.service").strip()
    assert cond == "not-started", f"consumer condition did not skip (ConditionResult={cond})"
    # The skip must leave NO shadow write.
    out = machine.succeed("ls -A /var/lib/hotdb-test || true")
    assert "probe.txt" not in out, f"shadow write detected: {out}"
  '';
}
