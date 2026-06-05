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

  emeetPixydOverlay = _final: prev: let
    pkg = emeet-pixyd.packages.${prev.stdenv.system}.default or null;
  in
    if pkg == null
    then {}
    else {
      emeet-pixyd = pkg.overrideAttrs (_old: {
        vendorHash = "sha256-jdt9WWOiRcEhJd9iqIcbJzGtQY7GOqzJJvJulzLAzNI=";
        postPatch = ''
          sed -i '/"github.com\/larsartmann\/httputil"/d' middleware.go
          sed -i 's/return httputil\.Chain(h, mws\.\.\.)/for i := len(mws) - 1; i >= 0; i-- {\n\t\th = mws[i](h)\n\t}\n\treturn h/' middleware.go
        '';
      });
    };
in [
  openaudibleOverlay
  (mkPackageOverlay dnsblockd "dnsblockd" {vendorHash = "sha256-1JzuMdW1ujWeIx7FoL1hkQHa739AMxWDM4HH3S2c68g=";})
  emeetPixydOverlay
  monitor365.overlays.default
  netwatchOverlay
  (mkPackageOverlay file-and-image-renamer "file-and-image-renamer" {})
]
