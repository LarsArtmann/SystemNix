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
  mkPackageOverlay,
  ...
}: let
  awWatcherOverlay = _final: prev: {
    aw-watcher-utilization = prev.callPackage ../pkgs/aw-watcher-utilization.nix {};
  };

  jscpdOverlay = _final: prev: {
    jscpd = prev.callPackage ../pkgs/jscpd.nix {};
  };

  govalidOverlay = _final: prev: {
    govalid = prev.callPackage ../pkgs/govalid.nix {};
  };

  todoListAiFixedHash = "sha256-LBN8P0SNnPSbJ7VnupopreSpblyLRi8ffn+XJ8D6rck=";

  todoListAiOverlay = _final: prev: let
    bun = prev.bun;
    upstream = todo-list-ai.packages.${prev.stdenv.system}.default;
    patchedDeps = prev.stdenv.mkDerivation {
      name = "todo-list-ai-deps";
      src = upstream.src;
      nativeBuildInputs = [bun];
      buildPhase = "bun install";
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
  (mkPackageOverlay library-policy "library-policy" {})
  (mkPackageOverlay hierarchical-errors "hierarchical-errors" {vendorHash = "sha256-imjTscWHsv2zw7OegiTiDHoKWSCM/Lamff5nzYrECEE=";})
  (mkPackageOverlay golangci-lint-auto-configure "golangci-lint-auto-configure" {})
  (mkPackageOverlay mr-sync "mr-sync" {vendorHash = "sha256-AXdOv79YtYsB+xYYDupRiIoTGaFIuD+hXWsjTb6OFE4=";})
  (mkPackageOverlay buildflow "buildflow" {vendorHash = "sha256-Lk0TCWmHVm0wTN1DutV1/p+ZsUhIXcwtn9Z7PgYTMhI=";})
  (mkPackageOverlay go-auto-upgrade "go-auto-upgrade" {})
  (mkPackageOverlay go-structure-linter "go-structure-linter" {vendorHash = "sha256-yUsGTYS58gQNre7D0ZPaMsQPjR3NZVa1e6aSdcPs8T8=";})
  (mkPackageOverlay branching-flow "branching-flow" {})
  (mkPackageOverlay art-dupl "art-dupl" {})
  (mkPackageOverlay projects-management-automation "projects-management-automation" {vendorHash = "sha256-SHqeKngo0k2YWKZfB+2OiFGysPLo/oZzVXr6SmN8nK0=";})
  d2DarwinOverlay
]
