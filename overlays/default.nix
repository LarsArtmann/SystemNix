inputs @ {nur, ...}: let
  mkPackageOverlay = input: name: overrides: _final: prev: let
    pkg = input.packages.${prev.stdenv.system}.default;
  in {
    ${name} =
      if overrides == {}
      then pkg
      else pkg.overrideAttrs overrides;
  };

  shared = import ./shared.nix (inputs // {inherit mkPackageOverlay;});
  linux = import ./linux.nix (inputs // {inherit mkPackageOverlay;});
in {
  inherit mkPackageOverlay;

  disableTests = _final: prev: {
    valkey = prev.valkey.overrideAttrs (_old: {doCheck = false;});
    aiocache = prev.python3Packages.aiocache.overrideAttrs (_old: {doCheck = false;});
  };

  pythonTest = _final: prev: {
    python313Packages = prev.python313Packages.overrideScope (_pyFinal: pyPrev: {
      timm = pyPrev.timm.overridePythonAttrs (_: {doCheck = false;});
      xformers = pyPrev.xformers.overridePythonAttrs (_: {doCheck = false;});
    });
  };

  sharedOverlays = [nur.overlays.default] ++ shared;

  linuxOnlyOverlays = linux;
}
