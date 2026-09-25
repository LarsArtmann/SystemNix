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
{
  pkgs,
  lib ? pkgs.lib,
  inputs,
}:
let
  # Device-override wrapper: the spec file pins by-id, the rehearsal
  # targets the blank vdisk (emptyDiskImages attach at /dev/vdb). Built by
  # PLAIN attrset override + serialization — a second module overriding
  # `device` breaks disko's deviceType dispatch (content resolves to null,
  # dry-run-proven).
  spec = import ../disko/samsung-tlc.nix;
  overridden = spec // {
    disko.devices.disk.samsung-tlc = spec.disko.devices.disk.samsung-tlc // {
      device = "/dev/vdb";
    };
  };
  # The disko SCRIPT is evaluated HOST-SIDE with our locked nixpkgs — the
  # CLI inside the VM would re-evaluate against a fresh <nixpkgs> and try
  # to build a whole stdenv offline (no network in the guest).
  # The overridden spec goes to disko's lib DIRECTLY (same dispatch as the
  # old cli.nix route: `mode = "destroy,format,mount"` with a diskoFile
  # resolves to `_cliDestroyFormatMount`). cli.nix's diskoFile route imports
  # a `writeText` OUTPUT, and `import` of a derivation path forces
  # realization at eval — `path '...vm.nix.drv' is not valid` after any
  # nixpkgs bump that invalidates the text drv (dead pre-commit gate
  # 2026-09-24..25). Pure attrset in, pure eval out.
  diskoLib = import "${inputs.disko}" {
    inherit lib;
    rootMountPoint = "/mnt";
  };
  diskoScript = diskoLib._cliDestroyFormatMount overridden pkgs;
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
        diskoScript
      ];
      system.stateVersion = "25.11";
    };

  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")

    # Apply the FULL destructive chain to the blank vdisk — the rescue path.
    machine.succeed("disko-destroy-format-mount --yes-wipe-all-disks")

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
