# qmd — on-device hybrid search engine for markdown notes
# (BM25 + vector embeddings + LLM reranking, all local via node-llama-cpp).
#
# Built from upstream GitHub source using pnpmConfigHook + the real
# pnpm-lock.yaml. The npm tarball is a prebuilt distribution artifact; this
# derivation is closer to Nix conventions: VCS source, lockfile-driven install,
# and a build step that produces dist/ from TypeScript.
#
# Build-time details:
#   - pnpmConfigHook installs all dependencies (including devDependencies) from
#     the offline pnpm store so `pnpm run build` can invoke the TypeScript compiler.
#   - `pnpm run build` emits dist/ and adds the Node shebang to dist/cli/qmd.js.
#   - Runtime only needs bin/, dist/, skills/, node_modules/, and package.json.
#   - Native dependencies (better-sqlite3, sqlite-vec, node-llama-cpp) are
#     installed from the lockfile; prebuilt optionalDependencies are preferred.
#     If a sandbox blocks a prebuilt download, the package falls back to compiling
#     from source, which is why build tools (python3, node-gyp, gcc) are included.
#
# CPU-only is the safe default at runtime — GPU selection is delegated to the
# QMD_LLAMA_GPU / QMD_FORCE_CPU env vars set by the service module.
{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchPnpmDeps,
  nodejs,
  pnpm,
  pnpmConfigHook,
  autoPatchelfHook,
  makeWrapper,
  python3,
  node-gyp,
  pkg-config,
  gcc,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "qmd";
  version = "2.5.3";

  src = fetchFromGitHub {
    owner = "tobi";
    repo = "qmd";
    rev = "v${finalAttrs.version}";
    hash = "sha256-bFk078qQ8Ha/1na+r5ka6yNPI/Pealh0Rk6hJxKBwNs=";
  };

  nativeBuildInputs =
    [
      nodejs
      pnpm
      pnpmConfigHook
      makeWrapper
      python3
      node-gyp
      gcc
    ]
    ++ lib.optionals stdenv.isLinux [
      autoPatchelfHook
      pkg-config
    ];

  # Lockfile-driven dependency store. The hash covers the offline pnpm store
  # contents, not the built node_modules. Run `nix build .#qmd` once with an
  # empty hash to discover the correct value.
  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    inherit pnpm;
    fetcherVersion = 4;
    hash = "sha256-4Nvsfo3JmMj+vPQZLjigV+DNX5JYMA8tI3IIXJbDM30=";
  };

  # node-llama-cpp ships optional GPU backends for Vulkan/CUDA/Metal. We
  # default to CPU inference (QMD_FORCE_CPU=1), so these shared libraries are
  # intentionally NOT in the closure. Tell autoPatchelfHook to ignore them.
  autoPatchelfIgnoreMissingDeps = [
    "libvulkan.so.1"
    "libcudart.so.12"
    "libcudart.so.13"
    "libcublas.so.12"
    "libcublas.so.13"
    "libcuda.so.1"
  ];

  buildPhase = ''
    runHook preBuild
    pnpm run build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/qmd $out/bin

    # Copy only the runtime artifacts that the published package includes.
    # src/ and test/ are build-time only and would bloat the closure.
    cp -r package.json node_modules $out/lib/qmd/
    cp -r bin $out/lib/qmd/
    cp -r dist $out/lib/qmd/
    cp -r skills $out/lib/qmd/

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
