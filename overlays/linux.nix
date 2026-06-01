{
  dnsblockd,
  emeet-pixyd,
  monitor365,
  file-and-image-renamer,
  mkPackageOverlay,
  ...
}: let
  openaudibleOverlay = _final: prev: {
    openaudible = prev.callPackage ../pkgs/openaudible.nix {};
  };

  netwatchOverlay = _final: prev: {
    netwatch = prev.callPackage ../pkgs/netwatch.nix {};
  };
in [
  openaudibleOverlay
  (mkPackageOverlay dnsblockd "dnsblockd" {vendorHash = "sha256-1JzuMdW1ujWeIx7FoL1hkQHa739AMxWDM4HH3S2c68g=";})
  (mkPackageOverlay emeet-pixyd "emeet-pixyd" {vendorHash = "sha256-jdt9WWOiRcEhJd9iqIcbJzGtQY7GOqzJJvJulzLAzNI=";})
  monitor365.overlays.default
  netwatchOverlay
  (mkPackageOverlay file-and-image-renamer "file-and-image-renamer" {})
]
