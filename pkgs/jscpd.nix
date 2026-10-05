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
    fetcherVersion = 4;
    # 2026-09-19: npm re-tagged a transitive dep in place (the django-polymorphic
    # playwright class), so the registry tarballs no longer match the hash
    # computed at commit time. Pin the measured content hash.
    # 2026-10-05: re-measured for the a7868a7 flake-update wave (nixpkgs
    # fetchPnpmDeps drift; src/lockfile unchanged).
    hash = "sha256-XrKNAT/xV7BT0Kd5aZZUnyTyRqozrotrk1arUIV5eX4=";
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
