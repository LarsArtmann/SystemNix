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

  # Skip Nix's automatic pnpm build hook (`pnpmBuildHook`) — invoke pnpm
  # directly. We only need `pnpm build` (vite build), not the test/lint/dev
  # scripts the default hook might try to run.
  #
  # pnpm 11's default `verify-deps-before-run=true` re-queries the registry
  # for supply-chain metadata, which fails inside the Nix sandbox (DNS for
  # registry.npmjs.org is blocked). The deps are already in the offline
  # store from fetchPnpmDeps, so the verification is redundant. `--config.*`
  # flags override .npmrc / pnpm-lock.yaml settings for this invocation only.
  buildPhase = ''
    runHook preBuild

    pnpm install --frozen-lockfile \
      --config.verify-deps-before-run=false \
      --config.manage-package-manager-versions=false \
      --config.auto-install-peers=false
    pnpm build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -R dist/. $out/

    runHook postInstall
  '';

  dontConfigure = true;

  meta = with lib; {
    description = "Pre-built React SPA for systemd-graph";
    license = licenses.mit;
    platforms = platforms.all;
  };
})
