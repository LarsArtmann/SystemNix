{
  lib,
  stdenv,
  fetchzip,
  fetchPnpmDeps,
  nodejs,
  pnpm,
  pnpmConfigHook,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "jscpd";
  version = "4.0.9";

  src = fetchzip {
    url = "https://registry.npmjs.org/jscpd/-/jscpd-${finalAttrs.version}.tgz";
    hash = "sha256-aF6cIYBnK/ffO/0LPjKZZ99LsG4jpSfE7NEwQAUqZFQ=";
  };

  postPatch = ''
    cp ${./jscpd-pnpm-lock.yaml} pnpm-lock.yaml
  '';

  nativeBuildInputs = [
    nodejs
    pnpm
    pnpmConfigHook
  ];

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    fetcherVersion = 3;
    hash = "";
  };

  dontBuild = true;

  meta = {
    description = "Copy/paste detector for programming source code";
    homepage = "https://github.com/kucherenko/jscpd";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
    mainProgram = "jscpd";
  };
})
