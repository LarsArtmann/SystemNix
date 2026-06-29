lib: {
  device,
  fsType,
  options ? [],
  ...
}: let
  # Catch cross-filesystem option contamination — using options that are
  # only valid on one fs type on a different fs type.
  #
  # Example: `discard=async` is btrfs-only. On ext4 it causes
  # `fsconfig() failed: ext4: Unexpected value for 'discard'` →
  # mount failure → local-fs.target failure → emergency shell.
  #
  # Each entry: { optionPrefix, validFsTypes, description }
  dangerousOptions = [
    {
      prefix = "discard=async";
      validFsTypes = ["btrfs"];
      desc = "BTRFS-only async TRIM. ext4/xfs use bare discard.";
    }
    {
      prefix = "space_cache=v2";
      validFsTypes = ["btrfs"];
      desc = "BTRFS free-space tree cache mode.";
    }
    {
      prefix = "space_cache=v1";
      validFsTypes = ["btrfs"];
      desc = "BTRFS free-space tree cache mode.";
    }
    {
      prefix = "compress";
      validFsTypes = ["btrfs"];
      desc = "BTRFS transparent compression.";
    }
    {
      prefix = "compress=zstd";
      validFsTypes = ["btrfs"];
      desc = "BTRFS transparent compression.";
    }
    {
      prefix = "compress=zstd:3";
      validFsTypes = ["btrfs"];
      desc = "BTRFS transparent compression.";
    }
    {
      prefix = "compress=lzo";
      validFsTypes = ["btrfs"];
      desc = "BTRFS transparent compression.";
    }
    {
      prefix = "subvol";
      validFsTypes = ["btrfs"];
      desc = "BTRFS subvolume selection.";
    }
    {
      prefix = "ssd";
      validFsTypes = ["btrfs"];
      desc = "BTRFS SSD optimizations.";
    }
    {
      prefix = "reflink";
      validFsTypes = [
        "btrfs"
        "xfs"
      ];
      desc = "Copy-on-write reflink support.";
    }
    {
      prefix = "nodiscard";
      validFsTypes = [
        "ext4"
        "btrfs"
        "xfs"
      ];
      desc = "Disable TRIM.";
    }
  ];

  violations =
    builtins.filter (
      {
        prefix,
        validFsTypes,
        desc,
      }:
        !builtins.elem fsType validFsTypes && builtins.any (opt: lib.hasPrefix prefix opt) options
    )
    dangerousOptions;

  violationMsg = builtins.concatStringsSep "\n  " (
    map (
      v: "option '${v.prefix}' is only valid on [${builtins.concatStringsSep ", " v.validFsTypes}] but used on ${fsType}: ${v.desc}"
    )
    violations
  );
in
  if violations != []
  then
    builtins.throw ''
      mkFilesystem: invalid mount options for ${fsType} on ${device}:
        ${violationMsg}''
  else {
    inherit device fsType options;
  }
