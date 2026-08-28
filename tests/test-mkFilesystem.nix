# Tests for lib/filesystems.nix mkFilesystem helper
# Run: nix eval --impure --file ./tests/test-mkFilesystem.nix
let
  flake = builtins.getFlake (toString /home/lars/projects/SystemNix);
  lib = flake.inputs.nixpkgs.lib;
  mkFilesystem = import ../lib/filesystems.nix lib;

  assertThrows = name: expr: {
    inherit name;
    passed = !(builtins.tryEval expr).success;
  };

  assertPass = name: expr: {
    inherit name;
    passed = (builtins.tryEval expr).success;
  };

  results = [
    # The original bug: discard=async on ext4 MUST throw
    (assertThrows "reject_discard_async_on_ext4" (mkFilesystem {
      device = "/dev/test";
      fsType = "ext4";
      options = [
        "noatime"
        "discard=async"
      ];
    }))

    # Bare discard on ext4 MUST pass
    (assertPass "accept_discard_on_ext4" (mkFilesystem {
      device = "/dev/test";
      fsType = "ext4";
      options = [
        "noatime"
        "discard"
        "nofail"
      ];
    }))

    # discard=async on btrfs MUST pass
    (assertPass "accept_discard_async_on_btrfs" (mkFilesystem {
      device = "/dev/test";
      fsType = "btrfs";
      options = [
        "discard=async"
        "compress=zstd"
        "subvol=@"
        "noatime"
      ];
    }))

    # subvol on ext4 MUST throw
    (assertThrows "reject_subvol_on_ext4" (mkFilesystem {
      device = "/dev/test";
      fsType = "ext4";
      options = ["subvol=@cache"];
    }))

    # compress on xfs MUST throw
    (assertThrows "reject_compress_on_xfs" (mkFilesystem {
      device = "/dev/test";
      fsType = "xfs";
      options = ["compress=zstd"];
    }))

    # space_cache=v2 on ext4 MUST throw
    (assertThrows "reject_space_cache_on_ext4" (mkFilesystem {
      device = "/dev/test";
      fsType = "ext4";
      options = ["space_cache=v2"];
    }))

    # No options at all MUST pass
    (assertPass "accept_no_options" (mkFilesystem {
      device = "/dev/test";
      fsType = "ext4";
    }))

    # Extra fileSystems attrs (neededForBoot, depends, …) MUST pass through.
    # The `…` pattern used to SILENTLY DROP them — accessing a dropped attr
    # throws "attribute missing", which tryEval turns into a failed test.
    (
      assertPass "passthrough_neededForBoot"
      (mkFilesystem {
        device = "/dev/test";
        fsType = "btrfs";
        options = ["subvol=@"];
        neededForBoot = true;
      }).neededForBoot
    )

    # The passed-through value must be the caller's, not clobbered
    (assertPass "passthrough_value_intact" (
      let
        fs = mkFilesystem {
          device = "/dev/test";
          fsType = "btrfs";
          options = ["subvol=@"];
          depends = ["/mnt/pool"];
        };
      in
        builtins.all (d: builtins.elem d fs.depends) ["/mnt/pool"]
    ))
  ];

  failures = builtins.filter (r: !r.passed) results;
in
  if failures == []
  then "All ${toString (builtins.length results)} tests passed ✓"
  else
    builtins.throw "${toString (builtins.length failures)} test(s) failed: ${
      builtins.concatStringsSep ", " (map (r: r.name) failures)
    }"
