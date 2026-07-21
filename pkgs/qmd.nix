# qmd — on-device hybrid search engine for markdown notes
# (BM25 + vector embeddings + LLM reranking, all local via node-llama-cpp).
#
# Packaged as a pure-Node pnpm build. The upstream npm tarball ships prebuilt
# JS with a `bin/qmd` shell wrapper, plus a package.json listing every
# transitive dep as a direct dependency. It does NOT ship a pnpm-lock.yaml —
# `fetchPnpmDeps` requires one to seed its offline pnpm store, so we wrap the
# npm tarball with a vendored lockfile (regenerated from package.json via
# `pnpm install --lockfile-only --prod`).
#
# Why wrapped-src: `fetchPnpmDeps` runs against `src` BEFORE patchPhase, so
# a copied lockfile via `postPatch` arrives too late. The fix (same as jscpd)
# is a derivation that copies the tarball and adds the lockfile, then point
# both `src` and `fetchPnpmDeps.src` at the wrapped output.
#
# Native dependencies:
#   - SQLite (better-sqlite3, sqlite-vec): prebuilt node-gyp binaries, install
#     via `optionalDependencies` per platform (sqlite-vec-linux-x64, etc.)
#   - node-llama-cpp: downloads model binaries from HuggingFace at first use
#   - tree-sitter-*: web-tree-sitter WASM grammars, no native compile needed
#   - autoPatchelfHook patches ELF RPATHs on Linux (noop on Darwin)
#
# CPU-only is the safe default — GPU selection is delegated to QMD_LLAMA_GPU
# / QMD_FORCE_CPU env vars at runtime. Vulkan probing on Strix Halo competes
# with Ollama for VRAM and isn't worth the brittleness.
#
# pnpm build uses --prod (skips devDeps = tsx, vitest, typescript) and
# --ignore-scripts (avoids sandbox-time compile of tree-sitter). The CLI
# wrapper script invokes node directly on dist/cli/qmd.js — no compile needed.
{
  lib,
  stdenv,
  fetchzip,
  fetchPnpmDeps,
  nodejs,
  pnpm,
  autoPatchelfHook,
  makeWrapper,
  perl,
  pkg-config,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "qmd";
  version = "2.5.3";

  # Wrap upstream tarball so pnpm-lock.yaml is present BEFORE fetchPnpmDeps
  # runs (the hook requires a lockfile to seed its offline store).
  src = stdenv.mkDerivation {
    name = "${finalAttrs.pname}-${finalAttrs.version}-with-lockfile";
    src = fetchzip {
      url = "https://registry.npmjs.org/@tobilu/qmd/-/qmd-${finalAttrs.version}.tgz";
      hash = "sha256-hdsZ3MYZibNFceWIKDVHGtYeyl0/RphpuOG0WQplfnE=";
    };
    dontBuild = true;
    dontConfigure = true;
    installPhase = ''
      cp -r $src $out
      chmod -R u+w $out
      cp ${./qmd-pnpm-lock.yaml} $out/pnpm-lock.yaml
    '';
  };

  nativeBuildInputs = [
    nodejs
    pnpm
    makeWrapper
  ]
  ++ lib.optionals stdenv.isLinux [
    autoPatchelfHook
    perl
    pkg-config
  ];

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm;
    fetcherVersion = 4;
    hash = "sha256-oVyRsxY2A+2KCGVsKPIiisfKuUgxSMEK046vzhc9VKk=";
  };

  # pnpmConfigHook is intentionally omitted: it runs `pnpm install` with
  # build scripts enabled, which tries to compile tree-sitter native addons
  # in the sandbox. Instead we install with --ignore-scripts — the prebuilt
  # optionalDependencies (sqlite-vec-linux-x64, sqlite-vec-darwin-arm64, etc.)
  # install platform binaries without compilation.
  buildPhase = ''
    runHook preBuild
    pnpm install --offline --frozen-lockfile --prod --ignore-scripts
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/qmd $out/bin
    cp -r . $out/lib/qmd/
    chmod -R u+w $out/lib/qmd

    makeWrapper ${nodejs}/bin/node $out/bin/qmd \
      --add-flags $out/lib/qmd/bin/qmd
    runHook postInstall
  '';

  meta = {
    description = "Query Markup Documents — on-device hybrid search for markdown with BM25, vector, and LLM reranking";
    longDescription = ''
      qmd indexes markdown notes, meeting transcripts, and documentation for
      fast keyword and semantic search. Combines SQLite FTS5 (BM25), vector
      embeddings via node-llama-cpp, and LLM reranking — fully local, no API
      keys required. Exposes both a CLI and an MCP server (stdio + HTTP).
    '';
    homepage = "https://github.com/tobi/qmd";
    license = lib.licenses.mit;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    mainProgram = "qmd";
  };
})
