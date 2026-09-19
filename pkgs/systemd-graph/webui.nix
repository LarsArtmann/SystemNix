{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpm,
  nodejs_24,
  pnpmConfigHook,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "systemd-graph-webui";
  version = "0-unstable-2026-06-08";

  src = fetchFromGitHub {
    owner = "icholy";
    repo = "systemd-graph";
    rev = "601521bda0303f44fd53637ed74f50161ff23d99";
    hash = "sha256-yb3w6/5UTI1ghY1/jl1PTma9wi9aEumNAG04FeHg8fY=";
  };
  sourceRoot = "source/webui";

  nativeBuildInputs = [
    pnpmConfigHook
    nodejs_24
    pnpm
  ];

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version;
    # fetchPnpmDeps runs yq on pnpm-lock.yaml from THIS src, not from
    # sourceRoot. Point it directly at webui/ inside the source archive.
    src = "${finalAttrs.src}/webui";
    fetcherVersion = 4;
    hash = "sha256-zZQ2/PqdeK1F/KV+NiKieCbmmzi9x4zpOteQuQTCCxU=";
  };

  # pnpmConfigHook (in nativeBuildInputs) runs in postConfigure and handles
  # `pnpm install --offline --ignore-scripts --frozen-lockfile` with the
  # correct pnpm 11 settings (trust_lockfile, store-dir from pnpmDeps).
  # We must NOT set dontConfigure — that skips postConfigureHooks and the
  # hook never fires, leaving deps uninstalled.
  buildPhase = ''
    runHook preBuild

    pnpm build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -R dist/. $out/

    runHook postInstall
  '';

  meta = with lib; {
    description = "Pre-built React SPA for systemd-graph";
    license = licenses.mit;
    platforms = platforms.all;
  };
})
