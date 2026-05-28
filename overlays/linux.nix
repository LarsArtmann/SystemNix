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
  (mkPackageOverlay dnsblockd "dnsblockd" {})
  emeet-pixyd.overlays.default
  monitor365.overlays.default
  netwatchOverlay
  (mkPackageOverlay file-and-image-renamer "file-and-image-renamer" {})
]
