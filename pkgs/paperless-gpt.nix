{
  lib,
  buildGoModule,
  buildNpmPackage,
  go_1_27,
  nodejs_24,
  src,
}:
# paperless-gpt — AI metadata enrichment + custom-field extraction for
# Paperless-ngx (github:icereed/paperless-gpt). Consumed by
# modules/nixos/services/paperless-gpt.nix (same callPackage + src input on
# both sites → identical store path) and exposed as `nix build .#paperless-gpt`.
#
# Build shape mirrors upstream's multi-stage Dockerfile:
#   1. npm stage: web-app (Vite + TS + React) → dist/
#   2. go stage: dist copied to web-app/dist, then `go build .`
#      (embedded_assets.go `//go:embed web-app/dist/*` REQUIRES dist in the
#      tree — it is not committed upstream)
#
# Runtime contract (module side): the binary writes prompts/, config/ and db/
# RELATIVE TO ITS WORKING DIRECTORY and copies prompt templates from
# default_prompts/ next to it — shipped under $out/share/paperless-gpt for a
# preStart copy into the state dir. CGO is REQUIRED (mattn/go-sqlite3).
#
# Keep `version` in sync with the tag-pinned input ref in flake.nix.
let
  version = "0.31.0";
  # Vite frontend embedded into the Go binary.
  frontend = buildNpmPackage {
    pname = "paperless-gpt-web";
    inherit version src;
    sourceRoot = "source/web-app";

    npmDepsHash = "sha256-6ZkO5pVQfJKYGpgUEKS/AXy/bfuot8cOJ2o+Z087HWM=";

    # cpu-features (transitive dev-dep: testcontainers -> ssh2) is a Nan
    # addon that no longer compiles on Node 24 and is never imported at
    # build time; vite/esbuild/swc ship prebuilt platform binaries via
    # optionalDependencies, so no install scripts are needed.
    npmFlags = [ "--ignore-scripts" ];

    # Upstream builds with node 24 (Dockerfile: node:24-alpine).
    nodejs = nodejs_24;

    # `npm run build` = `tsc -b && vite build --base=./` → dist/
    #
    # @swc/core 1.16 (pulled in by @vitejs/plugin-react-swc 4, new in
    # v0.31.0) ships self-loading compressed carriers: the first load
    # materializes the verified addon into a user cache and validates the
    # cache root's ANCESTOR permissions — the build sandbox's /build root
    # fails that check (ERR_SWC_NATIVE_CACHE: "cache root has a parent
    # writable by another user without trusted sticky protection"). Mode 0
    # materializes a unique temp image instead of a persistent cache, and
    # the skip-check opt-out exists for isolated trusted executors exactly
    # like the Nix sandbox (docs: native-addon-carriers.md).
    env = {
      SWC_NATIVE_BINDING_CACHE = "0";
      SWC_NATIVE_BINDING_CACHE_SKIP_SECURITY_CHECK = "1";
    };
    preBuild = ''
      echo "SWC-DIAG env: CACHE=$SWC_NATIVE_BINDING_CACHE SKIP=$SWC_NATIVE_BINDING_CACHE_SKIP_SECURITY_CHECK TMPDIR=$TMPDIR HOME=$HOME"
      node -e "try { require('@swc/core'); console.log('SWC-DIAG: core loads OK') } catch(e) { (e.cause||[]).forEach(function(c){ console.error('SWC-DIAG CAUSE:', c.code, String(c.message).split('\n')[0]) }); console.error('SWC-DIAG FAIL:', String(e.message).split('\n')[0]); process.exit(0) }"
    '';
    installPhase = ''
      runHook preInstall
      cp -r dist $out
      runHook postInstall
    '';

    meta = {
      description = "paperless-gpt web frontend (Vite build, embedded asset)";
      platforms = [ "x86_64-linux" ];
    };
  };

  buildGoModule' = buildGoModule.override { go = go_1_27; };
in
buildGoModule' {
  pname = "paperless-gpt";
  inherit version src;

  # go:embed needs web-app/dist present in the unpacked tree.
  postPatch = ''
    cp -r ${frontend} web-app/dist
    chmod -R u+w web-app/dist
  '';

  # go.mod requires go >= 1.27.1.
  vendorHash = "sha256-81a3B16v4rF8ut2HcT0w/KgT8XaZahQ3GPv/oEenXPk=";

  # Upstream tests are E2E (docker-compose paperless + LLM mock, pdfcpu
  # wants $HOME) — not hermetic. Binary verification happens via the
  # module's deploy smoke + version print, not here.
  doCheck = false;

  # mattn/go-sqlite3 (gorm local DB) needs CGO_ENABLED=1.
  env.CGO_ENABLED = 1;

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${version}"
    "-X main.commit=v${version}"
    "-X main.buildDate=1970-01-01T00:00:00Z"
  ];

  # Prompt templates the binary copies into prompts/ on first run
  # (loadTemplates reads default_prompts/<name> RELATIVE to its CWD).
  postInstall = ''
    mkdir -p $out/share/paperless-gpt
    cp -r default_prompts $out/share/paperless-gpt/
  '';

  meta = {
    description = "AI metadata enrichment + custom-field extraction for Paperless-ngx";
    homepage = "https://github.com/icereed/paperless-gpt";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "paperless-gpt";
  };
}
