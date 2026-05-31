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
  (mkPackageOverlay dnsblockd "dnsblockd" {vendorHash = "sha256-AVT7xZotrhCV/n9yHwgC5uV1XZvTy7VfF8S2wt5jECg=";})
  (mkPackageOverlay emeet-pixyd "emeet-pixyd" {vendorHash = "sha256-i6aGyhzKRJs+cTvKAIJJwqGxLYz7lxzCF9ugWxsjIQ4=";})
  monitor365.overlays.default
  netwatchOverlay
  (mkPackageOverlay file-and-image-renamer "file-and-image-renamer" {})
]
