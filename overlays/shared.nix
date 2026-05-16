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
  projects-management-automation,
  ...
}: let
  mkPackageOverlay = input: name: _final: prev: {
    ${name} = input.packages.${prev.stdenv.system}.default;
  };

  awWatcherOverlay = _final: prev: {
    aw-watcher-utilization = prev.callPackage ../pkgs/aw-watcher-utilization.nix {};
  };

  jscpdOverlay = _final: prev: {
    jscpd = prev.callPackage ../pkgs/jscpd.nix {};
  };

  govalidOverlay = _final: prev: {
    govalid = prev.callPackage ../pkgs/govalid.nix {};
  };

  todoListAiFixedHash = "sha256-1rKZziEfR9jX1XRMu2Zc5MpOi6voclbbUndQf120nkE=";

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
  govalidOverlay
  (mkPackageOverlay library-policy "library-policy")
  (mkPackageOverlay hierarchical-errors "hierarchical-errors")
  (mkPackageOverlay golangci-lint-auto-configure "golangci-lint-auto-configure")
  (mkPackageOverlay mr-sync "mr-sync")
  (mkPackageOverlay buildflow "buildflow")
  (mkPackageOverlay go-auto-upgrade "go-auto-upgrade")
  (mkPackageOverlay go-structure-linter "go-structure-linter")
  (mkPackageOverlay branching-flow "branching-flow")
  (mkPackageOverlay art-dupl "art-dupl")
  (mkPackageOverlay projects-management-automation "projects-management-automation")
  d2DarwinOverlay
]
