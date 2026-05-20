{
  lib,
  stdenv,
  fetchzip,
  fetchPnpmDeps,
  nodejs,
  pnpm,
  pnpmConfigHook,
  makeWrapper,
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
    makeWrapper
  ];

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version;
    src = stdenv.mkDerivation {
      name = "${finalAttrs.pname}-${finalAttrs.version}-with-lockfile";
      inherit (finalAttrs) src;
      dontBuild = true;
      installPhase = ''
        cp -r $src $out
        chmod -R u+w $out
        cp ${./jscpd-pnpm-lock.yaml} $out/pnpm-lock.yaml
      '';
    };
    fetcherVersion = 3;
    hash = "sha256-Mlax/TNyx2TkMiZKOvo1Z661hww3T2YH0dQ8cwAQjDc=";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/lib/jscpd
    cp -r . $out/lib/jscpd/
    makeWrapper ${nodejs}/bin/node $out/bin/jscpd \
      --add-flags $out/lib/jscpd/bin/jscpd
    runHook postInstall
  '';

  meta = {
    description = "Copy/paste detector for programming source code";
    homepage = "https://github.com/kucherenko/jscpd";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
    mainProgram = "jscpd";
  };
})
