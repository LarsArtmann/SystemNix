inputs @ {nur, ...}: let
  shared = import ./shared.nix;
  linux = import ./linux.nix inputs;
in {
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
