{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchPnpmDeps,
  nodejs,
  pnpm,
  pnpmConfigHook,
  autoPatchelfHook,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "openseo";
  version = "0.0.26";

  src = fetchFromGitHub {
    owner = "every-app";
    repo = "open-seo";
    rev = "v${finalAttrs.version}";
    hash = "sha256-QoneI22o7GYUNfQ+sSFq2kEx/GNv7SMIbfqo11L4/Y0=";
  };

  nativeBuildInputs = [
    nodejs
    pnpm
    pnpmConfigHook
    autoPatchelfHook
  ];

  # Native libraries needed by node_modules native addons (sharp, libsql, lightningcss, etc.)
  buildInputs = [
    stdenv.cc.cc.lib
  ];

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version;
    inherit (finalAttrs) src;
    fetcherVersion = 4;
    hash = "sha256-2aGxcFzezCke22IVFW4IDxlMWlakw0x0RzPXwCaoKjA=";
  };

  # Provide native libraries at build time so vite/wrangler/workerd can load native addons.
  # autoPatchelfHook handles final patching in postFixup (no /build/ references).
  preBuild = ''
    export LD_LIBRARY_PATH="${
      lib.makeLibraryPath [ stdenv.cc.cc.lib ]
    }''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  '';

  buildPhase = ''
    runHook preBuild

    # AUTH_MODE is inlined into the client bundle by vite (via envPrefix).
    # SystemNix always uses local_noauth.
    AUTH_MODE=local_noauth \
    VITE_SHOW_DEVTOOLS=false \
    NODE_OPTIONS=--max-old-space-size=4096 \
    pnpm run build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/openseo

    # Copy the entire built project (node_modules + dist + source + config)
    cp -r . $out/lib/openseo/

    # Remove build-time .wrangler state — runtime state goes to StateDirectory
    rm -rf $out/lib/openseo/.wrangler

    runHook postInstall
  '';

  meta = {
    description = "OpenSEO — self-hosted SEO suite (keyword research, rank tracking, audits)";
    homepage = "https://github.com/every-app/open-seo";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
})
