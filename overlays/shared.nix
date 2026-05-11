{
  todo-list-ai,
  library-policy,
  golangci-lint-auto-configure,
  mr-sync,
  hierarchical-errors,
  buildflow,
  go-auto-upgrade,
  go-structure-linter,
  branching-flow,
  art-dupl,
  ...
}: let
  awWatcherOverlay = _final: prev: {
    aw-watcher-utilization = prev.callPackage ../pkgs/aw-watcher-utilization.nix {};
  };

  jscpdOverlay = _final: prev: {
    jscpd = prev.callPackage ../pkgs/jscpd.nix {};
  };

  todoListAiFixedHash = "sha256-gK2KiswUrC4iym1X0r8Ykof1H8Fb2keBsc9X0PPQPPU=";

  todoListAiOverlay = _final: prev: let
    bun = prev.bun;
    upstream = todo-list-ai.packages.${prev.stdenv.system}.default;
    patchedDeps = prev.stdenv.mkDerivation {
      name = "todo-list-ai-deps";
      src = upstream.src;
      nativeBuildInputs = [bun];
      buildPhase = "bun install --frozen-lockfile";
      installPhase = "rm -rf node_modules/.cache && cp -r node_modules $out";
      outputHashAlgo = "sha256";
      outputHashMode = "recursive";
      outputHash = todoListAiFixedHash;
      dontFixup = true;
    };
  in {
    todo-list-ai = upstream.overrideAttrs (_: {
      buildPhase = ''
        runHook preBuild
        cp -r ${patchedDeps} node_modules
        chmod -R u+w node_modules
        find node_modules -type f -exec grep -q '^#!/usr/bin/env node' {} \; -print0 \
          | xargs -0 -r sed -i '1s|^#!/usr/bin/env node|#!${bun}/bin/bun|'
        patchShebangs node_modules/.bin

        bun build ./index.ts --compile --outfile ./dist/todo-list-ai
        runHook postBuild
      '';
    });
  };

  libraryPolicyOverlay = _final: prev: {
    library-policy = library-policy.packages.${prev.stdenv.system}.default;
  };

  hierarchicalErrorsOverlay = _final: prev: {
    hierarchical-errors = hierarchical-errors.packages.${prev.stdenv.system}.default;
  };

  golangciLintAutoConfigureOverlay = _final: prev: {
    golangci-lint-auto-configure = golangci-lint-auto-configure.packages.${prev.stdenv.system}.default;
  };

  mrSyncOverlay = _final: prev: {
    mr-sync = mr-sync.packages.${prev.stdenv.system}.default;
  };

  d2DarwinOverlay = _final: prev:
    prev.lib.optionalAttrs prev.stdenv.isDarwin {
      d2 = prev.callPackage (prev.path + "/pkgs/by-name/d2/d2/package.nix") {
        libgbm = prev.runCommand "libgbm-stub" {} "mkdir $out";
        playwright-driver = {browsers = prev.runCommand "playwright-stub" {} "mkdir $out";};
      };
    };
in [
  awWatcherOverlay
  todoListAiOverlay
  jscpdOverlay
  libraryPolicyOverlay
  buildflow.overlays.default
  go-auto-upgrade.overlays.default
  go-structure-linter.overlays.default
  branching-flow.overlays.default
  art-dupl.overlays.default
  golangciLintAutoConfigureOverlay
  mrSyncOverlay
  hierarchicalErrorsOverlay
  d2DarwinOverlay
]
