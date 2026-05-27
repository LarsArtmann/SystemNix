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
  (mkPackageOverlay dnsblockd "dnsblockd" {vendorHash = "sha256-FFcULtnmNhIJr392vRYGqZ+lvW300HWvzQoEJZj8pWw=";})
  emeet-pixyd.overlays.default
  monitor365.overlays.default
  netwatchOverlay
  (mkPackageOverlay file-and-image-renamer "file-and-image-renamer" {vendorHash = "sha256-of+ynTDQ5ahN+6vJFM9mrNNE3je4bCnLaF3O2j0Zo88=";})
]
