inputs @ {nur, ...}: {
  shared = import ./shared.nix inputs;

  linux = import ./linux.nix inputs;

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

  sharedOverlays = [nur.overlays.default] ++ (import ./shared.nix inputs);

  linuxOnlyOverlays = import ./linux.nix inputs;
}
