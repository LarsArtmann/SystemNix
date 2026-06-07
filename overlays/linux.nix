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
  (mkPackageOverlay dnsblockd "dnsblockd" {
    vendorHash = "sha256-ZKFAAtpWDN7Uu+GYyNQKVh0BmBvzD5WDHHLT25jBano=";
  })
  (mkPackageOverlay emeet-pixyd "emeet-pixyd" {vendorHash = "sha256-ItfLDPbCmZiFxmp8IBlt4nmxFxeLoC7my+qaYr4S46I=";})
  monitor365.overlays.default
  netwatchOverlay
  (mkPackageOverlay file-and-image-renamer "file-and-image-renamer" {})
]
