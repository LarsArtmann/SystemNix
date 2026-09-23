# VM rehearsal of the disko rescue path (Phase-2 plan T17; item: disko config
# for the deferred reinstall).
#
# Applies diskoConfigurations.samsung-tlc to a BLANK vdisk in a VM and
# asserts the rendered layout (partitions, labels, subvolumes, mounts).
# This is the rescue/blank-disk rehearsal: destructive disko modes are
# proven here, never on disks with data.
#
# The real config pins the Samsung by-id (kernel enumeration flips); the
# test wraps it with a device override pointing at the empty vdisk — same
# spec, different device.
{ pkgs }:
let
  # Device-override wrapper: the spec file pins by-id, the rehearsal
  # targets the blank vdisk (emptyDiskImages attach at /dev/vdb).
  testConfig = pkgs.writeText "disko-samsung-tlc-vm.nix" ''
    { lib, ... }: {
      imports = [ ${../disko/samsung-tlc.nix} ];
      disko.devices.disk.samsung-tlc.device = lib.mkForce "/dev/vdb";
    }
  '';

  diskoCli = "${pkgs.disko}/bin/disko";
in
{
  name = "disko-layout";

  nodes.machine =
    { ... }:
    {
      virtualisation.emptyDiskImages = [ 8192 ];
      virtualisation.diskSize = 8192;
      boot.supportedFilesystems = [ "btrfs" ];
      environment.systemPackages = [
        pkgs.disko
        pkgs.btrfs-progs
      ];
      system.stateVersion = "25.11";
    };

  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")

    # Apply the FULL destructive chain to the blank vdisk — the rescue path.
    machine.succeed(
        "NIX_PATH=nixpkgs=${pkgs.path} ${diskoCli} --mode destroy,format,mount --yes-wipe-all-disks ${testConfig}"
    )

    # Partition geometry: p1 = 4G vfat SAMSUNG-EFI, p2 = btrfs tlc
    machine.succeed("blkid /dev/vdb1 | grep 'LABEL=\"SAMSUNG-EFI\"'")
    machine.succeed("blkid /dev/vdb1 | grep 'TYPE=\"vfat\"'")
    machine.succeed("blkid /dev/vdb2 | grep 'LABEL=\"tlc\"'")
    machine.succeed("blkid /dev/vdb2 | grep 'TYPE=\"btrfs\"'")

    # Subvolumes through the toplevel (subvolid=5) at /mnt/hot — never a
    # named subvolume itself (hot-db bootstrap creates hot/<name> through it)
    out = machine.succeed("btrfs subvolume list /mnt/hot")
    assert "nix" in out, f"missing /nix subvolume: {out}"
    assert "users/lars/cache/nix" in out, f"missing cache-nix subvolume: {out}"

    # Mountpoints per the spec
    machine.succeed("findmnt /mnt/hot")
    machine.succeed("findmnt /mnt/hot/nix")
    machine.succeed("findmnt /mnt/hot/users/lars/cache/nix")
    machine.succeed("findmnt -no SUBVOL /mnt/hot/nix | grep -x '/nix'")

    print("disko layout rehearsal OK")
  '';
}
